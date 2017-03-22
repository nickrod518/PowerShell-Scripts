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
        This is a helper function for Sync-Gal.ps1
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