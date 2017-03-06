function Mail-Results {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $MessageBody,

        [Parameter(Mandatory=$true)]
        [string[]]
        $Attachments
    )

    $SMTPServer = 'smtp1.corp.local'
    $SMTP = New-Object Net.Mail.SmtpClient($SMTPServer)

    $Message = New-Object Net.Mail.MailMessage
    $Message.From = 'MunkiAlerts@company.com'
    $Message.To.Add('me@company.com')
    $Message.Subject = 'Munki Sync Results'
    $Message.Body = $MessageBody
    foreach ($Report in $Attachments) {
        $Message.Attachments.Add($Report)
    }
    $SMTP.Send($Message)
}

function Convert-RobocopyExitCode ($ExitCode) {
    switch ($ExitCode) {
        16 {'***FATAL ERROR***'}
        15 {'OKCOPY + FAIL + MISMATCHES + XTRA'}
        14 {'FAIL + MISMATCHES + XTRA'}
        13 {'OKCOPY + FAIL + MISMATCHES'}
        12 {'FAIL + MISMATCHES'}
        11 {'OKCOPY + FAIL + XTRA'}
        10 {'FAIL + XTRA'}
        9 {'OKCOPY + FAIL'}
        8 {'FAIL'}
        7 {'OKCOPY + MISMATCHES + XTRA'}
        6 {'MISMATCHES + XTRA'}
        5 {'OKCOPY + MISMATCHES'}
        4 {'MISMATCHES'}
        3 {'OKCOPY + XTRA'}
        2 {'XTRA'}
        1 {'OKCOPY'}
        0 {'No Change'}
        default {'Unknown'}
    }
}

# Create our log directory
$LogDir = New-Item -ItemType Directory "$PSScriptRoot\Logs" -Force

# Repo servers that are currently standing
$Servers = @(
    'munkirepo01',
	'munkirepo02',
	'munkirepo03'
)

$MessageBody = ''
$Logs = @()
$SourceRepo = '\\macserver.company.local\repo'

# Distribute content from the central repo to each node repo
foreach ($Repo in $Servers) {
	$Log = (New-Item -ItemType File "$LogDir\MunkiSync-$Repo-$( (Get-Date).ToString('yyyyMMdd-HHmm') ).log").FullName

    # Update repo
	ROBOCOPY $SourceRepo "\\$Repo\r$\repo" /DCOPY:DA /MIR /FFT /Z /XA:SH /R:10 /LOG:$Log /XJD
    $ExitCode = $LASTEXITCODE

    # Get volume info
    $Volume = Get-WmiObject Win32_Volume -ComputerName $Repo | Where-Object { $_.Name -eq 'R:\' } | Select-Object Name, Capacity, FreeSpace

    $Results += @([pscustomobject]@{
        Repo = $Repo
        'RoboCopy Results' = "$ExitCode`: $(Convert-RobocopyExitCode $ExitCode)"
        'Free (MB)' = [math]::truncate($Volume.FreeSpace / 1MB)
        'Capacity (MB)' = [math]::truncate($Volume.Capacity / 1MB)
        'Used (MB)' = [math]::truncate(($Volume.Capacity - $Volume.FreeSpace) / 1MB)
        'Completion Time' = Get-Date
    })
    $Logs += $Log
}

Mail-Results -MessageBody ($Results | Format-Table -AutoSize | Out-String) -Attachments $Logs