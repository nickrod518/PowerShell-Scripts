function Sync-Gal {
    <#
        .DESCRIPTION
        Does a one-way sync between two Exchange Online Gal's.

        .PARAMETER PrimaryTenantCreds
        Credentials to login to the primary tenant.

        .PARAMETER SecondaryTenantCreds
        Credentials to login to the secondary tenant.

        .PARAMETER AsJob
        Enables the updates to be run as PS Jobs.

        .PARAMETER Jobs
        The number of PS Jobs to create to run the updates. Limited to 3 because of an O365 default max concurrent connection.

        .PARAMETER ContactLimit
        Number of contacts to sync. Default is Unlimited. Useful for doing quick tests.

        .EXAMPLE
        ./Sync-Gal.ps1 -PrimaryTenantCreds (Get-Credential) -SecondaryTenantCreds (Get-Credential) -AsJob -Jobs 3

        .EXAMPLE
        ./Sync-Gal.ps1

        .NOTES
        Created by Nick Rodriguez
        Syncs the Gal of Exchange Online across two Office 365 tenants
        Note that this will break the creation of external user objects until MS addresses a known issue:
        https://products.office.com/en-us/business/office-365-roadmap?filters=&featureid=72273
    #>
    [CmdletBinding(
        SupportsShouldProcess = $true,
        DefaultParameterSetName = 'Synchronous'
    )]
    Param(
        [Parameter(Mandatory = $true)]
        [PSCredential]
        $PrimaryTenantCreds,

        [Parameter(Mandatory = $true)]
        [PSCredential]
        $SecondaryTenantCreds,

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
        $Jobs = 2,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, [Int]::MaxValue)]
        [Int]
        $ContactLimit = 0
    )

    begin {
        # Log everything
        $LogDirectory = (New-Item -ItemType Directory "C:\powershell-scripts\Exchange Online\Logs" -Force).FullName
        $Date = (Get-Date).ToString('yyyyMMdd-HHmm')
        Start-Transcript -Path "$LogDirectory\$($MyInvocation.MyCommand.Name)-$Date.log"
    }

    process {
        # Create Exchange Online PowerShell session for primary tenant
        $PrimaryTenantEOSession = New-EOSession -Credential $PrimaryTenantCreds

        # Enter session on primary tenant
        Import-PSSession $PrimaryTenantEOSession

        # Get all Gal recipients using the primary filter
        $GalFilter = (Get-GlobalAddressList).RecipientFilter
        $ResultSizeLimit = if ($ContactLimit -eq 0) { 'Unlimited' } else { $ContactLimit }
        $Gal = Get-Recipient -ResultSize $ResultSizeLimit -Filter $GalFilter

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
            foreach ($ContactList in $ContactLists.Values) {
                Start-Job -ArgumentList $SecondaryTenantCreds, $ContactList -ScriptBlock {
                    # Create Exchange Online PS session
                    $SecondaryTenantEOSession = New-EOSession -Credential $args[0]

                    # Enter session on secondary tenant
                    Import-PSSession $SecondaryTenantEOSession
    
                    Update-GalContact -Gal $args[1]
    
                    # Remove session on secondary tenant
                    Remove-PSSession -Session $SecondaryTenantEOSession
                } -InitializationScript { Import-Module 'C:\powershell-scripts\Exchange Online\GalSync.psm1' }
            }

            # Wait for all jobs to finish then receive and remove the jobs
            Get-Job | Wait-Job | Receive-Job
            Get-Job | Remove-Job
        } else {
            # Create Exchange Online PS session
            $SecondaryTenantEOSession = New-EOSession -Credential $SecondaryTenantCreds

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
}

function New-EOSession {
    <#
        .DESCRIPTION
        Create a new Exchange Online PowerShell session

        .PARAMETER Credential
        The credentials to use for the session.

        .EXAMPLE
        New-EOSession -Credential $creds

        .NOTES
        Created by Nick Rodriguez
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $true)]
        [PSCredential]
        $Credential
    )

    New-PSSession -ConfigurationName Microsoft.Exchange -Authentication Basic -AllowRedirection `
        -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $Credential
}

function Update-GalContact {
    <#
        .DESCRIPTION
        Takes an array of recipients and updates the Gal.

        .PARAMETER Gal
        The recipient or list of reipients to update.

        .EXAMPLE
        Update-GalContact -Gal $ExternalGal

        .NOTES
        Created by Nick Rodriguez
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [PSObject[]]$Gal
    )

    foreach ($Recipient in $Gal) {
        # Create a new contact if one doesn't exist
        if (Get-MailContact -Identity $Recipient.Name) {
            Write-Host "Contact $($Recipient.Name) already exists."
        } else {
            try {
                New-MailContact `
                    -ExternalEmailAddress $Recipient.PrimarySmtpAddress `
                    -Name $Recipient.Name `
                    -FirstName $Recipient.FirstName `
                    -LastName $Recipient.LastName `
                    -DisplayName $Recipient.DisplayName `
                    -Alias $Recipient.Alias
                Write-Host "New contact created for $($Recipient.Name)"
            } catch {
                Write-Host "Error creating new contact for $($Recipient.Name): $_"
            }
        }

        try {
            # Update mail contact properties
            Set-MailContact `
                -Identity $Recipient.Name `
                -ExternalEmailAddress $Recipient.PrimarySmtpAddress `
                -Name $Recipient.Name `
                -DisplayName $Recipient.DisplayName `
                -Alias $Recipient.Alias `
                -CustomAttribute1 $Recipient.CustomAttribute1 `
                -CustomAttribute2 $Recipient.CustomAttribute2 `
                -CustomAttribute3 $Recipient.CustomAttribute3 `
                -CustomAttribute4 $Recipient.CustomAttribute4 `
                -CustomAttribute5 $Recipient.CustomAttribute5 `
                -CustomAttribute6 $Recipient.CustomAttribute6 `
                -CustomAttribute7 $Recipient.CustomAttribute7 `
                -CustomAttribute8 $Recipient.CustomAttribute8 `
                -CustomAttribute9 $Recipient.CustomAttribute9 `
                -CustomAttribute10 $Recipient.CustomAttribute10 `
                -CustomAttribute11 $Recipient.CustomAttribute11 `
                -CustomAttribute12 $Recipient.CustomAttribute12 `
                -CustomAttribute13 $Recipient.CustomAttribute13 `
                -CustomAttribute14 $Recipient.CustomAttribute14 `
                -CustomAttribute15 $Recipient.CustomAttribute15 `
                -ExtensionCustomAttribute1 $Recipient.ExtensionCustomAttribute1 `
                -ExtensionCustomAttribute2 $Recipient.ExtensionCustomAttribute2 `
                -ExtensionCustomAttribute3 $Recipient.ExtensionCustomAttribute3 `
                -ExtensionCustomAttribute4 $Recipient.ExtensionCustomAttribute4 `
                -ExtensionCustomAttribute5 $Recipient.ExtensionCustomAttribute5 `
            | Out-Null
            
            # Update Windows Email Address only if it's populated
            if ($Recipient.WindowsLiveID -ne '') {
                Set-MailContact -Identity $Recipient.Name -WindowsEmailAddress $Recipient.WindowsLiveID | Out-Null
            }
        } catch {
            Write-Host "Error updating mail contact info for $($Recipient.Name): $_"
        }

        try {
            # Update contact properties
            Set-Contact `
                -Identity $Recipient.Name `
                -FirstName $Recipient.FirstName `
                -LastName $Recipient.LastName `
                -Department $Recipient.Department `
                -Company $Recipient.Company `
                -Phone $Recipient.Phone `
                -HomePhone $Recipient.HomePhone `
                -OtherHomePhone $Recipient.OtherHomePhone `
                -MobilePhone $Recipient.MobilePhone `
                -OtherTelephone $Recipient.OtherTelephone `
                -Pager $Recipient.Pager `
                -Fax $Recipient.Fax `
                -OtherFax $Recipient.OtherFax `
                -Office $Recipient.Office `
                -CountryOrRegion $Recipient.UsageLocation `
                -StreetAddress $Recipient.StreetAddress `
                -City $Recipient.City `
                -StateOrProvince $Recipient.StateOrProvince `
                -PostalCode $Recipient.PostalCode `
                -PostOfficeBox $Recipient.PostOfficeBox `
                -Title $Recipient.Title `
                -Manager $Recipient.Manager `
                -AssistantName $Recipient.AssistantName `
                -Notes $Recipient.Notes `
            | Out-Null
        } catch {
            Write-Host "Error updating contact info for $($Recipient.Name): $_"
        }
    }
}