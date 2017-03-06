# Return $true if 64-bit OS
function Test-64BitOS { 
    if ((Get-WmiObject Win32_OperatingSystem).OSArchitecture -eq '64-bit') { 
        $true
    } else { 
        $false
    }
}