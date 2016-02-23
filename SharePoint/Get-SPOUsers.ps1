$VerbosePreference = 'Continue'

# SharePoint Online admin portal
$sharepointAdminCenterUrl = 'https://company-admin.sharepoint.com'
# SharePoint Online URL for OneDrive accounts
$SPOOneDriveURL = 'https://company-my.sharepoint.com'
# SharePoint Online admin account
$tenantAdmin = 'admin@company.com'

function Load-SharePointOnlineModule {
    process {
        do {
            # Installation location: C:\Program Files\SharePoint Online Management Shell\Microsoft.Online.SharePoint.PowerShell
            $SPOModule = Get-Module -Name Microsoft.Online.SharePoint.PowerShell -ErrorAction SilentlyContinue

            if(-not $SPOModule) {
                try {
                    Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking
                    return $true
                }
                catch {
                    if($_.Exception.Message -match "Could not load file or assembly") {
                        Write-Error -Message "Unable to load the SharePoint Online Management Shell.`nDownload Location: http://www.microsoft.com/en-us/download/details.aspx?id=35588"
                    }
                    else {
                        Write-Error -Exception $_.Exception
                    }
                    return $false
                }
            }
            else {
                return $true
            }
        } while(-not $SPOModule)
    }
}

# Load the required PowerShell module
Load-SharePointOnlineModule

# Generate an array or CSV of SPO user URL's. 
# To generate CSV, use the -GenerateCSV parameter when calling function
Function Get-SPOUsersList {
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$true)][string]$SPOOneDriveURL,
        [parameter(Mandatory=$false)][string]$SPOAdminURL = $sharepointAdminCenterUrl,
        [parameter(Mandatory=$false)][switch]$GenerateCSV = $false
    )

    if ($GenerateCSV) {
        $CSVPath = "$PSScriptRoot\SPOUsers.csv"
        Write-Verbose "Getting a list of user OneDrive web URLs and saving as a CSV to $CSVPath."
        Write-Verbose "This may take a while..."
        # Get all users and format use their login names to export site URL's to a CSV
        Get-SPOUser -Site $SPOOneDriveURL -Limit ALL | 
        select { $SPOOneDriveURL + '/personal/' + $_.LoginName.Replace(".","_").Replace("@","_") } |
        ConvertTo-Csv -NoTypeInformation |
        select -Skip 1 | # Don't include the header
        Set-Content $CSVPath
        $webUrls = Get-Content -Path $CSVPath
    } else {
        Write-Verbose "Getting a list of user OneDrive web URLs and storing in an array."
        Write-Verbose "This may take a while..."
        # Get all users and format their login names to export site URL's to an array
        $SPOUsers = Get-SPOUser -Site $SPOOneDriveURL -Limit ALL
        $webUrls = New-Object -typeName System.Collections.Arraylist 
        $webUrls.Capacity = $SPOUsers.Count
        foreach ($User in $SPOUsers) {
	        $webUrls.Add( $SPOOneDriveURL + '/personal/' + $User.LoginName.Replace(".","_").Replace("@","_") ) | Out-Null
        }
    }
    
    Write-Verbose "$($webUrls.Count) web URLs found."
    return $webUrls
}

# Get credentials for SPO admin
$SPOAdminCreds = Get-Credential -UserName $tenantAdmin -Message "Enter the password for the Office 365 admin"

# Connect to SPO first, cmdlets to run
Connect-SPOService -Url $sharepointAdminCenterUrl -Credential $SPOAdminCreds

# Get a list of users
# Get-SPOUsersList -SPOOneDriveURL $SPOOneDriveURL
Get-SPOUsersList -SPOOneDriveURL $SPOOneDriveURL -GenerateCSV

# Disconnect our SPO session
Disconnect-SPOService -ErrorAction SilentlyContinue