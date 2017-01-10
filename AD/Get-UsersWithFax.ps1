$Creds = Get-Credential

$UsersWithFax = Get-ADUser -Credential $Creds `
    -Filter '(facsimileTelephoneNumber -like "*") -and (facsimileTelephoneNumber -ne "0") -or (otherFacsimileTelephoneNumber -like "*")' `
    -Properties facsimileTelephoneNumber, otherFacsimileTelephoneNumber | `
    Select-Object Name, SamAccountName, facsimileTelephoneNumber, otherFacsimileTelephoneNumber

Write-Host "Users with a fax line: $($UsersWithFax.Count)"
$UsersWithFax | Export-Csv -Path '.\UsersWithFax.csv' -NoTypeInformation