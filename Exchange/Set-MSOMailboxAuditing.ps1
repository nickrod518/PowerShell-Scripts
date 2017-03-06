# Connect to Exchange Online
Import-Module ..\OneDrive\OneDrive.psm1
$Creds = Get-OneDriveCredential
$ExchangeOnlineSession = New-PSSession -ConfigurationName Microsoft.Exchange `
    -ConnectionUri https://outlook.office365.com/powershell-liveid/ `
    -Credential $Creds -Authentication Basic -AllowRedirection
Import-PSSession $ExchangeOnlineSession

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

# Get all users and enable auditing options for their mailboxes
Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox | 
    Set-Mailbox -AuditEnabled $true -AuditOwner $AuditOwnerOptions `
        -AuditAdmin $AuditAdminOptions -AuditDelegate $AuditDelegateOptions

# Disconnect from Exchange Online
Remove-PSSession $ExchangeOnlineSession