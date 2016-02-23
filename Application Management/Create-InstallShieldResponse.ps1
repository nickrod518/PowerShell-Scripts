Function Get-FileName {
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.Title = 'Select a setup file to record'
    $OpenFileDialog.Filter = "EXE (*.exe)| *.exe"
    $OpenFileDialog.ShowHelp = $true
    $OpenFileDialog.ShowDialog() | Out-Null
    Get-Item $OpenFileDialog.FileName
}

try { $EXE = Get-FileName } catch { Exit }

Start-Process -Wait $EXE.FullName -ArgumentList '-r'

Move-Item 'C:\Windows\Setup.iss' "$($EXE.DirectoryName)\$($EXE.BaseName).iss"