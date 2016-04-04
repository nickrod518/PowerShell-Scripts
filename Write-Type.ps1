function Write-Type {
    [CmdletBinding()]
    [OutputType([string])]

    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Text,

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateRange(25, 500)]
        [int] $TypeSpeed = 125,

        [Parameter(Mandatory = $false, Position = 2)]
        [string] $ForegroundColor = 'White'
    )

    # Pause after typing each letter
    $Text.GetEnumerator() | ForEach-Object {
        Write-Host $_ -NoNewline -ForegroundColor $ForegroundColor
        Start-Sleep -Milliseconds $TypeSpeed
    }
}