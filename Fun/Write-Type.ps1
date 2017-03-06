function Write-Type {
    <#
    .Synopsis
        Make Write-Host text appear as if it is being typed

    .DESCRIPTION
        Input text and if desired specify the write speed (25-500 milliseconds) and foreground color for the text

    .EXAMPLE
        Write-Typewriter 'Hello world!'

    .EXAMPLE
        Write-Typewriter 'Hello world!' 250

    .EXAMPLE
        Write-Typewriter -Text '2 spooky 4 me!' -TypeSpeed 400 -ForegroundColor 'Red'

    .NOTES
        v1.1 - 2016-04-04 - Nick Rodriguez
            -Changed name
            -Changed TypeSpeed range
            -Added ForegroundColor param
            -Changed sleep to not use method after seeing it slow performance with Measure-Command
            -Changed code formatting to my liking

        v1.0 - 2016-01-25 - Nathan Kasco (http://poshcode.org/6193)
    #>

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