Import-Module ActiveDirectory

# Get all MSO users and their MFA status, convert into AD users
$MFAUsers = . "MSO\Get-MFAEnabledUser.ps1"
$RegisteredUsers = $MFAUsers | Where-Object -Property DefaultMethod -NE $null | ForEach-Object {
    Get-ADUser -Filter "UserPrincipalName -eq '$($_.UserPrincipalName)'"
}

# Get the group that holds unregistered MFA users and the users within
$UnregisteredGroup = Get-ADGroup -Identity 'MFA Registration Incomplete'
$UnregisteredUsers = $UnregisteredGroup | Get-ADGroupMember | Get-ADUser

# Find users in the group that have a default MFA method
$UsersToRemove = $UnregisteredUsers | Compare-Object -ReferenceObject $RegisteredUsers -IncludeEqual |
Where-Object -Property SideIndicator -eq '=='

# Remove users with a default MFA method
Remove-ADGroupMember -Identity $UnregisteredGroup -Members $UsersToRemove.InputObject