$servers = get-content \\server01\servers.txt
$badVersions = @{}
#$appName = Read-Host "Enter the app GUID or display name to search for (`"{E87F5D52-F934-4457-B6FF-8EC31BEE5650}`" or `"LTCCorePointInstall`")"
$GUID = 'LTCCorePointInstall'
#$version = Read-Host "Enter version number to compare (eg, 15.09.10)"
$version = '15.09.10'


 
Foreach ($server in $servers) {

    if (!$GUID.StartsWith('{')) {
        $GUID = Invoke-Command -cn $server -ArgumentList $GUID -ScriptBlock {
            $apps = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*
            $app = $apps | Where-Object { $_.DisplayName -eq $args[0] }
            $app.PSChildName
        }
    }

    $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $server)
    $RegKey= $Reg.OpenSubKey("Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\$GUID")
    $appVersion = $RegKey.GetValue("DisplayVersion")
    if ($appVersion -ne $version) {
        if ($appVersion -eq '') { $appVersion = 'Not installed.' }
        $badVersions.Add($server, $appVersion)
    }
}
 
if (!$badVersions.Count) {
    Write-Host "App version is correct on all of the servers listed in \\server01\servers.txt" -ForegroundColor Green -BackgroundColor Black
} else {
    $badVersions.GetEnumerator() | Out-String
    Write-Host "Updated app version not found on the the following servers: `n$results" -ForegroundColor Red -BackgroundColor Black
}