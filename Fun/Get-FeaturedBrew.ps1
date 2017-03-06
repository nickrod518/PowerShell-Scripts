# http://www.brewerydb.com/developers/docs
$BreweryDB = 'http://api.brewerydb.com/v2'
$APIKey = 'cd4f34c5b35a1a2c4c76dcad8c5253bc'
$Request = 'features'

$Result = Invoke-RestMethod -Method Get -Uri "$BreweryDB/$Request/?key=$APIKey" -ContentType 'application/json'
$Result.data | Select-Object Brewery, Beer | ForEach-Object {
    New-Object -TypeName psobject -Property @{
        BreweryName = $_.Brewery.Name
        #BreweryDescription = $_.Brewery.Description
        BeerName = $_.Beer.Name
        #BeerDescription = $_.Beer.Description
    }
} | Out-GridView
