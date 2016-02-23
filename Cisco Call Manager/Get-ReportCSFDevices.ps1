$scriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent

# log file that will contain our results
$date = (Get-Date).ToString('-yyyyMMdd-HHmm')
$outputFolder = New-Item -ItemType Directory "$scriptPath\output" -Force
$userOutput = New-Item -ItemType File "$outputFolder\ReportUsers-BadUsers-$date.csv"
$logOutput = New-Item -ItemType File "$outputFolder\ReportUsers-Log-$date.log"

# import the csv file that contains the users we want to work with
function Import () {
	$fileName = Read-Host "Exported users csv"
	try {
		$file = Import-Csv -Path "$scriptPath\$fileName" | select 'USER ID', 'PRIMARY EXTENSION', 'CONTROLLED DEVICE 1', 'CONTROLLED DEVICE 2', 'CONTROLLED DEVICE 3', 'CONTROLLED DEVICE 4', 'CONTROLLED DEVICE 5', 'CONTROLLED DEVICE 6', 'CONTROLLED DEVICE 7'
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
	$userID = $user.'USER ID'

	# give ourselves a nice progress bar
	Write-Progress -Activity "Processing $count users..." -Status $userID -PercentComplete (($counter / $count) * 100)
	
	# check if the user has a CSF device as a controlled device
	$bad = $true
	for ($i = 1; $i -le 5; $i++) {
		if ($user."CONTROLLED DEVICE $i" -eq '') {
			$badUsers++
			New-Object PSObject -Property @{
				USER_ID = $userID
				PRIMARY_EXTENSION = $user.'PRIMARY EXTENSION'
			} | Export-Csv -Append -NoTypeInformation $userOutput
			break
		} else {
			if (($user."CONTROLLED DEVICE $i").StartsWith('CSF')) {
				$goodUsers++
				$bad = $false
				break
			}
		}
	}
}

Add-Content $logOutput "$(Get-Date) - $badUsers need a CSF device created and assigned to them."
Write-Host "$badUsers need a CSF device created and assigned to them." -ForegroundColor Red

$percent = [int](($goodUsers / $count) * 100)
Add-Content $logOutput "$(Get-Date) - $percent% of users have a CSF device."
Write-Host "$percent% of users have a CSF device."

Write-Host "We're all done here. Your log can be found in the output folder."
pause