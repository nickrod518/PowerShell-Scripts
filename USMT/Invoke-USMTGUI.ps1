<#
.SYNOPSIS
    Migrate user state from one PC to another using USMT.

.DESCRIPTION
    Migrate user state from one PC to another using USMT. Intended for domain joined computers.
    By default, all user profile data except Favorites and Documents will be included.
    Tool also allows for user to specify additional folders to include.

.NOTES
    USMT environmental variables: https://technet.microsoft.com/en-us/library/cc749104(v=ws.10).aspx

#>

begin {
    # Default configuration options
    $Script:DefaultDomain = 'Domain'
    $Script:AdminExtension = '-admin'
    $Script:ValidIPAddress = '40.*'
    $Script:MigrationStorePath = 'C:\TempFiles\MigrationStore'
    $Script:DefaultExclude = @"
        <exclude>
            <objectSet>
                <pattern type="File">%CSIDL_FAVORITES%\* [*]</pattern>
                <pattern type="File">%CSIDL_PERSONAL%\* [*]</pattern>
            </objectSet>
        </exclude>
"@
    $Script:USMTPath = '.\USMT'
    $Script:ProfileMigrationSummary = "All data within user profile, excluding Documents and Favorites, will be migrated."

    function Update-Log {
        param(
            [string] $Message,
            [string] $Color = 'White',
            [switch] $NoNewLine
        )

        $LogTextBox.SelectionColor = $Color
        $LogTextBox.AppendText("$Message")
        if (-not $NoNewLine) { $LogTextBox.AppendText("`n") }
        $LogTextBox.Update()
        $LogTextBox.ScrollToCaret()
    }

    function Get-IPAddress { (Test-Connection -ComputerName (hostname) -Count 1).IPV4Address.IPAddressToString }

    # Get the host name the script is running from
    function Get-HostName { $env:COMPUTERNAME }

    # Get the user's name that ran this script
    function Get-CurrentUserName { $env:USERNAME }

    function Get-UserProfiles {
        # Get all user profiles on this PC and let the user select one to migrate
        $RegKey = 'Registry::HKey_Local_Machine\Software\Microsoft\Windows NT\CurrentVersion\ProfileList\*'

        # Return each profile on this computer
        Get-ItemProperty -Path $RegKey | ForEach-Object {
            $SID = New-object System.Security.Principal.SecurityIdentifier($_.PSChildName)
            try { 
                $User = $SID.Translate([System.Security.Principal.NTAccount]).Value
                # Don't show NT Authority or local accounts
                if (($User -notlike 'NT Authority\*') -and ($User -notlike "$(Get-HostName)\*")) {
                    $ProfilesDataGridView.Rows.Add($User) | Out-Null
                }
            } catch { }
        }
    }

    function Get-UserProfilePath {
        $SelectedUserDomain = $SelectedProfileTextBox.Text.Split('\', 2)[0]
        $SelectedUserName = $SelectedProfileTextBox.Text.Split('\', 2)[1]
        $UserObject = New-Object System.Security.Principal.NTAccount($SelectedUserDomain, $SelectedUserName) 
        $SID = $UserObject.Translate([System.Security.Principal.SecurityIdentifier])
        $User = Get-ItemProperty -Path "Registry::HKey_Local_Machine\Software\Microsoft\Windows NT\CurrentVersion\ProfileList\$($SID.Value)"
        $User.ProfileImagePath
    }

    function Test-UserAdmin {
        if (-not ($(Get-CurrentUserName) -like "*$AdminExtension")) {
            Update-Log "You are running this script with user account $(Get-CurrentUserName), which is not a $AdminExtension account. " -Color 'Red' -NoNewLine
            Update-Log "Some tasks may fail if not run with admin credentials.`n" -Color 'Red'
        }
    }

    function Add-ExtraDirectory {
        # Bring up file explorer so user can select a directory to add
        $OpenDirectoryDialog = New-Object Windows.Forms.FolderBrowserDialog
        $OpenDirectoryDialog.ShowDialog() | Out-Null
        $SelectedDirectory = $OpenDirectoryDialog.SelectedPath
        try {
            # If user hits cancel it could cause attempt to add null path, so check that there's something there
            if ($SelectedDirectory) {
                Update-Log "Adding to extra directories: $SelectedDirectory."
                $ExtraDirectoriesDataGridView.Rows.Add($SelectedDirectory)
            }
        } catch {
            Update-Log "There was a problem with the directory you chose: $($_.Exception.Message)" -Color Red
        }
    }

    function Remove-ExtraDirectory {
        # Remove selected cell from Extra Directories data grid view
        $CurrentCell = $ExtraDirectoriesDataGridView.CurrentCell
        Update-Log "Removed [$($CurrentCell.Value)] from extra directories."
        $CurrentRow = $ExtraDirectoriesDataGridView.Rows[$CurrentCell.RowIndex]
        $ExtraDirectoriesDataGridView.Rows.Remove($CurrentRow)
    }

    function Set-Config {
        $ExtraDirectoryCount = $ExtraDirectoriesDataGridView.RowCount

        if ($ExtraDirectoryCount) {
            Update-Log "Including $ExtraDirectoryCount extra directories."

            $ExtraDirectoryXML = @"
    <!-- This component includes the additional directories selected by the user -->
    <component type="Documents" context="System">
        <displayName>Additional Folders</displayName>
        <role role="Data">
            <rules>
                <include>
                    <objectSet>

"@
            # Include each directory user has added to the Extra Directories data grid view
            $ExtraDirectoriesDataGridView.Rows | ForEach-Object {
                $CurrentRowIndex = $_.Index
                $Path = $ExtraDirectoriesDataGridView.Item(0, $CurrentRowIndex).Value

                $ExtraDirectoryXML += @"
                        <pattern type=`"File`">$Path\* [*]</pattern>"

"@
            }

            $ExtraDirectoryXML += @"
                    </objectSet>
                </include>
            </rules>
        </role>
    </component>
"@
        } else {
            Update-Log 'No extra directories will be included.'
        }

        $ConfigContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<migration urlid="http://www.microsoft.com/migration/1.0/migxmlext/config">
    <_locDefinition>
        <_locDefault _loc="locNone"/>
        <_locTag _loc="locData">displayName</_locTag>
    </_locDefinition>

$ExtraDirectoryXML

    <!-- This component migrates all user data except favorites and documents -->
    <component type="Documents" context="User">
        <displayName>Documents</displayName>
        <role role="Data">
            <rules>
                <include filter="MigXmlHelper.IgnoreIrrelevantLinks()">
                    <objectSet>
                        <script>MigXmlHelper.GenerateDocPatterns ("FALSE","TRUE","FALSE")</script>
                    </objectSet>
                </include>
                <exclude filter='MigXmlHelper.IgnoreIrrelevantLinks()'>
                    <objectSet>
                        <script>MigXmlHelper.GenerateDocPatterns ("FALSE","FALSE","FALSE")</script>
                    </objectSet>
                </exclude>
                $DefaultExclude
                <contentModify script="MigXmlHelper.MergeShellLibraries('TRUE','TRUE')">
                    <objectSet>
                        <pattern type="File">*[*.library-ms]</pattern>
                    </objectSet>
                </contentModify>
                <merge script="MigXmlHelper.SourcePriority()">
                    <objectSet>
                        <pattern type="File">*[*.library-ms]</pattern>
                    </objectSet>
                </merge>
            </rules>
        </role>
    </component>

    <!-- This component migrates all user app data -->
    <component type="Documents" context="User">
        <displayName>App Data</displayName>
        <paths>
            <path type="File">%CSIDL_APPDATA%</path>
        </paths>
        <role role="Data">
            <detects>
                <detect>
                    <condition>MigXmlHelper.DoesObjectExist("File","%CSIDL_APPDATA%")</condition>
                </detect>
            </detects>
            <rules>
                <include filter='MigXmlHelper.IgnoreIrrelevantLinks()'>
                    <objectSet>
                        <pattern type="File">%CSIDL_APPDATA%\* [*]</pattern>
                    </objectSet>
                </include>
                <merge script='MigXmlHelper.DestinationPriority()'>
                    <objectSet>
                        <pattern type="File">%CSIDL_APPDATA%\* [*]</pattern>
                    </objectSet>
                </merge>
            </rules>
        </role>
    </component>

    <!-- This component migrates wallpaper settings -->
    <component type="System" context="User">
        <displayName>Wallpapers</displayName>
        <role role="Settings">
            <rules>
                <include>
                    <objectSet>
                        <pattern type="Registry">HKCU\Control Panel\Desktop [Pattern]</pattern>
                        <pattern type="Registry">HKCU\Control Panel\Desktop [PatternUpgrade]</pattern>
                        <pattern type="Registry">HKCU\Control Panel\Desktop [TileWallpaper]</pattern>
                        <pattern type="Registry">HKCU\Control Panel\Desktop [WallPaper]</pattern>
                        <pattern type="Registry">HKCU\Control Panel\Desktop [WallpaperStyle]</pattern>
                        <pattern type="Registry">HKCU\Software\Microsoft\Windows\CurrentVersion\Themes [SetupVersion]</pattern>
                        <pattern type="Registry">HKCU\Software\Microsoft\Internet Explorer\Desktop\General [BackupWallpaper]</pattern>
                        <pattern type="Registry">HKCU\Software\Microsoft\Internet Explorer\Desktop\General [TileWallpaper]</pattern>
                        <pattern type="Registry">HKCU\Software\Microsoft\Internet Explorer\Desktop\General [Wallpaper]</pattern>
                        <pattern type="Registry">HKCU\Software\Microsoft\Internet Explorer\Desktop\General [WallpaperFileTime]</pattern>
                        <pattern type="Registry">HKCU\Software\Microsoft\Internet Explorer\Desktop\General [WallpaperLocalFileTime]</pattern>
                        <pattern type="Registry">HKCU\Software\Microsoft\Internet Explorer\Desktop\General [WallpaperStyle]</pattern>
                        <content filter="MigXmlHelper.ExtractSingleFile(NULL, NULL)">
                            <objectSet>
                                <pattern type="Registry">HKCU\Control Panel\Desktop [WallPaper]</pattern>
                                <pattern type="Registry">HKCU\Software\Microsoft\Internet Explorer\Desktop\General [BackupWallpaper]</pattern>
                                <pattern type="Registry">HKCU\Software\Microsoft\Internet Explorer\Desktop\General [Wallpaper]</pattern>
                            </objectSet>
                        </content>
                    </objectSet>
                </include>
            </rules>
        </role>
    </component>

    <!-- This component migrates wallpaper files -->
    <component type="Documents" context="System">
        <displayName>Move JPG and BMP</displayName>
        <role role="Data">
            <rules>
                <include>
                    <objectSet>
                        <pattern type="File"> %windir% [*.bmp]</pattern>
                        <pattern type="File"> %windir%\web\wallpaper [*.jpg]</pattern>
                        <pattern type="File"> %windir%\web\wallpaper [*.bmp]</pattern>
                    </objectSet>
                </include>
            </rules>
        </role>
    </component>
</migration>
"@

        $Config = "$Destination\Config.xml"
        New-Item $Config -ItemType File -Force | Out-Null
        Set-Content $Config $ConfigContent

        # Return the path to the config
        $Config
    }

    function Get-USMT {
        # Test that USMT binaries are reachable
        if (Test-Path $USMTPath) {
            $Script:ScanState = "$USMTPath\scanstate.exe"
            $Script:LoadState = "$USMTPath\loadstate.exe"
        } else {
            Update-Log "Unable to reach USMT share. Verify connection to $USMTPath and restart script.`n" -Color 'Red'
            $TabControl.Enabled = $false
        }
    }

    function Get-USMTResults {
        param([string] $ActionType)

        if ($PSVersionTable.PSVersion.Major -lt 3) {
            # Print back the entire log
            $Results = Get-Content "$Destination\$ActionType.log" | Out-String
        } else {
            # Get the last 4 lines from the log so we can see the results
            $Results = Get-Content "$Destination\$ActionType.log" -Tail 4 | ForEach-Object { 
                ($_.Split(']', 2)[1]).TrimStart()
            } | Out-String
        }

        Update-Log $Results -Color 'Cyan'
    }

    function Get-USMTProgress {
        param(
            [string] $Destination,
            [string] $ActionType
        )

        try {
            # Get the most recent entry in the progress log
            $LastLine = Get-Content "$Destination\$($ActionType)_progress.log" -Tail 1 -ErrorAction SilentlyContinue | Out-String
            Update-Log ($LastLine.Split(',', 4)[3]).TrimStart()
        } catch { Update-Log '.' -NoNewLine }
    }

    function Get-SaveState {
        # Use the migration folder name to get the old computer name
        if ((Test-Path $MigrationStorePath) -and (Get-ChildItem $MigrationStorePath)) {
            $OldComputer = (Get-ChildItem $MigrationStorePath | Where-Object { $_.PSIsContainer } | 
                Sort-Object -Descending -Property { $_.CreationTime } | Select-Object -First 1 ).BaseName
        } else {
            $OldComputer = 'N/A'
            Update-Log -Message 'No saved state found on this computer.' -Color 'Yellow'
        }

        $OldComputer
    }

    function Save-UserState {
        Update-Log "`nBeginning migration..."

        # If connection hasn't been verfied, test now
        if (-not $ConnectionCheckBox_OldPage.Checked) {
            Test-ComputerConnection -ComputerNameTextBox $NewComputerNameTextBox_OldPage `
            -ComputerIPTextBox $NewComputerIPTextBox_OldPage -ConnectionCheckBox $ConnectionCheckBox_OldPage
        }

        # Try and use the IP if the user filled that out, otherwise use the name
        if ($NewComputerIPTextBox_OldPage.Text -ne '') {
            $NewComputer = $NewComputerIPTextBox_OldPage.Text
        } else {
            $NewComputer = $NewComputerNameTextBox_OldPage.Text
        }
        $OldComputer = $OldComputerNameTextBox_OldPage.Text

        # After connection has been verified, continue with save state
        if ($ConnectionCheckBox_OldPage.Checked) {
            Update-Log 'Connection verified, proceeding with migration...'

            # Get the user profile to save
            if ($SelectedProfileTextBox.Text) {
                $User = $SelectedProfileTextBox.Text
                Update-Log "$User's profile has been selected for save state."
            } else {
                Update-Log "You must select a user profile." -Color 'Red'
                return
            }

            # Create migration store destination folder on new computer
            $DriveLetter = $MigrationStorePath.Split(':', 2)[0]
            $MigrationStorePath = $MigrationStorePath.TrimStart('C:\')
            New-Item "\\$NewComputer\$DriveLetter$\$MigrationStorePath" -ItemType Directory -Force | Out-Null
            $Script:Destination = "\\$NewComputer\$DriveLetter$\$MigrationStorePath\$OldComputer"
            New-Item $Destination -ItemType Directory -Force | Out-Null

            # If profile is a domain other than $DefaultDomain, save this info to text file
            $Domain = $User.Split('\')[0]
            if ($Domain -ne $DefaultDomain) {
                New-Item "$Destination\DomainMigration.txt" -ItemType File -Value $User | Out-Null
                Update-Log "Text file created with cross-domain information."
            }

            # Create the scan configuration
            Update-Log 'Generating configuration file...'
            $Config = Set-Config

            # Generate arguments for save state process
            $Logs = "/l:$Destination\scan.log /progress:$Destination\scan_progress.log"
            # Overwrite existing save state, use volume shadow copy method, exclude all but the selected user
            $Arguments = "$Destination /i:$Config /o /vsc /ue:*\* /ui:$User $Logs"

            # Begin saving user state to new computer
            Update-Log "Saving state of $User to $NewComputer..." -NoNewLine
            Start-Process -FilePath $ScanState -ArgumentList $Arguments -Verb RunAs

            # Give the process time to start before checking for its existence
            Start-Sleep -Seconds 3

            # Wait until the save state is complete
            try {
                $ScanProcess = Get-Process -Name scanstate -ErrorAction Stop
                while (-not $ScanProcess.HasExited) {
                    Get-USMTProgress
                    Start-Sleep -Seconds 3
                }
                Update-Log "Complete!" -Color 'Green'

                Update-Log 'Results:'
                Get-USMTResults -ActionType 'scan'
            } catch {
                Update-Log 'Scan state process not found.' -Color 'Red'
            }
        }
    }

    function Load-UserState {
        Update-Log "`nBeginning migration..."

        # If override is enabled, skip network checks
        if (-not $OverrideCheckBox.Checked) {
            # If connection hasn't been verfied, test now
            if (-not $ConnectionCheckBox_NewPage.Checked) {
                Test-ComputerConnection -ComputerNameTextBox $OldComputerNameTextBox_NewPage `
                -ComputerIPTextBox $OldComputerIPTextBox_NewPage -ConnectionCheckBox $ConnectionCheckBox_NewPage
            }

            # Try and use the IP if the user filled that out, otherwise use the name
            if ($OldComputerIPTextBox_NewPage.Text -ne '') {
                $OldComputer = $OldComputerIPTextBox_NewPage.Text
            } else {
                $OldComputer = $OldComputerNameTextBox_NewPage.Text
            }

            if ($ConnectionCheckBox_NewPage.Checked) {
                Update-Log "Connection verified, checking in with $OldComputer..."

                # Check in with the old computer and don't start until the save is complete
                if (Get-Process -Name scanstate -ComputerName $OldComputer -ErrorAction SilentlyContinue) {
                    Update-Log "Waiting on $OldComputer to complete save state..."
                    while (Get-Process -Name scanstate -ComputerName $OldComputer -ErrorAction SilentlyContinue) {
                        Get-USMTProgress
                        Start-Sleep -Seconds 1
                    }
                } else {
                    Update-Log "Save state process on $OldComputer is complete. Proceeding with migration."
                }
            } else {
                Update-Log "Unable to verify connection with $OldComputer. Migration cancelled." -Color 'Red'
                return
            }
        } else {
            $OldComputer = $OldComputerNameTextBox_NewPage.Text
            Update-Log "User has verified the save state process on $OldComputer is already compelted. Proceeding with migration."
        }

        # Get the location of the save state data
        $Script:Destination = "$MigrationStorePath\$OldComputer"

        # Generate arguments for load state process
        $Logs = "/l:$Destination\load.log /progress:$Destination\load_progress.log"
        
        # Check if user to be migrated is coming from a different domain and do a cross-domain migration if so
        if ($CrossDomainMigrationGroupBox.Visible) {
            $OldUser = "$($OldDomainTextBox.Text)\$($OldUserNameTextBox.Text)"
            $NewUser = "$($NewDomainTextBox.Text)\$($NewUserNameTextBox.Text)"

            # Make sure the user entered a new user's user name before continuing
            if ($NewUserNameTextBox.Text -eq '') {
                Update-Log "New user's user name must not be empty." -Color 'Red'
                return
            }

            Update-Log "$OldUser will be migrated as $NewUser."
            $Arguments = "$Destination /i:$Destination\Config.xml /mu:$($OldUser):$NewUser $Logs"
        } else {
            $Arguments = "$Destination /i:$Destination\Config.xml $Logs"
        }

        # Begin loading user state to this computer
        Update-Log "Loading state of $OldComputer..." -NoNewLine
        Start-Process -FilePath $LoadState -ArgumentList $Arguments -Verb RunAs

        # Give the process time to start before checking for its existence
        Start-Sleep -Seconds 3

        # Wait until the load state is complete
        try {
            $LoadProcess = Get-Process -Name loadstate -ErrorAction Stop
            while (-not $LoadProcess.HasExited) {
                Get-USMTProgress
                Start-Sleep -Seconds 1
            }
            Update-Log "Complete!" -Color 'Green'
            
            Update-Log 'Results:'
            Get-USMTResults -ActionType 'load'

            # Sometimes loadstate will kill the explorer task and it needs to be start again manually
            if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
                Update-Log 'Restarting Explorer process.'
                Start-Process explorer
            }

            # Delete the save state data
            try {
                Get-ChildItem $MigrationStorePath | Remove-Item -Recurse
                Update-Log 'Successfully removed old save state data.'
            } catch {
                Update-Log 'There was an issue when trying to remove old save state data.'
            }
        } catch {
            Update-Log 'Load state process not found.' -Color 'Red'
        }
    }

    function Test-ComputerConnection {
        param(
            [System.Windows.Forms.TextBox] $ComputerNameTextBox,
            [System.Windows.Forms.TextBox] $ComputerIPTextBox,
            [System.Windows.Forms.CheckBox] $ConnectionCheckBox
        )

        $ConnectionCheckBox.Checked = $false

        # Try and use the IP if the user filled that out, otherwise use the name
        if ($ComputerIPTextBox.Text -ne '') {
            $Computer = $ComputerIPTextBox.Text
            # Try to update the computer's name with its IP address
            if ($ComputerNameTextBox.Text -eq '') {
                try {
                    Update-Log 'Computer name is blank, attempting to resolve...' -Color 'Yellow'
                    $HostName = ([System.Net.Dns]::GetHostEntry($Computer)).HostName
                    $ComputerNameTextBox.Text = $HostName
                    Update-Log "Computer name set to $HostName."
                } catch {
                    Update-Log "Unable to resolve host name from IP address, you'll need to manually set this." -Color 'Red'
                    return
                }
            }
        } elseif ($ComputerNameTextBox.Text -ne '') {
            $Computer = $ComputerNameTextBox.Text
            # Try to update the computer's IP address using its DNS name
            try {
                Update-Log 'Computer IP address is blank, attempting to resolve...' -Color 'Yellow'
                # Get the first IP address found, which is usually the primary adapter
                $IPAddress = ([System.Net.Dns]::GetHostEntry($Computer)).AddressList.IPAddressToString.Split('.', 1)[0]

                # Set IP address in text box
                $ComputerIPTextBox.Text = $IPAddress
                Update-Log "Computer IP address set to $IPAddress."
            } catch {
                Update-Log "Unable to resolve IP address from host name, you'll need to manually set this." -Color 'Red'
                return
            }
        } else {
            $Computer = $null
        }

        # Don't even try if both fields are empty
        if ($Computer) {
            # If the computer doesn't appear to have a valid office IP, such as if it's on VPN, don't allow the user to continue
            if ($ComputerIPTextBox.Text -notlike $ValidIPAddress) {
                Update-Log "$IPAddress does not appear to be a valid IP address. The Migration Tool requires an IP address matching $ValidIPAddress." -Color 'Red'
                return
            }

            Update-Log "Testing connection to $Computer..."

            if (Test-Connection $Computer -Quiet) {
                $ConnectionCheckBox.Checked = $true
                Update-Log "Connection established." -Color 'Green'
            } else {
                Update-Log "Unable to reach $Computer." -Color 'Red'
                if ($ComputerIPTextBox.Text -eq '') {
                    Update-Log "Try entering $Computer's IP address." -Color 'Yellow'
                }
            }
        } else {
            Update-Log "Enter the computer's name or IP address."  -Color 'Red'
        }
    }

    function Set-Logo {
        Update-Log "             __  __ _                 _   _             " -Color 'LightBlue'
        Update-Log "            |  \/  (_) __ _ _ __ __ _| |_(_) ___  _ __  " -Color 'LightBlue'
        Update-Log "            | |\/| | |/ _`` | '__/ _`` | __| |/ _ \| '_ \ " -Color 'LightBlue'
        Update-Log "            | |  | | | (_| | | | (_| | |_| | (_) | | | |" -Color 'LightBlue'
        Update-Log "            |_|  |_|_|\__, |_|  \__,_|\__|_|\___/|_| |_|" -Color 'LightBlue'
        Update-Log "                _     |___/  _     _              _     " -Color 'LightBlue'
        Update-Log "               / \   ___ ___(_)___| |_ __ _ _ __ | |_   " -Color 'LightBlue'
        Update-Log "              / _ \ / __/ __| / __| __/ _`` | '_ \| __|  " -Color 'LightBlue'
        Update-Log "             / ___ \\__ \__ \ \__ \ || (_| | | | | |_   " -Color 'LightBlue'
        Update-Log "            /_/   \_\___/___/_|___/\__\__,_|_| |_|\__| v1.0" -Color 'LightBlue'
        Update-Log
        Update-Log '                        by Nick Rodriguez' -Color 'Gold'
        Update-Log
    }

    function Test-IsISE { if ($psISE) { $true } else { $false } }

    # Hide parent PowerShell window unless run from ISE
    if (-not $(Test-IsISE)) {
        $ShowWindowAsync = Add-Type -MemberDefinition @"
    [DllImport("user32.dll")] 
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow); 
"@ -Name "Win32ShowWindowAsync" -Namespace Win32Functions -PassThru
        $ShowWindowAsync::ShowWindowAsync((Get-Process -Id $PID).MainWindowHandle, 0) | Out-Null
    }

    # Load assemblies for building forms
    [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
}

process {
    # Create form
    $Form = New-Object System.Windows.Forms.Form 
    $Form.Text = 'Migration Assistant by Nick Rodriguez'
    $Form.Size = New-Object System.Drawing.Size(990, 600) 
    $Form.SizeGripStyle = 'Hide'
    $Form.FormBorderStyle = 'FixedToolWindow'
    $Form.MaximizeBox = $false
    $Form.StartPosition = "CenterScreen"

    # Create tab controls
    $TabControl = New-object System.Windows.Forms.TabControl
    $TabControl.DataBindings.DefaultDataSourceUpdateMode = 0
    $TabControl.Location = New-Object System.Drawing.Size(10, 10)
    $TabControl.Size = New-Object System.Drawing.Size(480, 550)
    $Form.Controls.Add($TabControl)

    # Log output text box
    $LogTextBox = New-Object System.Windows.Forms.RichTextBox
    $LogTextBox.Location = New-Object System.Drawing.Size(500, 30) 
    $LogTextBox.Size = New-Object System.Drawing.Size(475, 530)
    $LogTextBox.ReadOnly = 'True'
    $LogTextBox.BackColor = 'Black'
    $LogTextBox.ForeColor = 'White'
    $LogTextBox.Font = 'Consolas, 10'
    $LogTextBox.DetectUrls = $false
    Set-Logo
    $Form.Controls.Add($LogTextBox)

    # Clear log button
    $ClearLogButton = New-Object System.Windows.Forms.Button
    $ClearLogButton.Location = New-Object System.Drawing.Size(370, 505)
    $ClearLogButton.Size = New-Object System.Drawing.Size(80, 20)
    $ClearLogButton.FlatStyle = 1
    $ClearLogButton.BackColor = 'White'
    $ClearLogButton.ForeColor = 'Black'
    $ClearLogButton.Text = 'Clear'
    $ClearLogButton.Add_Click({ $LogTextBox.Clear() })
    $LogTextBox.Controls.Add($ClearLogButton)

    #region old computer tab

    # Create old computer tab
    $OldComputerTabPage = New-Object System.Windows.Forms.TabPage
    $OldComputerTabPage.DataBindings.DefaultDataSourceUpdateMode = 0
    $OldComputerTabPage.UseVisualStyleBackColor = $true
    $OldComputerTabPage.Text = 'Old Computer'
    $TabControl.Controls.Add($OldComputerTabPage)

    #region computer info

    # Computer info group
    $OldComputerInfoGroupBox = New-Object System.Windows.Forms.GroupBox
    $OldComputerInfoGroupBox.Location = New-Object System.Drawing.Size(10, 10)
    $OldComputerInfoGroupBox.Size = New-Object System.Drawing.Size(450, 87)
    $OldComputerInfoGroupBox.Text = 'Computer Info'
    $OldComputerTabPage.Controls.Add($OldComputerInfoGroupBox)

    # Name label
    $ComputerNameLabel_OldPage = New-Object System.Windows.Forms.Label
    $ComputerNameLabel_OldPage.Location = New-Object System.Drawing.Size(100, 12)
    $ComputerNameLabel_OldPage.Size = New-Object System.Drawing.Size(100, 22)
    $ComputerNameLabel_OldPage.Text = 'Computer Name'
    $OldComputerInfoGroupBox.Controls.Add($ComputerNameLabel_OldPage)

    # IP label
    $ComputerIPLabel_OldPage = New-Object System.Windows.Forms.Label
    $ComputerIPLabel_OldPage.Location = New-Object System.Drawing.Size(230, 12)
    $ComputerIPLabel_OldPage.Size = New-Object System.Drawing.Size(80, 22)
    $ComputerIPLabel_OldPage.Text = 'IP Address'
    $OldComputerInfoGroupBox.Controls.Add($ComputerIPLabel_OldPage)

    # Old Computer name label
    $OldComputerNameLabel_OldPage = New-Object System.Windows.Forms.Label
    $OldComputerNameLabel_OldPage.Location = New-Object System.Drawing.Size(12, 35)
    $OldComputerNameLabel_OldPage.Size = New-Object System.Drawing.Size(80, 22)
    $OldComputerNameLabel_OldPage.Text = 'Old Computer'
    $OldComputerInfoGroupBox.Controls.Add($OldComputerNameLabel_OldPage)

    # Old Computer name text box
    $OldComputerNameTextBox_OldPage = New-Object System.Windows.Forms.TextBox
    $OldComputerNameTextBox_OldPage.ReadOnly = $true
    $OldComputerNameTextBox_OldPage.Location = New-Object System.Drawing.Size(100, 34) 
    $OldComputerNameTextBox_OldPage.Size = New-Object System.Drawing.Size(120, 20)
    $OldComputerNameTextBox_OldPage.Text = Get-HostName
    $OldComputerInfoGroupBox.Controls.Add($OldComputerNameTextBox_OldPage)

    # Old Computer IP text box
    $OldComputerIPTextBox_OldPage = New-Object System.Windows.Forms.TextBox
    $OldComputerIPTextBox_OldPage.ReadOnly = $true
    $OldComputerIPTextBox_OldPage.Location = New-Object System.Drawing.Size(230, 34) 
    $OldComputerIPTextBox_OldPage.Size = New-Object System.Drawing.Size(90, 20)
    $OldComputerIPTextBox_OldPage.Text = Get-IPAddress
    $OldComputerInfoGroupBox.Controls.Add($OldComputerIPTextBox_OldPage)

    # New Computer name label
    $NewComputerNameLabel_OldPage = New-Object System.Windows.Forms.Label
    $NewComputerNameLabel_OldPage.Location = New-Object System.Drawing.Size(12, 57)
    $NewComputerNameLabel_OldPage.Size = New-Object System.Drawing.Size(80, 22)
    $NewComputerNameLabel_OldPage.Text = 'New Computer'
    $OldComputerInfoGroupBox.Controls.Add($NewComputerNameLabel_OldPage)

    # New Computer name text box
    $NewComputerNameTextBox_OldPage = New-Object System.Windows.Forms.TextBox 
    $NewComputerNameTextBox_OldPage.Location = New-Object System.Drawing.Size(100, 56) 
    $NewComputerNameTextBox_OldPage.Size = New-Object System.Drawing.Size(120, 20)
    $NewComputerNameTextBox_OldPage.Add_TextChanged({
        if ($ConnectionCheckBox_OldPage.Checked) {
            Update-Log 'Computer name changed, connection status unverified.' -Color 'Yellow'
            $ConnectionCheckBox_OldPage.Checked = $false
        }
    })
    $OldComputerInfoGroupBox.Controls.Add($NewComputerNameTextBox_OldPage)

    # New Computer IP text box
    $NewComputerIPTextBox_OldPage = New-Object System.Windows.Forms.TextBox 
    $NewComputerIPTextBox_OldPage.Location = New-Object System.Drawing.Size(230, 56) 
    $NewComputerIPTextBox_OldPage.Size = New-Object System.Drawing.Size(90, 20)
    $NewComputerIPTextBox_OldPage.Add_TextChanged({
        if ($ConnectionCheckBox_OldPage.Checked) {
            Update-Log 'Computer IP address changed, connection status unverified.' -Color 'Yellow'
            $ConnectionCheckBox_OldPage.Checked = $false
        }
    })
    $OldComputerInfoGroupBox.Controls.Add($NewComputerIPTextBox_OldPage)

    # Button to test connection to new computer
    $TestConnectionButton_OldPage = New-Object System.Windows.Forms.Button
    $TestConnectionButton_OldPage.Location = New-Object System.Drawing.Size(335, 33)
    $TestConnectionButton_OldPage.Size = New-Object System.Drawing.Size(100, 22)
    $TestConnectionButton_OldPage.Text = 'Test Connection'
    $TestConnectionButton_OldPage.Add_Click({
        Test-ComputerConnection -ComputerNameTextBox $NewComputerNameTextBox_OldPage `
        -ComputerIPTextBox $NewComputerIPTextBox_OldPage -ConnectionCheckBox $ConnectionCheckBox_OldPage
    })
    $OldComputerInfoGroupBox.Controls.Add($TestConnectionButton_OldPage)

    # Connected check box
    $ConnectionCheckBox_OldPage = New-Object System.Windows.Forms.CheckBox
    $ConnectionCheckBox_OldPage.Enabled = $false
    $ConnectionCheckBox_OldPage.Text = 'Connected'
    $ConnectionCheckBox_OldPage.Location = New-Object System.Drawing.Size(336, 58) 
    $ConnectionCheckBox_OldPage.Size = New-Object System.Drawing.Size(100, 20)
    $OldComputerInfoGroupBox.Controls.Add($ConnectionCheckBox_OldPage)

    #endregion

    #region profile selection

    # Profile selection group box
    $ProfileSelectionGroupBox = New-Object System.Windows.Forms.GroupBox
    $ProfileSelectionGroupBox.Location = New-Object System.Drawing.Size(10, 110)
    $ProfileSelectionGroupBox.Size = New-Object System.Drawing.Size(220, 400)
    $ProfileSelectionGroupBox.Text = 'Profiles'
    $OldComputerTabPage.Controls.Add($ProfileSelectionGroupBox)

    # Profiles data table
    $ProfilesDataGridView = New-Object System.Windows.Forms.DataGridView
    $ProfilesDataGridView.Location = New-Object System.Drawing.Size(5, 20)
    $ProfilesDataGridView.Size = New-Object System.Drawing.Size(210, 320)
    $ProfilesDataGridView.ReadOnly = $true
    $ProfilesDataGridView.AllowUserToAddRows = $false
    $ProfilesDataGridView.AllowUserToResizeRows = $false
    $ProfilesDataGridView.AllowUserToResizeColumns = $false
    $ProfilesDataGridView.MultiSelect = $false
    $ProfilesDataGridView.ColumnCount = 1
    $ProfilesDataGridView.AutoSizeColumnsMode = 'Fill'
    $ProfilesDataGridView.ColumnHeadersVisible = $false
    $ProfilesDataGridView.RowHeadersVisible = $false
    # Populate profiles data grid view
    Get-UserProfiles
    $ProfilesDataGridView.Add_Click({
        # Get the selected row
        $SelectedProfile = $($ProfilesDataGridView.SelectedCells).Value
        Update-Log "Selected profile set to $SelectedProfile."

        # If domain is not $Domain, let user know cross-domain migration will take place
        $Domain = $SelectedProfile.Split('\')[0]
        if ($Domain -ne $DefaultDomain) {
            Update-Log "Selected profile is coming from $Domain domain. This will be noted in save state data and used during load state for cross-domain profile migration."
        }

        $SelectedProfileTextBox.Text = $SelectedProfile
    })
    $ProfileSelectionGroupBox.Controls.Add($ProfilesDataGridView)

    # Selected Profile label
    $SelectedProfileLabel = New-Object System.Windows.Forms.Label
    $SelectedProfileLabel.Location = New-Object System.Drawing.Size(5, 350)
    $SelectedProfileLabel.Size = New-Object System.Drawing.Size(210, 20)
    $SelectedProfileLabel.Text = 'Profile To Migrate'
    $ProfileSelectionGroupBox.Controls.Add($SelectedProfileLabel)

    # Selected Profile text box
    $SelectedProfileTextBox = New-Object System.Windows.Forms.TextBox
    $SelectedProfileTextBox.ReadOnly = $true
    $SelectedProfileTextBox.Location = New-Object System.Drawing.Size(5, 370) 
    $SelectedProfileTextBox.Size = New-Object System.Drawing.Size(210, 20)
    $SelectedProfileTextBox.Add_TextChanged({
        $UserProfilePath = Get-UserProfilePath
        Update-Log "Selected user profile path: $UserProfilePath."
        Update-Log $ProfileMigrationSummary
    })
    $ProfileSelectionGroupBox.Controls.Add($SelectedProfileTextBox)

    #endregion

    #region extra directories

    # Extra directories selection group box
    $ExtraDirectoriesGroupBox = New-Object System.Windows.Forms.GroupBox
    $ExtraDirectoriesGroupBox.Location = New-Object System.Drawing.Size(240, 110)
    $ExtraDirectoriesGroupBox.Size = New-Object System.Drawing.Size(220, 350)
    $ExtraDirectoriesGroupBox.Text = 'Extra Directories'
    $OldComputerTabPage.Controls.Add($ExtraDirectoriesGroupBox)
    
    # Extra directories data table
    $ExtraDirectoriesDataGridView = New-Object System.Windows.Forms.DataGridView
    $ExtraDirectoriesDataGridView.Location = New-Object System.Drawing.Size(5, 20)
    $ExtraDirectoriesDataGridView.Size = New-Object System.Drawing.Size(210, 320)
    $ExtraDirectoriesDataGridView.ReadOnly = $true
    $ExtraDirectoriesDataGridView.AllowUserToAddRows = $false
    $ExtraDirectoriesDataGridView.AllowUserToResizeRows = $false
    $ExtraDirectoriesDataGridView.AllowUserToResizeColumns = $false
    $ExtraDirectoriesDataGridView.MultiSelect = $false
    $ExtraDirectoriesDataGridView.ColumnCount = 1
    $ExtraDirectoriesDataGridView.AutoSizeColumnsMode = 'Fill'
    $ExtraDirectoriesDataGridView.ColumnHeadersVisible = $false
    $ExtraDirectoriesDataGridView.RowHeadersVisible = $false
    $ExtraDirectoriesGroupBox.Controls.Add($ExtraDirectoriesDataGridView)

    # Remove Extra directory button
    $RemoveExtraDirectoryButton = New-Object System.Windows.Forms.Button
    $RemoveExtraDirectoryButton.Location = New-Object System.Drawing.Size(0, 300)
    $RemoveExtraDirectoryButton.Size = New-Object System.Drawing.Size(20, 20)
    $RemoveExtraDirectoryButton.Text = '-'
    $RemoveExtraDirectoryButton.Font = 'Consolas, 14'
    $RemoveExtraDirectoryButton.Add_Click({ Remove-ExtraDirectory })
    $ExtraDirectoriesDataGridView.Controls.Add($RemoveExtraDirectoryButton)

    # Add Extra directory button
    $AddExtraDirectoryButton = New-Object System.Windows.Forms.Button
    $AddExtraDirectoryButton.Location = New-Object System.Drawing.Size(20, 300)
    $AddExtraDirectoryButton.Size = New-Object System.Drawing.Size(20, 20)
    $AddExtraDirectoryButton.Text = '+'
    $AddExtraDirectoryButton.Font = 'Consolas, 14'
    $AddExtraDirectoryButton.Add_Click({ Add-ExtraDirectory })
    $ExtraDirectoriesDataGridView.Controls.Add($AddExtraDirectoryButton)

    #endregion

    # Migrate button
    $MigrateButton_OldPage = New-Object System.Windows.Forms.Button
    $MigrateButton_OldPage.Location = New-Object System.Drawing.Size(300, 470)
    $MigrateButton_OldPage.Size = New-Object System.Drawing.Size(100, 40)
    $MigrateButton_OldPage.Font = New-Object System.Drawing.Font('Calibri', 16, [System.Drawing.FontStyle]::Bold)
    $MigrateButton_OldPage.Text = 'Migrate'
    $MigrateButton_OldPage.Add_Click({ Save-UserState })
    $OldComputerTabPage.Controls.Add($MigrateButton_OldPage)

    #endregion old computer tab

    #region new computer tab

    # Create new computer tab
    $NewComputerTabPage = New-Object System.Windows.Forms.TabPage
    $NewComputerTabPage.DataBindings.DefaultDataSourceUpdateMode = 0
    $NewComputerTabPage.UseVisualStyleBackColor = $true
    $NewComputerTabPage.Text = 'New Computer'
    $TabControl.Controls.Add($NewComputerTabPage)

    #region computer info

    # Computer info group
    $NewComputerInfoGroupBox = New-Object System.Windows.Forms.GroupBox
    $NewComputerInfoGroupBox.Location = New-Object System.Drawing.Size(10, 10)
    $NewComputerInfoGroupBox.Size = New-Object System.Drawing.Size(450, 87)
    $NewComputerInfoGroupBox.Text = 'Computer Info'
    $NewComputerTabPage.Controls.Add($NewComputerInfoGroupBox)
    
    # Name label
    $ComputerNameLabel_NewPage = New-Object System.Windows.Forms.Label
    $ComputerNameLabel_NewPage.Location = New-Object System.Drawing.Size(100, 12)
    $ComputerNameLabel_NewPage.Size = New-Object System.Drawing.Size(100, 22)
    $ComputerNameLabel_NewPage.Text = 'Computer Name'
    $NewComputerInfoGroupBox.Controls.Add($ComputerNameLabel_NewPage)

    # IP label
    $ComputerIPLabel_NewPage = New-Object System.Windows.Forms.Label
    $ComputerIPLabel_NewPage.Location = New-Object System.Drawing.Size(230, 12)
    $ComputerIPLabel_NewPage.Size = New-Object System.Drawing.Size(80, 22)
    $ComputerIPLabel_NewPage.Text = 'IP Address'
    $NewComputerInfoGroupBox.Controls.Add($ComputerIPLabel_NewPage)

    # Old Computer name label
    $OldComputerNameLabel_NewPage = New-Object System.Windows.Forms.Label
    $OldComputerNameLabel_NewPage.Location = New-Object System.Drawing.Size(12, 35)
    $OldComputerNameLabel_NewPage.Size = New-Object System.Drawing.Size(80, 22)
    $OldComputerNameLabel_NewPage.Text = 'Old Computer'
    $NewComputerInfoGroupBox.Controls.Add($OldComputerNameLabel_NewPage)

    # Old Computer name text box
    $OldComputerNameTextBox_NewPage = New-Object System.Windows.Forms.TextBox
    $OldComputerNameTextBox_NewPage.ReadOnly = $true
    $OldComputerNameTextBox_NewPage.Location = New-Object System.Drawing.Size(100, 34) 
    $OldComputerNameTextBox_NewPage.Size = New-Object System.Drawing.Size(120, 20)
    $OldComputerNameTextBox_NewPage.Text = Get-SaveState
    $NewComputerInfoGroupBox.Controls.Add($OldComputerNameTextBox_NewPage)

    # Old Computer IP text box
    $OldComputerIPTextBox_NewPage = New-Object System.Windows.Forms.TextBox
    $OldComputerIPTextBox_NewPage.Location = New-Object System.Drawing.Size(230, 34) 
    $OldComputerIPTextBox_NewPage.Size = New-Object System.Drawing.Size(90, 20)
    $OldComputerIPTextBox_NewPage.Add_TextChanged({
        if ($ConnectionCheckBox_NewPage.Checked) {
            Update-Log 'Computer IP address changed, connection status unverified.' -Color 'Yellow'
            $ConnectionCheckBox_NewPage.Checked = $false
        }
    })
    $NewComputerInfoGroupBox.Controls.Add($OldComputerIPTextBox_NewPage)

    # New Computer name label
    $NewComputerNameLabel_NewPage = New-Object System.Windows.Forms.Label
    $NewComputerNameLabel_NewPage.Location = New-Object System.Drawing.Size(12, 57)
    $NewComputerNameLabel_NewPage.Size = New-Object System.Drawing.Size(80, 22)
    $NewComputerNameLabel_NewPage.Text = 'New Computer'
    $NewComputerInfoGroupBox.Controls.Add($NewComputerNameLabel_NewPage)

    # New Computer name text box
    $NewComputerNameTextBox_NewPage = New-Object System.Windows.Forms.TextBox
    $NewComputerNameTextBox_NewPage.ReadOnly = $true
    $NewComputerNameTextBox_NewPage.Location = New-Object System.Drawing.Size(100, 56)
    $NewComputerNameTextBox_NewPage.Size = New-Object System.Drawing.Size(120, 20)
    $NewComputerNameTextBox_NewPage.Text = Get-HostName
    $NewComputerInfoGroupBox.Controls.Add($NewComputerNameTextBox_NewPage)

    # New Computer IP text box
    $NewComputerIPTextBox_NewPage = New-Object System.Windows.Forms.TextBox
    $NewComputerIPTextBox_NewPage.ReadOnly = $true
    $NewComputerIPTextBox_NewPage.Location = New-Object System.Drawing.Size(230, 56)
    $NewComputerIPTextBox_NewPage.Size = New-Object System.Drawing.Size(90, 20)
    $NewComputerIPTextBox_NewPage.Text = Get-IPAddress
    $NewComputerInfoGroupBox.Controls.Add($NewComputerIPTextBox_NewPage)

    # Button to test connection to new computer
    $TestConnectionButton_NewPage = New-Object System.Windows.Forms.Button
    $TestConnectionButton_NewPage.Location = New-Object System.Drawing.Size(335, 33)
    $TestConnectionButton_NewPage.Size = New-Object System.Drawing.Size(100, 22)
    $TestConnectionButton_NewPage.Text = 'Test Connection'
    $TestConnectionButton_NewPage.Add_Click({
        Test-ComputerConnection -ComputerNameTextBox $OldComputerNameTextBox_NewPage `
        -ComputerIPTextBox $OldComputerIPTextBox_NewPage -ConnectionCheckBox $ConnectionCheckBox_NewPage          
    })
    $NewComputerInfoGroupBox.Controls.Add($TestConnectionButton_NewPage)

    # Connected check box
    $ConnectionCheckBox_NewPage = New-Object System.Windows.Forms.CheckBox
    $ConnectionCheckBox_NewPage.Enabled = $false
    $ConnectionCheckBox_NewPage.Text = 'Connected'
    $ConnectionCheckBox_NewPage.Location = New-Object System.Drawing.Size(336, 58) 
    $ConnectionCheckBox_NewPage.Size = New-Object System.Drawing.Size(100, 20)
    $NewComputerInfoGroupBox.Controls.Add($ConnectionCheckBox_NewPage)

    #endregion computer info

    #region cross-domain migration

    # Cross-domain migration group box
    $CrossDomainMigrationGroupBox = New-Object System.Windows.Forms.GroupBox
    $CrossDomainMigrationGroupBox.Location = New-Object System.Drawing.Size(10, 100)
    $CrossDomainMigrationGroupBox.Size = New-Object System.Drawing.Size(290, 87)
    $CrossDomainMigrationGroupBox.Text = 'Cross-Domain Migration'
    $NewComputerTabPage.Controls.Add($CrossDomainMigrationGroupBox)

    # Domain label
    $DomainLabel = New-Object System.Windows.Forms.Label
    $DomainLabel.Location = New-Object System.Drawing.Size(100, 12)
    $DomainLabel.Size = New-Object System.Drawing.Size(80, 22)
    $DomainLabel.Text = 'Domain'
    $CrossDomainMigrationGroupBox.Controls.Add($DomainLabel)

    # User name label
    $UserNameLabel = New-Object System.Windows.Forms.Label
    $UserNameLabel.Location = New-Object System.Drawing.Size(190, 12)
    $UserNameLabel.Size = New-Object System.Drawing.Size(80, 22)
    $UserNameLabel.Text = 'User Name'
    $CrossDomainMigrationGroupBox.Controls.Add($UserNameLabel)

    # Old user label
    $OldUserLabel = New-Object System.Windows.Forms.Label
    $OldUserLabel.Location = New-Object System.Drawing.Size(12, 35)
    $OldUserLabel.Size = New-Object System.Drawing.Size(80, 22)
    $OldUserLabel.Text = 'Old User'
    $CrossDomainMigrationGroupBox.Controls.Add($OldUserLabel)

    # Old domain text box
    $OldDomainTextBox = New-Object System.Windows.Forms.TextBox
    $OldDomainTextBox.ReadOnly = $true
    $OldDomainTextBox.Location = New-Object System.Drawing.Size(100, 34) 
    $OldDomainTextBox.Size = New-Object System.Drawing.Size(80, 20)
    $OldDomainTextBox.Text = $OldComputerNameTextBox_NewPage.Text
    $CrossDomainMigrationGroupBox.Controls.Add($OldDomainTextBox)

    # Old user slash label
    $OldUserSlashLabel = New-Object System.Windows.Forms.Label
    $OldUserSlashLabel.Location = New-Object System.Drawing.Size(179, 33)
    $OldUserSlashLabel.Size = New-Object System.Drawing.Size(10, 20)
    $OldUserSlashLabel.Text = '\'
    $OldUserSlashLabel.Font = New-Object System.Drawing.Font('Calibri', 12)
    $CrossDomainMigrationGroupBox.Controls.Add($OldUserSlashLabel)

    # Old user name text box
    $OldUserNameTextBox = New-Object System.Windows.Forms.TextBox
    $OldUserNameTextBox.ReadOnly = $true
    $OldUserNameTextBox.Location = New-Object System.Drawing.Size(190, 34) 
    $OldUserNameTextBox.Size = New-Object System.Drawing.Size(80, 20)
    $OldUserNameTextBox.Add_TextChanged({
        if ($ConnectionCheckBox_NewPage.Checked) {
            Update-Log 'Computer IP address changed, connection status unverified.' -Color 'Yellow'
            $ConnectionCheckBox_NewPage.Checked = $false
        }
    })
    $CrossDomainMigrationGroupBox.Controls.Add($OldUserNameTextBox)

    # New user label
    $NewUserLabel = New-Object System.Windows.Forms.Label
    $NewUserLabel.Location = New-Object System.Drawing.Size(12, 57)
    $NewUserLabel.Size = New-Object System.Drawing.Size(80, 22)
    $NewUserLabel.Text = 'New User'
    $CrossDomainMigrationGroupBox.Controls.Add($NewUserLabel)

    # New domain text box
    $NewDomainTextBox = New-Object System.Windows.Forms.TextBox
    $NewDomainTextBox.ReadOnly = $true
    $NewDomainTextBox.Location = New-Object System.Drawing.Size(100, 56)
    $NewDomainTextBox.Size = New-Object System.Drawing.Size(80, 20)
    $NewDomainTextBox.Text = $Domain
    $CrossDomainMigrationGroupBox.Controls.Add($NewDomainTextBox)

    # New user slash label
    $NewUserSlashLabel = New-Object System.Windows.Forms.Label
    $NewUserSlashLabel.Location = New-Object System.Drawing.Size(179, 56)
    $NewUserSlashLabel.Size = New-Object System.Drawing.Size(10, 20)
    $NewUserSlashLabel.Text = '\'
    $NewUserSlashLabel.Font = New-Object System.Drawing.Font('Calibri', 12)
    $CrossDomainMigrationGroupBox.Controls.Add($NewUserSlashLabel)

    # New user name text box
    $NewUserNameTextBox = New-Object System.Windows.Forms.TextBox
    $NewUserNameTextBox.Location = New-Object System.Drawing.Size(190, 56)
    $NewUserNameTextBox.Size = New-Object System.Drawing.Size(80, 20)
    $CrossDomainMigrationGroupBox.Controls.Add($NewUserNameTextBox)
    
    # Populate old user data if DomainMigration.txt file exists, otherwise disable group box
    if (Test-Path "$MigrationStorePath\$($OldComputerNameTextBox_NewPage.Text)\DomainMigration.txt") {
        $OldUser = Get-Content "$MigrationStorePath\$($OldComputerNameTextBox_NewPage.Text)\DomainMigration.txt"
        $OldDomainTextBox.Text = $OldUser.Split('\')[0]
        $OldUserNameTextBox.Text = $OldUser.Split('\')[1]
    } else {
        $CrossDomainMigrationGroupBox.Visible = $false
    }

    #endregion cross-domain migration

    # Override check box
    $OverrideCheckBox = New-Object System.Windows.Forms.CheckBox
    $OverrideCheckBox.Text = 'Save state task completed'
    $OverrideCheckBox.Location = New-Object System.Drawing.Size(340, 110) 
    $OverrideCheckBox.Size = New-Object System.Drawing.Size(100, 30)
    $OverrideCheckBox.Add_Click({
        if ($OverrideCheckBox.Checked -eq $true) {
            $NewComputerInfoGroupBox.Enabled = $false
            Update-Log 'Network connection override enabled - ' -Color 'Yellow' -NoNewLine
            Update-Log 'Save state process on old computer is assumed to be completed and no network checks will be processed during load state.'
        } else {
            $NewComputerInfoGroupBox.Enabled = $true
            Update-Log 'Network connection override enabled - ' -Color 'Yellow' -NoNewLine
            Update-Log 'Network checks will be processed during load state.'
        }
    })
    $NewComputerTabPage.Controls.Add($OverrideCheckBox)

    # Migrate button
    $MigrateButton_NewPage = New-Object System.Windows.Forms.Button
    $MigrateButton_NewPage.Location = New-Object System.Drawing.Size(340, 145)
    $MigrateButton_NewPage.Size = New-Object System.Drawing.Size(100, 40)
    $MigrateButton_NewPage.Font = New-Object System.Drawing.Font('Calibri', 16, [System.Drawing.FontStyle]::Bold)
    $MigrateButton_NewPage.Text = 'Migrate'
    $MigrateButton_NewPage.Add_Click({ Load-UserState })
    $NewComputerTabPage.Controls.Add($MigrateButton_NewPage)

    #endregion new computer tab

    # Test if user is using an admin account
    Test-UserAdmin

    # Get the path to the USMT files
    Get-USMT

    # Show our form
    $Form.Add_Shown({$Form.Activate()})
    $Form.ShowDialog() | Out-Null
}