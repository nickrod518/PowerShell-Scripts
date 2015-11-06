Add-PSSnapin citrix* -ErrorAction SilentlyContinue

$scriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent

# create a log file
$log = "$scriptPath\versionList.log"
if (-not (Test-Path $log)) {
    $log = New-Item -ItemType File "$scriptPath\versionList.log"
}

# import our previous results if they exist
$versionCSV = "$scriptPath\versionList.csv"
if (-not (Test-Path $versionCSV)) {
    New-Item -ItemType File -Path $versionCSV
}
$importedCSV = Import-Csv $versionCSV -Header Workstation, Application, Client

# create a hashtable of arrays to provide superior performance comparing existing versions with new ones
$clients = @{}
# if the file is empty, we'll get an error, so put all this in a try block
try { 
    foreach($line in $importedCSV) {
        if (-not $clients.ContainsKey($line.Workstation)) {
    	   $clients.Add($line.Workstation, @($line.Application, $line.Client))
        }
    }
} catch { }

# map the build versions to a more friendly name
function convertToVersion($build) {
	switch ($build) {
		6685 {"13.0"; break}30 {"12.1"; break}6 {"12.0.3"; break}6410 {"12.0"; break}142{"Java"; break}317{"3.0"; break}324{"3.0"; break}330{"3.0"; break}349{"3.0"; break}304{"MAC 6.3"; break}314{"MAC 6.3"; break}323{"MAC 6.3"; break}326{"MAC 6.3"; break}400{"MAC 7.0"; break}402{"MAC 7.0"; break}405{"MAC 7.0"; break}406{"MAC 7.0"; break}407{"MAC 7.0"; break}402{"MAC 7.0"; break}411{"MAC 7.0"; break}500{"MAC 7.1"; break}600{"MAC 10.0"; break}601{"MAC 10.0"; break}581{"4.0"; break}606{"4.0"; break}609{"4.0"; break}614{"4.0"; break}686{"4.0"; break}715{"4.2"; break}727{"4.2"; break}741{"4.2"; break}779{"4.21"; break}730{"wyse1200le"; break}910{"6.0"; break}931{"6.0"; break}961{"6.01"; break}963{"6.01"; break}964{"6.01"; break}967{"6.01"; break}985{"6.2"; break}986{"6.2"; break}1041{"7.0"; break}1050{"6.3"; break}1051{"6.31"; break}1414{"Java 7.0"; break}1679{"Java 8.1"; break}1868{"Java 9.4"; break}1876{"Java 9.5"; break}2600{"RDP 5.01"; break}2650{"10.2"; break}3790{"RDP 5.2"; break}6000{"RDP 6.0"; break}2650{"10.2"; break}5284{"11.0"; break}5323{"11.0"; break}5357{"11.0"; break}6001{"RDP 6.0"; break}8292{"10.25"; break}10359{"10.13"; break}128b1{"MAC 10.0"; break}12221{"Linux 10.x"; break}13126{"Solaris 7.0"; break}17106{"7.0"; break}17534{"7.0"; break}20497{"7.01"; break}21825{"7.10"; break}21845{"7.1"; break}22650{"7.1"; break}24737{"8.0"; break}26449{"8.0"; break}26862{"8.01"; break}28519{"8.05"; break}29670{"8.1"; break}30817{"8.26"; break}31327{"9.0"; break}31560{"11.2"; break}32649{"9.0"; break}32891{"9.0"; break}34290{"8.4"; break}35078{"9.0"; break}36280{"9.1"; break}36824{"9.02 WinCE"; break}37358{"9.04"; break}39151{"9.15"; break}44236{"9.15 WinCE"; break}44367{"9.2"; break}44376{"9.2"; break}44467{"Linux 10.0"; break}45418{"10.0"; break}46192{"9.18 WinCE"; break}49686{"10.0"; break}50123{"Linux 10.6"; break}50211{"9.230"; break}52110{"10.0"; break}52504{"9.2"; break}53063{"9.237"; break}55362{"10.08"; break}55836{"10.1"; break}58643{"10.15"; break}				
		default {$build; break}
	}
}

Write-Host 'Getting all active ICA sessions...'
# get all active ICA sessions
$sessions = Get-XASession -Full -ErrorAction SilentlyContinue | Where-Object {$_.state -eq "Active" -and $_.protocol -eq "Ica"}
$count = $sessions.Count
Add-Content $log "$(Get-Date) - Processing $count active ICA sessions..."
$counter = $added = $updated = 0

# loop through each found session and add or update the csv
foreach ($session in $sessions) {
	$counter++
	$workstation = "$($session.AccountName)@$($session.ClientName)"

	# give ourselves a nice progress bar
	Write-Progress -Activity "Processing $count sessions..." -Status $workstation -PercentComplete (($counter / $count) * 100)
    
    $currentVersion = convertToVersion $session.ClientBuildNumber
    if ($clients.ContainsKey($workstation)) {
        if (-not ($clients.Get_Item($workstation)[1] -eq $currentVersion)) {
            # workstation exists and has a new build version, so update version
            $updated++
            $clients.Get_Item($workstation)[1] = $currentVersion
        }
    } else {
        # workstation is new, so add it
        $added++
        $clients.Add($workstation, @($session.BrowserName, $currentVersion))
    }
}

# create a new array of client psobjects that we'll export to csv
$results = @()
$clients.GetEnumerator() | ForEach-Object {
    $details = @{
        Workstation = $_.Name
        Application = $_.Get_Value()[0]
        Client = $_.Get_Value()[1]
    }
    $results += New-Object PSObject -Property $details
}
$results | Export-Csv -Path $versionCSV -NoTypeInformation

Add-Content $log "$(Get-Date) - Added $added entries and updated $updated."
Write-Host "Added $added entries and updated $updated."