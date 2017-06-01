<#
.SYNOPSIS
Get Zoom international users from AD and set them in Zoom.

#>
[CmdletBinding(SupportsShouldProcess = $True)]
Param()

Import-Module C:\powershell-scripts\Zoom\Zoom.psm1 -Force
Import-Module ActiveDirectory

# Get Zoom international users from AD group
$ADUsers = Get-ADGroupMember -Identity 'Zoom International Calling Accounts' |
    Get-ADUser | Select-Object -ExpandProperty UserPrincipalName

$GroupInfo = @{}
foreach ($Group in Get-ZoomGroup -All) {
    $GroupInfo.Add($Group.group_id, $(Get-ZoomGroupMember -Id $Group.group_id))
}

$InternationalGroup = Get-ZoomGroup -Name 'International Calling' | Select-Object -ExpandProperty group_id

foreach ($User in $ADUsers) {
    if (Test-ZoomUserEmail -Email $User) {
        # Get the associated Zoom user
        $ZoomUser = Get-ZoomUser -Email $User | Select-Object -ExpandProperty id

        # Add user to Int'l group if they aren't a member already
        if ($GroupInfo.$InternationalGroup.id -notcontains $ZoomUser) {
            Add-ZoomGroupMember -Id $ZoomUser -GroupId $InternationalGroup
        }

        # Remove user from other groups if they are a member
        foreach ($Group in $GroupInfo.Keys -ne $InternationalGroup) {
            if ($Group.id -contains $ZoomUser) {
                Remove-ZoomGroupMember -Id $ZoomUser -GroupId $Group
            }
        }
    }
}