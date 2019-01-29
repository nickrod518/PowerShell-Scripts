$url = 'RDSBROKER.COMPANY.COM'

$feeds = Get-ChildItem 'HKCU:\Software\Microsoft\Workspaces\Feeds'
foreach ($feed in $feeds) {
    $id = (Get-ItemProperty $feed.PSPath -Name WorkspaceId).WorkspaceId

    if ($id -eq $url) {
        # Remove Start folder and desktop icons
        $startFolder = (Get-ItemProperty $feed.PSPath -Name StartMenuRoot).StartMenuRoot
        $apps = Get-ChildItem $startFolder
        $desktopIcons = Get-ChildItem "$env:USERPROFILE\Desktop"
        foreach ($icon in $desktopIcons) {
            if ($apps.Name -contains $icon.Name) {
                Remove-Item $icon.FullName
            }
        }
    }
}

rundll32 tsworkspace,TaskUpdateWorkspaces2

Start-Sleep -Seconds 2

Copy-Item "$startFolder\*" "$env:USERPROFILE\Desktop\" -Recurse -Force