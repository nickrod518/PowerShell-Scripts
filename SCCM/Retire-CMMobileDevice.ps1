# references for building forms
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

# update the output log that the user sees, and scroll to keep up
function Update-Log ($text) {
    $logTextBox.AppendText("$text")
    $logTextBox.Update()
    $logTextBox.ScrollToCaret()
}

# verify that the username exists
function Validate-User ($user) {
    $userObject = Get-CMUser -Name "Domain\$user"
    if ($userObject -ne $null) {
        Update-Log "$user is a valid user.`n"
        return $userObject
    } else {
        $logTextBox.SelectionColor = 'Red'
        if ($user -eq '') {
            Update-Log "User ID field is blank."
        } else {
            Update-Log "$user was not found."
        }
        Update-Log " Aborted - no actions performed.`n"
        return
    }
}

# verify that the device exists
function Validate-Device ($deviceID) {
    $deviceObject = Get-CMDevice -ResourceId $deviceID
    if ($deviceObject -ne $null) {
        Update-Log "$deviceID is a valid device ID.`n"
        return $deviceObject
    } else {
        $logTextBox.SelectionColor = 'Red'
        if ($deviceID -eq '') {
            Update-Log "device ID field is blank."
        } else {
            Update-Log "$deviceID was not found."
        }
        Update-Log " Aborted - no actions performed.`n"
        return
    }
}

# allow the user to use "*" to search for usernames and select the one they want
function Get-User ($user) {
    $users = Get-CMUser -Name "Domain\$user"
    if ($users -ne $null) {
        try {
            $selected = $users.Name | Out-GridView -Title 'Select a user' -OutputMode Single
            $selected = $selected.Replace("Domain\","")
            $selected = $selected.Split(" ")[0]
            $userTextBox.Text = $selected
            Update-Log "Updated user ID field to $selected.`n"
        } catch { }
    } else {
        $logTextBox.SelectionColor = 'Yellow'
        if ($user -eq '') {
            Update-Log "User ID field is blank.`n"
        } else {
            Update-Log "No users were found with $user in their ID.`n"
        }
    }
}

# get the mobile devices assigned to the user
function Get-UserDevices ($user) {
    $userObject = Validate-User $user
    Try {
        # get all the primary devices for the user
        $primaryDevices = Get-CMUserDeviceAffinity -UserId $userObject.ResourceID

        # with those id's, create a list of device objects
        Update-Log 'Searching for devices'
        $devices = foreach ($device in $primaryDevices) {
            Get-CMDevice -ResourceID $device.ResourceID
            Update-Log '.'
        }
        Update-Log "`n"

        # filter the objects list so we're only looking at mobile devices not equal to OS X
        $mobileDevices = $devices | Where-Object { ($_.ClientType -eq 3) -and ($_.DeviceOS -notlike "OS X*") }

        # output what we have
        $selected = $mobileDevices | Select-Object -Property ResourceID, Name, DeviceOS, LastActiveTime, WipeStatus | Out-GridView -Title 'Select a device' -OutputMode Single

        if ($selected) {
			$deviceIDTextBox.Text = $selected.ResourceID
			$deviceNameTextBox.Text = $Selected.Name
			Update-Log "Set device field to resource ID $($selected.ResourceID) and name field to $($selected.Name).`n"
        } else {
            Update-Log "No mobile devices found for $user."
        }
    } Catch {
        $logTextBox.SelectionColor = 'Yellow'
        Update-Log "There was a problem trying to update the device ID and name fields.`n"
    }
}

# generate a list of all mobile devices inactive for 30+ days
function Get-InactiveDevices {
    Update-Log 'Searching for devices'
    Get-CMDevice -CollectionId 'SMSDM001' | Where-Object { $_.LastActiveTime -lt (Get-Date).AddDays(-30) } |
    foreach {
        New-Object PSObject -Property @{
            UserName = (Get-CMUserDeviceAffinity -DeviceId $_.ResourceID).UniqueUserName.Replace("Domain\","")
            ResourceID =  [string]$_.ResourceID
            Name = $_.Name
            DeviceOS = $_.DeviceOS
            LastActiveTime = $_.LastActiveTime
            WipeStatus = $_.WipeStatus
        }
        Update-Log '.'
    } | Select-Object -Property UserName, ResourceID, Name, DeviceOS, LastActiveTime, WipeStatus | Out-GridView -Title 'Inactive devices'
    Update-Log "`n"
}

function Retire-Device ($user, $deviceID) {  
    # validate the user input and create objects
    if (($userObject = Validate-User $user) -eq $null) { return }
    if (($deviceObject = Validate-Device $deviceID) -eq $null) { return }

    # retire the device
    Try {
        Invoke-CMDeviceRetire -DeviceId $deviceID -Force
        Update-Log "Successfully retired resource ID $deviceID.`n"
    } Catch {
        $logTextBox.SelectionColor = 'Red'
        Update-Log "There was a problem retiring resource ID $deviceID.`n"
    }

    Update-Log "All done!`n"
}

function Create-UtilityForm {
    $objForm = New-Object System.Windows.Forms.Form 
    $objForm.Text = "SCCM Retire Device"
    $objForm.Size = New-Object System.Drawing.Size(495, 595) 
    $objForm.StartPosition = "CenterScreen"

    # Creates output textbox
    $logTextBox = New-Object System.Windows.Forms.RichTextBox
    $logTextBox.Location = New-Object System.Drawing.Size(12, 80) 
    $logTextBox.Size = New-Object System.Drawing.Size(460, 470)
    $logTextBox.ReadOnly = 'True'
    $logTextBox.BackColor = 'Black'
    $logTextBox.ForeColor = 'White'
    $logTextBox.Font = 'Consolas'
    $objForm.Controls.Add($logTextBox)

    # user id input
    $UserSearchButton = New-Object System.Windows.Forms.Button
    $UserSearchButton.Location = New-Object System.Drawing.Size(12, 14)
    $UserSearchButton.Size = New-Object System.Drawing.Size(75, 22)
    $UserSearchButton.Text = "User ID"
    $UserSearchButton.Add_Click(
        { Script:Get-User $UserTextBox.Text })
    $objForm.Controls.Add($UserSearchButton)

    $UserTextBox = New-Object System.Windows.Forms.TextBox 
    $UserTextBox.Location = New-Object System.Drawing.Size(110, 15) 
    $UserTextBox.Size = New-Object System.Drawing.Size(60, 20)
    $objForm.Controls.Add($UserTextBox) 

    # button to search for devices assigned to user
    $deviceSearchButton = New-Object System.Windows.Forms.Button
    $deviceSearchButton.Location = New-Object System.Drawing.Size(250, 14)
    $deviceSearchButton.Size = New-Object System.Drawing.Size(75, 22)
    $deviceSearchButton.Text = "Device ID"
    $deviceSearchButton.Add_Click(
        { Script:Get-UserDevices $UserTextBox.Text })
    $objForm.Controls.Add($deviceSearchButton)

    # device ID
    $deviceIDTextBox = New-Object System.Windows.Forms.TextBox 
    $deviceIDTextBox.Location = New-Object System.Drawing.Size(345, 15)
    $deviceIDTextBox.Size = New-Object System.Drawing.Size(125, 20)
    $deviceIDTextBox.ReadOnly = 'True'
    $objForm.Controls.Add($deviceIDTextBox) 

    # device Name
    $deviceNameTextBox = New-Object System.Windows.Forms.TextBox 
    $deviceNameTextBox.Location = New-Object System.Drawing.Size(345, 44)
    $deviceNameTextBox.Size = New-Object System.Drawing.Size(125, 20)
    $deviceNameTextBox.ReadOnly = 'True'
    $objForm.Controls.Add($deviceNameTextBox) 

    # retire button
    $migrateButton = New-Object System.Windows.Forms.Button
    $migrateButton.Location = New-Object System.Drawing.Size(250, 44)
    $migrateButton.Size = New-Object System.Drawing.Size(75, 22)
    $migrateButton.Text = "Retire"
    $migrateButton.Add_Click(
        { Script:Retire-Device $UserTextBox.Text $deviceIDTextBox.Text })
    $objForm.Controls.Add($migrateButton)

    # report button
    $reportButton = New-Object System.Windows.Forms.Button
    $reportButton.Location = New-Object System.Drawing.Size(110, 44)
    $reportButton.Size = New-Object System.Drawing.Size(110, 22)
    $reportButton.Text = "Inactive Devices"
    $reportButton.Add_Click(
        { Script:Get-InactiveDevices })
    $objForm.Controls.Add($reportButton)
    
    # clear log button
    $clearButton = New-Object System.Windows.Forms.Button
    $clearButton.Location = New-Object System.Drawing.Size(12, 44)
    $clearButton.Size = New-Object System.Drawing.Size(75, 22)
    $clearButton.Text = "Clear Log"
    $clearButton.Add_Click(
        { $logTextBox.Clear() })
    $objForm.Controls.Add($clearButton)

    $objForm.Add_Shown({$objForm.Activate()})
    [void] $objForm.ShowDialog()
}

try {
    # make sure we have access to CM commands before we continue
    Import-Module '\\sccm01\e$\SCCM\AdminConsole\bin\ConfigurationManager.psd1'
    Set-Location -Path "$(Get-PSDrive -PSProvider CMSite):\" -ErrorAction Stop
    Create-UtilityForm
} catch {
    [System.Windows.Forms.MessageBox]::Show("Failed to set CM site drive. Are you sure you are running this from SCCM01 and the console is up to date?" , "Fail!")
    exit
}