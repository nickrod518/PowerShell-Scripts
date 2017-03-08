# These 3 lines get the Documents site from SPO for the specified user
$webUrl = "https://company-my.sharepoint.com/personal/company"
$clientContext = New-Object Microsoft.SharePoint.Client.ClientContext($webUrl)
$list = $clientContext.Web.Lists.GetByTitle("Documents")
 
# reset the value to the default settings
$list.InformationRightsManagementSettings.Reset()
# disable IRM
$list.IrmEnabled = $false