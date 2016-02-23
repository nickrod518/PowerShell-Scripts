Write-Host 'Please allow several minutes for the install to complete. '

# Exit if the script was not run with Administrator priveleges
$User = New-Object Security.Principal.WindowsPrincipal( [Security.Principal.WindowsIdentity]::GetCurrent() )
if (-not $User.IsInRole( [Security.Principal.WindowsBuiltInRole]::Administrator )) {
	Write-Host 'Please run again with Administrator privileges.' -ForegroundColor Red
    Read-Host 'Press [Enter] to exit'
    exit
}

Function Download-Chrome {
    Write-Host 'Downloading Google Chrome... ' -NoNewLine

    # Test internet connection
    if (Test-Connection google.com -Count 3 -Quiet) {
        $Link = 'http://dl.google.com/edgedl/chrome/install/GoogleChromeStandaloneEnterprise.msi'

        # Download the installer from Google
        try {
	        New-Item -ItemType Directory 'C:/TEMP' -Force | Out-Null
	        (New-Object System.Net.WebClient).DownloadFile($Link, 'C:/TEMP/Chrome.msi')
            Write-Host 'success!' -ForegroundColor Green
        } catch {
	        Write-Host 'failed. There was a problem with the download.' -ForegroundColor Red
            Read-Host 'Press [Enter] to exit'
	        exit
        }
    } else {
        Write-Host "failed. Unable to connect to Google's servers." -ForegroundColor Red
        Read-Host 'Press [Enter] to exit'
	    exit
    }
}

Function Install-Chrome {
    Write-Host 'Installing Chrome... ' -NoNewline

    # Install Chrome
	$ExitCode = (Start-Process msiexec "/i C:/TEMP/Chrome.msi /qn" -Wait -PassThru).ExitCode
    
    if ($ExitCode -eq 0) {
        Write-Host 'success!' -ForegroundColor Green
    } else {
        Write-Host "failed. There was a problem installing Google Chrome. MsiExec returned exit code $ExitCode." -ForegroundColor Red
        Clean-Up
        Read-Host 'Press [Enter] to exit'
	    exit
    }
}

Function Clean-Up {
    Write-Host 'Removing Chrome installer... ' -NoNewline

    try {
        # Remove the installer
        Remove-Item C:/TEMP/Chrome.msi -ErrorAction Stop
        Write-Host 'success!' -ForegroundColor Green
    } catch {
        Write-Host 'failed. You will have to remove the installer yourself from C:\TEMP\.' -ForegroundColor Yellow
    }
}

Download-Chrome
Install-Chrome
Clean-Up

Read-Host 'Install complete! Press [Enter] to exit'