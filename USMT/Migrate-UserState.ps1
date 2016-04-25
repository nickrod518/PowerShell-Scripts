<#
.SYNOPSIS
    Migrate user state from one PC to another using USMT.

.DESCRIPTION
    *Must be run with admin credentials*

    1. Get USMT binaries and config from network location
    2. Prompt whether script is running from new or old PC
        a. If running from old PC, save state
            i. Prompt for user profile to migrate
            ii. Prompt for new PC name to save user state to
            iii. Run USMT ScanState
        b. If running from new PC, load state
            i. Script will automatically collect saved state from C:\Migrations
            ii. Reach out to old PC and verify scan state process is complete before proceeding
            iii. Run USMT LoadState
            iv. Remove scan state data
    3. Get USMT job results from log file

.NOTES
    Created by Nick Rodriguez

    Version 1.2 - 4/5/16
        -Added test for -a creds, and choice to continue anyway
        -Changed Config.xml to be dynamically created from script
        -Added ability to select an additional folder to include

    Version 1.1 - 4/4/16
        -Removed cred request assuming user will run using admin creds

    Version 1.0 - 3/30/16
        -Creation
#>

begin {
    function Get-UserProfile {
        # Get all user profiles on this PC and let the user select one to migrate
        $RegKey = 'Registry::HKey_Local_Machine\Software\Microsoft\Windows NT\CurrentVersion\ProfileList\*'
        $Items = Get-ItemProperty -Path $RegKey

        Foreach ($Item in $Items) {
            $objUser = New-Object System.Security.Principal.SecurityIdentifier($Item.PSChildName)
            $ErrorActionPreference = 'SilentlyContinue'
            $objName = $objUser.Translate([System.Security.Principal.NTAccount])
            $ErrorActionPreference = 'Continue'
            $Item.PSChildName = $objName.value
        }

        # Filter users list to only show CORP users
        $DomainUsers = $Items | Where-Object { $_.PSChildName -like 'DomainName\*' }

        # Allow the user to select a profile to migrate
        $SelectedUser = $DomainUsers | Select-Object -Property PSChildName, ProfileImagePath | Out-GridView -Title 'Select a user' -OutputMode Single
        if (-not $SelectedUser) {
            Write-Warning 'Nothing selected, please try again.'
            Start-Sleep -Seconds 2
            Get-UserProfile
        } else { $SelectedUser }
    }

    function Read-YesOrNo {
        param ([string] $Message)

        $Continue = Read-Host $Message
        while('yes', 'no', 'y', 'n', 'retry', 'skip', 'r', 's' -notcontains $Continue) { $Continue = Read-Host $Message }
        if (($Continue -like 'n*') -or ($Continue -like 's*')) { $false } else { $true }
    }

    function Test-UserAdmin {
        $RunningUser = $env:USERNAME

        # This assumes you use a "-admin" suffix for admin accounts
        if (-not ($RunningUser -like '*-admin')) {
            # Give user option to quit, or continue
            Write-Warning "You are running this script with user account $RunningUser, which is not a -admin account."
            $Continue = Read-YesOrNo 'Some tasks may fail if not run with admin credentials. Continue anyway (yes/no)?'
            if (-not $Continue) { exit }
        }
    }

    function Set-Config {
        $Continue = Read-YesOrNo 'Include extra directories in migration (yes/no)?'
        if ($Continue) {
            $ExtraDirectoryXML = @"
    <!-- This component includes the additional directories selected by the user -->
    <component type="Documents" context="System">
        <displayName>Additional Folders</displayName>
        <role role="Data">
            <rules>
                <include>
                    <objectSet>

"@

            [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
            $OpenDirectoryDialog = New-Object Windows.Forms.FolderBrowserDialog
            $ExtraDirectories = @()

            while ($Continue) {
                $OpenDirectoryDialog.ShowDialog() | Out-Null
                try { 
                    $ExtraDirectories += $OpenDirectoryDialog.SelectedPath
                    Write-Host "Including: ($OpenDirectoryDialog.SelectedPath)"
                } catch {
                    Write-Host "There was a problem with the directory you chose: $($_.Exception.Message)" -ForegroundColor Red
                }
                $Continue = Read-YesOrNo 'Include another extra directory in migration (yes/no)?'
            }

            $ExtraDirectories | ForEach-Object { 
                $ExtraDirectoryXML += @"
                        <pattern type=`"File`">$_\* [*]</pattern>"

"@
            }

            $ExtraDirectoryXML += @"
                    </objectSet>
                </include>
            </rules>
        </role>
    </component>
"@
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
                <exclude>
                    <objectSet>
                        <pattern type="File">%CSIDL_FAVORITES%\* [*]</pattern>
                        <pattern type="File">%CSIDL_PERSONAL%\* [*]</pattern>
                    </objectSet>
                </exclude>
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

        $Script:Config = "$Destination\Config.xml"
        New-Item $Config -ItemType File -Force | Out-Null
        Set-Content $Config $ConfigContent
    }

    function Get-USMT {
        # Test that USMT binaries are reachable
        $Script:USMT = '\\server\path\to\USMT'
        if (Test-Path $USMT) {
            $Script:ScanState =  "$USMT\scanstate.exe"
            $Script:LoadState =  "$USMT\loadstate.exe"
        } else {
            Read-Host 'Unable to reach USMT share - exiting'
            exit
        }
    }

    function Get-USMTResults {
        Write-Progress -Activity 'Migration Assistant' -Status 'Complete' -Completed

        if ($PSVersionTable.PSVersion.Major -lt 3) {
            Get-Content "$Destination\$ActionType.log"
        } else {
            Get-Content "$Destination\$ActionType.log" -Tail 4 | ForEach-Object { ($_.Split(']', 2)[1]).TrimStart() }
        }

        Read-Host 'Press [Enter] to exit.'
    }

    function Get-USMTProgress {
        try {
            # Get the most recent entry in the progress log
            $LastLine = Get-Content "$Destination\$(ActionType)_progress.log" -Tail 1 -ErrorAction SilentlyContinue | Out-String
            $Script:Progress = ($LastLine.Split(',', 4)[3]).TrimStart() 
        } catch { $Script:Progress = '' }
    }

    function Save-UserState {
        # Get the new computer and make sure it's reachable
        $NewComputer = Read-Host 'Enter the name or IP of the new computer'
        Write-Progress -Activity 'Migration Assistant' -Status "Testing connection to $NewComputer..."
        while (-not (Test-Connection $NewComputer -Quiet -Count 3)) {
            Write-Warning "Unable to reach $NewComputer. Make sure it's connected to the network or try its IP."
            Start-Sleep -Seconds 1
            $NewComputer = Read-Host 'Enter the name or IP of the new computer'
            Write-Progress -Activity 'Migration Assistant' -Status "Testing connection to $NewComputer..."
        }

        # Get the user profile to save
        Write-Progress -Activity 'Migration Assistant' -Status 'Getting user profile...'
        $User = (Get-UserProfile).PSChildName

        # Create migration store destination folder on new computer
        New-Item "\\$NewComputer\C$\MigrationStore" -ItemType Directory -Force | Out-Null
        $Script:Destination = "\\$NewComputer\C$\MigrationStore\$env:COMPUTERNAME"
        New-Item $Destination -ItemType Directory -Force | Out-Null

        # Begin saving user state to new computer
        Write-Progress -Activity 'Migration Assistant' -Status "Saving state of $User to $NewComputer..."
        Set-Config
        $Logs = "/l:$Destination\scan.log /progress:$Destination\scan_progress.log"
        # Overwrite existing save state, use volume shadow copy method, exclude all but the selected user
        $Arguments = "$Destination /i:$Config /o /vsc /ue:*\* /ui:$User $Logs"
        Start-Process -FilePath $ScanState -ArgumentList $Arguments -Verb RunAs
        # Give the process time to start before checking for its existence
        Start-Sleep -Seconds 3

        # Wait until the save state is complete
        $ScanProcess = Get-Process -Name scanstate
        while (-not $ScanProcess.HasExited) {
            Get-USMTProgress
            Write-Progress -Activity 'Migration Assistant' -Status "Saving state of $User to $NewComputer..." -CurrentOperation $Progress
            Start-Sleep -Seconds 3
        }
    }

    function Load-UserState {
        # Use the migration folder name to get the old computer name
        $Script:MigrationStore = 'C:\MigrationStore'
        if (Test-Path $MigrationStore) {
            $OldComputer = (Get-ChildItem $MigrationStore | Where-Object { $_.PSIsContainer } | 
                Sort-Object { CreationTime -desc } | Select-Object -First 1 ).BaseName
        } else {
            Read-Host 'No saved state found. Press [Enter] to exit'
            exit
        }

        # Get the location of the save state
        $Script:Destination = "$MigrationStore\$OldComputer"

        Write-Progress -Activity 'Migration Assistant' -Status "Testing connection to $OldComputer..."
        while (-not (Test-Connection $OldComputer -Quiet -Count 3)) {
            # Give user option to retry with a new computer name or skip
            Write-Warning "Unable to reach $OldComputer. Make sure it's connected to the network or try its IP."
            $Retry = Read-YesOrNo 'If save state process has already been completed you can safely skip this. How do you want to proceed (retry/skip)?'
            if ($Retry) {
                # Give user a chance to try entering the computer's IP or another name
                $OldComputer = Read-Host 'Enter the name or IP of the old computer'
                Write-Progress -Activity 'Migration Assistant' -Status "Testing connection to $OldComputer..."
            } else { break } 
        }

        if ($Retry) {
            # Check in with the old computer and don't start until the save is complete
            if (Get-Process -Name scanstate -ComputerName $OldComputer -ErrorAction SilentlyContinue) {
                Write-Progress -Activity 'Migration Assistant' -Status "Waiting on $OldComputer to complete save state..."
                while (Get-Process -Name scanstate -ComputerName $OldComputer -ErrorAction SilentlyContinue) {
                    Get-USMTProgress
                    Write-Progress -Activity 'Migration Assistant' -Status "Waiting on $OldComputer to complete save state..." -CurrentOperation $Progress
                    Start-Sleep -Seconds 1
                }
            }
        }

        # Begin loading user state to this computer
        Write-Progress -Activity 'Migration Assistant' -Status "Loading state..."
        $Logs = "/l:$Destination\load.log /progress:$Destination\load_progress.log"
        $Arguments = "$Destination /i:$Destination\Config.xml $Logs"
        Start-Process -FilePath $LoadState -ArgumentList $Arguments -Verb RunAs
        # Give the process time to start before checking for its existence
        Start-Sleep -Seconds 3

        # Wait until the load state is complete
        $LoadProcess = Get-Process -Name loadstate
        while (-not $LoadProcess.HasExited) {
            Get-USMTProgress
            Write-Progress -Activity 'Migration Assistant' -Status "Loading state..." -CurrentOperation $Progress
            Start-Sleep -Seconds 1
        }

        # Sometimes loadstate will kill the explorer task and it needs to be start again manually
        if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer }
    }
}

process {
    # Test if user is using a admin account
    Test-UserAdmin

    # Get the path to the network USMT files
    Get-USMT

    # Ask if we're saving or loading user state
    $Computer = Read-Host 'Which computer is this (old/new)?'
    while('old', 'new' -notcontains $Computer) {
    	$Computer = Read-Host 'Which computer is this (old/new)?'
    }

    if ($Computer -eq 'old') { 
        Save-UserState 
        $Script:ActionType = 'scan'
    } else { 
        Load-UserState
        $Script:ActionType = 'load'
    }
}

end {
    # Give us the results
    Get-USMTResults

    # If we just finished loading, delete the save state
    if ($ActionType -eq 'load') { Get-ChildItem $MigrationStore | Remove-Item -Recurse }
}