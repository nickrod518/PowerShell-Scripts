Import-Module ActiveDirectory

$DomainAdmins = (Get-ADGroupMember -Identity 'Domain Admins').DistinguishedName
$DomainControllers = (Get-ADDomainController -Filter *).HostName

function Get-ADUserLastLogon {
    param(
        [string]$UserName,
        [string[]]$DomainControllers
    )

    $Time = 0

    $ADUserObject = Get-ADUser $UserName

    foreach ($DC in $DomainControllers) {
        $ADObject = $ADUserObject | Get-ADObject -Properties LastLogon
        if ($ADObject.LastLogon -gt $Time) { $Time = $ADObject.LastLogon }
    }
    $ADUserObject | Add-Member -NotePropertyName LastLogon -NotePropertyValue ([DateTime]::FromFileTime($Time)) -Force
    $ADUserObject | Select-Object Name, SamAccountName, UserPrincipalName, LastLogon, Enabled
}

foreach ($Admin in $DomainAdmins) {
    Get-ADUserLastLogon -UserName $Admin -DomainControllers $DomainControllers
}