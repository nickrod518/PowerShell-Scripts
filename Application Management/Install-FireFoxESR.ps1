# Mozilla Firefox Install Script
# This script will fetch and then install the most current version of the 32-Bit Mozilla Firefox ESR.
# 2017/03/07 - William.Myers1


# Specify the URL Source for Firefox.
$FireFoxSourceURI = "https://download.mozilla.org/?product=firefox-esr-latest&lang=en-US"

# Specify the location to cache the download
$DownloadLocation = "$ENV:Temp\Firefox Setup esr.exe"

#Define a list of processes to stop
$ProcessesToStop = @(
"Firefox*"
)

# Retrieve the file
Write-host "Retrieving download from $FireFoxSourceURI"
write-host "Downloading file to $DownloadLocation"
Invoke-WebRequest -uri $FireFoxSourceURI -Outfile "$DownloadLocation"

# Stop running processes
foreach ($ProcToStop in $ProcessesToStop){
    get-process $ProcToStop -EA SilentlyContinue |Stop-Process -FOrce
}


# Launch the installer.
start-process -filepath "$DownloadLocation" -argumentlist "-MS" -wait


# Delete the global desktop shortcut
IF (Test-path "$ENV:SystemDrive\Users\Public\Desktop\Mozilla Firefox.lnk"){
    Remove-item "$ENV:SystemDrive\Users\Public\Desktop\Mozilla Firefox.lnk"}