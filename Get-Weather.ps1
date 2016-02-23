$UtilityName = 'Archaic Weather Gathering Utility - Nick Rodriguez'

# Default values
$City = 'Asheville'
$Country = 'United States'
$ZipCode = '28803'
$Days = '6'

Function Get-Weather {
    param([string]$City, [string]$Country)
    $webservice = New-WebServiceProxy -Uri 'http://www.webservicex.net/globalweather.asmx?WSDL'
    $CurrentWeather = ([xml]$webservice.GetWeather($City, $Country)).CurrentWeather
	return $CurrentWeather
}

Function Get-Forecast {
	Param([string]$ZipCode, [int]$Days)
	$URI = 'http://www.weather.gov/forecasts/xml/DWMLgen/wsdl/ndfdXML.wsdl'
	$Proxy = New-WebServiceProxy -uri $URI -namespace WebServiceProxy
	[xml]$latlon=$proxy.LatLonListZipCode($ZipCode)
	$Forecast = foreach($l in $latlon) {
		$a = $l.dwml.latlonlist -split ","
		$lat = $a[0]
		$lon = $a[1]
		$sDate = get-date -UFormat %Y-%m-%d
		$format = "Item24hourly"
		[xml]$weather = $Proxy.NDFDgenByDay($lat,$lon,$sDate,$Days,'e',$format)
		For($i = 0 ; $i -le $Days -1 ; $i ++) {
			New-Object psObject -Property @{
				"Date" = ((Get-Date).addDays($i)).tostring("MM/dd/yyyy") ;
				"maxTemp" = $weather.dwml.data.parameters.temperature[0].value[$i] ;
				"minTemp" = $weather.dwml.data.parameters.temperature[1].value[$i] ;
				"Summary" = $weather.dwml.data.parameters.weather."weather-conditions"[$i]."Weather-summary"
			}
		}
	}

	return $Forecast | Format-Table -Property date, maxTemp, minTemp, Summary -AutoSize
}

Function LoadMenuSystem {
	[INT]$MenuLevel1=0
	[INT]$xMenuLevel2=0
	[BOOLEAN]$xValidSelection=$false
	while ( $MenuLevel1 -lt 1 -or $MenuLevel1 -gt 3 ) {
		CLS
		#… Present the Menu Options
		Write-Host "`n`t$UtilityName`n" -ForegroundColor Magenta
		Write-Host "`t`tPlease select an option`n" -Fore Cyan
		Write-Host "`t`t`t1. Current Weather" -Fore Cyan
		Write-Host "`t`t`t2. Forecast" -Fore Cyan
		Write-Host "`t`t`t3. Exit`n" -Fore Cyan
		#… Retrieve the response from the user
		[int]$MenuLevel1 = Read-Host "`t`tEnter Menu Option Number"
		if( $MenuLevel1 -lt 1 -or $MenuLevel1 -gt 3 ) {
			Write-Host "`tPlease select one of the options available.`n" -Fore Red; Start-Sleep -Seconds 1
		}
	}
	Switch ($MenuLevel1){    #… User has selected a valid entry.. load next menu
		1 {
			while ( $xMenuLevel2 -lt 1 -or $xMenuLevel2 -gt 4 ) {
				CLS
				# Present the Menu Options
				Write-Host "`n`t$UtilityName`n" -Fore Magenta
				Write-Host "`t`tCurrent weather for $City, $Country`n" -Fore Cyan
				Write-Host "`t`t`t1. Refresh" -Fore Cyan
				Write-Host "`t`t`t2. Change City" -Fore Cyan
				Write-Host "`t`t`t3. Change Country" -Fore Cyan
				Write-Host "`t`t`t4. Go to Main Menu`n" -Fore Cyan
				[int]$xMenuLevel2 = Read-Host "`t`tEnter Menu Option Number"
				if( $xMenuLevel2 -lt 1 -or $xMenuLevel2 -gt 4 ) {
					Write-Host "`tPlease select one of the options available.`n" -Fore Red; Start-Sleep -Seconds 1
				}
			}
			Switch ($xMenuLevel2) {
				1{ Get-Weather $City $Country; pause }
				2{ $City = Read-Host "`n`tEnter a city name" }
				3{ $Country = Read-Host "`n`tEnter a country name" }
				default { break}
			}
		}
		2 {
			while ( $xMenuLevel2 -lt 1 -or $xMenuLevel2 -gt 4 ) {
				CLS
				# Present the Menu Options
				Write-Host "`n`t$UtilityName`n" -Fore Magenta
				Write-Host "`t`t$Days day forecast for area code $ZipCode`n" -Fore Cyan
				Write-Host "`t`t`t1. Refresh" -Fore Cyan
				Write-Host "`t`t`t2. Change Zip Code" -Fore Cyan
				Write-Host "`t`t`t3. Change Number of Days" -Fore Cyan
				Write-Host "`t`t`t4. Go to Main Menu`n" -Fore Cyan
				[int]$xMenuLevel2 = Read-Host "`t`tEnter Menu Option Number"
			}
			if( $xMenuLevel2 -lt 1 -or $xMenuLevel2 -gt 4 ){
				Write-Host "`tPlease select one of the options available.`n" -Fore Red; Start-Sleep -Seconds 1
			}
			Switch ($xMenuLevel2) {
				1{ Get-Forecast $ZipCode $Days; pause }
				2{ $ZipCode = Read-Host "`n`tEnter a zip code" }
				3{ $Days = Read-Host "`n`tEnter the number of days to forecast" }
				default { break}
			}
		}
		default { exit }
	}

	LoadMenuSystem
}

LoadMenuSystem