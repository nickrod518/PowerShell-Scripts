[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
[string]$regPath = 'HKCU:\Software\Policies\Microsoft\Windows\Control Panel\Desktop\'
[string]$Status = "Time before screen saver default settings are restored:"

# Validate input; must be between 15-240
do { [int]$Minutes = Read-Host "Minutes to suspend screen saver (15-240)" }
while ((15..240) -notcontains $Minutes)

[Int32]$Seconds = $Minutes * 60
[string]$Message = "Screen saver suspended for $Minutes minutes..."

function Set-SS {
    Param (
        [Parameter(Mandatory=$true)]
        [int]
        $TimeOut,

        [Parameter(Mandatory=$true)]
        [int]
        $Active,

        [Parameter(Mandatory=$true)]
        [int]
        $IsSecure
    )

    try {
        # Set screen saver registry properties
        Set-ItemProperty -Path $regPath -Name ScreenSaveTimeOut -Value $TimeOut -ErrorAction Stop
        Set-ItemProperty -Path $regPath -Name ScreenSaveActive -Value $Active -ErrorAction Stop
        Set-ItemProperty -Path $regPath -Name ScreenSaverIsSecure -Value $IsSecure -ErrorAction Stop
    } catch {
        Write-Host 'There was an issue disabling the screen saver:'
        Write-Host $_.Exception.Message -ForegroundColor Red
        Read-Host 'Press [Enter] to exit'
        exit
    }
}

# Disable screen saver
Set-SS -TimeOut 0 -Active 0 -IsSecure 0

foreach ($Sec in (1..$Seconds)) {
    # Update progress bar every second
    Write-Progress -Activity $Message -Status $Status -SecondsRemaining ($Seconds - $Sec)

    # Disable screen saver every 5 minutes
    if ( !($Sec % 300) ) { Set-SS -TimeOut 0 -Active 0 -IsSecure 0 }

    Start-Sleep -Seconds 1

    # Restore screen saver during last second... literally
    if ($Sec -eq $Seconds) { Set-SS -TimeOut 900 -Active 1 -IsSecure 1 }
}