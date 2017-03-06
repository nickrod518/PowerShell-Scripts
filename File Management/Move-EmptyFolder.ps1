$Folders = Get-ChildItem '\\server\users'

$EmptyDir = New-Item -ItemType Directory '.\empty' -Force

foreach ($Folder in $Folders) {
    if ((Get-ChildItem $Folder.FullName).Count -eq 0) {
        Write-Host "moving: $Folder"
        Move-Item $Folder.FullName $EmptyDir
    }
}