$Creds = Get-Credential
$User = Read-Host "Enter search term for user ID or Name (wildcards allowed before and after)"
Get-ADUser -Credential $Creds -Filter 'Name -Like $User -or SamAccountName -Like $User' | Format-Table Name, SamAccountName -AutoSize