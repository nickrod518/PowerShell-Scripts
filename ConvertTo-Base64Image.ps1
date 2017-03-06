[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
$OpenFileDialog.ShowDialog() | Out-Null
$Image = Get-Item $OpenFileDialog.FileName
[System.Convert]::ToBase64String((Get-Content $Image -Encoding Byte)) >> .\EncodedImage.txt