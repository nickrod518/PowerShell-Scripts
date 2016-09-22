#Requires -Version 3

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $true)]
    [string[]]$ComputerName
)

<#
.SYNOPSIS
    Runs Windows update on remote computer(s) with an emailed report of results
.DESCRIPTION
    This script disables logins and sends messages to any connected users (15, 5, and 1 minute intervals).
    After messaging job ends a VBScript is launched, which applies/installs all windows updates approved via WSUS before rebooting the server. 
    As soon as the "TermService" service is running again (necessary for Citrix services) logins are re-enabled. 
    An email is then sent out to the admins containing all applied windows updates, including exit codes. 
    The entire PowerShell transcript is then saved to a logs folder for review if necessary.
    This script is designed to run with Task Scheduler.
.NOTES
    Author : Jon Rodriguez (rewritten by Nick Rodriguez)
#>

begin {
    function Set-ComputerLogon {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param (
            [Parameter(Mandatory = $true)]
            [string[]]$ComputerName,

            [Parameter(Mandatory = $true)]
            [ValidateSet('Enable', 'Disable')]
            [string]$Action
        )
        
        $Logon = Get-CimInstance -ClassName win32_terminalservicesetting -Namespace 'root\cimv2\TerminalServices' `
            -ComputerName $ComputerName

        if ($Action -eq 'Enable') {
            $Logon.SessionBrokerDrainMode = 0
            $Logon.Logons = 0
        } else {
            $Logon.Logons = 1
        }

        try {
            Set-CimInstance -CimInstance $Logon -ComputerName $ComputerName
            Write-Verbose "Computer logon set to $Action."
        } catch {
            Write-Error "Error setting computer logon to $Action. $_"
        }
    }

    function Send-WarningMessage {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param (
            [Parameter(Mandatory = $false)]
            [string[]]$ComputerName = $env:COMPUTERNAME,
            
            # Intervals, in seconds, of 24 hours, 15 mins, 5 mins, and 1 minute
            [Parameter(Mandatory = $false)]
            [int[]]$Intervals = @(86400, 900, 300, 60)
        )

        if ($pscmdlet.ShouldProcess($ComputerName, 'Send server shutdown warning message to users')) {
            # Begin messages to all connected users
            Write-Verbose "Initiating messages"
            foreach ($Interval in ($Intervals | Sort-Object -Descending)) {
                $MessageTime = if ($Interval -lt 3600) {
                    "$($Interval / 60) minutes"
                } else {
                    "$($Interval / 3600) hours"
                }

                Write-Verbose "Sending message and waiting $Interval seconds..."

                $Message = "Please close and reopen the AHT application to connect to a different server, this server is being shutdown for updates in $MessageTime."
                msg * /SERVER:$ComputerName $Message
                Start-Sleep -Seconds $Interval
            }

            Write-Verbose "All messages sent."
        }
    }
    
    # Look for this in my repo
    Import-Module 'C:\Scripts\WindowsUpdates\WindowsUpdate.psm1'
    Add-PSSnapin citrix*

    $Results = @{}
    
    $Date = (Get-Date).ToString('yyyyMMdd-HHmm')
	Start-Transcript -Path "C:\Scripts\Logs\Install-WindowsUpdate-$Date.log" -Force
}

process {
    foreach ($Computer in $ComputerName) {
        if (Test-Connection -Count 1 -ComputerName $Computer -Quiet) {
            # Disable logons for $Computer
            Set-ComputerLogon -ComputerName $Computer -Action Disable

            # Send periodic warning messages to logged on users for $Computer
            Send-WarningMessage -ComputerName $Computer -Intervals 1

            # Graceful logoff of all Citrix sessions on server
            Get-XASession -ServerName $Computer | Stop-XASession

            # Install updates and capture exit code
            $InstalledUpdates = Install-WindowsUpdate -ComputerName $Computer
            if ($InstalledUpdates) {
                foreach ($Update in $UpdateResults) {
                    $UpdateResult = @(
                        $_.Name,
                        $_ | ConvertTo-CCMFriendlyEvaluationState
                        $_.ErrorCode
                    )
                    $Results.Add($Computer, $UpdateResult)
                }
            } else {
                $Results.Add($Computer, 'No updates available')
            }

            # Restart and wait for WinRM to start
            Restart-Computer -ComputerName $ComputerName -Wait -For WinRM -Force
            
            # Enable logons for $Computer
            Set-ComputerLogon -ComputerName $Computer -Action Enable
        } else {
            Write-Warning "$Computer is unreachable"
            $Results.Add($Computer, 'Unreachable')
        }
    }
}

end {
    Write-Verbose ($Results | Format-Table -AutoSize | Out-String)

    if ($pscmdlet.ShouldProcess('ServerUpdates@company.com', 'Send email of update results')) {
        Send-MailMessage -From 'ServerUpdates@company.com' -To 'my.email@company.com' `
            -Subject 'Server Updates'-SmtpServer smtp.company.local `
            -BodyAsHtml -Body ($Results | ConvertTo-Html | Out-String)
    }

    Stop-Transcript
}