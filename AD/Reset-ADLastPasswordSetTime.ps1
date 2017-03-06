$creds = Get-Credential

$Me = Get-ADUser -Filter * | Where-Object -Property SamAccountName -Like userid*
$Me | Set-ADUser -ChangePasswordAtLogon $true -Credential $creds
$Me | Set-ADUser -ChangePasswordAtLogon $false -Credential $creds