$version = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Version -ErrorAction SilentlyContinue).Version
if ($version -like "4.5*") {
    return $true
} else {
    return $false
}