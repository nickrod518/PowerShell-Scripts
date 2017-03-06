$Date = (Get-Date).ToString('yyyyMMdd-HHmm')
$LogFolder = New-Item -ItemType Directory ".\logs" -Force
$Log = New-Item -ItemType File "$LogFolder\Action-$Date.log"

function Write-CMTraceLog {
    Param (
		[Parameter(Mandatory=$false)] $Message,
		[Parameter(Mandatory=$false)] $ErrorMessage,
		[Parameter(Mandatory=$false)] $Component,
        # Type: 1 = Normal, 2 = Warning (yellow), 3 = Error (red)
		[Parameter(Mandatory=$false)] [int]$Type,
		[Parameter(Mandatory=$true)] $LogFile
	)

	$Time = Get-Date -Format "HH:mm:ss.ffffff"
	$Date = Get-Date -Format "MM-dd-yyyy"
 
	if ($ErrorMessage -ne $null) {$Type = 3}
	if ($Component -eq $null) {$Component = " "}
	if ($Type -eq $null) {$Type = 1}
 
	$LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
	$LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LogFile
}

<# Usage
    $LogFile = "C:\TestFolder\TestLog.Log"
    Write-CMTraceLog -LogFile $LogFile
    Write-CMTraceLog -Message "This is a normal message" -ErrorMessage $Error -LogFile $LogFile
    Write-CMTraceLog -Message "This is a warning" -Type 2 -Component "Test Component" -LogFile $LogFile
    Write-CMTraceLog -Message "This is an Error!" -Type 3 -Component "Error Component" -LogFile $LogFile
#>