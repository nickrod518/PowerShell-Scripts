function Write-CMTraceLog {
    <# 
    .Description  
        Write to a cmtrace readable log.
    .Example
        $LogFile = "C:\TestFolder\TestLog.Log"
		Write-CMTraceLog -LogFile $LogFile
		Write-CMTraceLog -Message "This is a normal message" -ErrorMessage $Error -LogFile $LogFile
		Write-CMTraceLog -Message "This is a warning" -Type 2 -Component "Test Component" -LogFile $LogFile
		Write-CMTraceLog -Message "This is an Error!" -Type 3 -Component "Error Component" -LogFile $LogFile
    #>
    param (
        [Parameter(Mandatory = $false)]
        [string]$Message,
		
        [Parameter(Mandatory = $false)]
        [string]$ErrorMessage,
		
        [Parameter(Mandatory = $false)]
        [string]$Component,
		
        # 1 = Normal, 2 = Warning (yellow), 3 = Error (red)
        [Parameter(Mandatory = $false)]
        [int]$Type,
		
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )

    $Time = Get-Date -Format "HH:mm:ss.ffffff"
    $Date = Get-Date -Format "MM-dd-yyyy"
 
    if ($ErrorMessage -ne $null) {
        $Type = 3
    }
    if ($Component -eq $null) {
        $Component = " "
    }
    if ($Type -eq $null) {
        $Type = 1
    }
 
    $LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
    $LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LogFile
    $LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LogFile
    $LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LogFile
}