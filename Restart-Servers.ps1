Function Get-ServerList {
    Add-PSSnapin citrix* -ErrorAction SilentlyContinue | Out-Null
    Get-PSSnapin citrix* -ErrorAction SilentlyContinue | Out-Null
    $Groups = Get-XAWorkerGroup
    
    Write-Host "Select a server group to deploy to:`n"
    
    $Menu = @{}
    for ($i=1; $i -le $Groups.count; $i++) {
        Write-Host "$i. $($Groups[$i-1].WorkerGroupName)"
        $Menu.Add($i,($Groups[$i-1].WorkerGroupName))
    }

    [int]$Choice = (Read-Host 'Enter selection') - 1
    $Group = $Groups[$Choice]
    $Continue = Read-Host "You chose the $Group server group - Continue?"
    while("yes","no" -notcontains $Continue) {
    	$Continue = Read-Host "You chose the $Group server group - Continue?"
    }

    if ($Continue -eq 'no') {
        Exit
    }
    
    Return $Group.ServerNames
}

Function Restart ($ServerList) {
    # Log file
    $Date = (Get-Date).ToString('yyyyMMdd-HHmm')
    $LogFolder = New-Item -ItemType Directory "C:\Logs" -Force
    $Log = New-Item -ItemType File "$LogFolder\RestartServers-$Date.log" -Force
    
    $Count = $ServerList.Count
    $Counter = 0
    
    foreach ($Server in $ServerList) {
        Write-Progress -Activity "Processing Servers" -Status $Server -CurrentOperation "Testing connection..." -PercentComplete (($Counter / $Count) * 100)

	    if (Test-Connection $Server -Count 3) {
            Write-Progress -Activity "Processing Servers" -Status $Server -CurrentOperation "Rebooting server..." -PercentComplete (($Counter / $Count) * 100)
            Restart-Computer $Server -Force
            Add-Content $Log "$(Get-Date) $Server - rebooted."
            
	    } else {
            Write-Host "ERROR: Unable to Ping $Server." -ForegroundColor red
            Add-Content $Log "$(Get-Date) $Server - unable to ping."
        }
        $Counter++
    }
}

$ServerList = Get-ServerList
Restart $ServerList

Pause