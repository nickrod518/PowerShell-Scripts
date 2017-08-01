[CmdletBinding()]
Param()

$LogDirectory = (New-Item -ItemType Directory '.\Logs' -Force).FullName
$Date = (Get-Date).ToString('yyyyMMdd-HHmm')
$LogPath = "$LogDirectory\$($MyInvocation.MyCommand.Name)-$Date.log"
Start-Transcript -Path $LogPath

$Params = @{
    'ADSearchBase' = 'OU=Users,DC=Company,DC=LOCAL'
    'ADNotLikeFilter' = '*OU=Disabled*'
    'DefaultZoomGroup' = 'General'
    'EOCredential' = Get-Credential
}
.\Update-ZoomADUser.ps1 -UpdatePictureFromEO @Params
.\Set-ZoomUserIntern.ps1
.\Set-ZoomUserInternational.ps1

Stop-Transcript