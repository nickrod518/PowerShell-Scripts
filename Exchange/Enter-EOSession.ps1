# If you get an Access Denied message but you're a member of Exchange Online Admins, 
# make sure you don't have MFA enabled
$ExchangeOnlineSession = New-PSSession -ConfigurationName Microsoft.Exchange `
    -ConnectionUri https://outlook.office365.com/powershell-liveid/ `
    -Credential (Get-Credential) -Authentication Basic -AllowRedirection

Import-PSSession $ExchangeOnlineSession