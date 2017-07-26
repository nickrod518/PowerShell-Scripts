[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [string]$CollectionName,

    [Parameter(Mandatory = $true)]
    [pscredential]$Credential
)

Import-Module "C:\powershell-scripts\dependencies\ConfigurationManager.psd1"
$StartingLocation = Get-Location
Set-Location -Path "$(Get-PSDrive -PSProvider CMSite):\" -ErrorAction Stop

Invoke-Command -Credential $Credential -ComputerName dcsccm03 -ScriptBlock {
    Param($CollectionName)

    Import-Module "C:\powershell-scripts\dependencies\ConfigurationManager.psd1"
    $StartingLocation = Get-Location
    Set-Location -Path "$(Get-PSDrive -PSProvider CMSite):\" -ErrorAction Stop

    Invoke-CMDeploymentSummarization -CollectionName $CollectionName -Verbose

    Set-Location $StartingLocation
    
    Start-Sleep -Seconds 10
} -ArgumentList $CollectionName

Get-CMDeployment -CollectionName $CollectionName |
    Select-Object -Property ApplicationName, NumberSuccess, NumberTargeted, SummarizationTime,
    @{
        Name = 'DeploymentSummary'
        Expression = { "{0:P0}" -f ($_.NumberSuccess / $_.NumberTargeted) }
    }

Set-Location $StartingLocation