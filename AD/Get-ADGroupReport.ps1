function Get-ADGroupReport {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$SaveToCsv,
            
        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [string]$ADGroupFilter = 'GroupCategory -eq "Distribution"'
    )

    begin {
        Import-Module ActiveDirectory

        Write-Progress -Id 1 -Activity "Getting AD groups using filter $ADGroupFilter..."
        $Groups = Get-ADGroup -Filter $ADGroupFilter
        $Users = @{}
    }
    
    process {
        $GroupCount = $Groups.Count
        $GroupCounter = 0

        foreach ($Group in $Groups) {
            $GroupCounter++

            $GroupName = $Group.Name
            
            $GroupProgressParams = @{
                'Id' = 1
                'Activity' = "Processing group $GroupCounter of $GroupCount"
                'Status' = $GroupName
                'PercentComplete' = ($GroupCounter / $GroupCount) * 100
            }
            Write-Progress @GroupProgressParams
            
            $Members = Get-ADGroupMember $Group -Recursive

            $MemberCount = $Members.Count
            $MemberCounter = 0
            
            foreach ($Member in $Members) {
                $MemberCounter++

                $MemberName = $Member.SamAccountName

				$MemberProgressParams = @{
                    'Id' = 2
                    'ParentId' = 1
                    'Activity' = "Processing member $MemberCounter of $MemberCount"
                    'Status' = $MemberName
                }
                if ($MemberCount.GetType() -eq [int]) {
                    $MemberProgressParams.Add('PercentComplete', ($MemberCounter / $MemberCount) * 100)
                }
                Write-Progress @MemberProgressParams
                
                if ($Member.objectClass -eq 'user') {
                    Write-Verbose "$MemberName is a user"

                    if (-not $Users.ContainsKey($MemberName)) {
                        Write-Verbose "Adding $MemberName to users list"
                        $Users.Add($MemberName, @{})
                    }

                    Write-Verbose "Adding $($GroupName) to $MemberName's group list"
                    $Users.($MemberName).Add($GroupName, $true)
                } else {
                    Write-Verbose "$MemberName is not a user"
                }
            }

            Write-Progress -Id 2 -ParentId 1 -Activity "Processing members" -Completed
        }

        $ReportProgressParams = @{
            'Id' = 1
            'Activity' = 'Building report...'
        }
        Write-Progress @ReportProgressParams
        
        $Results = @()

        foreach ($User in $Users.GetEnumerator()) {
            $ADUser = Get-ADUser -Identity $User.Name -Properties @(
                'physicalDeliveryOfficeName', 'Office', 'Department', 'Company', 'City', 'telephoneNumber'
                )

            $UserObject = New-Object psobject -Property @{
                UserId = $User.Name
                Email = $ADUser.UserPrincipalName
                Phone = $ADUser.telephoneNumber
                FullName = $ADUser.Name
                Enabled = $ADUser.Enabled
                PhysicalOffice = $ADUser.physicalDeliveryOfficeName
                Office = $ADUser.Office
                Department = $ADUser.Department
                Company = $ADUser.Company
                City = $ADUser.City
            }

            foreach ($Group in $Groups) {
                $UserObject | Add-Member -MemberType NoteProperty -Name $Group.Name -Value ''

                if ($User.Value.ContainsKey($Group.Name)) {
                    $UserObject.($Group.Name) = 'x'
                }
            }

            $Results += $UserObject
        }
    }

    end {
        if ($SaveToCsv) { $Results | Export-Csv -Path $SaveToCsv -NoTypeInformation }
        $Results
    }
}