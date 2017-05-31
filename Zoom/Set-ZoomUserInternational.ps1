Import-Module C:\powershell-scripts\Zoom\Zoom.psm1 -Force
Import-Module ActiveDirectory

# Get Zoom international users from AD group
$ADUsers = Get-ADGroupMember -Identity 'Zoom International Calling Accounts' |
    Get-ADUser | Select-Object -ExpandProperty UserPrincipalName
$ZoomUsers = Get-ZoomUser -Email $ADUsers

# Add users to international Zoom group
$InternationalGroup = Get-ZoomGroup -Name 'International Calling'
$ZoomUsers | Add-ZoomGroupMember -GroupId $InternationalGroup.group_id

# Remove users from other Zoom groups
$OtherGroups = Get-ZoomGroup | Where-Object -Property name -ne 'International Calling'
foreach ($Group in $OtherGroups) { $ZoomUsers | Remove-ZoomGroupMember -GroupId $Group.group_id }