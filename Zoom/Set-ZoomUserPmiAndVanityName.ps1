<#
.SYNOPSIS
Set every Zoom user's Pmi, vanity name, and enable Pmi.

.DESCRIPTION
Set every user's private meeting Id to their AD telephone number, set their vanity name to the name in their UserPrincipalName, and enable Pmi.
#>
[CmdletBinding(SupportsShouldProcess = $True)]
Param()

Import-Module C:\powershell-scripts\Zoom\Zoom.psm1 -Force
Import-Module ActiveDirectory

$Users = Get-ZoomUser

foreach ($User in $Users) {
    $Email = $User.email
    $VanityName = $User.email.Split('@')[0]
    $Pmi = (Get-ADUser -Filter { UserPrincipalName -eq $Email } -Properties telephoneNumber |
        Select-Object -ExpandProperty telephoneNumber) -replace '-', ''

    Set-ZoomUser -Id $User.id -Pmi $Pmi -EnablePmi $true -VanityName $VanityName
}