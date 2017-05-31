Import-Module C:\powershell-scripts\Zoom\Zoom.psm1 -Force
Import-Module ActiveDirectory

function Set-ZoomUserIntern {
    [CmdletBinding()]
    Param(
        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Id
    )

    foreach ($UserId in $Id) {
        Set-ZoomUserInfo -Id $UserId -License Basic

        $Groups = Get-ZoomGroup
        $InternGroupId = ($Groups | Where-Object -Property name -eq 'Interns/Temps').group_id
        $OtherGroupIds = ($Groups | Where-Object -Property name -ne 'Interns/Temps').group_id

        $OtherGroupIds | ForEach-Object {
            Remove-ZoomGroupMember -GroupId $_ -Id $UserId
        }

        $UserId | Add-ZoomGroupMember -GroupId $InternGroupId
    }
}

# Get Zoom intern users from AD group and set their Zoom license and group
$ADUsers = Get-ADGroupMember -Recursive -Identity 'Global - Interns' |
    Get-ADUser | Select-Object -ExpandProperty UserPrincipalName
Get-ZoomUser -Email $ADUsers | Set-ZoomUserIntern