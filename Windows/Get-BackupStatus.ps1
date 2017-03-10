if ($env:COMPUTERNAME -ne 'BackupServer') {
    Write-Warning 'This needs to be run from [BackupServer]'
    Pause
    exit
}

Get-WBJob

while ((Get-WBJob).JobState -eq 'Running') {
    (Get-WBJob).CurrentOperation
    Start-Sleep -Seconds 30
}

Get-WBJob
Pause