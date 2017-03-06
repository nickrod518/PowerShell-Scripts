Add-Type -AssemblyName System.Windows.Forms

$Network = New-Object -ComObject WScript.Network

function Show-Error {
    param([string]$Message)

    [System.Windows.Forms.MessageBox]::Show(
        "$Message`n`nClick OK to exit",
        'Map Drives Utility Error',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Hand
    ) | Out-Null
}

try {
    $Offices = Import-Csv "\\server01\MapDrivesUtility\Offices.csv"
} catch {
    Show-Error 'You must be in an office or connected via VPN for the Map Network Drives utility to launch'
    exit
}

# Get the large logo from a base64 string
$Base64Logo = ''
$IconStream = [System.IO.MemoryStream][System.Convert]::FromBase64String($Base64Icon)
$IconBMP = [System.Drawing.Image]::FromStream($IconStream)
$Hicon = $IconBMP.GetHicon()
$IconBMP = [System.Drawing.Icon]::FromHandle($Hicon)


function Get-MappedDrives {
    $MappedDrives = @{}
    $Letter = ''

    $Network.EnumNetworkDrives() | ForEach-Object {
        if ($Letter -ne '') {
            $MappedDrives.Add($Letter, $_)
            $Letter = ''
        } else {
            $Letter = $_
        }
    }

    $MappedDrives
}

function Invoke-MapNetworkDrives {
    param([psobject[]]$Mappings)
    
    foreach ($Drive in $Mappings) {
        $DriveLetter = "$($Drive.DriveLetter)`:"
        $DrivePath = $Drive.DrivePath

        Write-Host "$DriveLetter to $DrivePath"

        # Map drive
        try {
            # Check if drive letter is already mapped
            if (-not (Test-Path -Path $DriveLetter -ErrorAction Stop)) {
                Write-Verbose "$DriveLetter was not mapped, mapping"

                # Map new drive if it's not in use
                $Network.MapNetworkDrive($DriveLetter, $DrivePath)
            } elseif ($DrivePath -ne (Get-MappedDrives).$DriveLetter) {
                Write-Verbose "$DrivePath doesn't match, remapping"
                
                # Remove mapped drive
                $Network.RemoveNetworkDrive($DriveLetter, $true)

                # Map new drive
                $Network.MapNetworkDrive($DriveLetter, $DrivePath)
            } else {
                Write-Verbose "$DriveLetter is already mapped to $DrivePath"
                # Already mapped
            }
        } catch {
            Show-Error -Message "There was a problem mapping $DriveLetter to [$DrivePath]`n`n$($_.Exception.Message)"
        }
    }
}

function Remove-NetworkDrives {
    try {
        $MappedDrives = Get-MappedDrives
        
        # Remove each mapped drive
        foreach ($DriveLetter in $MappedDrives.Keys) {
            $Network.RemoveNetworkDrive($DriveLetter, $true)
        }
    } catch {
        Show-Error -Message "There was a problem removing all mapped drives`n`n$($_.Exception.Message)"
    }
}

$Form = New-Object System.Windows.Forms.Form
$Form.Text = 'Map Network Drives'
$Form.Icon = $IconBMP
$Form.SizeGripStyle = 'Hide'
$Form.FormBorderStyle = 'FixedSingle'
$Form.MaximizeBox = $false
$Form.Width = 300
$Form.Height = 260
$Form.BackColor = "#ffffff"

$Logo = New-Object System.Windows.Forms.PictureBox
$Logo.Image = $LogoBMP
$Logo.Location = New-Object System.Drawing.Point(30, 0)
$logo.AutoSize = $true
$Form.Controls.Add($Logo)

$OfficeList = New-Object System.Windows.Forms.ComboBox
$OfficeList.DropDownStyle = 'DropDownList'
$OfficeList.Items.Insert(0, 'Please select an Office')
$OfficeList.SelectedIndex = 0
$OfficeList.Width = 200
$OfficeList.Location = New-Object System.Drawing.Point(50, 130)
$Offices | Where-Object { $_.Type -ne 'Citrix' } | Select-Object Location -Unique | 
    ForEach-Object { $OfficeList.Items.Add($_.Location) | Out-Null }
$OfficeList.Add_SelectionChangeCommitted({
    if ($OfficeList.Items[0] -eq 'Please select an Office' -and 
    $OfficeList.SelectedItem -ne 'Please select an Office') {
        $OfficeList.Items.RemoveAt(0)
    }
})
$Form.Controls.Add($OfficeList)

$ConnectingLabel = New-Object System.Windows.Forms.Label
$ConnectingLabel.Visible = $false
$ConnectingLabel.Text = 'Connecting...'
$ConnectingLabel.Width = 250
$ConnectingLabel.Height = 20
$ConnectingLabel.Location = New-Object System.Drawing.Point(110, 200)
$ConnectingLabel.Font = "Microsoft Sans Serif, 8"
$Form.Controls.Add($ConnectingLabel)

$ConnectButton = New-Object System.Windows.Forms.Button
$ConnectButton.AutoSize = $true
$ConnectButton.UseVisualStyleBackColor = $true
$ConnectButton.Location = New-Object System.Drawing.Point(60, 160)
$ConnectButton.Text = 'Connect Network Drives'
$ConnectButton.Font = 'Microsoft Sans Serif, 11'
$ConnectButton.Add_Click({
    if ($OfficeList.SelectedItem -eq '<Remove All>') {
        Remove-NetworkDrives
    } elseif ($OfficeList.SelectedItem -ne 'Please select an Office') {
        # Show the connecting label
        $ConnectingLabel.Visible = $true

        # Get the selected office's drive mappings
        $Mappings = $Offices | Where-Object { $_.Location -eq $OfficeList.SelectedItem }

        # Launch selected product
        Invoke-MapNetworkDrives $Mappings

        # Exit
        $Form.Dispose()
    }
})
$Form.Controls.Add($ConnectButton)

[void]$Form.ShowDialog()
$Form.Dispose()