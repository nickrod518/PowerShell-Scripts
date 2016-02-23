$ScriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent
$Servers = @('server1', 'server2')
$Creds = Get-Credential
$Output = @()

# Loop through each server
$Output = foreach ($Server in $Servers) {
	Invoke-Command -Credential $Creds -ComputerName $Server -ScriptBlock {
		$Server = $args[0]
		$Output = $args[1]
 
		$Shares = Get-WmiObject Win32_Printer -ComputerName $Server
		# Loop through each printer share
		foreach ($Share in $Shares) {
			# Create an object for each share to store all of its info in and pass that to our output list
			$Output += New-Object PSObject -Property @{
				Server = $Server
				Share = $Share.Portname
				IP = (Get-WmiObject Win32_TcpIpPrinterPort -Filter "name = '$($Share.Portname)'").HostAddress
				Location = $Share.location
				Comment = $Share.comment
			}
		}
		return $Output
	} -ArgumentList $Server, $Output
}
 
 
# create csv at script root with output
$Output | select Server, Share, IP, Location, Comment | Export-Csv "$ScriptPath\Printers.csv" -NoTypeInformation