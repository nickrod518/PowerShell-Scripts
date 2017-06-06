[CmdletBinding()]
Param(
    [ValidateScript({ Test-Path -Path $_ -PathType Container })]
    [string]$Path
)

Get-ChildItem -Path $Path | ForEach-Object {
    $NewName = $_.Name -replace 'Season ', 'S' -replace ', Episode ', 'E'
    $Season = 'S' + "{0:D2}" -f [int]($NewName -split 'S', 2 -split 'E', 2)[1]
    $Episode = 'E' + "{0:D2}" -f [int]($NewName -split 'E', 2 -split ' ', 2)[1]
    $NewName = "$Season$Episode - $(($NewName -split ' ', 2)[1])"
    Rename-Item -Path $_.FullName -NewName $NewName
}