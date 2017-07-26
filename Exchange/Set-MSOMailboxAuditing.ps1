# Start a transcript of everything we do
$LogDirectory = (New-Item -ItemType Directory "$PSScriptRoot\Logs" -Force).FullName
$Date = (Get-Date).ToString('yyyyMMdd-HHmm')
$LogPath = "$LogDirectory\$($MyInvocation.MyCommand.Name)-$Date.log"
$ResultsPath = "$LogDirectory\$($MyInvocation.MyCommand.Name)-$Date.csv"

# Connect to Exchange Online
$Creds = Get-Credential
$ExchangeOnlineSession = New-PSSession -ConfigurationName Microsoft.Exchange `
    -ConnectionUri https://outlook.office365.com/powershell-liveid/ `
    -Credential $Creds -Authentication Basic -AllowRedirection
Import-PSSession $ExchangeOnlineSession

Start-Transcript -Path $LogPath

# Audit options
$AuditOwnerOptions = @(
    'Create', 'HardDelete', 'MailboxLogin', 'Move', 'MoveToDeletedItems', 
    'SoftDelete', 'Update'
)

$AuditAdminOptions = @(
    'Copy', 'Create', 'FolderBind', 'HardDelete', 'MessageBind', 'Move', 
    'MoveToDeletedItems', 'SendAs', 'SendOnBehalf', 'SoftDelete', 'Update'
)

$AuditDelegateOptions = @(
    'Create', 'FolderBind', 'HardDelete', 'Move', 'MoveToDeletedItems', 
    'SendAs', 'SendOnBehalf', 'SoftDelete', 'Update'
)

# Keep track of how many accounts we fix
$BadAccounts = 0

# Get all users and enable auditing options for their mailboxes
Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox | ForEach-Object {
    $Params = @{ 'Identity' = $_.UserPrincipalName }

    # Verify audit options are enabled
    if (-not $_.AuditEnabled) {
        Write-Output "$($_.UserPrincipalName) - enabling audit."
        $Params.Add('AuditEnabled', $true)
    }

    # Verify audit owner options are correct
    if (Compare-Object -ReferenceObject $_.AuditOwner -DifferenceObject $AuditOwnerOptions) {
        Write-Output "$($_.UserPrincipalName) - resetting Audit Owner options."
        $Params.Add('AuditOwner', $AuditOwnerOptions)
    }

    # Verify audit admin options are correct
    if (Compare-Object -ReferenceObject $_.AuditAdmin -DifferenceObject $AuditAdminOptions) {
        Write-Output "$($_.UserPrincipalName) - resetting Audit Admin options."
        $Params.Add('AuditAdmin', $AuditAdminOptions)
    }

    # Verify audit delegate options are correct
    if (Compare-Object -ReferenceObject $_.AuditDelegate -DifferenceObject $AuditDelegateOptions) {
        Write-Output "$($_.UserPrincipalName) - resetting Audit Delegate options."
        $Params.Add('AuditDelegate', $AuditDelegateOptions)
    }

    # Update user options if any don't match out settings
    if ($Params.Count -gt 1) {
        Write-Output "$($_.UserPrincipalName) - setting mailbox options."
        try { Set-Mailbox @Params -WhatIf } catch { $_ }
        $BadAccounts++
    }
}

Write-Output "Audit options were set on $BadAccounts mailboxes."

# Save resulting audit rules of all users to csv
Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox |
    Select-Object PrimarySmtpAddress, Name, Audit* |
    Export-Csv -Path $ResultsPath -NoTypeInformation

# Disconnect from Exchange Online
Remove-PSSession $ExchangeOnlineSession
Stop-Transcript

# Send results via email
$Params = @{
    'Body' = Get-Content -Path $LogPath | Out-String
    'From' = 'Alerts@company.com'
    'SmtpServer' = 'smtp.company.local'
    'Subject' = 'Enable Mailbox Auditing'
    'To' = 'person@company.com'
    'Attachments' = $ResultsPath
}
Send-MailMessage @Params