$scriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent

# log file that will contain our results
$date = (Get-Date).ToString('yyyyMMdd-HHmm')
$outputFolder = New-Item -ItemType Directory "$scriptPath\output" -Force
$phoneOutput = New-Item -ItemType File "$outputFolder\ReportPhonesWithoutOwner-BadPhones-$date.csv"
$logOutput = New-Item -ItemType File "$outputFolder\ReportPhonesWithoutOwner-Log-$date.log"

# import the csv file that contains the phones we want to work with
function Import () {
	$fileName = Read-Host "Exported phones csv"
	try {
		$file = Import-Csv -Path "$scriptPath\$fileName" | select *
	} catch {
		Write-Host "$fileName was not found; please try again."
		Import
	}
	Add-Content $logOutput "$(Get-Date) - $fileName used for phones data."
	return $file
}

# exported csv for phones we'll use
$phones = Import

$count = $phones.Count
$goodPhones = $badPhones = 0
Add-Content $logOutput "$(Get-Date) - Processing $count phones."

foreach ($phone in $phones) {
	$counter++
	$DeviceName = $phone.'Device Name'

	# give ourselves a nice progress bar
	Write-Progress -Activity "Processing $count phones..." -Status $DeviceName -PercentComplete (($counter / $count) * 100)
	
	# check if the phone has an owner
	if ($phone.'Owner User ID' -eq '') {
		$badPhones++
		New-Object PSObject -Property @{
			Device = $DeviceName
			Description = $phone.'Description'
		} | Export-Csv -Append -NoTypeInformation $phoneOutput
	} else {
		$goodPhones++
	}
}

Add-Content $logOutput "$(Get-Date) - $badPhones need an owner user ID assigned to them."
Write-Host "$badPhones need an owner user ID assigned to them." -ForegroundColor Red

$Percent = [int](($goodPhones / $count) * 100)
Add-Content $logOutput "$(Get-Date) - $Percent% of phones have an owner user ID assigned to them."
Write-Host "$Percent% of phones have an owner user ID assigned to them."

Write-Host "We're all done here. Your log can be found in the output folder."
pause