# Search and replace the following strings with whatever's appropriate for your environment
# CMSERVER, DOMAINNAME, MOBILEDEVICECOLLECTIONID

# Update the output log that the user sees, and scroll to keep up
function Update-Log {
    param(
        [string]$Text,

        [Parameter(Mandatory = $false)]
		#[ValidateSet('White', 'Yellow', 'Red', 'Green')]
        [string]$Color = 'White',

        [switch]$NoNewLine
    )

    $LogTextBox.SelectionColor = $Color
    $LogTextBox.AppendText("$Text")
    if (-not $NoNewLine) { $LogTextBox.AppendText("`n") }
    $LogTextBox.Update()
    $LogTextBox.ScrollToCaret()
}

# Verify that the username exists
function Test-User {
    param([string]$UserID)

    $UserObject = Get-CMUser -Name "DOMAINNAME\$UserID"

    if ($UserObject -ne $null) {
        Update-Log "$UserID is a valid user."

        return $UserObject
    } else {
        if ($UserID -eq '') {
            Update-Log "User ID field is blank." -Color Red -NoNewLine
        } else {
            Update-Log "$UserID was not found." -Color Red -NoNewLine
        }

        Update-Log " Aborted - no actions performed.`n" -Color Red

        return
    }
}

# verify that the device exists
function Test-Device {
    param([string]$DeviceID)

    $DeviceObject = Get-CMDevice -ResourceId $DeviceID

    if ($DeviceObject -ne $null) {
        Update-Log "$DeviceID is a valid device ID."
        return $DeviceObject
    } else {
        if ($DeviceID -eq '') {
            Update-Log "device ID field is blank." -Color Red -NoNewLine
        } else {
            Update-Log "$DeviceID was not found." -Color Red -NoNewLine
        }

        Update-Log " Aborted - no actions performed." -Color Red

        return
    }
}

# allow the user to use "*" to search for usernames and select the one they want
function Get-User {
    param([string]$UserID)

    $Users = Get-CMUser -Name "DOMAINNAME\$UserID"

    if ($Users -ne $null) {
        try {
            $Selected = if ($Users.Count -gt 1) {
                $Users.Name | Out-GridView -Title 'Select a user' -OutputMode Single
            } else {
                $Users.Name
            }

            $Selected = $Selected.Replace("DOMAINNAME\","")
            $Selected = $Selected.Split(" ")[0]
            $UserTextBox.Text = $Selected

            Update-Log "Updated user ID field to $Selected."
        } catch { }
    } else {
        if ($UserID -eq '') {
            Update-Log "User ID field is blank." -Color Yellow
        } else {
            Update-Log "No users were found with ID $UserID." -Color Yellow
        }
    }
}

# get the mobile devices assigned to the user
function Get-UserDevices {
    param([string]$UserID)

    $UserObject = Test-User $UserID

    Try {
        # Get all the primary devices for the user
        $PrimaryDevices = Get-CMUserDeviceAffinity -UserId $UserObject.ResourceID

        # With those id's, create a list of device objects
        Update-Log 'Searching for devices' -NoNewLine

        $Devices = foreach ($Device in $PrimaryDevices) {
            Get-CMDevice -ResourceID $Device.ResourceID
            Update-Log '.' -NoNewLine
        }

        Update-Log ''

        # Filter the objects list so we're only looking at mobile devices not equal to OS X
        $MobileDevices = $Devices | Where-Object { ($_.ClientType -eq 3) -and ($_.DeviceOS -notlike "OS X*") }

        # Output what we have and let 
        $Selected = if ($MobileDevices.Count -gt 1) {
            $MobileDevices | Select-Object -Property ResourceID, Name, DeviceOS, LastActiveTime, WipeStatus | Out-GridView -Title 'Select a device' -OutputMode Single
        } else {
            $MobileDevices
        }

        if ($Selected) {
			$DeviceIDTextBox.Text = $Selected.ResourceID
			$DeviceNameTextBox.Text = $Selected.Name
			Update-Log "Set device field to resource ID $($Selected.ResourceID) and name field to $($Selected.Name)."
        } else {
            Update-Log "No mobile devices found for $UserID."
        }
    } Catch {
        Update-Log "There was a problem trying to update the device ID and name fields." -Color Yellow
    }
}

# generate a list of all mobile devices inactive for 30+ days
function Get-InactiveDevices {
    Update-Log 'Searching for devices' -NoNewLine
    Get-CMDevice -CollectionId 'MOBILEDEVICECOLLECTIONID' | Where-Object { $_.LastActiveTime -lt (Get-Date).AddDays(-30) } | ForEach-Object {
        New-Object PSObject -Property @{
            UserName = (Get-CMUserDeviceAffinity -DeviceId $_.ResourceID).UniqueUserName.Replace("DOMAINNAME\","")
            ResourceID =  [string]$_.ResourceID
            Name = $_.Name
            DeviceOS = $_.DeviceOS
            LastActiveTime = $_.LastActiveTime
            WipeStatus = $_.WipeStatus
        }

        Update-Log '.' -NoNewLine
    } | Select-Object -Property UserName, ResourceID, Name, DeviceOS, LastActiveTime, WipeStatus | Out-GridView -Title 'Inactive devices'

    Update-Log ''
}

function Write-Title {
    Update-Log "             __  ___     __   _ __      ___           _        " -Color Orange
    Update-Log "            /  |/  /__  / /  (_) /__   / _ \___ _  __(_)______ " -Color Orange
    Update-Log "           / /|_/ / _ \/ _ \/ / / -_) / // / -_) |/ / / __/ -_)" -Color Orange
    Update-Log "          /_/__/_/\___/_.__/_/_/\__/ /____/\__/|___/_/\__/\__/ " -Color Orange
    Update-Log "            /  |/  /__ ____  ___ ____ ____ __ _  ___ ___  / /_ " -Color Orange
    Update-Log "           / /|_/ / _ ``/ _ \/ _ ``/ _ ``/ -_)  ' \/ -_) _ \/ __/ " -Color Orange
    Update-Log "          /_/  /_/\_,_/_//_/\_,_/\_, /\__/_/_/_/\__/_//_/\__/  v1.2" -Color Orange
    Update-Log "                                /___/    " -Color Orange -NoNewLine
    Update-Log " by Nick Rodriguez    " -Color Gold
    Update-Log ''
}

function New-UtilityForm {
    # References for building forms
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

    $Form = New-Object System.Windows.Forms.Form
    $Form.FormBorderStyle = 'FixedDialog'
    $Form.Text = 'Config Manager Mobile Device Management'
    $Form.Size = New-Object System.Drawing.Size(490, 590) 
    $Form.StartPosition = "CenterScreen"

    # Creates output textbox
    $LogTextBox = New-Object System.Windows.Forms.RichTextBox
    $LogTextBox.Location = New-Object System.Drawing.Size(12, 120) 
    $LogTextBox.Size = New-Object System.Drawing.Size(460, 430)
    $LogTextBox.ReadOnly = 'True'
    $LogTextBox.BackColor = 'Black'
    $LogTextBox.ForeColor = 'White'
    $LogTextBox.Font = 'Consolas'
    $Form.Controls.Add($LogTextBox)

    # User id input
    $UserSearchButton = New-Object System.Windows.Forms.Button
    $UserSearchButton.Location = New-Object System.Drawing.Size(12, 14)
    $UserSearchButton.Size = New-Object System.Drawing.Size(75, 22)
    $UserSearchButton.Text = "User ID"
    $UserSearchButton.Add_Click(
        { Script:Get-User $UserTextBox.Text })
    $Form.Controls.Add($UserSearchButton)

    $UserTextBox = New-Object System.Windows.Forms.TextBox 
    $UserTextBox.Location = New-Object System.Drawing.Size(110, 15) 
    $UserTextBox.Size = New-Object System.Drawing.Size(60, 20)
    $Form.Controls.Add($UserTextBox) 

    # Button to search for devices assigned to user
    $DeviceSearchButton = New-Object System.Windows.Forms.Button
    $DeviceSearchButton.Location = New-Object System.Drawing.Size(250, 14)
    $DeviceSearchButton.Size = New-Object System.Drawing.Size(75, 22)
    $DeviceSearchButton.Text = 'Device ID'
    $DeviceSearchButton.Add_Click({ Get-UserDevices $UserTextBox.Text })
    $Form.Controls.Add($DeviceSearchButton)

    # Device ID
    $DeviceIDTextBox = New-Object System.Windows.Forms.TextBox 
    $DeviceIDTextBox.Location = New-Object System.Drawing.Size(345, 15)
    $DeviceIDTextBox.Size = New-Object System.Drawing.Size(125, 20)
    $DeviceIDTextBox.ReadOnly = 'True'
    $Form.Controls.Add($DeviceIDTextBox)

    # Device ID
    $DeviceNameLabel = New-Object System.Windows.Forms.Label 
    $DeviceNameLabel.Location = New-Object System.Drawing.Size(250, 48)
    $DeviceNameLabel.Size = New-Object System.Drawing.Size(75, 20)
    $DeviceNameLabel.Text = "Device Name"
    $Form.Controls.Add($DeviceNameLabel) 

    # Device Name
    $DeviceNameTextBox = New-Object System.Windows.Forms.TextBox 
    $DeviceNameTextBox.Location = New-Object System.Drawing.Size(345, 44)
    $DeviceNameTextBox.Size = New-Object System.Drawing.Size(125, 20)
    $DeviceNameTextBox.ReadOnly = 'True'
    $Form.Controls.Add($DeviceNameTextBox)

    # Retire button
    $MigrateButton = New-Object System.Windows.Forms.Button
    $MigrateButton.Location = New-Object System.Drawing.Size(50, 85)
    $MigrateButton.Size = New-Object System.Drawing.Size(75, 22)
    $MigrateButton.Text = 'Retire'
    $MigrateButton.Add_Click({
        try {
            Invoke-CMDeviceRetire -Id $DeviceIDTextBox.Text -Force
            Update-Log "Successfully retired $($DeviceNameTextBox.Text) [$($DeviceIDTextBox.Text)]." -Color Green
        } catch {
            Update-Log "There was a problem retiring $($DeviceNameTextBox.Text) [$($DeviceIDTextBox.Text)]:" -Color Red
            Update-Log $_.Exception.Message -Color Red
        }
    })
    $Form.Controls.Add($MigrateButton)

    # Lock button
    $LockButton = New-Object System.Windows.Forms.Button
    $LockButton.Location = New-Object System.Drawing.Size(150, 85)
    $LockButton.Size = New-Object System.Drawing.Size(75, 22)
    $LockButton.Text = 'Lock'
    $LockButton.Add_Click({
        try {
            Invoke-CMDeviceAction -Id $DeviceIDTextBox.Text -Action Lock -ErrorAction Stop

            Update-Log "Lock on $($DeviceNameTextBox.Text) [$($DeviceIDTextBox.Text)] successfully initiated." -Color Green
        } catch {
            Update-Log "There was a problem performing Lock on $($DeviceNameTextBox.Text) [$($DeviceIDTextBox.Text)]:" -Color Red
            Update-Log $_.Exception.Message -Color Red
        }
    })
    $Form.Controls.Add($LockButton)

    # Reset pin button
    $ResetPinButton = New-Object System.Windows.Forms.Button
    $ResetPinButton.Location = New-Object System.Drawing.Size(250, 85)
    $ResetPinButton.Size = New-Object System.Drawing.Size(75, 22)
    $ResetPinButton.Text = 'Reset Pin'
    $ResetPinButton.Add_Click({
        try {
            Invoke-CMDeviceAction -Id $DeviceIDTextBox.Text -Action PinReset -ErrorAction Stop

            Update-Log "Pin Reset on $($DeviceNameTextBox.Text) [$($DeviceIDTextBox.Text)] successfully initiated." -Color Green
        } catch {
            Update-Log "There was a problem performing Pin Reset on $($DeviceNameTextBox.Text) [$($DeviceIDTextBox.Text)]:" -Color Red
            Update-Log $_.Exception.Message -Color Red
        }
    })
    $Form.Controls.Add($ResetPinButton)

    # Status button
    $StatusButton = New-Object System.Windows.Forms.Button
    $StatusButton.Location = New-Object System.Drawing.Size(350, 85)
    $StatusButton.Size = New-Object System.Drawing.Size(75, 22)
    $StatusButton.Text = 'Status'
    $StatusButton.Add_Click({
        try {
            $Action = Get-CMDeviceAction -Id $DeviceIDTextBox.Text -Fast -ErrorAction Stop

            if ($Action -ne $null) {
                Update-Log "Getting action history for $($DeviceNameTextBox.Text) [$($DeviceIDTextBox.Text)]..."
                Update-Log "Action`t`tState`t`tLast Update Time`tPin" -Color Gray

                $Action | ForEach-Object {
                    Update-Log "$($_.Action)$(if ($_.Action -eq 'Lock') { "`t" })`t" -NoNewLine
                    Update-Log "$(switch ($_.State) { 1 { "Pending`t" } 4 { "Complete" } })`t" -NoNewLine
                    Update-Log "$($_.LastUpdateTime)`t" -NoNewLine
                    if ($_.Action -eq 'PinReset') {
                        $PinResetState = Get-WmiObject -ComputerName CMSERVER -NameSpace root/SMS/site_$(Get-PSDrive -PSProvider CMSite) `
                            -Class SMS_DeviceAction -Filter "Action='PinReset' and ResourceID='$($DeviceIDTextBox.Text)'" -ErrorAction Stop

                        $Pin = ([wmi]$PinResetState.__PATH).ResponseText
                        Update-Log $Pin
                    } else {
                        Update-Log 'N/A'
                    }
                }
            }
            else { 
                Update-Log "No state information available for $($DeviceNameTextBox.Text) [$($DeviceIDTextBox.Text)]." -Color Yellow
            }
        } catch {
            Update-Log "Failed to get the state information for $($DeviceNameTextBox.Text) [$($DeviceIDTextBox.Text)]:" -Color Red
            Update-Log $_.Exception.Message -Color Red
        }
    })
    $Form.Controls.Add($StatusButton)

    # Report button
    $ReportButton = New-Object System.Windows.Forms.Button
    $ReportButton.Location = New-Object System.Drawing.Size(110, 44)
    $ReportButton.Size = New-Object System.Drawing.Size(110, 22)
    $ReportButton.Text = "Inactive Devices"
    $ReportButton.Add_Click({ Get-InactiveDevices })
    $Form.Controls.Add($ReportButton)
    
    # Clear log button
    $ClearButton = New-Object System.Windows.Forms.Button
    $ClearButton.Location = New-Object System.Drawing.Size(12, 44)
    $ClearButton.Size = New-Object System.Drawing.Size(75, 22)
    $ClearButton.Text = "Clear Log"
    $ClearButton.Add_Click({ $LogTextBox.Clear() })
    $Form.Controls.Add($ClearButton)

    Write-Title

    $Form.Add_Shown({ $Form.Activate() })
    $Form.ShowDialog()
}

try {
    # Verify we have access to CM commands before we continue
    Import-Module ConfigurationManager
    Set-Location -Path "$(Get-PSDrive -PSProvider CMSite):\" -ErrorAction Stop

    $CMPSSuppressFastNotUsedCheck = $true

    New-UtilityForm
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Failed to set CM site drive. Are you running this from CMSERVER and is the console is up to date?
        `n`nError: $($_.Exception.Message)", 
        'Fail!'
    )

    exit
}