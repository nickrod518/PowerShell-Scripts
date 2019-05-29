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
    foreach ($RetiringApp in $RetiringApps) {
        if ($RetiringApp = Get-CMApplication -Name $RetiringApp) {
            Write-Host "So long, $RetiringApp!"

            # checking retired status, setting to active so that we can make changes
            if ($RetiringApp.IsExpired) {
                $RetiringAppWMI = gwmi -Namespace Root\SMS\Site_$PSD -class SMS_ApplicationLatest -Filter "LocalizedDisplayName = '$RetiringApp'"
                $RetiringAppWMI.SetIsExpired($false) | Out-Null
                Write-Host "Setting Status of $RetiringApp to Active so that changes can be made."
            }

            $oldDeploys = Get-CMDeployment -SoftwareName $RetiringApp.LocalizedDisplayName

            # remove all deployments for the app
            if ($oldDeploys) {
                $oldDeploys | ForEach-Object {
                    Remove-CMDeployment -ApplicationName $RetiringApp -DeploymentId $_.DeploymentID -Force
                }
                Write-Host "Removed $($oldDeploys.Count) deployments of $RetiringApp."
            }

            # remove content from all dp's and dpg's
            Write-Host -NoNewline "Removing content from all distribution points"
            $DPs = Get-CMDistributionPoint -AllSite
            foreach ($DP in $DPs)
            {
                $dpNetworkOSPath = $dp.NetworkOSPath #TODO: unify 2 variables
                $dpName = ($dp.NetworkOSPath).Substring(2,$dpNetworkOSPath.Length-2)
                Write-Host -NoNewline "."
                try
                {
                    Remove-CMContentDistribution -ApplicationName "$RetiringApp" -DistributionPointName $dpName -Force -EA SilentlyContinue
                }
                catch { }
            }
            Write-Host
            Write-Host -NoNewline "Removing content from all distribution point groups"
            $DPGs = Get-CMDistributionPointGroup
            foreach ($DPG in $DPGs) {
                Write-Host -NoNewline "."
                try {
                    Remove-CMContentDistribution -ApplicationName $RetiringApp -DistributionPointGroupName ($DPG).Name -Force -EA SilentlyContinue
                } catch { }
            }
            Write-Host

            # rename the app
            $RetiringApp = $RetiringApp.Replace('Retired-', '')
            try {
                Set-CMApplication -Name $RetiringApp -NewName "Retired-$RetiringApp"
            } catch { }
            Write-Host "Renamed to Retired-$RetiringApp."

            # move the app according to category
            if ($RetiringApp.LocalizedCategoryInstanceNames -eq "Mac") {
                Move-CMObject -FolderPath "Application\Retired" -InputObject $RetiringApp
                Write-Host "Moved to Retired."
            } else {
                Move-CMObject -FolderPath "Application\Retired" -InputObject $RetiringApp
                Write-Host "Moved to Retired."
            }

            # retire the app
            if (!$RetiringApp.IsExpired) {
                $RetiringAppWMI = gwmi -Namespace Root\SMS\Site_$PSD -class SMS_ApplicationLatest -Filter "LocalizedDisplayName = 'Retired-$RetiringApp'"
                $RetiringAppWMI.SetIsExpired($true) | Out-Null
                Write-Host "Set status to Retired."
            } else {
                Write-Host "Status was already set to Retired."
            }

            # return source files location
            $xml = [xml]$RetiringApp.SDMPackageXML
            $loc = $xml.AppMgmtDigest.DeploymentType.Installer.Contents.Content.Location
            Write-Host "Don't forget to delete the source files from $loc."

        } else {
            Write-Host "$RetiringApp was not found. No actions performed."
        }
    }
}
