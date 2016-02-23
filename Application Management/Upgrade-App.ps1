[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null

$scriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent

# installer msi (must be located in same folder as this script)
$installer = "newapp.msi"

# name of app as it will appear in msgbox to user (may want to check for grammar mistakes where it's called)
$appName = "New Application"

# processes to watch
$processes = @("proc1", "proc2")

# old GUIDs
$oldGUIDs = @(
"{abs-guid-id1}",
"{abs-guid-id2}",
"{abs-guid-id3}"
)

Function Upgrade-App {
    # see if processes are running in the background
    $running = $false
    foreach ($process in $processes) {
        if (Get-Process $process -ErrorAction SilentlyContinue) { $running = $true }
    }

    # process not found
    if (!$running) {

        # loop through and uninstall each GUID
        foreach ($oldGUID in $oldGUIDs) {
            $uninstallArgs = "/qn /x $oldGUID /norestart"
            Start-Process msiexec -Args $uninstallArgs -Wait
        }

        # workaround to get psscriptroot to work in ps versions older than 3
        if ($PSVersionTable.PSVersion.Major -lt 3) {
            $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
        }

        # install the new app using an msi
        $installArgs = "/qn /i $Script:scriptPath\$installer /norestart /l*v C:\Logs\$($appName.Replace(' ', '_')).log"
        $install = Start-Process msiexec -PassThru -Wait -Args $installArgs

        <# install the new app using an exe
        $installArgs = "/qn"
        $install = Start-Process $installer -Wait -ArgumentList $installArgs
        #>

        # save exit code in case install fails
        $CMExitCode = $install.ExitCode

        # do post install stuff here
        <# example of copying config file
        $destination = "$env:ProgramData\app\DHG.xml"
        New-Item -ItemType File -Path $destination -Force
        Copy-Item "DHG.xml" $destination -Force
        #>
        <# example of installing regkey
        New-ItemProperty -Path "HKCU:\Software\app" -Name "new name" -Value "new value" -Type 'String' -Force
        #>

    # process found
    } else {

        # in two seconds, bring the msgbox we create to focus
        Invoke-Command -ScriptBlock {
            Start-Sleep 2
            [void] [System.Reflection.Assembly]::LoadWithPartialName("'Microsoft.VisualBasic")
            $msg = Get-Process | Where-Object {$_.Name -like "powershell"}
            [Microsoft.VisualBasic.Interaction]::AppActivate($msg.ID)
        }

        # ask the user how to proceed
        $ready = [System.Windows.Forms.MessageBox]::Show(
            "Installation cannot continue because $appName is currently running. Press `"OK`" to automatically close $appName and continue with the upgrade or press `"Cancel`" to try again later",
            "$appName Install", 1)

        if ($ready -eq "OK") {
            # kill the processes
            foreach ($process in $processes) {
                Stop-Process -ProcessName $process -Force -ErrorAction SilentlyContinue
            }

            # give the processes 5 seconds to die
            Start-Sleep -s 5

            # try again
            Upgrade-App
        } elseif ($ready -eq "Cancel") {
            # abort
            exit 999
        }
    }

    exit $CMExitCode
}

Upgrade-App
