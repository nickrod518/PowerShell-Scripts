# Syncs the Gal of Exchange Online across two Office 365 tenants
# Note that this will break the creation of external user objects until MS
# addresses a known issue:
# https://products.office.com/en-us/business/office-365-roadmap?filters=&featureid=72273

# Log everything
$LogDirectory = (New-Item -ItemType Directory "C:\powershell-scripts\Exchange Online\Logs" -Force).FullName
$Date = (Get-Date).ToString('yyyyMMdd-HHmm')
Start-Transcript -Path "$LogDirectory\$($MyInvocation.MyCommand.Name)-$Date.log"

# Get credentials for both tenants
Write-Host "Enter credentials for primary tenant"
$PrimaryTenantCreds = Get-Credential
Write-Host "Enter credentials for secondary tenant"
$SecondaryTenantCreds = Get-Credential

# Create Exchange Online PowerShell session for both tenants
$PrimaryTenantEOSession = New-PSSession -ConfigurationName Microsoft.Exchange `
    -ConnectionUri https://outlook.office365.com/powershell-liveid/ `
    -Credential $PrimaryTenantCreds -Authentication Basic -AllowRedirection
$SecondaryTenantEOSession = New-PSSession -ConfigurationName Microsoft.Exchange `
    -ConnectionUri https://outlook.office365.com/powershell-liveid/ `
    -Credential $SecondaryTenantCreds -Authentication Basic -AllowRedirection

# Enter session on primary tenant
Import-PSSession $PrimaryTenantEOSession

# Get all Gal recipients using the primary filter
$GalFilter = (Get-GlobalAddressList).RecipientFilter
$Gal = Get-Recipient -ResultSize Unlimited -Filter $GalFilter

# Export Gal to Csv file
$Gal | Export-Csv -Path "$LogDirectory\Gal.csv" -NoTypeInformation -Force

# Remove session on primary tenant
Remove-PSSession -Session $PrimaryTenantEOSession

# Enter session on secondary tenant
Import-PSSession $SecondaryTenantEOSession

# Create/Update contact for each Gal entry
$Gal | ForEach-Object {
    # Create a new contact if one doesn't exist
    if (Get-MailContact -Identity $_.Name) {
        Write-Host "Contact $($_.Name) already exists."
    } else {
        try {
            New-MailContact `
                -ExternalEmailAddress $_.PrimarySmtpAddress `
                -Name $_.Name `
                -FirstName $_.FirstName `
                -LastName $_.LastName `
                -DisplayName $_.DisplayName `
                -Alias $_.Alias
            Write-Host "New contact created for $($_.Name)"
        } catch {
            Write-Host "Error creating new contact for $($_.Name): $_"
        }
    }

    try {
        # Update mail contact properties
        Set-MailContact `
            -Identity $_.Name `
            -ExternalEmailAddress $_.PrimarySmtpAddress `
            -Name $_.Name `
            -DisplayName $_.DisplayName `
            -Alias $_.Alias `
            -CustomAttribute1 $_.CustomAttribute1 `
            -CustomAttribute2 $_.CustomAttribute2 `
            -CustomAttribute3 $_.CustomAttribute3 `
            -CustomAttribute4 $_.CustomAttribute4 `
            -CustomAttribute5 $_.CustomAttribute5 `
            -CustomAttribute6 $_.CustomAttribute6 `
            -CustomAttribute7 $_.CustomAttribute7 `
            -CustomAttribute8 $_.CustomAttribute8 `
            -CustomAttribute9 $_.CustomAttribute9 `
            -CustomAttribute10 $_.CustomAttribute10 `
            -CustomAttribute11 $_.CustomAttribute11 `
            -CustomAttribute12 $_.CustomAttribute12 `
            -CustomAttribute13 $_.CustomAttribute13 `
            -CustomAttribute14 $_.CustomAttribute14 `
            -CustomAttribute15 $_.CustomAttribute15 `
            -ExtensionCustomAttribute1 $_.ExtensionCustomAttribute1 `
            -ExtensionCustomAttribute2 $_.ExtensionCustomAttribute2 `
            -ExtensionCustomAttribute3 $_.ExtensionCustomAttribute3 `
            -ExtensionCustomAttribute4 $_.ExtensionCustomAttribute4 `
            -ExtensionCustomAttribute5 $_.ExtensionCustomAttribute5 `
        | Out-Null
            
        # Update Windows Email Address only if it's populated
        if ($_.WindowsLiveID -ne '') { Set-MailContact -Identity $_.Name -WindowsEmailAddress $_.WindowsLiveID | Out-Null }
    } catch {
        Write-Host "Error updating mail contact info for $($_.Name): $_"
    }

    try {
        # Update contact properties
        Set-Contact `
            -Identity $_.Name `
            -FirstName $_.FirstName `
            -LastName $_.LastName `
            -Department $_.Department `
            -Company $_.Company `
            -Phone $_.Phone `
            -HomePhone $_.HomePhone `
            -OtherHomePhone $_.OtherHomePhone `
            -MobilePhone $_.MobilePhone `
            -OtherTelephone $_.OtherTelephone `
            -Pager $_.Pager `
            -Fax $_.Fax `
            -OtherFax $_.OtherFax `
            -Office $_.Office `
            -CountryOrRegion $_.UsageLocation `
            -StreetAddress $_.StreetAddress `
            -City $_.City `
            -StateOrProvince $_.StateOrProvince `
            -PostalCode $_.PostalCode `
            -PostOfficeBox $_.PostOfficeBox `
            -Title $_.Title `
            -Manager $_.Manager `
            -AssistantName $_.AssistantName `
            -Notes $_.Notes `
        | Out-Null
    } catch {
        Write-Host "Error updating contact info for $($_.Name): $_"
    }
}

# Remove session on secondary tenant
Remove-PSSession -Session $SecondaryTenantEOSession

Stop-Transcript