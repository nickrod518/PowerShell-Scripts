function ConvertTo-CCMFriendlyEvaluationState {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string]$EvaluationState
    )

    switch ($EvaluationState) {
        0 { 'None'; break }
        1 { 'Available'; break }
        2 { 'Detecting'; break }
        4 { 'PreDownload'; break }
        5 { 'Downloading'; break }
        6 { 'WaitInstall'; break }
        7 { 'Installing'; break }
        8 { 'PendingSoftReboot'; break }
        9 { 'PendingHardReboot'; break }
        10 { 'WaitReboot'; break }
        11 { 'Verifying'; break }
        12 { 'InstallComplete'; break }
        13 { 'Error'; break }
        14 { 'WaitServiceWindow'; break }
        15 { 'WaitUserLogon'; break }
        16 { 'WaitUserLogoff'; break }
        17 { 'WaitJobUserLogon'; break }
        18 { 'WaitUserReconnect'; break }
        19 { 'PendingUserLogoff'; break }
        20 { 'PendingUpdate'; break }
        21 { 'WaitingRetry'; break }
        22 { 'WaitPresModeOff'; break }
        23 { 'WaitForOrchestration'; break }
        default { 'Unknown' }
    }
}

function Get-WindowsUpdate {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string]$ComputerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $false)]
        [pscredential]$Credential
    )
    
    if ($Credential) {
        $AvailableUpdates = Get-WmiObject -Query 'SELECT * FROM CCM_SoftwareUpdate' -Namespace 'ROOT\ccm\ClientSDK' `
            -ComputerName $ComputerName -Credential $Credential
    } else {
        $AvailableUpdates = Get-WmiObject -Query 'SELECT * FROM CCM_SoftwareUpdate' -Namespace 'ROOT\ccm\ClientSDK' `
            -ComputerName $ComputerName
    }
}

function Install-WindowsUpdate {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string]$ComputerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $false)]
        [pscredential]$Credential
    )
    
    $AvailableUpdates = if ($Credential) {
        Get-WindowsUpdate -ComputerName $ComputerName -Credential $Credential
    } else {
        Get-WindowsUpdate -ComputerName $ComputerName
    }
    
    if ($AvailableUpdates) {
        Write-Verbose "The following updates are available:"
        foreach ($Update in $AvailableUpdates) { Write-Verbose $Update.Name }

        if ($pscmdlet.ShouldProcess($ComputerName, "Install all available Windows Updates")) {
            $ScriptBlock = {
                ([wmiclass]'ROOT\ccm\ClientSDK:CCM_SoftwareUpdatesManager').InstallUpdates(
                    (
                        [System.Management.ManagementObject[]] `
                        (Get-WmiObject -Query 'SELECT * FROM CCM_SoftwareUpdate' -Namespace 'ROOT\ccm\ClientSDK')
                    )
                )
            }

            if ($Credential) {
                Invoke-Command -ComputerName $ComputerName -ArgumentList $AvailableUpdates -ScriptBlock $ScriptBlock `
                    -Credential $Credential
            } else {
                Invoke-Command -ComputerName $ComputerName -ArgumentList $AvailableUpdates -ScriptBlock $ScriptBlock
            }

            $Running = $true

            while ($Running) {
                $AvailableUpdates = if ($Credential) {
                    Get-WindowsUpdate -ComputerName $ComputerName -Credential $Credential
                } else {
                    Get-WindowsUpdate -ComputerName $ComputerName
                }

                $Running = $AvailableUpdates | Where-Object {
                    # ciJobStatePendingSoftReboot or ciJobStatePendingHardReboot or ciJobStateInstallComplete
                    $_.EvaluationState -eq 8 -or $_.EvaluationState -eq 9 -or $_.EvaluationState -eq 12
                }

                Start-Sleep -Seconds 10
            }

            Write-Output $AvailableUpdates
        }
    } else {
        Write-Verbose "No updates available for $ComputerName."
    }
}

Export-ModuleMember -Function *