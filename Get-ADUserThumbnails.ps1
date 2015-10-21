# import commands to speak with AD
Import-Module ActiveDirectory
# get the directory our script was called from
$scriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent
# create a thumbnails directory here
New-Item -Type Directory $scriptPath\thumbnails -Force

# pretty progress banner
Write-Progress -Activity "Gathering all users with thumbnail photos..."
# get all the AD accounts with a thumbnail photo
$users = Get-ADUser -Filter * -Properties thumbnailphoto | Where-Object { $_.thumbnailphoto }
# how many accounts have thumbnails
$count = $users.Count
# create a counter to keep track of percent complete
$counter = 0

# loop through each user account with a thumbnail photo
foreach ($user in $users) {
	# increment our counter to keep track of percent complete
	$counter++
	# pretty progress bar showing percent complete and what user we're currently on
	Write-Progress -Activity "Processing $count users..." -Status "Downloading thumbnail for $($user.Name)" -PercentComplete (($counter / $count) * 100)
	# get the email of the user and make it all lowercase
	$fullname = ($user.UserPrincipalName).ToLower()
	# download the user's thumbnail and name it according to the name we just created
	$user.thumbnailphoto | Set-Content "$scriptPath\thumbnails\$fullname.jpg" -Encoding byte
}

# try to zip up our thumbnails folder and remove the original folder if successful
try {
	Add-Type -AssemblyName System.IO.Compression.FileSystem
	[System.IO.Compression.ZipFile]::CreateFromDirectory("$scriptPath\thumbnails", "$scriptPath\thumbnails.zip")
	Remove-Item -Path "$scriptPath\thumbnails" -Force -Recurse
} catch {
	Read-Host "There was a problem zipping the thumbnails directory. PowerShell 3.0+ and .NET 4.5+ is required for this."
}
