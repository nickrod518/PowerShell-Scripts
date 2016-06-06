function Validate-Credentials {
	param (
		[Parameter(Mandatory=$True)]
		[String]$UserName,

		[Parameter(Mandatory=$False)]
		[String]$Password
	)

    # Get the URL to the user's OneDrive account
    $FormattedName = $UserName.Replace('.', '_').Replace('@', '_')
    $URL = "https://dhgllp-my.sharepoint.com/personal/$FormattedName"

	$SecurePassword = $Password | ConvertTo-SecureString -AsPlainText -Force
	$Context = New-Object Microsoft.SharePoint.Client.ClientContext($Url)
	$Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($UserName, $SecurePassword)
	$Context.Credentials = $Credentials

    # Target library is OneDrive
    $TargetListTitle = "Documents"

	$web = $Context.Web 
	$Context.Load($web)
	$list = $web.Lists.GetByTitle($TargetListTitle);
	$Context.Load($list.RootFolder)
    try {
	    $Context.ExecuteQuery()
        Write-Host 'valid' -ForegroundColor Green
    } catch {
        Write-Host 'invalid' -ForegroundColor Red
    }
}

try {
	# Requires SharePoint client components SDK, exit if not found
	# https://www.microsoft.com/en-us/download/details.aspx?id=35585
	Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\15\ISAPI\Microsoft.SharePoint.Client.dll"
	Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\15\ISAPI\Microsoft.SharePoint.Client.Runtime.dll"
} catch {
	Write-Host "`nSharePoint client components not found!" -ForegroundColor Red
	Stop-Transcript
	return
}

# Import CSV with user details
$UsersCSV = Import-Csv '.\users.csv'

foreach ($User in $UsersCSV) {
	$Email = $User.Email
	$Password = $User.Password

	Write-Host 'Verifying credentials for ' -NoNewline
    Write-Host $Email -NoNewline -ForegroundColor Cyan
    Write-Host '...' -NoNewline

    Validate-Credentials $Email $Password
}