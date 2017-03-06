begin {
    # Set $DebugMode to $true to log every map occurrence or $false to disable
    $DebugMode = $false

    # Destination for error and debug logs to be copied to
    $CentralLogPath = '\\server01\DriveMapError'

    # Enable debug mode if user's name is in debug user list
    if ((Get-Content "$CentralLogPath\DebugUsers.txt") -contains (whoami)) { $DebugMode = $true }

    # Error flag - set to false when error occurs
    $ErrorFree = $true

    Start-Transcript -Path "$env:TEMP\MapNetworkDrive.log" -Force
    Write-Host "Map Network Drives v2.0"

    Add-Type -AssemblyName System.Windows.Forms

    $Network = New-Object -ComObject WScript.Network

    function Get-UserGroups {
        [cmdletbinding()]
        param()

        $Groups = [System.Security.Principal.WindowsIdentity]::GetCurrent().Groups

        foreach ($Group in $Groups) {
            $GroupSID = $Group.Value
            $GroupName = New-Object System.Security.Principal.SecurityIdentifier($GroupSID)
            $GroupDisplayName = $GroupName.Translate([System.Security.Principal.NTAccount])
            $GroupDisplayName.Value
        }
    }
}

process {
    # Import the csv's with our mapping rules
    $Offices = Import-Csv -Path "\\server01\MapDrivesUtility\Offices.csv"
    $Translations = Import-Csv -Path "\\server01\MapDrivesUtility\Translations.csv"

    # Get all groups the user is a member of that match a translated group
    $GroupsFound = Get-UserGroups
    $UserGroups = foreach ($GroupName in $GroupsFound) {
        $Translations | ForEach-Object { if ($_.GroupName -eq $GroupName) { $GroupName } }
    }

    Write-Host "$env:USERNAME is a member of the following groups: $($GroupsFound -join ', ')"
    Write-Host "The following groups match a map drives translation group: [$($UserGroups -join '], [')]"

    Write-Host "Checking location criteria..."
    $Locations = ($Translations | Where-Object {
        $Translation = $_
        $Location = $_.Location
        Write-Host "$Location..."

        # Group filter
        ($Translation.GroupName -eq '' -or
        ($Translation.GroupName -split ',' | ForEach-Object { 
            if ($UserGroups -contains $_) {
                Write-Host "+++$_ is in a member group: [$($Translation.GroupName)]"
                return $true
            } else {
                Write-Host "---not in a member group: [$($Translation.GroupName)]"
            }
        })) -and

        # NOT group filter
        ($Translation.NotGroupName -eq '' -or
        ($Translation.NotGroupName -split ',' | ForEach-Object {
            if ($UserGroups -contains $_) {
                Write-Host "---$_ is a member of a NOT group: [$($Translation.NotGroupName)]"
                return $false
            } else {
                Write-Host "+++not a member of a NOT group: [$($Translation.NotGroupName)]"
                $true
            }
        })) -and
        
        # UserName filter
        ($Translation.UserName -eq '' -or
        ($Translation.UserName -split ',' | ForEach-Object { 
            if ((whoami) -eq $_) {
                Write-Host "+++$_ is a member user: [$($Translation.UserName)]"
                return $true
            } else {
                Write-Host "---$(whoami) is not a member user: [$($Translation.UserName)]"
            }
        })) -and

        # ComputerName filter
        ($Translation.ComputerName -eq '' -or
        ($Translation.ComputerName -split ',' | ForEach-Object { 
            if ((hostname) -eq $_) {
                Write-Host "+++$_ is a member computer: [$($Translation.ComputerName)]"
                return $true
            } else {
                Write-Host "---$(hostname) is not a member computer: [$($Translation.ComputerName)]"
            }
        }))
    }).Location
    Write-Host "Mapping the following locations: [$($Locations -join '], [')]"

    # Map the drive mappings the user is a member of
    foreach ($Location in $Locations) {
        $Offices | Where-Object {
            $_.Type -ne 'Local' -and
            $_.Location -contains $Location
        } | ForEach-Object {
            $Location = $_.Location
            $DriveLetter = "$($_.DriveLetter)`:"
            $DrivePath = $_.DrivePath

            # Remove any old drive mapping
            try {
                Write-Host "Removing old mapping for drive for $DriveLetter..." -NoNewline
                $Network.RemoveNetworkDrive($DriveLetter, $true)
                Write-Host "success!" -ForegroundColor Green
            } catch {
                if ($_.Exception.Message -like '*This network connection does not exist.*') {
                    Write-Host $_.Exception.Message -ForegroundColor Yellow
                } else {
                    Write-Host "error:`n$($_.Exception.Message)" -ForegroundColor Red
                    $ErrorFree = $false
                }
            }

            # Wait a moment before continuing
            Start-Sleep -Seconds 1

            # Map new drive
            try {
                Write-Host "Mapping drive for $Location ($DriveLetter to $DrivePath)..." -NoNewline
                $Network.MapNetworkDrive($DriveLetter, $DrivePath)
                Write-Host "success!" -ForegroundColor Green
            } catch {
                Write-Host "error:`n$($_.Exception.Message)" -ForegroundColor Red
                $ErrorFree = $false
            }
        }
    }
}

end {
    Write-Host "Currently mapped drives:"
    $New = $true
    $Network = New-Object -ComObject WScript.Network
    $Network.EnumNetworkDrives() | ForEach-Object {
        if ($New) {
            Write-Host "$_ = " -NoNewline
            $New = $false
        } else {
            Write-Host $_
            $New = $true
        }
    }

    Stop-Transcript

    if (-not $ErrorFree -or $DebugMode) {
        if (-not $ErrorFree) { $Prefix = 'Error-' }
        $Date = (Get-Date).ToString('yyyyMMdd-HHmm')
        Copy-Item -Path "$env:TEMP\MapNetworkDrive.log" -Destination "$CentralLogPath\$Prefix$env:COMPUTERNAME-$env:USERNAME-$Date.log"
    }
}