#Requires -Version 5
<#
.DESCRIPTION
Compress logs older than given time into an archive. Uses LastWriteTime property to determine age.

.PARAMETER Path
Path of log files.

.PARAMETER Extension
Extension of the log files to search for, default is 'log'.

.PARAMETER DaysOld
How many days old the file must be to get archived.

.EXAMPLE
./CompressLog.ps1 -Path ~\Downloads\logs -DaysOld 8
Searches for log files (.log extension) in the given path that are older than 8 days old and compresses them.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
Param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -Path $_ -PathType Container })]
    [string]$Path,

    [Parameter(Mandatory = $false)]
    [string]$Extension = 'log',

    [Parameter(Mandatory = $false)]
    [int]$DaysOld = 7
)

begin {
    $CompareDate = (Get-Date).AddDays(-$DaysOld)
    Write-Verbose "Threshold date: $CompareDate"

    $ArchiveName = "LogsOlderThan-$($CompareDate.ToString('yyyy-MM-dd'))"
    Write-Verbose "Archive name: $ArchiveName"
}

process {
    # Get logs older than the compare date
    $Files = Get-ChildItem -Path $Path -File -Filter "*.$Extension" | 
        Where-Object -Property LastWriteTime -LT $CompareDate

    if ($Files.Count) {
        Write-Verbose "$($Files.Count) old logs found"

        # Create archive will old logs in it
        if ($PSCmdlet.ShouldProcess($ArchiveName, 'New archive')) {
            Compress-Archive -Path $Files.FullName -DestinationPath "$Path\$ArchiveName" -Update
        }

        # Delete old logs
        $Files | Remove-Item
    } else {
        Write-Verbose 'No old logs found'
    }
}