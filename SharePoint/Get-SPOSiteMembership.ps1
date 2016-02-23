# Connect to SPOL
Connect-SPOService -Url 'https://company-admin.sharepoint.com'

# Get site(s)
$Input = Read-Host "Enter the name of a specific site or leave blank for all sites"
if ($Input) {
    $Sites = $Input
} else {
    $Sites = (Get-SPOSite).Url
}

# Loop through every site on SPOL
foreach ($Site in $Sites) {
    Write-Host $Site -ForegroundColor "Yellow"
    # Loop through every group in the site
    foreach ($Group in Get-SPOSiteGroup -Site $Site) {
        # Give us the group name
        Write-Host $Group.Title -ForegroundColor "Cyan"
        # List all the users of that group
        $Group | Select-Object -ExpandProperty Users
        Write-Host
    }
}

# Disconnect from SPOL
Disconnect-SPOService -ErrorAction SilentlyContinue