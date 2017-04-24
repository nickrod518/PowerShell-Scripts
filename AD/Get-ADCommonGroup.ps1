[CmdletBinding()]
param (
	[Parameter(Mandatory = $true)]
    [ValidateScript({ Get-ADGroup -Identity $_ })]
	[string]$GroupName
)

begin {
    Import-Module ActiveDirectory
    $Group = Get-ADGroup -Identity $GroupName
    $AllGroups = @{}
}

process {
    $Members = Get-ADGroupMember -Identity $Group

    $Members | ForEach-Object {
        $User = $_.SamAccountName

        (Get-ADUser $User -Properties MemberOf).MemberOf | ForEach-Object {
            # Check if the group exists in our list
            if ($AllGroups.ContainsKey($_)) {
                $AllGroups.($_)++
            } else {
                # Item is unique so add it to the list
                $AllGroups.Add($_, 1)
            }
        }
    }

    Write-Host "Results:"
    $AllGroups | Format-Table -AutoSize
    $AllGroups.GetEnumerator() | Select-Object -Property Key, Value | 
        Export-Csv -Path .\$GroupName-CommonGroups.csv -NoTypeInformation

    Write-Host "Common memberships:"
    $AllGroups.GetEnumerator() | ForEach-Object {
        if ($_.Value -eq $Members.Count) { $_.Key }
    }
}