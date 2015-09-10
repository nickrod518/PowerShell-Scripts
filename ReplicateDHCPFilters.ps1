# computer this script is run from is the source server to export from and from where all commands will be run
# must be running on 2012 or 8 for DHCP cmdlets to be supported
$sourceServer = $env:computername

# list of destination servers to import filter list to (separate each line by commas)
$servers = @(
'DHCP02',
'DHCP03',
'DHCP04'
)

# displays the verbose messages which can help troubleshoot
$VerbosePreference = "Continue"

# log path created using date
$log_date = ( Get-Date ).ToString('yyyyMMdd-HHmmss')
$time = Get-Date
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
        Add-Content $log_file "$time : Exported $listCount $listType items from $Script:sourceServer"
    } else {
        Write-Verbose "The $listType list on $Script:sourceServer was empty and will be ignored."
        Add-Content $Script:log_file "$Script:time : The $listType list on $Script:sourceServer was empty and will be ignored."
    }
    return $list
}

# import the provided filter list onto designated server
# repeat until the item count on the destination matches the source list count
function Import-List ($server, $list, $listType) {
    if ($list.Count) {
        Write-Verbose "Importing $listType list on $server..."
        while ($list.Count -ne (Get-DhcpServerv4Filter -Cn $server -List $listType).Count) {
            $list | Add-DhcpServerv4Filter -Cn $server -List $listType -Force
            Write-Verbose "$listType list import on $server failed... retrying..."
        }
        Add-Content $Script:log_file "$Script:time : Imported $listType list on $server"
    }
}

# export the lists from the source server
$allow_list = Export-List Allow
$deny_list = Export-List Deny

# import lists on each destination server
foreach ($server in $servers) {
    Import-List $server $allow_list Allow
    Import-List $server $deny_list Deny
}
