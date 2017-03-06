# Return $true if run from ISE
function Test-IsISE { if ($psISE) { $true } else { $false } }