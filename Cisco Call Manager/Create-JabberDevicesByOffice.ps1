Import-Module ActiveDirectory

$scriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent

# let the user select a location from a filtered list retrieved from the Offices OU in AD
try {
	# exclude these locations
	$badOffices = @('Computers', 'Disabled Accounts', 'Old Groups', 'Termed prior to migration', 'zz Disabled Accounts Office 365 Okta', 'zz FTG Azure Office 365 Admins', 'SMTP Custom Contacts', 'O365ScriptTest')
	$office = Get-ADOrganizationalUnit -SearchBase 'OU=Offices,DC=CORP,DC=LOCAL' -Filter * | select Name, distinguishedName | Sort-Object Name | 
	Where-Object { $badOffices -notcontains $_.Name } | Out-GridView -Title 'Select a location' -OutputMode Single
} catch {
	exit
}
$location = $office.Name
# location will be empty if user hits cancel on previous prompt, in which case we want to abandon ship
try { $locationNoSpaces = $($location.Replace(' ', '')) } catch { exit }

# 3 files we'll save the output csv files to be imported into call manager, dated, plus a log file
$date = (Get-Date).ToString('yyyyMMdd-HHmm')
$outputFolder = New-Item -ItemType Directory "$scriptPath\output" -Force
$phoneOutput = New-Item -ItemType File "$outputFolder\JabberDevices-$locationNoSpaces-Phones-$date.csv"
$userOutput = New-Item -ItemType File "$outputFolder\JabberDevices-$locationNoSpaces-Users-$date.csv"
$logOutput = New-Item -ItemType File "$outputFolder\JabberDevices-$locationNoSpaces-Log-$date.log"

# import the users file exported from CM and Unity
function Import ($type) {
    Start-Sleep -Seconds 1
	$fileName = Read-Host "Exported $type users file"
	try {
		# exclude 'DIGEST CREDENTIALS', per Cisco TAC, to avoid an error about character length
		$file = Import-Csv -Path "$scriptPath\$fileName" | select * -ExcludeProperty 'DIGEST CREDENTIALS'
	} catch {
		Write-Host "$fileName was not found; please try again."
		Import $type
	}
	Add-Content $logOutput "$(Get-Date) - $fileName used for $type users data."
	return $file
}

# exported csv for users and unity mailboxes we'll use to scrounge for data
$users = Import 'CM'
$unity = Import 'Unity'

# office code map - this would be the first three digits of the user's extension and what office that translates to
$officeCodes = @{
	200 = 'Office1'; 201 = 'Office2'; 202 = 'Office3'
}

# if the user's extension ends in that office's front desk number, don't create a Jabber device for them
$officeNumbers = @{
    'Office1' = 1234; 'Office2' = 1234; 'Office3' = 1234
}

# add all users from that OU into our ADLocationUsers dictionary
$ADLocationUsers = Get-ADUser -SearchBase $office.distinguishedName -Properties sAMAccountName, ipPhone, telephoneNumber, distinguishedName, sAMAccountName -Filter *
Add-Content $logOutput "$(Get-Date) - $($ADLocationUsers.Count) users found in the $location OU."

$count = $ADLocationUsers.Count
$counter = $badUsers = $processedUsers = 0
$alreadyUsers = $badADUsers = @()
Add-Content $logOutput "$(Get-Date) - Processing $count users."

:nextUser foreach ($ADUser in $ADLocationUsers) {
	$counter++
	$userID = $ADUser.SamAccountName
	$user = ( $users | Where-Object { $_.'USER ID' -like $userID } )

	# give ourselves a nice progress bar
	Write-Progress -Activity "Processing $count users in $location..." -Status $userID -PercentComplete (($counter / $count) * 100)

	if (-not $user) {
		Add-Content $logOutput "$(Get-Date) - $userID was not found in the provided users file; skipped."
		$badADUsers += $userID
		Continue
	}
	
	$fullName = "$($user.'FIRST NAME') $($user.'LAST NAME')"

	# if the user already has a CSF/Jabber device, skip them
	$device = "CSF$userID"
	for ($i = 1; $i -le 5; $i++) {
		if ($user."CONTROLLED DEVICE $i" -eq '') {
			break
		} else {
			if (($user."CONTROLLED DEVICE $i").StartsWith('CSF')) {
				$alreadyUsers += $userID
				Continue nextUser
			}
		}
	}

	# use the users Unity mailbox to get the correct extension
	$extension = ( $unity | Where-Object { $_.Alias -like $userID } ).Extension
	if (-not $extension) {
		Add-Content $logOutput "$(Get-Date) - A Unity mailbox was not found for $userID; skipped."
		$badUsers++
		Continue
	}

	# get the office abbreviation from the office code map, using the first 3 digits of the extension
	$officeCode = $officeCodes[ [int]$extension.Substring(0, 3) ]
	if (-not $officeCode) { 
		Add-Content $logOutput "$(Get-Date) - $userID's extension of $extension does not begin with a valid office code; skipped."
		$badUsers++
		Continue
	}

	# verify that the user's AD account does not have the phone number set as the office's number
	$fullNumber = $ADUser.telephoneNumber
	if ($fullNumber) {
		$fullNumber = $fullNumber.replace('-', '')
		$officeNumber =  $officeNumbers[$officeCode]
		if ($fullNumber.Substring($fullNumber.Length - 4, 4) -eq $officeNumber) {
			Add-Content $logOutput "$(Get-Date) - $userID's phone number in AD is set as $location's main number ($fullNumber); skipped."
			$badUsers++
			Continue
		}
	} else {
		Add-Content $logOutput "$(Get-Date) - The telephone number attribute for $userID is not set in AD; skipped."
		$badUsers++
		Continue
	}
	
	# make sure the user's AD account has the ipPhone attribute populated and that it's not set as the office's number
	$IPPhone = $ADUser.ipPhone
	if ($IPPhone) {
		if ($IPPhone.Substring($IPPhone.Length - 4, 4) -eq $officeNumber) {
			Add-Content $logOutput "$(Get-Date) - $userID's IP phone number in AD is set as $officeCode's main number ($fullNumber); skipped."
			$badUsers++
			Continue
		}
	} else {
		Add-Content $logOutput "$(Get-Date) - The ipPhone attribute for $userID is not set in AD; skipped."
		$badUsers++
		Continue
	}

	$displayName = "$officeCode-$fullName-$extension"
	
	# create the phones we'll be exporting to Phone_Update.csv
	New-Object PSObject -Property @{
        'DEVICE NAME' = $device
        'DESCRIPTION' =  $displayName
        'OWNER USER ID' = $userID
		'ASCII ALERTING NAME 1' = $fullName
		'ASCII DISPLAY 1' = $fullName
		'ALERTING NAME 1' = $fullName
        'DIRECTORY NUMBER 1' = $extension
		'DISPLAY 1' = $fullName
		'EXTERNAL PHONE NUMBER MASK 1' = $fullNumber
		'LINE DESCRIPTION 1' = $displayName
		'LINE TEXT LABEL 1' = $displayName
		'ROUTE PARTITION 1' = 'All-Phones-PT'
    } | Export-Csv -Append -NoTypeInformation $phoneOutput

	# update the user info and export to User_Update.csv
	$user.'PIN' = '123456'
	$user.'USER LOCALE' = 'English United States'
	$user.'PRIMARY EXTENSION' = "$extension in All-Phones-PT"
	$user.'ACCESS CONTROL GROUP 1' = 'Standard CTI Allow Control of Phones supporting Rollover Mode'
	$user.'ACCESS CONTROL GROUP 2' = 'Standard CTI Enabled'
	$user.'ACCESS CONTROL GROUP 3' = 'Standard CTI Allow Control of Phones supporting Connected Xfer and conf'
	$user.'ACCESS CONTROL GROUP 4' = 'Standard CCM End Users'
	# add the new phone to the next available controlled device property
	for ($i = 1; $i -le 5; $i++) {
		if ($user."CONTROLLED DEVICE $i" -eq '') {
			$user."CONTROLLED DEVICE $i" = $device
			break
		}
	}
	$user | Export-Csv -Append -NoTypeInformation $userOutput

	$processedUsers++
}

# remove all the unnecessary double quotes
(Get-Content $phoneOutput) | % {$_ -replace '"', ""} | out-file -FilePath $phoneOutput -Force -Encoding ascii
(Get-Content $userOutput) | % {$_ -replace '"', ""} | out-file -FilePath $userOutput -Force -Encoding ascii

# let us know of users that had errors and were skipped while being processed
if ($badUsers) {
	Add-Content $logOutput "$(Get-Date) - $badUsers users were not processed because of errors."
	Write-Host "$badUsers users were not processed because of errors." -ForegroundColor Red
}

# let us know about users in the OU that weren't in the users file provided
$badADUsersCount = $badADUsers.Count
if ($badADUsersCount) {
	$badADUsersList = $null
	foreach ($user in $badADUsers) {
		$badADUsersList += "$user, "
	}
	Add-Content $logOutput "$(Get-Date) - The following $badADUsersCount additional users were found in the $location OU in AD but not processed because they were not in the provided CM users file: $($badADUsersList.TrimEnd(', '))."
	Write-Host "$badADUsersCount additional users were found in the $location OU in AD but not processed because they were not in the provided CM users file." -ForegroundColor Yellow
}

# let us know about users that already have Jabber
$alreadyUsersCount = $alreadyUsers.Count
if ($alreadyUsersCount) {
	$alreadyUsersList = $null
	foreach ($user in $alreadyUsers) {
		$alreadyUsersList += "$user, "
	}
	Add-Content $logOutput "$(Get-Date) - The following $alreadyUsersCount users already have the Jabber client and were not processed: $($alreadyUsersList.TrimEnd(', '))."
	Write-Host "$alreadyUsersCount users already have the Jabber client and were not processed." -ForegroundColor Green
}

# let us know of users that were successfully processed
if ($processedUsers) {
	Add-Content $logOutput "$(Get-Date) - $processedUsers users were successfully processed."
	Write-Host "$processedUsers users were successfully processed." -ForegroundColor Green
}

Write-Host "We're all done here. Your output files can be found in the output folder."
pause