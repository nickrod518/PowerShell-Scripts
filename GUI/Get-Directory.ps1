function Get-Directory {
    [CmdletBinding()]
    [OutputType([psobject])]
    param()

    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    $OpenDirectoryDialog = New-Object Windows.Forms.FolderBrowserDialog
    $OpenDirectoryDialog.ShowDialog() | Out-Null
    try {
        Get-Item $OpenDirectoryDialog.SelectedPath
    } catch {
        Write-Warning 'Open Directory Dialog was closed or cancelled without selecting a Directory'
    }
}