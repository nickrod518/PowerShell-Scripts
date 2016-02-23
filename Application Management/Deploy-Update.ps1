function Write-Log {
    Param (
		[Parameter(Mandatory=$false)] $Message,
		[Parameter(Mandatory=$false)] $ErrorMessage,
		[Parameter(Mandatory=$false)] $Component,
        # Type: 1 = Normal, 2 = Warning (yellow), 3 = Error (red)
		[Parameter(Mandatory=$false)] [int]$Type,
		[Parameter(Mandatory=$true)] $LogFile
	)

	$Time = Get-Date -Format "HH:mm:ss.ffffff"
	$Date = Get-Date -Format "MM-dd-yyyy"
 
	if ($ErrorMessage -ne $null) {$Type = 3}
	if ($Component -eq $null) {$Component = " "}
	if ($Type -eq $null) {$Type = 1}
 
	$LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
	$LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LogFile
}

function Get-File {
    Param (
		[Parameter(Mandatory=$false)] $Computer
	)

    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.Title = 'Select a setup file to deploy'
    $OpenFileDialog.InitialDirectory = "C:\"
    $OpenFileDialog.Filter = "Setup File (*.msi, *.exe)| *.msi; *.exe"
    $OpenFileDialog.ShowHelp = $true
    $OpenFileDialog.ShowDialog() | Out-Null
    Get-Item $OpenFileDialog.FileName
}

function Get-ServerList {
    Add-PSSnapin citrix* -ErrorAction SilentlyContinue | Out-Null
    Get-PSSnapin citrix* -ErrorAction SilentlyContinue | Out-Null
    $Groups = Get-XAWorkerGroup
    
    Write-Host "Select a server group to deploy to:`n"
    
    $Menu = @{}
    Write-Host "1. Single Server"
    $Menu.Add(1, "Single Server")
    for ($i = 2; $i -le ($Groups.Count + 1); $i++) {
        Write-Host "$i. $($Groups[$i - 2].WorkerGroupName)"
        $Menu.Add($i, ($Groups[$i - 2].WorkerGroupName))
    }

    [int]$Choice = Read-Host "`nEnter selection"    
    while(-not $Menu.ContainsKey($Choice)) {
    	$Choice = Read-Host "Please choose a valid number from the list."
    }
    
    $Continue = Read-Host "`nYou chose $($Menu[$Choice]); continue (yes/no)?"
    while("yes","no" -notcontains $Continue) {
    	$Continue = Read-Host "You chose $($Menu[$Choice]); continue (yes/no)?"
    }

    if ($Continue -eq 'no') {
        Exit
    }
    
    CLS
    if ($Choice -ne 1) {
        Write-Host "Deploying to $($Menu[$Choice]):"
        $Group = $Groups | where { $_.WorkerGroupName -eq $Menu[$Choice] }
        $Group.ServerNames | ForEach-Object {
            Write-Host $_
        }
        Return $Group.ServerNames
    } else {
        $Computer = Read-Host "Enter the name of a server"
        Write-Host "Deploying to $Computer."
        Return $Computer
    }   
    
}

function Stage-Files {
    Param (
		[Parameter(Mandatory=$true)] $Setup,
		[Parameter(Mandatory=$true)] $Computer
	)

    # Create temp directory to store files
    $Temp = "\\$Computer\C$\Installs\$($Setup.BaseName)"
    New-Item -ItemType Directory -Path $Temp -Force

    # Copy over the setup file
	Copy-Item $Setup $Temp -Force

    if ($Setup.Extension -eq '.exe') {
        # Copy over the responses file
        try {
            Copy-Item ($Setup.FullName).Replace('.exe', '.iss') $Temp -Force
        } catch {
            Read-Host "ISS response file not found - press Enter to exit."
            Exit
        }
    }

    # Give a second to release any file locks
    Start-Sleep -Seconds 1
}

function Install-Setup {
    Param (
		[Parameter(Mandatory=$true)] $Setup,
		[Parameter(Mandatory=$true)] $Computer,
		[Parameter(Mandatory=$false)] $MSIOptions
	)

    # Start install job
	Invoke-Command -ComputerName $Computer -AsJob -JobName "Install-$($Setup.BaseName)" -ScriptBlock {
        param($Setup, $Computer, $MSIOptions, $DBUpdate)
    
        $SetupName = $Setup.Split('.')[0]
        $Extension = $Setup.Split('.')[1]
        $Temp = "\\$Computer\C$\Installs\$SetupName"
        
        # Put the server in install mode
        cmd /c change user /install | Out-Null
        
        if ($Extension -eq 'msi') {
            # Install the MSI and capture the results
            $Result = (Get-WmiObject -List | Where-Object -FilterScript {$_.Name -eq "Win32_Product"}).Install("$Temp\$SetupName.msi", $MSIOptions)
            $ExitCode = $Result.ReturnValue
        } else {
            # Start as a process and wait until finished
            $Result = Start-Process "$Temp\$SetupName.exe" -ArgumentList "/s /f1`"$Temp\$SetupName.iss`" /f2`"$Temp\$SetupName.log`"" -PassThru -Wait
            $ExitCode = $Result.ExitCode
        }

        # Put the server in execute mode
        cmd /c change user /execute | Out-Null
        
        # Clean up
        Remove-Item $Temp -Recurse -Force
        
        Return $ExitCode
    } -ArgumentList ($Setup.Name, $Computer, $MSIOptions)
}

Function Deploy {
    Param (
		[Parameter(Mandatory=$true)] $ServerList,
		[Parameter(Mandatory=$true)] $ThrottleLimit,
		[Parameter(Mandatory=$false)] $MSIOptions
	)

    # Get the setup file
    Write-Host "`nSelect a setup file to deploy..."
    try { $Setup = Get-File } catch { Exit }
    $Setup.Name
    
    # Log file
    $Date = (Get-Date).ToString('yyyyMMdd-HHmm')
    $LogFolder = New-Item -ItemType Directory ".\Logs" -Force
    $Log = New-Item -ItemType File "$LogFolder\$($Setup.BaseName)-$Date.log" -Force
    
    $LTCCAB = ''
    
    [int]$Count = $ServerList.Count
    $Counter = 0
    
    foreach ($Computer in $ServerList) {
        # Avoid dividing by zero on our progress bar when there's only one server
        if ($Count -eq 0) {
            $Progress = 100
        } else {
            $Progress = ($Counter / $Count) * 100
        }
        
        Write-Progress -Activity "Processing Servers" -Status $Computer -CurrentOperation "Testing connection..." -PercentComplete $Progress

	    if (Test-Connection $Computer -Count 3) {
            # Only allow as many jobs as the throttle limit allows
            while ((Get-Job -State Running).Count -ge $ThrottleLimit) {
                Write-Progress -Activity "Processing Servers" -Status "Throttle limit reached." -CurrentOperation "Waiting for jobs to finish..." -PercentComplete $Progress
                Start-Sleep -Seconds 1
            }
            
            # Stage files
            Write-Progress -Activity "Processing Servers" -Status $Computer -CurrentOperation "Staging files..." -PercentComplete $Progress
            Stage-Files -Setup $Setup -Computer $Computer
            
            # Install
            Write-Progress -Activity "Processing Servers" -Status $Computer -CurrentOperation "Creating install job..." -PercentComplete $Progress
            Install-Setup -Setup $Setup -Computer $Computer -MSIOptions $MSIOptions -DBUpdate $DBUpdate

	    } else {
            Write-Log -Message "Unable to establish connection." -Type 2 -Component $Computer -LogFile $Log
        }
        $Counter++
    }
    
    # Wait for all jobs to complete
    while ((Get-Job -State Running).Count -gt 0){
        [string]$Running = (Get-Job -State Running) | ForEach-Object { $_.Location }
        Write-Progress -Activity "Processing Jobs" -Status "Waiting on jobs to complete..." -CurrentOperation $Running
        Start-Sleep -Seconds 1
    }
    
    # Process jobs whenever they finish
    $Jobs = Get-Job -Name "Install-$($Setup.BaseName)"
    foreach ($Job in $Jobs) {
        Write-Progress -Activity "Processing Jobs" -Status "Gathering exit codes and validating installs..."
        
        $Computer = $Job.Location
        $ExitCode = Receive-Job $Job

        # Process exit codes
        if ($ExitCode -eq 0) {
            Write-Log -Message "Installation successful - exit code: $ExitCode" -Component $Computer -LogFile $Log
        } elseif ($ExitCode -eq 1641) {
            Write-Log -Message "Installation successful and computer is restarting - exit code: $ExitCode" -Component $Computer -LogFile $Log
        } elseif ($ExitCode -eq 3010) {
            Write-Log -Message "Installation successful and computer is being forced to restart - exit code: $ExitCode" -Component $Computer -LogFile $Log
		    Restart-Computer -ComputerName $Computer -Force
        } else {
            Write-Log -Message "Error during install - exit code: $ExitCode" -Type 3 -Component $Computer -LogFile $Log
        }
    }
}

$ServerList = Get-ServerList

<#
ThrottleLimit: Max parallel deployments
MSIOptions: Arguments to use when an MSI is selected
#>
Deploy -ServerList $ServerList -ThrottleLimit 5 -MSIOptions "ALLUSERS=1 REBOOT=ReallySuppress"

Read-Host 'Press Enter to view the log'

cmtrace $Log