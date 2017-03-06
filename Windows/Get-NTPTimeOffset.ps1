$Times = @{}
$Count = 0
$CountLimit = 60
$Server = 'server05'
$ServerToCompare = 'server06'

function Get-TimeOffset {
    $ResultObject = New-Object -TypeName psobject
    Add-Member -InputObject $ResultObject NoteProperty Computer 'pool.ntp.org'
    $W32TMResult = w32tm /stripchart /computer:'pool.ntp.org' /dataonly /samples:3 /ipprotocol:4

    if (-not ($W32TMResult -is [array])) {
        Add-Member -InputObject $ResultObject NoteProperty Status "Offline"
        Add-Member -InputObject $ResultObject NoteProperty Offset $null
    } else {
        $FoundTime = $false

        # Go through the 5 samples to find a response with timeoffset
        for ($i = 3; $i -lt 8; $i++) {
            if (-not $FoundTime) {
                if ($W32TMResult[$i] -match ", ([-+]\d+\.\d+)s") {
                    $Offset = [float]$Matches[1] 
                    Add-Member -InputObject $ResultObject NoteProperty Status "Online"
                    Add-Member -InputObject $ResultObject NoteProperty Offset $Offset
                    $FoundTime = $true
                } 
            }
        }

        # If no time samples were found check for error
        if (-not $FoundTime) {
            if ($W32TMResult[3] -match "error") {
                #0x800705B4 is not advertising/responding
                Add-Member -InputObject $ResultObject NoteProperty Status "NTP not responding"
            } else {
                Add-Member -InputObject $ResultObject NoteProperty Status $W32TMResult[3]
            }
            Add-Member -InputObject $ResultObject NoteProperty Offset $null
        }
    }

    $ResultObject
}

while ($true) {
    $Count++

    if (Test-Connection -Quiet -ComputerName $Server) {
        $Offset = try {
            $Result = Invoke-Command -ComputerName $Server -ScriptBlock ${function:Get-TimeOffset}
            try { $Result.Offset } catch { $Result.Status }
        } catch {
            $_ | Out-String
        }

        $Times.Add((Get-Date), $Offset)
        Start-Sleep -Seconds 10
    } else {
        $Times.Add((Get-Date), 'Unreachable')
        Start-Sleep -Seconds 10
    }

    if ($Count -ge $CountLimit) {
        $OffsetToCompare = try {
            $Result = Invoke-Command -ComputerName $Server -ScriptBlock ${function:Get-TimeOffset}
            try { $Result.Offset } catch { $Result.Status }
        } catch {
            $_ | Out-String
        }

        $SortedTimesString = $Times.GetEnumerator() | Sort-Object -Property Name | Out-String

        Send-MailMessage -Body "$ServerToCompare offset = $OffsetToCompare`n`n$Server datestamp and offset:`n$SortedTimesString" `
            -Subject 'server05 time script' -From 'Alerts@company.com' -To 'me@company.com' -SmtpServer smtp.company.local

        Write-Host 'Reset the clocks...'
        $Count = 0
        $Times = @{}
    }
}