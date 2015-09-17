function Retire-CMApplication {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $RetiringApps = @()
    )

    # import cm module
    Import-Module 'C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1'

    # change to the cm site drive
    $PSD = Get-PSDrive -PSProvider CMSite
    cd "$($PSD):"

    # for each provided app name, remove deployments, rename, and retire
    foreach ($app in $RetiringApps) {
        if ($RetiringApp = Get-CMApplication -Name $app) {
            $oldDeploys = Get-CMDeployment -SoftwareName $RetiringApp.LocalizedDisplayName

            # remove all deployments for the app
            if ($oldDeploys) {
                $oldDeploys | ForEach-Object {
                    Remove-CMDeployment -ApplicationName $app -DeploymentId $_.DeploymentID -Force
                }
            }

            # remove content from all dp's and dpg's
            $DPs = Get-CMDistributionPoint
            foreach ($DP in $DPs) {
                Remove-CMContentDistribution -Application $RetiringApp -DistributionPointName ($DP).NetworkOSPath -Force -EA SilentlyContinue
            }
            $DPGs = Get-CMDistributionPointGroup
            foreach ($DPG in $DPGs) {
                Remove-CMContentDistribution -Application $RetiringApp -DistributionPointGroupName ($DPG).Name -Force -EA SilentlyContinue
            }

            # rename the app
            $app = $app.Replace('Retired-', '')
            Set-CMApplication -Name $app -NewName "Retired-$app"

            # move the app according to category
            if ($RetiringApp.LocalizedCategoryInstanceNames -eq "Mac") {
                Move-CMObject -FolderPath "Application\Mac\Retired Applications" -InputObject $RetiringApp
            } else {
                Move-CMObject -FolderPath "Application\Retired Applications" -InputObject $RetiringApp
            }

            # retire the app
            if (!$RetiringApp.IsExpired) {
                $appWMI = gwmi -Namespace Root\SMS\Site_$PSD -class SMS_ApplicationLatest -Filter "LocalizedDisplayName = 'Retired-$app'"
                $appWMI.SetIsExpired($true)
            }

        } else {
            Write-Host "$app was not found."
        }

        # return source files location
        $xml = [xml]$RetiringApp.SDMPackageXML
        $loc = $xml.AppMgmtDigest.DeploymentType.Installer.Contents.Content.Location
        Write-Host "Don't forget to delete the source files from $loc"
    }
}
