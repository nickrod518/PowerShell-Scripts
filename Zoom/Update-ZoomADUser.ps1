<#
.SYNOPSIS
Sync Zoom users with AD.

.DESCRIPTION
Get all enabled users from AD and create a Zoom account if they don't have one. Remove disabled AD users from Zoom.
#>
[CmdletBinding(SupportsShouldProcess = $True)]
Param()

Import-Module C:\powershell-scripts\Zoom\Zoom.psm1 -Force
Import-Module ActiveDirectory

# Get all the enabled users
$EnabledFilter = { (Enabled -eq 'True') }
$SearchBase = 'OU=People,DC=Company,DC=LOCAL'
$ADUsers = Get-ADUser -SearchBase $SearchBase -Filter $EnabledFilter -Properties telephoneNumber |
    Where-Object { $_.distinguishedName -notlike '*OU=Disabled*'}

# Pre-provision Zoom accounts for all selected AD users that don't already exist
$ZoomUsers = Get-ZoomUser -All
foreach ($User in $ADUsers) {
    if ($ZoomUsers.email -notcontains $User.UserPrincipalName) {
        New-ZoomSSOUser -Email $($User.UserPrincipalName) -License Pro -Pmi $($User.telephoneNumber -replace '-', '')
    }
}

# Remove any Zoom accounts that don't have matching AD users
Get-ZoomUser -All | ForEach-Object {
    if ($ADUsers.UserPrincipalName -notcontains $_.email) { $_ | Remove-ZoomUser }
}