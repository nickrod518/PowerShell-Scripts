# server
$server = $env:computername

# scope id we want the leases from
$scope = '10.20.192.168'

# displays the verbose messages which can help troubleshoot
$VerbosePreference = 'Continue'

# log path created using date
$log_date = (Get-Date).ToString('-yyyyMMdd-HHmm')
$scriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent
$log_file = "$scriptPath\logs\Copy-DHCPLeaseToFilter" + $log_date + ".log"
$log_file = New-Item -type file $log_file -Force

# get the active leases on the server
function Export-List () {
    Write-Verbose "Exporting active leases from $Script:server on scope $Script:scope..."
    $goodLeases = Get-DhcpServerv4Lease -Cn $Script:server -ScopeId $Script:scope -AllLeases | Where-Object { $_.AddressState -eq 'Active' }
    $leaseCount = $goodLeases.Count
    if ($leaseCount) {
        Write-Verbose "Successfully exported $leaseCount active leases!"
        Add-Content $Script:log_file "$(Get-Date) - Exported $listCount active leases from $Script:server."
    } else {
        Write-Verbose 'There were no active leases to export.'
        Add-Content $Script:log_file "$(Get-Date) -There were no active leases to export."
        exit
    }
    return $goodLeases
}

# export the good leases
$goodLeases = Export-List

# import the leases into the allow filter
Write-Verbose "Starting import of lease list on $server..."
$goodLeases | ForEach-Object { Add-DhcpServerv4Filter -Cn $server -MacAddress $_.ClientId -Description $_.HostName -List Allow -Force }

Write-Verbose 'Import complete!'
Add-Content $log_file "$(Get-Date) - Import complete."
