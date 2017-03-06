$Creds = Get-Credential
$PSSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell/ `
    -Credential $Creds -Authentication Basic –AllowRedirection 

Import-PSSession $PSSession

$Results = Get-Mailbox | Select-Object DisplayName, @{
    Name = 'EmailAddresses'
    Expression = { ($_.EmailAddresses | Where-Object { $_ -LIKE "SMTP:*" }).TrimStart('SMTP:') }
}

$Results | Format-Table -AutoSize

#$Results | Export-Csv c:\temp\UsersWithAlias.csv -NoTypeInformation