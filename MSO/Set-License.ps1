<#
.SYNOPSIS
    Grant MSO license to users

.DESCRIPTION

.PARAMETER xx

.EXAMPLE

.NOTES
    Created by Nick Rodriguez

#>

begin {
    # https://support.microsoft.com/en-us/kb/3108269

    # Connect to MS Online
    Connect-MsolService

    function Get-LicenseSkuId {
        param ([string] $LicenseName)

        # Get the license name
        $LicenseObj = Get-MsolAccountSku | Where-Object {
            $_.SkuPartNumber -eq $LicenseName -or
            $_.AccountSkuId -eq $LicenseName
        } 
        $LicenseObj.AccountSkuId
    }

    function Set-License {
        [CmdletBinding(DefaultParameterSetName = 'SpecificUser')]
        param (
            [Parameter(Mandatory=$true)]
            [ValidateSet('All','SpecificUser','Department')]
            [string] $UserSet,

            [Parameter(Mandatory=$true)]
            [string] $LicenseSkuId,

            [Parameter(Mandatory=$false, ParameterSetName = 'Group')]
            [ValidateSet('All','EnabledOnly','DisabledOnly')]
            [string] $FilterIsLicensed,

            [Parameter(Mandatory=$false, ParameterSetName = 'SpecificUser')]
            [string] $Email,

            [Parameter(Mandatory=$false, ParameterSetName = 'Group')]
            [string] $Department
        )

        switch ($UserSet) {
            # Give license to all users
            All { $Users = Get-MSOLUser -All -EnabledFilter $FilterIsLicensed }

            # Get specific user based on email
            SpecificUser { $Users = Get-MsolUser -UserPrincipalName $Email }

            # Get specific user group based on department
            Department { $Users = Get-MsolUser -Department $Department -EnabledFilter $FilterIsLicensed }
        }

        # Grant license to given users
        $Users | Set-MsolUserLicense -AddLicenses $LicenseSkuId -Verbose

        # Verify license was granted
        $Users | Select UserPrincipalName, Licenses | ForEach-Object {
            Write-Host "$($_.UserPrincipalName) - " -NoNewline

            if ($_.Licenses.AccountSkuId -contains $LicenseSkuId) { 
                Write-Host $true -ForegroundColor Green
            } else { 
                Write-Host $false -ForegroundColor Red
            }
        }
    }
}

process {
    $License = Get-LicenseSkuId -LicenseName 'enterprisewithscal'

    # Add users from file
    #Get-Content 'C:\users.txt' | ForEach-Object { Set-License -UserSet SpecificUser -LicenseSkuId $License -Email $_ }

    # Add single user
    #Set-License -UserSet SpecificUser -LicenseSkuId $License -Email 'me@company.com'

    # Add department
    #Set-License -UserSet Department -LicenseSkuId $License -Department 'IT' -FilterIsLicensed EnabledOnly

    # All enabled users
    Set-License -UserSet All -LicenseSkuId $License -FilterIsLicensed EnabledOnly
}