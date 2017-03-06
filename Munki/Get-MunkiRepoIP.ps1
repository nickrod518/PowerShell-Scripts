# List of servers with Munki repos setup
$Servers = (Get-ADGroupMember -Identity MunkiRepos).Name

$Creds = Get-Credential

foreach ($Computer in $Servers) {
    if(Test-Connection -ComputerName $Computer -Count 1 -ea 0) {
        try {
            $Networks = Get-WmiObject Win32_NetworkAdapterConfiguration -ComputerName $Computer -EA Stop -Credential $Creds | ? {$_.IPEnabled}
        } catch {            
                Write-Warning "Error occurred while querying $Computer."
                Continue
        }
        foreach ($Network in $Networks) {
            $IPAddress  = $Network.IpAddress[0]
            $OutputObj  = New-Object -Type PSObject
            $OutputObj | Add-Member -MemberType NoteProperty -Name Repo -Value $Computer.ToUpper()
            $OutputObj | Add-Member -MemberType NoteProperty -Name IPAddress -Value $IPAddress
            $OutputObj
        }
    }
 }