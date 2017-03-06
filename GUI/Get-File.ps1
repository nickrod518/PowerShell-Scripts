Function Get-File {
    <#
    .SYNOPSIS
        Prompt user to select a file.

    .DESCRIPTION
        

    .PARAMETER TypeName
        The type of file you're prompting for. This appears in the Open File Dialog and is only used to help the user.

    .PARAMETER TypeExtension
        The extension you're prompting for (e.g. "exe")

    .PARAMETER MultipleExtensions
        Filter by multiple extensions. Comma separated list.

    .PARAMETER MultipleFiles
        Use this to allow the user to select multiple files.

    .PARAMETER InitialDirectory
        Directory the Open File Dialog will start from.

    .PARAMETER Title
        Title that will appear in the Title Bar of the Open File Dialog.
    
    .INPUTS
        None. You cannot pipe input to this function.

    .OUTPUTS
        System.IO.FileSystemInfo

    .EXAMPLE
        Get-File
        # Prompts the user to select a file of any type

    .EXAMPLE
        Get-File -TypeName 'Setup File' -TypeExtension 'msi' -InitialDirectory 'C:\Temp\Downloads'
        # Prompts the user to select an msi file and begin the prompt in the C:\Temp\Downloads directory

    .EXAMPLE
        Get-File -TypeName 'Log File' -MultipleExtensions 'log', 'txt' -MultipleFiles
        # Prompts the user to select one or more txt or log file

    .NOTES
        Created by Nick Rodriguez

        Version 1.0 - 2/26/16

    #>
    [CmdletBinding(DefaultParameterSetName = 'SingleExtension')]
    [OutputType([psobject[]])]
    param (
        [Parameter(Mandatory=$false, ParameterSetName = 'SingleExtension')]
        [string]
        $TypeName = 'All Files (*.*)',

        [Parameter(Mandatory=$false, ParameterSetName = 'SingleExtension')]
        [string]
        $TypeExtension = '*',

        [Parameter(Mandatory=$false, ParameterSetName = 'MultipleExtensions')]
        [string[]]
        $MultipleExtensions,

        [Parameter(Mandatory=$false)]
        [switch]
        $MultipleFiles,

        [Parameter(Mandatory=$false)]
        [ValidateScript({
            if (-not (Test-Path $_ )) {
                throw "The path [$_] was not found."
            } else { $true }
        })]
        [string[]]
        $InitialDirectory = $PSScriptRoot,

        [Parameter(Mandatory=$false)]
        [string]
        $Title = 'Select a file'
    )

    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.Title = $Title
    $OpenFileDialog.InitialDirectory = $InitialDirectory

    if ($PSCmdlet.ParameterSetName -eq 'MultipleExtensions' ) {
        foreach ($Extension in $MultipleExtensions) {
            $TypeExtensionName += "*.$Extension, "
            $TypeExtensionFilter += "*.$Extension; "
        }
        $TypeExtensionName = $TypeExtensionName.TrimEnd(', ')
        $TypeExtension = $TypeExtension.TrimEnd('; ')
        $OpenFileDialog.Filter = "$TypeName ($TypeExtensionName)| $TypeExtensionFilter"
    } else {
        $OpenFileDialog.Filter = "$TypeName (*.$TypeExtension)| *.$TypeExtension"
    }

    $OpenFileDialog.ShowHelp = $true
    $OpenFileDialog.ShowDialog() | Out-Null

    try {
        if ($MultipleFiles) {
            foreach ($FileName in $OpenFileDialog.FileNames) { Get-Item $FileName }
        } else {
            Get-Item $OpenFileDialog.FileName
        }
    } catch { } # User closed the window or hit Cancel, return nothing
}