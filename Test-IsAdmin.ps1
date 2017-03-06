function Test-IsAdmin {
    $UserIdentity = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()

    if (-not $UserIdentity.IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
        Update-Log "You are not running this script with an admin account. " -Color 'Red' -NoNewLine
        Update-Log "Some tasks may fail if not run with admin credentials.`n" -Color 'Red'
    }
}