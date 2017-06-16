<#
.SYNOPSIS
Sync Zoom users with AD.

.DESCRIPTION
Get all enabled users from AD and create a Zoom account if they don't have one. Remove disabled AD users from Zoom.
#>
[CmdletBinding(SupportsShouldProcess = $True)]
Param(
    [Parameter(Mandatory = $false)]
    [switch]$UpdatePictureFromAD
)

Import-Module C:\powershell-scripts\Zoom\Zoom.psm1 -Force
Import-Module ActiveDirectory

# Get all the enabled users
$EnabledFilter = { (Enabled -eq 'True') }
$SearchBase = 'OU=Users,DC=Company,DC=LOCAL'
$ADUsers = Get-ADUser -SearchBase $SearchBase -Filter $EnabledFilter -Properties mail, telephoneNumber, thumbnailPhoto, mobile |
    Where-Object { $_.distinguishedName -notlike '*OU=Disabled*' }

$DefaultGroup = Get-ZoomGroup -Name Default | Select-Object -ExpandProperty group_id

$ZoomUsers = Get-ZoomUser -All
foreach ($User in $ADUsers) {
    $PhoneNumber = if ($User.telephoneNumber) {
        $User.telephoneNumber -replace '-', ''
    } elseif ($User.mobile) {
        $User.mobile -replace '-', ''
    } else {
        ''
    }

    # Pre-provision Zoom accounts for all selected AD users that don't already exist
    if ($ZoomUsers.email -notcontains $User.mail) {
        $Params = @{
            Email = $User.mail
            FirstName = $User.GivenName
            LastName = $User.Surname
            License = 'Pro'
            GroupId = $DefaultGroup
        }
        if ($PhoneNumber) {
            if ($ZoomUsers.pmi -notcontains $PhoneNumber) {
                $Params.Add('Pmi', $PhoneNumber)
            } else {
                Write-Warning "Unable to set Pmi for $($User.mail), $PhoneNumber already exists."
            }
        }

        New-ZoomSSOUser @Params
    # Update existing accounts with their AD info
    } else {
        $ZoomUser = Get-ZoomUser -Email $User.mail

        $Params = @{ }

        # Add params in Zoom and AD users have mismatched properties
        if ($ZoomUser.first_name -ne $User.GivenName) {
            $Params.Add('FirstName', $User.GivenName)
        }
        if ($ZoomUser.last_name -ne $User.Surname) {
            $Params.Add('LastName', $User.Surname)
        }
        if ($PhoneNumber -and $ZoomUser.type -ne 1) {
            if ($ZoomUser.pmi -ne [int64]$PhoneNumber) {
                if ($ZoomUsers.pmi -notcontains $PhoneNumber) {
                    $Params.Add('Pmi', $PhoneNumber)
                } else {
                    Write-Warning "Unable to set Pmi for $($User.mail), $PhoneNumber already exists."
                }
            }
        }
        if ($ZoomUser.vanity_url.Split('/')[-1] -ne $User.mail.Split('@')[0]) {
            $Params.Add('VanityName', $User.mail.Split('@')[0])
        }

        # Only update Zoom user properties if they have mismatches
        if ($Params.Count -gt 0) {
            $Params.Add('id', $ZoomUser.id)
            Set-ZoomUser @Params
        } else {
            Write-Verbose "$($ZoomUser.email) is already up to date."
        }
    }

    # Upload user photo if it exists
    if ($UpdatePictureFromAD -and $User.thumbnailPhoto) {
        $ZoomUserId = Get-ZoomUser -Email $User.mail | Select-Object -ExpandProperty id
        Set-ZoomUserPicture -Id $ZoomUserId -ByteArray $User.thumbnailPhoto
    }
}

# Remove any Zoom accounts that don't have matching AD users
Get-ZoomUser -All | ForEach-Object {
    if ($ADUsers.mail -notcontains $_.email) { $_ | Remove-ZoomUser }
}