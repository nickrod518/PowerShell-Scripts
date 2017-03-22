<#
    .DESCRIPTION
    Does a one-way sync between two Exchange Online Gal's.

    .PARAMETER AsJob
    Enables the updates to be run as PS Jobs.

    .PARAMETER Jobs
    The number of PS Jobs to create to run the updates. Limited to 3 because of an O365 default max concurrent connection.

    .EXAMPLE
    ./Sync-Gal.ps1 -AsJob -Jobs 3

    .EXAMPLE
    ./Sync-Gal.ps1

    .NOTES
    Created by Nick Rodriguez
#>
[CmdletBinding(
    SupportsShouldProcess = $true,
    DefaultParameterSetName = 'Synchronous'
)]
Param(
    [Parameter(
        Mandatory = $false,
        ParameterSetName = 'Asynchronous'
    )]
    [Switch]
    $AsJob,

    [Parameter(
        Mandatory = $false,
        ParameterSetName = 'Asynchronous'
    )]
    [ValidateRange(1, 3)]
    [Int]
    $Jobs = 2
)

# Syncs the Gal of Exchange Online across two Office 365 tenants
# Note that this will break the creation of external user objects until MS
# addresses a known issue:
# https://products.office.com/en-us/business/office-365-roadmap?filters=&featureid=72273

begin {
    # Log everything
    $LogDirectory = (New-Item -ItemType Directory "C:\powershell-scripts\Exchange Online\Logs" -Force).FullName
    $Date = (Get-Date).ToString('yyyyMMdd-HHmm')
    Start-Transcript -Path "$LogDirectory\$($MyInvocation.MyCommand.Name)-$Date.log"
}

process {
    # Get credentials for both tenants
    Write-Host "Enter credentials for primary tenant"
    $PrimaryTenantCreds = Get-Credential
    Write-Host "Enter credentials for secondary tenant"
    $SecondaryTenantCreds = Get-Credential

    # Create Exchange Online PowerShell session for primary tenant
    $PrimaryTenantEOSession = New-PSSession -ConfigurationName Microsoft.Exchange `
        -ConnectionUri https://outlook.office365.com/powershell-liveid/ `
        -Credential $PrimaryTenantCreds -Authentication Basic -AllowRedirection

    # Enter session on primary tenant
    Import-PSSession $PrimaryTenantEOSession

    # Get all Gal recipients using the primary filter
    $GalFilter = (Get-GlobalAddressList).RecipientFilter
    $Gal = Get-Recipient -ResultSize Unlimited -Filter $GalFilter

    # Export Gal to Csv file
    $Gal | Export-Csv -Path "$LogDirectory\Gal.csv" -NoTypeInformation -Force

    # Remove session on primary tenant
    Remove-PSSession -Session $PrimaryTenantEOSession

    # Create/Update contact for each Gal entry
    # If Jobs param specified, break up the list into smaller lists that can be started as jobs
    if ($AsJob) {
        $ContactLists = @{}
        $Count = 0

        # Separate the contacts into smaller lists
        $Gal | ForEach-Object {
            $ContactLists[$Count % $Jobs] += @($_)
            $Count++
        }

        # Create a job for each sublist of contacts
        foreach ($List in $ContactLists.Values) {
            Start-Job -ArgumentList $SecondaryTenantCreds, $List -ScriptBlock {
                # Create Exchange Online PS session
                $SecondaryTenantEOSession = New-PSSession -ConfigurationName Microsoft.Exchange `
                    -ConnectionUri https://outlook.office365.com/powershell-liveid/ `
                    -Credential $args[0] -Authentication Basic -AllowRedirection

                # Enter session on secondary tenant
                Import-PSSession $SecondaryTenantEOSession
    
                Update-GalContact -Gal $args[1]
    
                # Remove session on secondary tenant
                Remove-PSSession -Session $SecondaryTenantEOSession
            } -InitializationScript { . 'C:\powershell-scripts\Exchange Online\Update-GalContact.ps1' }
        }

        # Wait for all jobs to finish then receive and remove the jobs
        Get-Job | Wait-Job | Receive-Job
        Get-Job | Remove-Job
    } else {
        # Import function
        . 'C:\powershell-scripts\Exchange Online\Update-GalContact.ps1'

        # Create Exchange Online PS session
        $SecondaryTenantEOSession = New-PSSession -ConfigurationName Microsoft.Exchange `
            -ConnectionUri https://outlook.office365.com/powershell-liveid/ `
            -Credential $SecondaryTenantCreds -Authentication Basic -AllowRedirection

        # Enter session on secondary tenant
        Import-PSSession $SecondaryTenantEOSession
    
        Update-GalContact -Gal $Gal
    
        # Remove session on secondary tenant
        Remove-PSSession -Session $SecondaryTenantEOSession
    }
}

end {
    # Remove any lingering PSSessions and stop the logging
    Get-PSSession | Remove-PSSession
    Stop-Transcript
}