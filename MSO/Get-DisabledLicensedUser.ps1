Connect-MsolService
Get-MsolUser -All -EnabledFilter DisabledOnly | Where-Object { $_.IsLicensed }