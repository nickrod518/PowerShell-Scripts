#Requires -Version 3

$UtilityName = 'Archaic Weather Gathering Utility - Nick Rodriguez'

# Default values
$City = 'Asheville'
$Country = 'United States'
$ZipCode = '28803'
$Days = '6'

function Get-Weather {
    param(
		[Parameter(Mandatory = $true)]
		[string]$City,
		
		[Parameter(Mandatory = $true)]
		[string]$Country
	)

    $WebService = New-WebServiceProxy -Uri 'http://www.webservicex.net/globalweather.asmx?WSDL'
    return ([xml]$WebService.GetWeather($City, $Country)).CurrentWeather
}

function Get-Forecast {
	param(
		[Parameter(Mandatory = $true)]
		[string]$ZipCode,

		[Parameter(Mandatory = $true)] 
		[int]$Days
	)

	$URI = 'http://www.weather.gov/forecasts/xml/DWMLgen/wsdl/ndfdXML.wsdl'
	$Proxy = New-WebServiceProxy -uri $URI -namespace WebServiceProxy
    $LatLonList = ([xml]$Proxy.LatLonListZipCode($ZipCode)).dwml.LatLonlist -split ','
	$Lat = $LatLonList[0]
	$Lon = $LatLonList[1]
	$Date = Get-Date -UFormat %Y-%m-%d
	$Format = "Item24hourly"
	[xml]$Weather = $Proxy.NDFDgenByDay($Lat, $Lon, $Date, $Days, 'e', $Format)


	$Forecast = for ($Day = 0; $Day -le $Days - 1; $Day ++) {
		New-Object PSObject -Property @{
			Date = ((Get-Date).AddDays($i)).ToString("MM/dd/yyyy") ;
			MaxTemp = $Weather.dwml.data.parameters.temperature[0].Value[$Day] ;
			MinTemp = $Weather.dwml.data.parameters.temperature[1].Value[$Day] ;
			Summary = $Weather.dwml.data.parameters.weather."weather-conditions"[$Day]."Weather-summary"
		}
	}

	return $Forecast | Format-Table -Property Date, MaxTemp, MinTemp, Summary -AutoSize
}

function Load-MenuSystem {
	[int]$MenuLevel1 = 0
	[int]$MenuLevel2 = 0
	[boolean]$xValidSelection = $false

	while ($MenuLevel1 -lt 1 -or $MenuLevel1 -gt 3) {
		Clear-Host

		# Present the Menu Options
		Write-Host "`n`t$UtilityName`n" -ForegroundColor Magenta
		Write-Host "`t`tPlease select an option`n" -ForegroundColor Cyan
		Write-Host "`t`t`t1. Current Weather" -ForegroundColor Cyan
		Write-Host "`t`t`t2. Forecast" -ForegroundColor Cyan
		Write-Host "`t`t`t3. Exit`n" -ForegroundColor Cyan
		# Retrieve the response from the user
		[int]$MenuLevel1 = Read-Host "`t`tEnter Menu Option Number"
		if ( $MenuLevel1 -lt 1 -or $MenuLevel1 -gt 3 ) {
			Write-Host "`tPlease select one of the options available.`n" -ForegroundColor Red
			Start-Sleep -Seconds 1
		}
	}

	switch ($MenuLevel1){    # User has selected a valid entry.. load next menu
		1 {
			while ($MenuLevel2 -lt 1 -or $MenuLevel2 -gt 4) {
				Clear-Host

				# Present the Menu Options
				Write-Host "`n`t$UtilityName`n" -ForegroundColor Magenta
				Write-Host "`t`tCurrent weather for $City, $Country`n" -ForegroundColor Cyan
				Write-Host "`t`t`t1. Refresh" -ForegroundColor Cyan
				Write-Host "`t`t`t2. Change City" -ForegroundColor Cyan
				Write-Host "`t`t`t3. Change Country" -ForegroundColor Cyan
				Write-Host "`t`t`t4. Go to Main Menu`n" -ForegroundColor Cyan
				[int]$MenuLevel2 = Read-Host "`t`tEnter Menu Option Number"
				if( $MenuLevel2 -lt 1 -or $MenuLevel2 -gt 4 ) {
					Write-Host "`tPlease select one of the options available.`n" -ForegroundColor Red
					Start-Sleep -Seconds 1
				}
			}
			switch ($MenuLevel2) {
				1 { 
					Get-Weather $City $Country
					pause
				}
				2 { $City = Read-Host "`n`tEnter a city name" }
				3 { $Country = Read-Host "`n`tEnter a country name" }
				default { break }
			}
		}

		2 {
			while ($MenuLevel2 -lt 1 -or $MenuLevel2 -gt 4) {
				Clear-Host

				# Present the Menu Options
				Write-Host "`n`t$UtilityName`n" -Fore Magenta
				Write-Host "`t`t$Days day forecast for area code $ZipCode`n" -Fore Cyan
				Write-Host "`t`t`t1. Refresh" -Fore Cyan
				Write-Host "`t`t`t2. Change Zip Code" -Fore Cyan
				Write-Host "`t`t`t3. Change Number of Days" -Fore Cyan
				Write-Host "`t`t`t4. Go to Main Menu`n" -Fore Cyan
				[int]$MenuLevel2 = Read-Host "`t`tEnter Menu Option Number"
			}
			if( $MenuLevel2 -lt 1 -or $MenuLevel2 -gt 4 ){
				Write-Host "`tPlease select one of the options available.`n" -Fore Red; Start-Sleep -Seconds 1
			}
			Switch ($MenuLevel2) {
				1 { 
					Get-Forecast $ZipCode $Days
					pause 
				}
				2 { $ZipCode = Read-Host "`n`tEnter a zip code" }
				3 { $Days = Read-Host "`n`tEnter the number of days to forecast" }
				default { break }
			}
		}

		default { exit }
	}

	Load-MenuSystem
}

Load-MenuSystem