function Read-FolderBrowserDialog {
    $ShellApp = New-Object -ComObject Shell.Application
    $Directory = $ShellApp.BrowseForFolder(0, 'Select a directory', 0, 'C:\')
    if ($Directory) { return $Directory.Self.Path } else { return '' }
}