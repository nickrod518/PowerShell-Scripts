<#PSScriptInfo

.VERSION 2.0

.GUID a6048a09-3e66-467a-acd4-ce3e97098a65

.AUTHOR velecky@velecky.onmicrosoft.com modified by Nick Rodriguez

.PROJECTURI https://www.powershellgallery.com/packages/Speedtest/2.0

.DESCRIPTION
 WAN speed test

#>

[CmdletBinding()]
param(
    [int]$Repetitions = 4
)

function Invoke-SpeedTest {
    param(
        [string]$UploadUrl
    )

    $topServerUrlSpilt = $UploadUrl -split 'upload'
    $url = $topServerUrlSpilt[0] + 'random2000x2000.jpg'
    $col = New-Object System.Collections.Specialized.NameValueCollection
    $wc = New-Object System.Net.WebClient
    $wc.QueryString = $col
    $downloadElaspedTime = (Measure-Command { $webpage1 = $wc.DownloadData($url) }).TotalMilliseconds
    $downSize = ($webpage1.length + $webpage2.length) / 1MB
    $downloadSize = [Math]::Round($downSize, 2)
    $downloadTimeSec = $downloadElaspedTime * 0.001
    $downSpeed = ($downloadSize / $downloadTimeSec) * 8
    $downloadSpeed = [Math]::Round($downSpeed, 2)

    Write-Verbose "Downloaded $downloadSize MB in $downloadTimeSec seconds at a speed of $downloadSpeed mbps"

    return $downloadSpeed
}

# Interact with speedtest page avoiding api
$objXmlHttp = New-Object -ComObject MSXML2.ServerXMLHTTP
$objXmlHttp.Open("GET", "http://www.speedtest.net/speedtest-config.php", $False)
$objXmlHttp.Send()
[xml]$content = $objXmlHttp.responseText

# Select closest server based on lat/lon
$oriLat = $content.settings.client.lat
$oriLon = $content.settings.client.lon
Write-Verbose "Latitude: $oriLat"
Write-Verbose "Longitude: $oriLon"

# Make another request, this time to get the server list from the site
$objXmlHttp.Open("GET", "http://www.speedtest.net/speedtest-servers.php", $False)
$objXmlHttp.Send()
[xml]$ServerList = $objXmlHttp.responseText

# Cons contains all of the information about every server in the speedtest.net database
$cons = $ServerList.settings.servers.server

# Calculate servers relative closeness by doing math against latitude and longitude
Write-Verbose "Searching for closest geographical servers from list of $($cons.Count)..."
foreach ($val in $cons) {
    $R = 6371
    $pi = [Math]::PI

    [float]$dlat = ([float]$oriLat - [float]$val.lat) * $pi / 180
    [float]$dlon = ([float]$oriLon - [float]$val.lon) * $pi / 180
    [float]$a = [math]::Sin([float]$dLat / 2) * [math]::Sin([float]$dLat / 2) + [math]::Cos([float]$oriLat * $pi / 180 ) * [math]::Cos([float]$val.lat * $pi / 180 ) * [math]::Sin([float]$dLon / 2) * [math]::Sin([float]$dLon / 2)
    [float]$c = 2 * [math]::Atan2([math]::Sqrt([float]$a ), [math]::Sqrt(1 - [float]$a))
    [float]$d = [float]$R * [float]$c

    $serverInformation += @([pscustomobject]@{
        Distance = $d
        Country  = $val.country
        Sponsor  = $val.sponsor
        Url      = $val.url
    })
}

$serverInformation = $serverInformation | Sort-Object -Property distance

$speedResults = @()

for ($i = 0; $i -lt $Repetitions; $i++) {
    $url = $serverInformation[$i].url
    Write-Verbose "Download attempt ($($i + 1) of $Repetitions) from $url..."
    $speed = Invoke-SpeedTest $url
    $speedResults += $speed
}

$results = $speedResults | Measure-Object -Average -Minimum -Maximum

New-Object psobject -Property @{
    "Fastest (mbps)" = $results.Maximum
    "Slowest (mbps)" = $results.Minimum
    "Average (mbps)" = $results.Average
}