[CmdletBinding()]
Param()

$LogDirectory = (New-Item -ItemType Directory '.\Logs' -Force).FullName
$Date = (Get-Date).ToString('yyyyMMdd-HHmm')
$LogPath = "$LogDirectory\$($MyInvocation.MyCommand.Name)-$Date.log"
Start-Transcript -Path $LogPath

.\Update-ZoomADUser.ps1
.\Set-ZoomUserIntern.ps1
.\Set-ZoomUserInternational.ps1

Stop-Transcript