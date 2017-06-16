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

# Get intern group and members
$InternGroupId = ($Groups | Where-Object -Property name -eq 'Interns/Temps').group_id
$InternGroupMembers = Get-ZoomGroupMember -Id $InternGroupId

# Get other group id's and members
$OtherGroupIds = ($Groups | Where-Object -Property name -ne 'Interns/Temps').group_id
$OtherGroupMembers = @{}
$OtherGroupIds | ForEach-Object { $OtherGroupMembers.Add($_, (Get-ZoomGroupMember -Id $_)) }

# Get Zoom intern users from AD group and set their Zoom license and group
Get-ADGroupMember -Recursive -Identity 'Global - Interns' | Get-ADUser | 
    Select-Object -ExpandProperty mail | ForEach-Object {
        try {
            $ZoomUser = Get-ZoomUser -Email $_

            # Set license to Basic if it isn't already
            if ($ZoomUser.type -ne 1) { Set-ZoomUser -Id $ZoomUser.id -License Basic }

            # Remove user from other groups
            $OtherGroupIds | ForEach-Object {
                if ($OtherGroupMembers.$_.id -contains $ZoomUser.id) {
                    Remove-ZoomGroupMember -GroupId $_ -Id $ZoomUser.id
                }
            }

            # Add user to intern group
            if ($InternGroupMembers.id -notcontains $ZoomUser.id) {
                Add-ZoomGroupMember -GroupId $InternGroupId -Id $ZoomUser.id
            } else {
                Write-Verbose "$($ZoomUser.email) is already a member of the Intern group."
            }
        } catch {
            Write-Warning "$_ not found."
        }
    }