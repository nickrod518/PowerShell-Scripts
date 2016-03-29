function Get-ServerList {
    Add-PSSnapin citrix* -ErrorAction SilentlyContinue | Out-Null
    Get-PSSnapin citrix* -ErrorAction SilentlyContinue | Out-Null
    $Groups = Get-XAWorkerGroup
    
    Write-Host "Select a server group:`n"
    
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
    
    Clear-Host
    if ($Choice -ne 1) {
        Write-Host "You selected $($Menu[$Choice]):"
        $Group = $Groups | where { $_.WorkerGroupName -eq $Menu[$Choice] }
        $Group.ServerNames | ForEach-Object {
            Write-Host $_
        }
        Return $Group.ServerNames
    } else {
        $Server = Read-Host "Enter the name of a server"
        Write-Host "Deploying to $Server."
        Return $Server
    }   
}

function Set-ServiceRecoveryOptions {
    Param(
        [string] $Computers,
        [string] $ServiceName,
        [int] $Reset = 86400, # 24 hours
        [int] $Restart = 5000 # 5 seconds
    )

    foreach ($Computer in $Computers) {
        # Get the service on the remote computer
        $Service = Get-WMIObject win32_service -ComputerName $Computer | Where-Object { $_.Name -eq $ServiceName }
        
        if ($Service) {
            # More details on sc.exe found here - https://technet.microsoft.com/en-us/library/cc742019.aspx
            sc.exe \\$Computer failure $Service.Name reset= $Reset actions= restart/$Restart/restart/$Restart/restart/$Restart
            Write-Host "Recovery options set, exited with code: $LASTEXITCODE."
        } else {
            Write-Warning "Service: $ServiceName, not found on $Computer."
        }
    }
}

$Computers = Get-ServerList
$ServiceName = Read-Host 'Enter a service name you want to set recovery options for'

<#
    Parameters:
        Computers - computer(s) to set recovery options on
        ServiceName - name of service as it would appear for "Service name" under service properties
        Reset - seconds to wait before reset failure count is reset to 0
        Restart - milliseconds to wait before service is restarted after a failure
#>
Set-ServiceRecoveryOptions -Computers $Computers -ServiceName $ServiceName