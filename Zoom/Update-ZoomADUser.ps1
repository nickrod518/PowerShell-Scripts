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
$SearchBase = 'OU=Users,DC=COMPANY,DC=LOCAL'
$ADUsers = Get-ADUser -SearchBase $SearchBase -Filter $EnabledFilter -Properties telephoneNumber, thumbnailPhoto |
    Where-Object { $_.distinguishedName -notlike '*OU=zz*'}

$DefaultGroup = Get-ZoomGroup -Name DHG | Select-Object -ExpandProperty group_id

$ZoomUsers = Get-ZoomUser -All
foreach ($User in $ADUsers) {
    # Pre-provision Zoom accounts for all selected AD users that don't already exist
    if ($ZoomUsers.email -notcontains $User.UserPrincipalName) {
        $Params = @{
            Email = $User.UserPrincipalName
            FirstName = $User.GivenName
            LastName = $User.Surname
            License = 'Pro'
            Pmi = $User.telephoneNumber -replace '-', ''
            GroupId = $DefaultGroup
        }
        New-ZoomSSOUser @Params
    # Update existing accounts with their AD info
    } else {
        $ZoomUser = $ZoomUsers | Where-Object -Property email -eq $User.UserPrincipalName
        $Params = @{
            Id = $ZoomUser.id
            FirstName = $User.GivenName
            LastName = $User.Surname
            Pmi = $User.telephoneNumber -replace '-', ''
            VanityName = $User.UserPrincipalName.Split('@')[0]
        }
        Set-ZoomUser @Params
    }

    # Upload user photo if it exists
    if ($User.thumbnailPhoto) {
        $ZoomUserId = Get-ZoomUser -Email $User.UserPrincipalName | Select-Object -ExpandProperty id
        Set-ZoomUserPicture -Id $ZoomUserId -ByteArray $User.thumbnailPhoto
    }
}

# Remove any Zoom accounts that don't have matching AD users
Get-ZoomUser -All | ForEach-Object {
    if ($ADUsers.UserPrincipalName -notcontains $_.email) { $_ | Remove-ZoomUser }
}