# references for building forms
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

function Update-Log ($text) {
    $LogTextBox.AppendText("$text")
    $LogTextBox.Update()
    $LogTextBox.ScrollToCaret()
}

function Validate-User ($user) {
    $userObject = Get-CMUser -Name "Domain\$user"
    if ($userObject -ne $null) {
        Update-Log "$user is a valid user.`n"
        return $userObject
    } else {
        $LogTextBox.SelectionColor = 'Red'
        if ($user -eq '') {
            Update-Log "User ID field is blank."
        } else {
            Update-Log "$user was not found."
        }
        Update-Log " Aborted - no actions performed.`n"
        return
    }
}

function Validate-PC ($pc) {
    $pcObject = Get-CMDevice -Name $pc
    if ($pcObject -ne $null) {
        Update-Log "$pc is a valid PC.`n"
        return $pcObject
    } else {
        $LogTextBox.SelectionColor = 'Red'
        if ($pc -eq '') {
            Update-Log "Asset tag field is blank."
        } else {
            Update-Log "$pc was not found."
        }
        Update-Log " Aborted - no actions performed.`n"
        return
    }
}

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

function Get-PrimaryMachines ($user) {
    $userObject = Validate-User $user
    Try {
        $devices = Get-CMUserDeviceAffinity -UserId $userObject.ResourceID
        $selected = $devices.ResourceName | Out-GridView -Title 'Select an asset' -OutputMode Single
		if ($selected) {
			$oldPCTextBox.Text = $selected
			Update-Log "Updated old asset tag field to $selected.`n"
		} else {
			Update-Log "No primary machines found for $user"
		}
    } Catch {
        $LogTextBox.SelectionColor = 'Yellow'
        Update-Log "There was a problem trying to update the old asset tag field.`n"
    }
}

function Remove-UAD ($userObject, $pcObject) {
    Try {
        $primaryUsers = Get-CMUserDeviceAffinity -DeviceId $pcObject.ResourceID
        if ( $primaryUsers | Where-Object { $_.UniqueUserName -eq $userObject.SMSID } ) {
            Remove-CMUserAffinityFromDevice -DeviceId $pcObject.ResourceID -UserId $userObject.ResourceID -Force
            Update-Log "$($pcObject.Name) has been removed as $($userObject.Name)'s primary device.`n"
        } else {
            Update-Log "$($pcObject.Name) was not previously set as $($userObject.Name)'s primary device; no action taken.`n"
        }
    } Catch {
        $LogTextBox.SelectionColor = 'Yellow'
        Update-Log "There was a problem trying to remove $($pcObject.Name) as $($userObject.Name)'s primary device. It may not be assigned as a primary device.`n"
    }
}

function Add-UAD ($userObject, $pcObject) {
    Try {
        $primaryUsers = Get-CMUserDeviceAffinity -DeviceId $pcObject.ResourceID
        if ( $primaryUsers | Where-Object { $_.UniqueUserName -eq $userObject.SMSID } ) {
            Update-Log "$($pcObject.Name) is already set as $($userObject.Name)'s primary device; no action taken.`n"
        } else {
            Add-CMUserAffinityToDevice -DeviceId $pcObject.ResourceID -UserId $userObject.ResourceID
            Update-Log "$($pcObject.Name) has been added as $($userObject.Name)'s primary device.`n"
        }
    } Catch {
        $LogTextBox.SelectionColor = 'Red'
        Update-Log "There was a problem trying to add $($pcObject.Name) as $($userObject.Name)'s primary device.`n"
    }
}

function Get-CollectionMembership ($pcObject, $collectionObject) {
    $strNamespace = 'root/sms/site_Company'
    $strQuery = "select * from SMS_FullCollectionMembership inner join SMS_Collection on SMS_Collection.CollectionID = SMS_FullCollectionMembership.CollectionID where SMS_FullCollectionMembership.ResourceID like '" + $pcObject.ResourceID + "'"
    
    Get-WmiObject -Namespace $strNamespace -Query $strQuery | ForEach-Object {
	    $strQuery = "select * from SMS_ObjectContainerItem inner join SMS_ObjectContainerNode on SMS_ObjectContainerNode.ContainerNodeID = SMS_ObjectContainerItem.ContainerNodeID where SMS_ObjectContainerItem.InstanceKey like '" + $_.SMS_Collection.CollectionID + "'"
	    $objWMISearch = Get-WmiObject -Namespace $strNamespace -Query $strQuery
	    foreach ($instance in $objWMISearch) {
            if ($instance.SMS_ObjectContainerItem.InstanceKey -eq $collectionObject.CollectionID) { return $true }
	    }
    }

    return $false
}

function Remove-DeviceFromCollection ($pcObject, $collectionObject) {
    Try {
        if (Get-CollectionMembership $pcObject $collectionObject) {
            Remove-CMDeviceCollectionDirectMembershipRule -CollectionId $collectionObject.CollectionID -ResourceId $pcObject.ResourceID -Force
            Update-Log "$($pcObject.Name) has been removed from the `"$($collectionObject.Name)`" collection.`n"
        } else {
            Update-Log "$($pcObject.Name) was not a member of the `"$($collectionObject.Name)`" collection; no action taken.`n"
        }
    } Catch {
        $LogTextBox.SelectionColor = 'Yellow'
        Update-Log "There was a problem removing $($pcObject.Name) from the `"$($collectionObject.Name)`" collection.`n"
    }
}

function Add-DeviceToCollection ($pcObject, $collectionObject) {
    Try {
        if (-not (Get-CollectionMembership $pcObject $collectionObject)) {
            Add-CMDeviceCollectionDirectMembershipRule -CollectionId $collectionObject.CollectionID -ResourceId $pcObject.ResourceID
            Update-Log "$($pcObject.Name) has been added to the `"$($collectionObject.Name)`" collection.`n"
        } else {
            Update-Log "$($pcObject.Name) was already a member of the `"$($collectionObject.Name)`" collection; no action taken.`n"
        }
    } Catch {
        $LogTextBox.SelectionColor = 'Yellow'
        Update-Log "There was a problem adding $($pcObject.Name) to the `"$($collectionObject.Name)`" collection.`n"
    }
}

function Migrate-Device ($user, $oldPC, $newPC) {  
    # validate the user input and create objects
    if (($userObject = Validate-User $user) -eq $null) { return }
    if (($oldPCObject = Validate-PC $oldPC) -eq $null) { return }
    if (($newPCObject = Validate-PC $newPC) -eq $null) { return }

    # get the collection objects
    $retiredCollectionObject = Get-CMDeviceCollection -Name 'Old PCs'
    $activeCollectionObject = Get-CMDeviceCollection -Name 'Active PCs'

    # remove the old pc as the user's primary device
    Remove-UAD $userObject $oldPCObject

    # add the new pc as the user's primary device
    Add-UAD $userObject $newPCObject

    # remove old pc from all workstations collection
    Remove-DeviceFromCollection $oldPCObject $activeCollectionObject

    # add the old pc to the retired pc's collection
    Add-DeviceToCollection $oldPCObject $retiredCollectionObject

    # add the new pc to the all workstations collection
    Add-DeviceToCollection $newPCObject $activeCollectionObject

    Update-Log "All done!`n"
}

#
#
#
# beginning of form code
#
function Create-UtilityForm {
    $objForm = New-Object System.Windows.Forms.Form 
    $objForm.Text = "SCCM PC Migration"
    $objForm.Size = New-Object System.Drawing.Size(500, 600) 
    $objForm.StartPosition = "CenterScreen"

    # Creates output textbox
    $LogTextBox = New-Object System.Windows.Forms.RichTextBox
    $LogTextBox.Location = New-Object System.Drawing.Size(12, 80) 
    $LogTextBox.Size = New-Object System.Drawing.Size(460, 470)
    $LogTextBox.ReadOnly = 'True'
    $LogTextBox.BackColor = 'Black'
    $LogTextBox.ForeColor = 'White'
    $LogTextBox.Font = 'Consolas'
    $objForm.Controls.Add($LogTextBox)

    # user id input
    $UserSearchButton = New-Object System.Windows.Forms.Button
    $UserSearchButton.Location = New-Object System.Drawing.Size(12, 14)
    $UserSearchButton.Size = New-Object System.Drawing.Size(75, 22)
    $UserSearchButton.Text = "User ID"
    $UserSearchButton.Add_Click(
        { Script:Get-User $userTextBox.Text })
    $objForm.Controls.Add($UserSearchButton)

    $userTextBox = New-Object System.Windows.Forms.TextBox 
    $userTextBox.Location = New-Object System.Drawing.Size(110, 15) 
    $userTextBox.Size = New-Object System.Drawing.Size(60, 20)
    $objForm.Controls.Add($userTextBox) 

    # button to search for primary machines and fill in old asset text box
    $PCSearchButton = New-Object System.Windows.Forms.Button
    $PCSearchButton.Location = New-Object System.Drawing.Size(250, 14)
    $PCSearchButton.Size = New-Object System.Drawing.Size(75, 22)
    $PCSearchButton.Text = "Old Asset"
    $PCSearchButton.Add_Click(
        { Script:Get-PrimaryMachines $userTextBox.Text })
    $objForm.Controls.Add($PCSearchButton)

    $oldPCTextBox = New-Object System.Windows.Forms.TextBox 
    $oldPCTextBox.Location = New-Object System.Drawing.Size(345, 15)
    $oldPCTextBox.Size = New-Object System.Drawing.Size(125, 20)
    $objForm.Controls.Add($oldPCTextBox) 

    # new pc input
    $MigrateButton = New-Object System.Windows.Forms.Button
    $MigrateButton.Location = New-Object System.Drawing.Size(250, 44)
    $MigrateButton.Size = New-Object System.Drawing.Size(75, 22)
    $MigrateButton.Text = "Migrate"
    $MigrateButton.Add_Click(
        { Script:Migrate-Device $userTextBox.Text $oldPCTextBox.Text $newPCTextBox.Text })
    $objForm.Controls.Add($MigrateButton)

    $newPCTextBox = New-Object System.Windows.Forms.TextBox 
    $newPCTextBox.Location = New-Object System.Drawing.Size(345, 45) 
    $newPCTextBox.Size = New-Object System.Drawing.Size(125, 20) 
    $objForm.Controls.Add($newPCTextBox)
    
    # clear log button
    $clearButton = New-Object System.Windows.Forms.Button
    $clearButton.Location = New-Object System.Drawing.Size(12, 44)
    $clearButton.Size = New-Object System.Drawing.Size(75, 22)
    $clearButton.Text = "Clear Log"
    $clearButton.Add_Click(
        { $LogTextBox.Clear() })
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
    [System.Windows.Forms.MessageBox]::Show("Failed to set CM site drive. Are you sure you are running this from sccm01 and the console is up to date?" , "Fail!")
    exit
}