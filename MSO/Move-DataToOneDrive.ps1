$Functions = {
	param(
		[Parameter(Mandatory=$true)]
		[string]$UserEmail,

		[Parameter(Mandatory=$true)]
		[string]$Password,

		[Parameter(Mandatory=$true)]
		[string]$SourceFolderPath 
	)

	function Ensure-Folder {
		param (
		  [Parameter(Mandatory=$True)]
		  [Microsoft.SharePoint.Client.Web]$Web,

		  [Parameter(Mandatory=$True)]
		  [Microsoft.SharePoint.Client.Folder]$ParentFolder, 

		  [Parameter(Mandatory=$True)]
		  [String]$FolderUrl
		)

		$folderNames = $FolderUrl.Trim().Split("/",[System.StringSplitOptions]::RemoveEmptyEntries)
		$folderName = $folderNames[0]
		Write-Host "Creating folder [$folderName] ..."
		$curFolder = $ParentFolder.Folders.Add($folderName)
		$Web.Context.Load($curFolder)
		$web.Context.ExecuteQuery()
		Write-Host "Folder [$folderName] has been created succesfully. Url: $($curFolder.ServerRelativeUrl)"

		if ($folderNames.Length -gt 1) {
			$curFolderUrl = [System.String]::Join("/", $folderNames, 1, $folderNames.Length - 1)
			Ensure-Folder -Web $Web -ParentFolder $curFolder -FolderUrl $curFolderUrl
		}
	}

	function Upload-File {
		param (
		  [Parameter(Mandatory=$True)]
		  [Microsoft.SharePoint.Client.Web]$Web,

		  [Parameter(Mandatory=$True)]
		  [String]$FolderRelativeUrl, 

		  [Parameter(Mandatory=$True)]
		  [System.IO.FileInfo]$LocalFile
		)

		try {
		   $fileUrl = $FolderRelativeUrl + "/" + $LocalFile.Name
		   Write-Host "Uploading file [$($LocalFile.FullName)] ..."
		   [Microsoft.SharePoint.Client.File]::SaveBinaryDirect($Web.Context, $fileUrl, $LocalFile.OpenRead(), $true)
		   Write-Host "File [$($LocalFile.FullName)] has been uploaded succesfully. Url: $fileUrl"
		} catch {
		   Write-Host "An error occured while uploading file [$($LocalFile.FullName)]"
		}
	}

	function Upload-Files {
		param (
		  [Parameter(Mandatory=$True)]
		  [String]$Url,

		  [Parameter(Mandatory=$True)]
		  [String]$UserName,

		  [Parameter(Mandatory=$False)]
		  [String]$Password, 

		  [Parameter(Mandatory=$True)]
		  [String]$TargetListTitle,

		  [Parameter(Mandatory=$True)]
		  [String]$SourceFolderPath
		)

		$SecurePassword = $Password | ConvertTo-SecureString -AsPlainText -Force
		$Context = New-Object Microsoft.SharePoint.Client.ClientContext($Url)
		$Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($UserName, $SecurePassword)
		$Context.Credentials = $Credentials

		$web = $Context.Web 
		$Context.Load($web)
		$list = $web.Lists.GetByTitle($TargetListTitle);
		$Context.Load($list.RootFolder)
		$Context.ExecuteQuery()

		Get-ChildItem $SourceFolderPath -Recurse | % {
			if ($_.PSIsContainer -eq $True) {
				$folderUrl = $_.FullName.Replace($SourceFolderPath,"").Replace("\","/")   
				if ($folderUrl) {
					Ensure-Folder -Web $web -ParentFolder $list.RootFolder -FolderUrl $folderUrl
				}  
			} else {
				$folderRelativeUrl = $list.RootFolder.ServerRelativeUrl + $_.DirectoryName.Replace($SourceFolderPath,"").Replace("\","/")
				Upload-File -Web $web -FolderRelativeUrl $folderRelativeUrl -LocalFile $_ 
			}
		}
	}

	$Date = (Get-Date).ToString('yyyyMMdd-HHmm')
	Start-Transcript "$SourceFolderPath\..\logs\$UserEmail-$Date.log"

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

	# Target library is OneDrive
	$TargetListTitle = "Documents"

	# Get the URL to the user's OneDrive account
	$FormattedName = $UserEmail.Replace('.', '_').Replace('@', '_')
	# Update this to match your SPO URL
	$URL = "https://my.sharepoint.com/personal/$FormattedName"

	# Begin uploading files
	Upload-Files -Url $URL -UserName $UserEmail -Password $Password -TargetListTitle $TargetListTitle -SourceFolderPath $SourceFolderPath

	Stop-Transcript
}

# Limit concurrent jobs
function Throttle-Jobs {
	param([int] $MaxJobs = 2)
	while ( (Get-Job -State Running | Measure-Object).Count -ge $MaxJobs ) {
		Start-Sgllleep 1
	}
}

# Clear completed jobs
function Clear-CompletedJobs {
	foreach ($Job in Get-Job) {
		if ($Job.State -eq 'Completed') {
			Write-Host "$($Job.Name) import complete!" -ForegroundColor Green
			Remove-Job $Job
		}
	}
}

# Create logs directory and begin transcript
$LogFolder = New-Item -ItemType Directory ".\logs" -Force
$Date = (Get-Date).ToString('yyyyMMdd-HHmm')
Start-Transcript ".\logs\_Migration-$Date.log"

# Import CSV with user details
$UsersCSV = Import-Csv '.\users.csv'

foreach ($User in $UsersCSV) {
	Throttle-Jobs
    Clear-CompletedJobs

	$Email = $User.Email
	$Password = $User.Password
	$UserDirectory =  ".\$Email"

	Write-Host 'Starting migration of ' -NoNewline
    Write-Host $Email -ForegroundColor Cyan

	# Upload files
	if (Test-Path $UserDirectory) {
		$SourceFolderPath = (Get-Item $UserDirectory).Fullname
		Start-Job -Name "$Email" -ScriptBlock $Functions -ArgumentList $Email, $Password, $SourceFolderPath | Out-Null
		Write-Host "Job started for $Email." -ForegroundColor Cyan
	} else {
		Write-Host "No user directory located at $UserDirectory." -ForegroundColor Yellow
	}
}

# Wait for the remaining jobs to complete
While (Get-Job) {
    Clear-CompletedJobs
    Start-Sleep 1
}

Stop-Transcript