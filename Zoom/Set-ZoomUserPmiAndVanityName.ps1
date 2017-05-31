Import-Module C:\powershell-scripts\Zoom\Zoom.psm1 -Force
Import-Module ActiveDirectory

$Users = Get-ZoomUser

foreach ($User in $Users) {
    $Email = $User.email
    $VanityName = $User.email.Split('@')[0]
    $Pmi = (Get-ADUser -Filter { UserPrincipalName -eq $Email } -Properties telephoneNumber |
        Select-Object -ExpandProperty telephoneNumber) -replace '-', ''

    Set-ZoomUserInfo -Id $User.id -Pmi $Pmi -EnablePmi $true -VanityName $VanityName
}