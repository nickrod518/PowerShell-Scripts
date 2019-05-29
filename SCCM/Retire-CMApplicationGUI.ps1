# references for building forms
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

function Update-Log ($text) {
    $LogTextBox.AppendText("$text")
    $LogTextBox.Update()
    $LogTextBox.ScrollToCaret()
}

function Retire-CMApplication {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $RetiringApps = @()
    )

    # for each provided app name, remove deployments, rename, and retire
    foreach ($app in $RetiringApps) {
        if ($RetiringApp = Get-CMApplication -Name $app) {
            Update-Log "So long, $app!`n"

            # checking retired status, setting to active so that we can make changes
            if ($RetiringApp.IsExpired) {
                $appWMI = gwmi -Namespace Root\SMS\Site_$PSD -class SMS_ApplicationLatest -Filter "LocalizedDisplayName = '$app'"
                $appWMI.SetIsExpired($false) | Out-Null
                Update-Log "Setting Status of $app to Active so that changes can be made.`n"
            }

            $oldDeploys = Get-CMDeployment -SoftwareName $RetiringApp.LocalizedDisplayName

            # remove all deployments for the app
            if ($oldDeploys) {
                $oldDeploys | ForEach-Object {
                    Remove-CMDeployment -ApplicationName $app -DeploymentId $_.DeploymentID -Force
                }
                Update-Log "Removed $($oldDeploys.Count) deployments of $app.`n"
            }

            # remove content from all dp's and dpg's
            Update-Log "Removing content from all distribution points"
            $DPs = Get-CMDistributionPoint
            foreach ($DP in $DPs) {
                Update-Log "."
                try {
                    Remove-CMContentDistribution -Application $RetiringApp -DistributionPointName ($DP).NetworkOSPath -Force -EA SilentlyContinue
                } catch { }
            }
            Update-Log "`n"
            Update-Log "Removing content from all distribution point groups"
            $DPGs = Get-CMDistributionPointGroup
            foreach ($DPG in $DPGs) {
                Update-Log "."
                try {
                    Remove-CMContentDistribution -Application $RetiringApp -DistributionPointGroupName ($DPG).Name -Force -EA SilentlyContinue
                } catch { }
            }
            Update-Log "`n"

            # rename the app
            $app = $app.Replace('Retired-', '')
            try {
                Set-CMApplication -Name $app -NewName "Retired-$app"
            } catch { }
            Update-Log "Renamed to Retired-$app.`n"

            # move the app according to category
            if ($RetiringApp.LocalizedCategoryInstanceNames -eq "Mac") {
                Move-CMObject -FolderPath "Application\Retired" -InputObject $RetiringApp
                Update-Log "Moved to Mac\Retired Applications.`n"
            } else {
                Move-CMObject -FolderPath "Application\Retired" -InputObject $RetiringApp
                Update-Log "Moved to Retired.`n"
            }

            # retire the app
            if (!$RetiringApp.IsExpired) {
                $appWMI = gwmi -Namespace Root\SMS\Site_$(Get-PSDrive -PSProvider CMSite) -class SMS_ApplicationLatest -Filter "LocalizedDisplayName = 'Retired-$app'"
                $appWMI.SetIsExpired($true) | Out-Null
                Update-Log "Set status to Retired.`n"
            } else {
                Update-Log "Status was already set to Retired.`n"
            }

            # return source files location
            $xml = [xml]$RetiringApp.SDMPackageXML
            $loc = $xml.AppMgmtDigest.DeploymentType.Installer.Contents.Content.Location
            Update-Log "Don't forget to delete the source files from $loc.`n"

        } else {
            Update-Log "$app was not found. No actions performed.`n"
        }
    }
}

# user form
function Create-UtilityForm {
    $objForm = New-Object System.Windows.Forms.Form 
    $objForm.Text = "SCCM App Retire"
    $objForm.Size = New-Object System.Drawing.Size(500, 600) 
    $objForm.StartPosition = "CenterScreen"

    # Creates output log
    $LogTextBox = New-Object System.Windows.Forms.RichTextBox
    $LogTextBox.Location = New-Object System.Drawing.Size(12, 50) 
    $LogTextBox.Size = New-Object System.Drawing.Size(460, 500)
    $LogTextBox.ReadOnly = 'True'
    $LogTextBox.BackColor = 'Black'
    $LogTextBox.ForeColor = 'White'
    $LogTextBox.Font = 'Consolas'
    $objForm.Controls.Add($LogTextBox)

    # app retire button
    $AppRetireButton = New-Object System.Windows.Forms.Button
    $AppRetireButton.Location = New-Object System.Drawing.Size(12, 14)
    $AppRetireButton.Size = New-Object System.Drawing.Size(75, 22)
    $AppRetireButton.Text = "Retire"
    $AppRetireButton.Add_Click(
        { Script:Retire-CMApplication $appTextBox.Text })
    $objForm.Controls.Add($AppRetireButton)

    # app name input box
    $appTextBox = New-Object System.Windows.Forms.TextBox 
    $appTextBox.Location = New-Object System.Drawing.Size(110, 15) 
    $appTextBox.Size = New-Object System.Drawing.Size(260, 20)
    $objForm.Controls.Add($appTextBox)
    
    # clear log button
    $clearButton = New-Object System.Windows.Forms.Button
    $clearButton.Location = New-Object System.Drawing.Size(395, 14)
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
    Import-Module ($Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5) + '\ConfigurationManager.psd1')
    Set-Location -Path "$(Get-PSDrive -PSProvider CMSite):\" -ErrorAction Stop
    Create-UtilityForm
} catch {
    [System.Windows.Forms.MessageBox]::Show("Failed to set CM site drive. Are you sure you are running this from SCCM01 and the console is up to date?" , "Fail!")
    exit
}