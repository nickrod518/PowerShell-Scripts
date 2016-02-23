$scriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent
$servers = Get-Content "$scriptPath\printservers.csv"
$creds = Get-Credential
$date = Get-Date
 
function Get-Shares ($server) {
    $output = Invoke-Command -Credential $creds -ComputerName $server -ScriptBlock {
       $server = $args[0]
    write-host $server
        $Printers = @{}
    
       $shares = Get-WmiObject Win32_Printer -ComputerName $server
       foreach ($share in $shares) {
            try {
                  $Printers.Add($share.ShareName,
                  (Get-WmiObject Win32_TcpIpPrinterPort -Filter "name = '$($share.Portname)'").HostAddress)
            } catch { } # this printer's port wasn't setup properly and the ip will be blank in the csv
       }
 
       $Printers.GetEnumerator()
    } -argumentlist $server
   
    # create csv at script root with output
    $output | select name, value | Export-Csv -Append -NoTypeInformation -Path "$scriptPath\printshares.csv"
}
 
foreach ($server in $servers) {
    Get-Shares $server
}