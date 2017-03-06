function Copy-SPOList {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SiteUrl,

        [Parameter(Mandatory = $true)]
        [string]$SourceListName,

        [Parameter(Mandatory = $true)]
        [string]$DestinationListName
    )

    Import-Module .\OneDrive.psm1
    Import-SharePointClientComponents

    $Context = New-Object Microsoft.SharePoint.Client.ClientContext($SiteUrl)
    $Creds = Get-Credential
    $SPOCreds = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($Creds.UserName, $Creds.Password)
    $Context.Credentials = $SPOCreds

    $SourceList = $Context.Web.Lists.GetByTitle($SourceListName)
    $DestinationList = $Context.Web.Lists.GetByTitle($DestinationListName)
    $ItemsToCopy = $SourceList.GetItems([Microsoft.SharePoint.Client.CamlQuery]::CreateAllItemsQuery())
    $Fields = $SourceList.Fields

    Write-Progress -Activity "Gathering all items from $SourceListName..."
    $Context.Load($ItemsToCopy)
    $Context.Load($SourceList)
    $Context.Load($DestinationList)
    $Context.Load($Fields)
    $Context.ExecuteQuery()

    $Count = $ItemsToCopy.Count
    $Counter = 0

    foreach ($Item in $ItemsToCopy) {
        $Counter++

        $SPOItem = New-Object -TypeName psobject
        $SPOItem | Add-Member -Name ID -MemberType NoteProperty -Value $Item.ID

	    Write-Progress -Activity "Copying items from $SourceListName to $DestinationListName" `
            -Status "Item $Counter of $Count - $($SPOItem.ID)" -PercentComplete (($Counter / $Count) * 100)

        $ListItemInfo = New-Object Microsoft.SharePoint.Client.ListItemCreationInformation
        $NewItem = $DestinationList.AddItem($ListItemInfo)

        foreach ($Field in $Fields) {
            if (
                (-Not ($Field.ReadOnlyField)) -and 
                (-Not ($Field.Hidden)) -and 
                ($Field.InternalName -ne  "Attachments") -and 
                ($Field.InternalName -ne "ContentType")
            ) {
                $SPOItem | Add-Member -Name $Field.InternalName -MemberType NoteProperty -Value $Item[$Field.InternalName]
                $NewItem[$Field.InternalName] = $Item[$Field.InternalName]
                $NewItem.update()
            }
        }

        $SPOItem

        $Context.ExecuteQuery()
    }
}