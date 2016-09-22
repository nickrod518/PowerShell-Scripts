function Get-O365GroupMember {
    [CmdletBinding()]
    param ()

    Connect-MsolService

    Get-MsolGroup -All | ForEach-Object {
        $MsolGroup = $_

        Write-Verbose "Getting members of $($_.DisplayName)"
        Get-MsolGroupMember -GroupObjectId $_.ObjectId -All | ForEach-Object {
            New-Object psobject -Property @{
                Email = $_.EmailAddress
                DisplayName = $_.DisplayName
                Type = $_.GroupMemberType
                GroupName = $MsolGroup.DisplayName
            } | Export-Csv -Path .\MsolGroupMembers.csv -Append -NoTypeInformation
        }
    }
}