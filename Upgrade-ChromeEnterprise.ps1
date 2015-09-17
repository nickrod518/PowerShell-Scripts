function Upgrade-ChromeEnterprise {
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null

    # see if app processes are running in the background
    $running = $false
    if (Get-Process "chrome" -ErrorAction SilentlyContinue) { $running = $true }

    # process not found
    if (!$running) {

        $installed = $true
        $x86Path = "C:\Program Files (x86)\Google\Chrome\Application"
        $x64Path = "C:\Program Files\Google\Chrome\Application"

        if (Test-Path $x86Path) {
            $chrome = (Get-ChildItem -Directory $x86Path).FullName
        } elseif (Test-Path $x64Path) {
            $chrome = (Get-ChildItem -Directory $x64Path).FullName
        } else {
            $installed = $false
        }

        # uninstall previous versions of chrome
        if ($installed) {
            $uninstallArgs = "--uninstall --multi-install --chrome --system-level --force-uninstall"
            Start-Process "$chrome\Installer\setup.exe" -Args $uninstallArgs -PassThru -Wait
        }

        # install the new app either via msi using quiet flags
        $installArgs = "/qn /i googlechromestandaloneenterprise.msi /norestart /log C:\FTG\Logs\GoogleChromeEnterprise.log"
        $install = Start-Process msiexec -PassThru -Wait -Args $installArgs
        $CMExitCode = $install.ExitCode

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
            "Installation cannot continue because Chrome is currently running. Press `"OK`" to automatically close Chrome and continue with the upgrade or press `"Cancel`" to try again later",
            "Google Chrome Enterprise Install", 1)

        if ($ready -eq "OK") {
            # kill the process
            Stop-Process -ProcessName "chrome" -Force -ErrorAction SilentlyContinue

            # give the processes 5 seconds to die
            Start-Sleep -s 5

            # try again
            Upgrade-ChromeEnterprise
        } elseif ($ready -eq "Cancel") {
            # abort
            exit 999
        }
    }

    exit $CMExitCode
}
Upgrade-ChromeEnterprise
