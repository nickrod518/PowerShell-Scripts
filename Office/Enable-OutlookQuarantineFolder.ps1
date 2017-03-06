# Get Outlook object
$Outlook = New-Object -ComObject Outlook.Application

# Get Inbox
$Namespace = $Outlook.GetNamespace('MAPI')
$Inbox = $Namespace.GetDefaultFolder(6)

try {
    # Create new Quarantine folder
    $Quarantine = $Inbox.Folders.Add('Quarantine')
} catch {
    # Get existing Quarantine folder
    $Quarantine = $Inbox.Folders | Where-Object -Property Name -eq 'Quarantine'
}

# Set the web Url to the Quarantine admin site and set web view as default
$Quarantine.WebViewURL = 'https://admin.protection.outlook.com/quarantine'
$Quarantine.WebViewOn = $true

# Add Quarantine folder to favorites
$OutlookModule = $Outlook.ActiveExplorer().NavigationPane.Modules.Item('Mail')
$Favorites = $OutlookModule.NavigationGroups.Item('Favorites')
$Favorites.NavigationFolders.Add($Quarantine)

# Validate settings
$Quarantine = $Inbox.Folders | Where-Object -Property Name -eq 'Quarantine'

if ($Quarantine) {
    if ($Quarantine.WebViewURL -ne 'https://admin.protection.outlook.com/quarantine') { exit 999 }

    if (-not $Quarantine.WebViewOn) { exit 999 }

    if (-not $Favorites.NavigationFolders.Item($Quarantine.Name)) { exit 999 }

    exit 0
} else {
    exit 999
}