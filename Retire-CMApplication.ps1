function Retire-CMApplication {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $RetiringApps = @()
    )

    # import cm module
    Import-Module ($Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5) + '\ConfigurationManager.psd1')

    # change to the cm site drive
    $PSD = Get-PSDrive -PSProvider CMSite
    cd "$($PSD):"

    # for each provided app name, remove deployments, rename, and retire
    foreach ($app in $RetiringApps) {
        if ($RetiringApp = Get-CMApplication -Name $app) {
            Write-Host "So long, $app!"

            # checking retired status, setting to active so that we can make changes
            if ($RetiringApp.IsExpired) {
                $appWMI = gwmi -Namespace Root\SMS\Site_$PSD -class SMS_ApplicationLatest -Filter "LocalizedDisplayName = '$app'"
                $appWMI.SetIsExpired($false) | Out-Null
                Write-Host "Setting Status of $app to Active so that changes can be made."
            }

            $oldDeploys = Get-CMDeployment -SoftwareName $RetiringApp.LocalizedDisplayName

            # remove all deployments for the app
            if ($oldDeploys) {
                $oldDeploys | ForEach-Object {
                    Remove-CMDeployment -ApplicationName $app -DeploymentId $_.DeploymentID -Force
                }
                Write-Host "Removed $($oldDeploys.Count) deployments of $app."
            }

            # remove content from all dp's and dpg's
            Write-Host -NoNewline "Removing content from all distribution points"
            $DPs = Get-CMDistributionPoint
            foreach ($DP in $DPs) {
                Write-Host -NoNewline "."
                try {
                    Remove-CMContentDistribution -Application $RetiringApp -DistributionPointName ($DP).NetworkOSPath -Force -EA SilentlyContinue
                } catch { }
            }
            Write-Host
            Write-Host -NoNewline "Removing content from all distribution point groups"
            $DPGs = Get-CMDistributionPointGroup
            foreach ($DPG in $DPGs) {
                Write-Host -NoNewline "."
                try {
                    Remove-CMContentDistribution -Application $RetiringApp -DistributionPointGroupName ($DPG).Name -Force -EA SilentlyContinue
                } catch { }
            }
            Write-Host

            # rename the app
            $app = $app.Replace('Retired-', '')
            try {
                Set-CMApplication -Name $app -NewName "Retired-$app"
            } catch { }
            Write-Host "Renamed to Retired-$app."

            # move the app according to category
            if ($RetiringApp.LocalizedCategoryInstanceNames -eq "Mac") {
                Move-CMObject -FolderPath "Application\Mac\Retired Applications" -InputObject $RetiringApp
                Write-Host "Moved to Mac\Retired Applications."
            } else {
                Move-CMObject -FolderPath "Application\zRetired Applications" -InputObject $RetiringApp
                Write-Host "Moved to zRetired Applications."
            }

            # retire the app
            if (!$RetiringApp.IsExpired) {
                $appWMI = gwmi -Namespace Root\SMS\Site_$PSD -class SMS_ApplicationLatest -Filter "LocalizedDisplayName = 'Retired-$app'"
                $appWMI.SetIsExpired($true) | Out-Null
                Write-Host "Set status to Retired."
            } else {
                Write-Host "Status was already set to Retired."
            }

            # return source files location
            $xml = [xml]$RetiringApp.SDMPackageXML
            $loc = $xml.AppMgmtDigest.DeploymentType.Installer.Contents.Content.Location
            Write-Host "Don't forget to delete the source files from $loc."

        } else {
            Write-Host "$app was not found. No actions performed."
        }
    }
}
