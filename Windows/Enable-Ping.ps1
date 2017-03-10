Invoke-Command -ComputerName (Get-ADComputer -Filter *).DNSHostName -ScriptBlock {
    New-NetFirewallRule –DisplayName “Allow Ping” –Direction Inbound –Action Allow –Protocol icmpv4 –Enabled True
}