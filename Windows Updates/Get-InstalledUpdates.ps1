Function Get-InstalledUpdates($title) {
    $UpdateSession = New-Object -ComObject Microsoft.Update.Session 
    $SearchResult = $null
    $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
    $UpdateSearcher.Online = $true
    $SearchResult = $UpdateSearcher.Search("IsInstalled=1 and Type='Software'") 

    $i = 1
    foreach($Update in $SearchResult.Updates)
    {
	    If ($Update.Title -like "*$title*") {
        Write-Host "$i) $($Update.Title + " | " + $Update.SecurityBulletinIDs)"
        $i += 1
        }
    }
}

cls

Get-InstalledUpdates("Lync")