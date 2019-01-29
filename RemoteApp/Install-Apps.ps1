$url = 'RDSBROKER.COMPANY.COM'
$domain = 'DOMAIN'

Write-Host "Cleaning up previous RemoteApp install..."

try {
    $feeds = Get-ChildItem 'HKCU:\Software\Microsoft\Workspaces\Feeds' -ErrorAction Stop
}
catch {
    Write-Host "No feeds found"
}

if ($feeds) {
    foreach ($feed in $feeds) {
        $id = (Get-ItemProperty $feed.PSPath -Name WorkspaceId).WorkspaceId

        if ($id -eq $url) {
            Write-Host "Previous install found"

            Write-Host "Removing Workspace folder..."
            $workspaceFolder = (Get-ItemProperty $feed.PSPath -Name WorkspaceFolder).WorkspaceFolder
            Remove-Item $workspaceFolder -Recurse -ErrorAction SilentlyContinue

            Write-Host "Removing Desktop icons..."
            $startFolder = (Get-ItemProperty $feed.PSPath -Name StartMenuRoot).StartMenuRoot
            $apps = Get-ChildItem $startFolder
            $desktopIcons = Get-ChildItem "$env:USERPROFILE\Desktop"
            foreach ($icon in $desktopIcons) {
                if ($apps.Name -contains $icon.Name) {
                    Remove-Item $icon.FullName
                }
            }

            Write-Host "Removing Start Menu items..."
            Remove-Item $startFolder -Recurse

            Write-Host "Removing registry items..."
            Remove-Item $feed.PSPath -Recurse
        }

        Write-Host "Cleanup complete"

        break
    }
}

Write-Host "`n`nEnter your credentials..."

try {
    $creds = Get-Credential -Credential $null
}
catch {
    Write-Warning "You must enter credentials to complete the setup"
    Read-Host "`n`nPress [Enter] to exit"
    exit
}

$username = $creds.UserName
$password = $creds.GetNetworkCredential().Password

Write-Host "`n`nAdding credentials to Credential Manager..."
cmdkey /add:$url /user:$domain$username /password:$password
cmdkey /add:*.company.com /user:$domain$username /password:$password
cmdkey /add:TERMSRV/$url /user:$domain$username /password:$password

Write-Host "`n`nSetting up Workspace..."

$winVer = [System.Environment]::OSVersion.Version.Major
if ($winVer -ne "10" ) {
    Write-Host "Windows 10 not detected"
    $userProf = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\RemoteApp and Desktop Connections\Work Resources\"
}
else {
    Write-Host "Windows 10 detected"
    $userProf = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Work Resources (RADC)"
}

# Create the wcx file
Write-Host "Creating setup wcx file..."
$wcxPath = "$env:TEMP\RDSWebSetup.wcx"
$config = @"
<?xml version=`"1.0`" encoding=`"utf-8`" standalone=`"yes`"?>
<workspace name=`"Workspace Resources`" xmlns=`"http://schemas.microsoft.com/ts/2008/09/tswcx`" xmlns:xs=`"http://www.w3.org/2001/XMLSchema`">
  <defaultFeed url=`"https://$url/RDWeb/Feed/webfeed.aspx`" />
</workspace>
"@
New-Item -Path $wcxPath -ItemType "File" -Value $config -Force | Out-Null

# Silently run the RemoteApp config
Write-Host "Running wcx setup..."
rundll32.exe tsworkspace, WorkspaceSilentSetup $wcxPath



# Wait until the icons appear in the user profile and then copy them to the desktop
Write-Host "Waiting for Workspace icons to be created..."
$counter = 0
$timeout = $false

while (-not (Test-Path $userProf) -and $counter -lt 15) {
    Start-Sleep -Seconds 2
    $counter++
}

if ($counter -eq 15) {
    $timeout = $true
}

$found = $false

$feeds = Get-ChildItem 'HKCU:\Software\Microsoft\Workspaces\Feeds'
foreach ($feed in $feeds) {
    $id = (Get-ItemProperty $feed.PSPath -Name WorkspaceId).WorkspaceId

    if ($id -eq $url) {
        $found = $true
    }
}

if (-not $found -or $timeout) {
    Write-Host "`n`nCredentials invalid or timeout reached. Please follow the instructions in the new window..." -ForegroundColor Red

    Start-Process $wcxPath -Wait
}

Remove-Item $wcxPath

Write-Host "`n`nCopying icons to desktop..."
Copy-Item "$userProf\*" "$env:USERPROFILE\Desktop\" -Recurse -Force

Read-Host "`n`nPress [Enter] to exit"
exit