$GroupName = 'Group Name';
$Output = (whoami.exe /groups) -join '';
if ($Output -match $GroupName) {
    Write-Host -Object 'True';
} 
