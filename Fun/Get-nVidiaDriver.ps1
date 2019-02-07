# Most logic taken from https://github.com/ElPumpo/TinyNvidiaUpdateChecker/blob/master/TinyNvidiaUpdateChecker/MainConsole.cs

$osVersion = [Environment]::OSVersion.Version.ToString()
$is64Bit = [Environment]::Is64BitOperatingSystem

switch ($osVersion) {
    { $_ -like '10.0*' } {
        $winVer = '10'

        if ($is64Bit) {
            $osId = 57
        }
        else {
            $osId = 56
        }
    }

    { $_ -like '6.3*' } {
        $winVer = '8.1'
        
        if ($is64Bit) {
            $osId = 41
        }
        else {
            $osId = 40
        }
    }

    { $_ -like '6.2*' } {
        $winVer = '8'
        
        if ($is64Bit) {
            $osId = 28
        }
        else {
            $osId = 27
        }
    }

    { $_ -like '6.1*' } {
        $winVer = '7'
        
        if ($is64Bit) {
            $osId = 19
        }
        else {
            $osId = 18
        }
    }
}

Write-Verbose "Windows $winVer version $osVersion"
Write-Verbose "64-Bit: $is64Bit"

$langId = switch (Get-Culture) {
    'en-US' { 1 }
    'en-GB' { 2 }
    'zh-CHS' { 5 }
    'zh-CHT' { 6 }
    'ja-JP' { 7 }
    'ko-KR' { 8 }
    'de-DE' { 9 }
    'es-ES' { 10 }
    'fr-FR' { 12 }
    'it-IT' { 13 }
    'pl-PL' { 14 }
    'pt-BR' { 15 }
    'ru-RU' { 16 }
    'tr-TR' { 19 }
    default { 17 }
}

Write-Verbose "Language ID: $langId"

foreach ($gpu in Get-CimInstance -ClassName Win32_VideoController) {
    Write-Verbose $gpu.Description

    if ($gpu.Description.Split() -contains 'nvidia') {
        $gpuName = $gpu.Description.Trim()
        $offlineGpuVersion = $gpu.DriverVersion
    }
    elseif ($gpu.PNPDeviceID.Split() -contains 'ven_10de') {
        Get-CimInstance -ClassName Win32_SystemEnclosure | ForEach-Object {
            if ($_.ChassisTypes -eq 3) {
                $gpuName = "GTX"
            }
            else {
                $gpuName = "GTX M"
            }
        }
    }
}

if (-not $gpuName) {
    Write-Warning "No nVidia GPU found"
    exit
}

if ($gpuName -contains 'M') {
    $psId = 99
    $pfId = 758
}
else {
    $psId = 98
    $pfId = 756
}

$gpuUrl = "http://www.nvidia.com/Download/processDriver.aspx?psid=$psID&pfid=$pfID&rpf=1&osid=$osId&lid=$langID&ctk=0"
$processUrl = Invoke-WebRequest $gpuUrl | Select-Object -ExpandProperty Content

$objXmlHttp = New-Object -ComObject MSXML2.ServerXMLHTTP
$objXmlHttp.Open("GET", $processUrl, $False)
$objXmlHttp.Send()
$response = $objXmlHttp.responseText
$html = New-Object -Com "HTMLFile"
$html.IHTMLDocument2_write($response)

$version = $html.getElementById("tdVersion").innerText.Split(' ')[0]
$releaseDate = $html.getElementById("tdReleaseDate").innerText.Split(' ')[0].Split('.')
$friendlyReleaseDate = Get-Date -Year $releaseDate[0] -Month $releaseDate[1] -Day $releaseDate[2] -Format D
$releaseNotes = $html.getElementsByTagName('a') | Where-Object href -like "*release-notes.pdf*" | Select-Object -ExpandProperty href
$releaseDescription = $html.getElementById("tab1_content").innerText
$confirmUrl = $html.getElementsByTagName('a') | Where-Object href -like "*/content/DriverDownload-March2009/*" | ForEach-Object {
    'http://www.nvidia.com/' + $_.pathname + $_.search
}

$objXmlHttp.Open("GET", $confirmUrl, $False)
$objXmlHttp.Send()
$response = $objXmlHttp.responseText
$html = New-Object -Com "HTMLFile"
$html.IHTMLDocument2_write($response)

$downloadUrl = $html.getElementsByTagName('a') | Where-Object href -like "*download.nvidia*" | Select-Object -ExpandProperty href



Write-Output "Download URL: $downloadUrl"
Write-Output "Release notes: $releaseNotes"
Write-Output "Offline version: $offlineGpuVersion"
Write-Output "Online version: $version released on $friendlyReleaseDate"
