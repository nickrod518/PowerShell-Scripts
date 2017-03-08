[CmdletBinding()]
param(
    [Parameter(
        Mandatory = $true,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true
    )]
    [ValidateScript({
        if (Test-Path -Path $_ -PathType Leaf) {
            $true
        } else {
            throw "[$_] is not a valid file."
            $false
        }
    })]
    [string[]]$FilePath
)

foreach ($Path in $FilePath) {
    Add-Type -AssemblyName System.Drawing

    $File = Get-Item -Path $Path
    $Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($File.FullName)
    $Icon.ToBitmap().Save($File.FullName.Replace($File.Extension, '.ico'))
}