function New-CWSyncServer {
    <#
        .DESCRIPTION
        Add SmartSync server to CaseWare Working Papers.

        .PARAMETER HostName
        Host name of SmartSync server.

        .PARAMETER Label
        Friendly name of SmartSync server as it will appear in CaseWare Working Papers.

        .EXAMPLE
        New-CWSyncServer site01.company.com

        .NOTES
        Created by Nick Rodriguez
        Adds new SmartSync server to registry that will appear in CaseWare Working Papers.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $true)]
        [String]
        $HostName,

        [Parameter(Mandatory = $false)]
        [String]
        $FriendlyName
    )

    # Create the site key
    $RegPath = 'HKCU:\SOFTWARE\CaseWare International\Working Papers\*\SyncServer'
    if (-not (Test-Path -Path "$RegPath\{$HostName}")) { New-Item -Path $RegPath -Name "{$HostName}" }

    # Set the two site key properties
    Set-ItemProperty -Path "$RegPath\{$HostName}" -Name Host -Value $HostName
    Set-ItemProperty -Path "$RegPath\{$HostName}" -Name Label -Value $FriendlyName

    # Validate with SCCM friendly exit codes
    $SiteKey = Get-ItemProperty -Path "$RegPath\{$HostName}"
    if ($SiteKey.Host -eq $HostName -and $SiteKey.Label -eq $FriendlyName) { exit 0 } else { exit 999 }
}