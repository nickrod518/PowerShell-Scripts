$scriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent
$server = Read-Host "What server do you want to query?"
$creds = Get-Credential
$output = @()
 
$output += Invoke-Command -Credential $creds -ComputerName $server -ScriptBlock {
    $server = $args[0]
	$output = $args[1]
 
    $shares = Get-WmiObject Win32_Printer -ComputerName $server
    # loop through each printer share
	foreach ($share in $shares) {
		# Create an object for each share to store all of its info in and pass that to our output list
		$output += New-Object PSObject -Property @{
			Server = $server
			Share = $share.Portname
			IP = (Get-WmiObject Win32_TcpIpPrinterPort -Filter "name = '$($share.Portname)'").HostAddress
			Location = $share.location
			Comment = $share.comment
		}
	}
	return $output
} -ArgumentList $server, $output
 
 
# create csv at script root with output
$output | select Server, Share, IP, Location, Comment | Export-Csv "$scriptPath\Printers-$server.csv" -NoTypeInformation