$ScriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent
$Servers = Get-Content servers.txt

$Results = ForEach ($Server in $Servers) { 
    Invoke-Command -ComputerName $Server {
        Get-ChildItem "C:\inetpub\AHT\AHTWorkcenter\UI\bin\AHT.UI.dll" |
        Select-Object -ExpandProperty VersionInfo | 
        Select-Object OriginalFilename, FileVersion, @{ Name='ServerName'; Expression={ $env:COMPUTERNAME } }
    }
}

$Results | Select-Object OriginalFilename, FileVersion, ServerName | Format-Table -AutoSize | Out-File $ScriptPath\DLLVersions-Workcenter.txt