<#
.SYNOPSIS
Sync Zoom users with AD.

.DESCRIPTION
Get all enabled users from AD and create a Zoom account if they don't have one. Remove disabled AD users from Zoom.
#>
[CmdletBinding(SupportsShouldProcess = $True)]
Param(
    [Parameter(
        Mandatory = $false,
        ParameterSetName = 'AD'
    )]
    [switch]$UpdatePictureFromAD,

    [Parameter(
        Mandatory = $false,
        ParameterSetName = 'EO'
    )]
    [switch]$UpdatePictureFromEO
)

Import-Module C:\powershell-scripts\Zoom\Zoom.psm1
Import-Module ActiveDirectory
if ($UpdatePictureFromEO) {
    $SessionParameters = @{
        'ConfigurationName' = 'Microsoft.Exchange'
        'ConnectionUri' = 'https://outlook.office365.com/powershell-liveid'
        'Credential' = Get-Credential
        'Authentication' = 'Basic'
        'AllowRedirection' = $true
    }

    try {
        Import-PSSession (New-PSSession @SessionParameters)
    } catch {
        Write-Error "Unable to connect to Exchange Online: $_"
        exit
    }
}

# Get all the enabled users
$EnabledFilter = { (Enabled -eq 'True') }
$SearchBase = 'OU=Users,DC=COMPANY,DC=LOCAL'
$ADUsers = Get-ADUser -SearchBase $SearchBase -Filter $EnabledFilter -Properties mail, telephoneNumber, thumbnailPhoto, mobile |
    Where-Object { $_.distinguishedName -notlike '*OU=Disabled*' }

$DefaultGroup = Get-ZoomGroup -Name DHG | Select-Object -ExpandProperty group_id

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

    if ($UpdatePictureFromEO) {
        $PhotoExists = $false

        try {
            # Get the photo from Exchange Online
            $Photo = Get-UserPhoto -Identity $ZoomUser.email
            $PhotoExists = $true
        } catch {
            Write-Warning "Exchange Online photo does not exist for $($ZoomUser.email)"
        }

        if ($PhotoExists) {
            # Save the photo to a temporary file
            $FilePath = "$env:TEMP\$($ZoomUser.email).jpg"
            if (Test-Path $FilePath) { Remove-Item $FilePath }
            [IO.File]::WriteAllBytes($FilePath, $Photo.PictureData)

            # Load the photo and its properties
            $Image = New-Object -ComObject Wia.ImageFile
            $Image.LoadFile($FilePath)

            # Check if the photo is square
            if ($Image.Height -eq $Image.Width) {
                Set-ZoomUserPicture -Id $ZoomUser.id -ByteArray $Photo.PictureData
            } else {
                Write-Verbose "Photo is not square, cropping..."

                # Create a new crop filter
                $Filter = New-Object -ComObject Wia.ImageProcess
                $Filter.Filters.Add($Filter.FilterInfos.Item('Crop').FilterId)

                # Set the height/width to whichever is smallest
                if ($Image.Height -lt $Image.Width) {
                    $PixelsToCrop = ($Image.Width - $Image.Height) / 2
                    $Filter.Filters.Item(1).Properties.Item("Left") = $PixelsToCrop
                    $Filter.Filters.Item(1).Properties.Item("Right") = $PixelsToCrop
                } else {
                    $PixelsToCrop = ($Image.Height - $Image.Width) / 2
                    $Filter.Filters.Item(1).Properties.Item("Top") = $PixelsToCrop
                    $Filter.Filters.Item(1).Properties.Item("Bottom") = $PixelsToCrop
                }

                # Apply the filter and upload the new image
                $Image = $Filter.Apply($Image)
                $CroppedFilePath = "$env:TEMP\$($ZoomUser.email)-cropped.jpg"
                if (Test-Path $CroppedFilePath) { Remove-Item $CroppedFilePath }
                $Image.SaveFile($CroppedFilePath)
                Set-ZoomUserPicture -Id $ZoomUser.id -Path $CroppedFilePath
                Remove-Item $CroppedFilePath
            }

            Remove-Item $FilePath
        }
    }
}

# Remove any Zoom accounts that don't have matching AD users
Get-ZoomUser -All | ForEach-Object {
    if ($ADUsers.mail -notcontains $_.email) { $_ | Remove-ZoomUser -Permanently }
}