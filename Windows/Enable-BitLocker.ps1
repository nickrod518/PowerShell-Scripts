$Creds = Get-Credential

$Computers = @(
    'computer1', 'computer2'
)

# Log file
$Date = (Get-Date).ToString('yyyyMMdd-HHmm')
$LogFolder = New-Item -ItemType Directory "C:\Logs" -Force
$Log = New-Item -ItemType File "$LogFolder\Enable-BitLocker-$Date.log" -Force

foreach ($Computer in $Computers) {

    Add-Content $Log "$Computer..."

    if (Test-Connection $Computer -Quiet -Count 3) {
        
        $Return = Invoke-Command -ComputerName $Computer -Credential $Creds -ScriptBlock {
            
            # Delete any current BitLocker pin
            try {
                $Result = ((manage-bde -protectors -delete C: | Select-String -Pattern "(?<=(ERROR:)).*").ToString()).TrimStart()
                $Return = 'Deleted old protectors.'
            } catch {
                $Return += $Error
            }
            $Return += "`n"

            # Add new Pin and TPM security
            try {
                $Result = ((manage-bde -protectors -add C: -tp newpin | Select-String -Pattern "(?<=(ERROR:)).*").ToString()).TrimStart()
                $Return += 'Added new protectors.'
            } catch {
                $Return += $Error
            }
            $Return += "`n"

            # Get the BitLocker's status after changes
            $Result = ((manage-bde -status | Select-String -Pattern "(?<=(Protection Status:)).*").ToString()).Replace('Protection Status:', '').TrimStart()
            if (!$Result) {
                $Return += 'ERROR: Unable to capture BitLocker status.'
            } elseif ($Result -eq 'Protection Off') {
                # Enable protection
                try {
                    $Result = ((manage-bde -protectors -enable C: | Select-String -Pattern "(?<=(ERROR:)).*").ToString()).TrimStart()
                    $Return += 'Enabled protectors.'
                } catch {
                    $Return += $Error
                }
                $Return += "`n"

                # Get the BitLocker's status after changes
                $Result = ((manage-bde -status | Select-String -Pattern "(?<=(Protection Status:)).*").ToString()).Replace('Protection Status:', '').TrimStart()
                if ($Result -eq 'Protection Off') {
                    $Return += 'ERROR: Unable to enable protectors.'
                } elseif ($Result -eq 'Protection On') {
                    $Return += $Result
                }
            } elseif ($Result -eq 'Protection On') {
                $Return += $Result
            }

            Return $Return
        }

        Add-Content $Log $Return

    } else {
        Add-Content $Log "ERROR: Failed to connect."
    }
}