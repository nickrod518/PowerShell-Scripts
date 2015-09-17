function UpgradeApp {
    <#
    .SYNOPSIS
    Upgrade the version of an application.
    .DESCRIPTION
    The function will uninstall old versions of the application either by name or GUID, and install the new version. If the application is running already, there will be a user prompt and the application will restart upon completion.
    .EXAMPLE
    Upgrade BigCompany app using an exe, a configuration profile to include, and providing 2 processes to check for:
    UpgradeApp -oldAppName "BigCompany" -AppProcesses @("BCApp1", "BCApp2") -installer ".\installDir\BigCompany2.0.exe" -config @(".\installDir\profile.xml", "$env:AppData\BCApp\profile.xml")
    .EXAMPLE
    Upgrade BigCompany app using an msi:
    UpgradeApp -oldAppName "BigCompany" -installer ".\installDir\BigCompany2.0.exe"
    .PARAMETER GUIDUninstall
    False by default. Uninstall by providing a name that would appear as a valid installed Win32_Product. Set to True to uninstall by providing GUIDs.
    .PARAMETER oldGUIDs
    If you are set GUIDUninstall to True, provide a string array of GUIDs to uninstall. Include the curly braces and dashes in the GUID name.
    .PARAMETER oldAppName
    The name of the old application as it would appear in Add Remove Programs
    .PARAMETER AppProcesses
    Some appications will not uninstall or install if they are currently running. Provide any process names as they would appear in Task Manager (without the ".exe").
    .PARAMETER installer
    The path to the msi or exe installer.
    .PARAMETER config
    If there is a config file you would like to provide, give a string array with source and destination here.
    #>

    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [bool]$GUIDUninstall = $false,
        [string[]]$oldGUIDs,
        [string]$oldAppName,
        [string[]]$AppProcesses = $null,
        [string]$installer,
        [string[]]$config = $null
    )

    # see if app processes are running in the background
    $running = $false
    if ($AppProcesses) {
        foreach ($AppProcess in $AppProcesses) {
            if (Get-Process $AppProcess -ErrorAction SilentlyContinue) { $running = $true }
        }
    }

    # process not found
    if (!$running) {

        if ($GUIDUninstall) {
            # loop through and uninstall each GUID
            foreach ($oldAppGUID in $oldAppGUIDS) {
                Start-Process msiexec -Wait -ArgumentList "/qn /x $oldAppGUID"
            }
        } else {
            # uninstall via app name
            $oldApp = Get-WmiObject -Class Win32_Product -Filter "Name=$oldAppName"
            $oldApp.Uninstall()
        }

        # install the new app either via msi or exe using quiet flags
        $installerExt = (Get-Item $installer).extension
        if ($installerExt -eq '.msi') {
            Start-Process msiexec -Wait -ArgumentList "/qn /i $installer"
        } else {
            Start-Process $installer -Wait -ArgumentList "/qn"
        }

        # copy over any config file that would make deployment more easy
        # create a blank file where the config goes to insure the full path is created first
        if ($config) {
            $destination = $config[1]
            New-Item -ItemType File -Path $destination -Force
            Copy-Item $config[0] $destination -Force
        }

    # process found
    } else {

        # ask the user how to proceed
        $ready = [System.Windows.Forms.MessageBox]::Show(
            "Installation cannot continue because [Application] is currently running. Press `"OK`" to automatically close the [Application] and continue with the upgrade or press `"Cancel`" to try again later",
            "Application Upgrade", 1)

        if ($ready -eq "OK") {
            # kill the processes
            if ($appProcesses) {
                foreach ($AppProcess in $AppProcesses) {
                    Stop-Process -ProcessName $AppProcess -Force -ErrorAction SilentlyContinue
                }
            }

            # give the processes 5 seconds to die
            Start-Sleep -s 5

            # try again
            UpgradeApp
        } elseif ($ready -eq "Cancel") {
            # abort
            exit 999
        }
    }

    exit 0
}
