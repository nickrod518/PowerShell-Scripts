$ServerList = Get-Content "servers.txt"
$Counter = 0

$Results = foreach ($Computer in $ServerList) {
    $Counter++
    Write-Progress -Activity "Processing Servers" -Status $Computer -CurrentOperation "Getting CorePoint version info..." `
    -PercentComplete (($Counter / $ServerList.Count) * 100)
    
    Invoke-Command -ComputerName $Computer -ScriptBlock {
        Get-ItemProperty "HKLM:\Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{E87F5D52-F934-4457-B6FF-8EC31BEE5650}" |
        Select-Object DisplayVersion, InstallDate
    } | Select-Object @{Name = "Server"; Expression = {$Computer} }, DisplayVersion, InstallDate
}

$Results | Format-Table -AutoSize

Read-Host 'Press Enter to exit'