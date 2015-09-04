# displays the verbose messages which can help troubleshoot
$VerbosePreference = "Continue"

# source server that the lists will come from
$sourceServer = 'DHCP01'

# list of destination servers to export filter list to
$servers = @(
'server01',
'server02'
)

try {
    # export the Allow List and make sure its count matches the server's filter
    Write-Verbose -message "Exporting Allow List from $sourceServer..."
    $allow_list = Get-DhcpServerv4Filter -ComputerName $sourceServer -List Allow
    $allow_count = $allow_list.Count

    # if the list is empty, skip this
    if ($allow_count) {

        if ($allow_count -eq (Get-DhcpServerv4Filter -ComputerName $sourceServer -List Allow).Count) {
            Write-Verbose -message "Successfully exported $allow_count items!"
        } else {
            $Host.UI.WriteErrorLine("ERROR: Something went horribly wrong when exporting the Allow List from $sourceServer...")
            exit 999
        }

    } else {
        Write-Verbose -message "The Allow List was empty and will not be imported."
    }
} catch {
    $Host.UI.WriteErrorLine("ERROR: Something went horribly wrong when exporting the Allow List from $sourceServer...")
    exit 999
}


try {
    # export the Deny List and make sure its count matches the server's filter
    Write-Verbose -message "Exporting Deny List from $sourceServer..."
    $deny_list = Get-DhcpServerv4Filter -ComputerName $sourceServer -List Deny
    $deny_count = $deny_list.Count

    # if the list is empty, skip this
    if ($deny_count) {

        if ($deny_count -eq (Get-DhcpServerv4Filter -ComputerName $sourceServer -List Deny).Count) {
            Write-Verbose -message "Successfully exported $deny_count items!"
        } else {
            $Host.UI.WriteErrorLine("ERROR: Something went horribly wrong when exporting the Deny List from $sourceServer...")
            exit 999
        }

    } else {
        Write-Verbose -message "The Deny List was empty and will not be imported."
    }
} catch {
    $Host.UI.WriteErrorLine("ERROR: Something went horribly wrong when exporting the Deny List from $sourceServer...")
    exit 999
}

foreach ($destinationServer in $servers) {
    # only import if the list isn't empty
    if ($allow_count) {

        # keep trying to overwrite the allow and deny lists on the destination server until the filter count
        # matches the filter count from the source server's lists
        Write-Verbose "Importing Allow List on $destinationServer..."
        while ($allow_list.Count -ne (Get-DhcpServerv4Filter -ComputerName $destinationServer -List Allow).Count) {
            $allow_list | Add-DhcpServerv4Filter -ComputerName $destinationServer -List Allow –Force
            Write-Warning "Allow List import failed... retrying..."
        }
        Write-Verbose "Import successful!"
    }

    # only import if the list isn't empty
    if ($deny_count) {

        # keep trying to overwrite the allow and deny lists on the destination server until the filter count
        # matches the filter count from the source server's lists
        Write-Verbose "Importing Deny List on $destinationServer..."
        while ($deny_list.Count -ne (Get-DhcpServerv4Filter -ComputerName $destinationServer -List Deny).Count) {
            $deny_list | Add-DhcpServerv4Filter -ComputerName $destinationServer -List Deny –Force
            Write-Warning "Deny List import failed... retrying..."
        }
        Write-Verbose "Import successful!"
    }

    Write-Verbose "Import on $destinationServer complete!"
}

pause
