$scriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent

# log file that will contain our results
$date = (Get-Date).ToString('yyyyMMdd-HHmm')
$outputFolder = New-Item -ItemType Directory "$scriptPath\output" -Force
$userOutput = New-Item -ItemType File "$outputFolder\ReportUsersHomeCluster-BadUsers-$date.csv"
$logOutput = New-Item -ItemType File "$outputFolder\ReportUsersHomeCluster-Log-$date.log"

# import the csv file that contains the users we want to work with
function Import () {
	$fileName = Read-Host "Exported users csv"
	try {
		$file = Import-Csv -Path "$scriptPath\$fileName" | select 'USER ID', 'HOME CLUSTER'
	} catch {
		Write-Host "$fileName was not found; please try again."
		Import
	}
	Add-Content $logOutput "$(Get-Date) - $fileName used for users data."
	return $file
}

# exported csv for users we'll use
$users = Import

$count = $users.Count
$goodUsers = $badUsers = 0
Add-Content $logOutput "$(Get-Date) - Processing $count users."

foreach ($user in $users) {
	$counter++
	$UserID = $user.'USER ID'

	# give ourselves a nice progress bar
	Write-Progress -Activity "Processing $count users..." -Status $UserID -PercentComplete (($counter / $count) * 100)
	
	# check if the "HOME CLUSTER" option is set to true
	if ($user.'HOME CLUSTER' -eq 'f') {
		$badUsers++
		New-Object PSObject -Property @{
			User = $UserID
		} | Export-Csv -Append -NoTypeInformation $userOutput
	} else {
		$goodUsers++
	}
}

Add-Content $logOutput "$(Get-Date) - $badUsers users have do not have the home cluster option set."
Write-Host "$badUsers users have do not have the home cluster option set." -ForegroundColor Red

$Percent = [int](($goodUsers / $count) * 100)
Add-Content $logOutput "$(Get-Date) - $Percent% of users have the home cluster option set."
Write-Host "$Percent% of users have the home cluster option set."

Write-Host "We're all done here. Your log can be found in the output folder."
pause