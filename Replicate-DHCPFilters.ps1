# computer this script is run from is the source server to export from and from where all commands will be run
# must be running on 2012 or 8 for DHCP cmdlets to be supported
$sourceServer = $env:computername

# list of destination servers to import filter list to (separate each line by commas)
$servers = @(
'DHCP02',
'DHCP03',
'DHCP04'
)

# number of simultaneous jobs to run at one time - throttling is necessary to prevent the script from crashing
$maxJobs = 2

# displays the verbose messages which can help troubleshoot
$VerbosePreference = "Continue"

# log path created using date
$log_date = (Get-Date).ToString('-yyyyMMdd-HHmm')
$log_file = ".\logs\ReplicateDHCPFilters" + $log_date + ".log"

# check for log file and create if it doesn't exist
if (Test-Path ".\logs") {
    $log_file = New-Item -type file $log_file
} else {
    $log_file = New-Item -type file $log_file
}

# get the filter list from the designated server
function Export-List ($listType) {
    Write-Verbose "Exporting $listType list from $Script:sourceServer..."
    $list = Get-DhcpServerv4Filter -Cn $Script:sourceServer -List $listType
    $listCount = $list.Count
    if ($listCount) {
        Write-Verbose "Successfully exported $listCount $listType items from $Script:sourceServer!"
        Add-Content $Script:log_file "$(Get-Date) - Exported $listCount $listType items from $Script:sourceServer."
    } else {
        Write-Verbose "The $listType list on $Script:sourceServer was empty and will be ignored."
        Add-Content $Script:log_file "$(Get-Date) - The $listType list on $Script:sourceServer was empty and will be ignored."
    }
    return $list
}

# limit concurrent jobs
function Throttle-Jobs {
    param([int] $maxJobs)
    while ( (Get-Job -State Running | Measure-Object).Count -ge $maxJobs ) {
        Start-Sleep 1
    }
}

# clear completed jobs and add to log
function Clear-CompletedJobs {
    foreach ($job in Get-Job) {
        if ($job.State -eq "Completed") {
            Write-Verbose "$($job.Name) list import complete!"
            Add-Content $Script:log_file "$(Get-Date) - $($job.Name) list import complete."
            Remove-Job $job
        }
   }
}

# import the provided filter list onto designated server
# repeat until the item count on the destination matches the source list count
$importScript = {
    function Import-List ($server, $list, $listType, $log_file) {
        while ($list.Count -ne (Get-DhcpServerv4Filter -Cn $server -List $listType).Count) {
            $list | Add-DhcpServerv4Filter -Cn $server -List $listType -Force
        }
    }
}

# export the lists from the source server
$allow_list = Export-List Allow
$deny_list = Export-List Deny

# import lists on each destination server using background jobs
Write-Verbose "Starting import of filter lists on $($servers.Count) servers with $maxJobs asynchronous jobs..."
foreach ($server in $servers) {
    Throttle-Jobs $maxJobs
    Clear-CompletedJobs
    $script = {
        param($server, $list, $listType)
        Import-List $server $list $listType
    }
    if ($allow_list.Count) {
        Write-Verbose "Starting import of allow list on $server..."
        Start-Job -Name "$server allow" -Command $script -InitializationScript $importScript -Args $server, $allow_list, Allow | Out-Null
    }
    if ($deny_list.Count) {
        Write-Verbose "Starting import of deny list on $server..."
        Start-Job -Name "$server deny" -Command $script -InitializationScript $importScript -Args $server, $deny_list, Deny | Out-Null
    }
}

# watch the remaining jobs to complete
While (Get-Job) {
    Clear-CompletedJobs
    Start-Sleep 1
}

Write-Verbose "Replication complete!"
