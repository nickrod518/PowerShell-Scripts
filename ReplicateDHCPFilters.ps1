# source server that the lists will come from
$sourceServer = 'DHCP01'

# list of destination servers to export filter list to
$servers = @(
'server01',
'server02'
)

# displays the verbose messages which can help troubleshoot
$VerbosePreference = "Continue"

# log path created using date
$log_date = ( get-date ).ToString('yyyyMMdd-hhmm')
$time = get-date
$log_file = ".\logs\ReplicateDHCPFilters" + $log_date + ".log"

# check for a logs folder
if (Test-Path ".\logs") {
} else {
    New-Item -ItemType directory -Path ".\logs"
}

# check for log file and create if it doesn't exist
if (Test-Path $log_file) {
} else {
    $log_file = New-Item -type file $log_file
}

# script block to get a filter list
$getListScript = {
    param ($server, $listType)
    Get-DhcpServerv4Filter -ComputerName $server -List $listType
}

try {
    # export the Allow List and get its item count
    Write-Verbose "Exporting Allow List from $sourceServer..."
    $allow_list = Invoke-Command -ComputerName $sourceServer -ScriptBlock $getListScript -ArgumentList $sourceServer, Allow
    $allow_count = $allow_list.Count

    # if the list is empty, skip this
    if ($allow_count) {

        # compare source list count to the list we have
        if ($allow_count -eq (Invoke-Command -ComputerName $sourceServer -ScriptBlock $getListScript -ArgumentList $sourceServer, Allow).Count) {
            Write-Verbose "Successfully exported $allow_count items!"
            Add-Content $log_file "$time : Exported $allow_count Allow items"
        } else {
            $Host.UI.WriteErrorLine("ERROR: Something went horribly wrong when exporting the Allow List from $sourceServer...")
            exit 999
        }

    } else {
        Write-Warning "The Allow List was empty and will not be imported."
        Add-Content $log_file "$time : Allow list was empty"
    }
} catch {
    $Host.UI.WriteErrorLine("ERROR: Something went horribly wrong when exporting the Allow List from $sourceServer...")
    exit 999
}


try {
    # export the Deny List and get its item count
    Write-Verbose "Exporting Deny List from $sourceServer..."
    $deny_list = Invoke-Command -ComputerName $sourceServer -ScriptBlock $getListScript -ArgumentList $sourceServer, Deny
    $deny_count = $deny_list.Count

    # if the list is empty, skip this
    if ($deny_count) {

        # compare source list count to the list we have
        if ($deny_count -eq (Invoke-Command -ComputerName $sourceServer -ScriptBlock $getListScript -ArgumentList $sourceServer, Deny).Count) {
            Write-Verbose "Successfully exported $deny_count items!"
            Add-Content $log_file "$time : Exported $deny_count Deny items"
        } else {
            $Host.UI.WriteErrorLine("ERROR: Something went horribly wrong when exporting the Deny List from $sourceServer...")
            exit 999
        }

    } else {
        Write-Warning "The Deny List was empty and will not be imported."
        Add-Content $log_file "$time : Deny list was empty"
    }
} catch {
    $Host.UI.WriteErrorLine("ERROR: Something went horribly wrong when exporting the Deny List from $sourceServer...")
    exit 999
}

# script block to add a filter list
$addListScript = {
    param ($server, $listType)
    Add-DhcpServerv4Filter -ComputerName $server -List $listType -Force
}

foreach ($destinationServer in $servers) {
    # only import if the list isn't empty
    if ($allow_count) {

        # keep trying to overwrite the allow and deny lists on the destination server until the filter count
        # matches the filter count from the source server's lists
        Write-Verbose "Importing Allow List on $destinationServer..."
        while ($allow_list.Count -ne (Invoke-Command -ComputerName $destinationServer -ScriptBlock $getListScript -ArgumentList $destinationServer, Allow).Count) {
            $allow_list | Invoke-Command -ComputerName $destinationServer -ScriptBlock $addListScript -ArgumentList $destinationServer, Allow
            Write-Warning "Allow List import failed... retrying..."
        }
        Write-Verbose "Import successful!"
    }

    # only import if the list isn't empty
    if ($deny_count) {

        # keep trying to overwrite the allow and deny lists on the destination server until the filter count
        # matches the filter count from the source server's lists
        Write-Verbose "Importing Deny List on $destinationServer..."
        while ($deny_list.Count -ne (Invoke-Command -ComputerName $destinationServer -ScriptBlock $getListScript -ArgumentList $destinationServer, Deny).Count) {
            $deny_list | Invoke-Command -ComputerName $destinationServer -ScriptBlock $addListScript -ArgumentList $destinationServer, Deny
            Write-Warning "Deny List import failed... retrying..."
        }
        Write-Verbose "Import successful!"
    }

    Write-Verbose "Import on $destinationServer complete!"
    Add-Content $log_file "$time : Import on $destinationServer complete"
}
