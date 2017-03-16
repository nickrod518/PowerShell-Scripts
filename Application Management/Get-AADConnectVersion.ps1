$Creds = Get-Credential
$DirSyncServer = 'dirsync01'

Invoke-Command -ComputerName $DirSyncServer -Credential $Creds -ScriptBlock {
    $RegKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    Get-ItemProperty -Path $RegKey | Where-Object -Property DisplayName -EQ 'Microsoft Azure AD Connect'
} | Select-Object -Property DisplayName, PSPath, Version, DisplayVersion | Format-List