$Servers = @('server02' ,'server08')
$Servers | ForEach-Object {
    Write-Host $_
    Test-NetConnection -ComputerName $_ -Port 80 -InformationLevel Quiet
    Test-NetConnection -ComputerName $_ -Port 443 -InformationLevel Quiet
}