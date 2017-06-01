<#
.SYNOPSIS
Get interns from AD and set.

.DESCRIPTION
Get interns from AD and set their license to Basic and move to Intern group in Zoom.
#>
[CmdletBinding(SupportsShouldProcess = $True)]
Param()

Import-Module C:\powershell-scripts\Zoom\Zoom.psm1 -Force
Import-Module ActiveDirectory

$Groups = Get-ZoomGroup
$InternGroupId = ($Groups | Where-Object -Property name -eq 'Interns/Temps').group_id
$OtherGroupIds = ($Groups | Where-Object -Property name -ne 'Interns/Temps').group_id

# Get Zoom intern users from AD group and set their Zoom license and group
Get-ADGroupMember -Recursive -Identity 'Global - Interns' | Get-ADUser | 
    Select-Object -ExpandProperty UserPrincipalName | ForEach-Object {
        if (Test-ZoomUserEmail -Email $_) {
            $Id = Get-ZoomUser -Email $_ | Select-Object -ExpandProperty id

            # Set license to Basic
            Set-ZoomUser -Id $Id -License Basic

            # Remove user from other groups
            $OtherGroupIds | ForEach-Object { Remove-ZoomGroupMember -GroupId $_ -Id $Id }

            # Add user to intern group
            Add-ZoomGroupMember -GroupId $InternGroupId -Id $Id
        }
    }