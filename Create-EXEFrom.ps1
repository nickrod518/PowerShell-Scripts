# Requires PowerShell 3.0+

<#
.SYNOPSIS
    Convert a PowerShell script into a deployable exe using iexpress.

.DESCRIPTION
    Takes one PowerShell script and any number of supplementary files and create an exe using Windows's built in iexpress program.
    Verbose output is available for most of the processes in this script if you call it using the -Verbose parameter.

.PARAMETER PSScriptPath (Optional)
    Path string to PowerShell script that you want to use as the first thing iexpress calls when the exe is run.
    If blank, you will be prompted with a file browse dialog where you can select a file.

.PARAMETER SupplementalFilePaths (Optional)
    Array of comma separated supplemental file paths that you want to include as resources.

.OUTPUTS
    An exe file is created in the same directory you run the script from

.EXAMPLE
    .\ps1toexe.ps1 -PSScriptPath .\test.ps1 -SupplementalFilePaths '..\test2.ps1', .\ps1toexe.ps1
    # Creates an exe using the provided PowerShell script and supplemental files


.EXAMPLE
    .\ps1toexe.ps1 -SelectSupplementalFiles
    # Prompts the user to select the PowerShell script and supplemental files using an Open File Dialog.

.NOTES
    Created by Nick Rodriguez

    Version 1.0 - 2/26/16

#>

[CmdletBinding(DefaultParameterSetName = 'SelectFiles')]
param (
    [Parameter(Mandatory=$false)]
    [ValidateScript({
        if ((Get-Item $_).Extension -ne '.ps1') {
            throw "The file [$_] is not a PowerShell script (ps1)."
        } else { $true }
    })]
    [string]
    $PSScriptPath,
    [Parameter(Mandatory=$false, ParameterSetName = 'SpecifyFiles')]
    [ValidateScript({
        foreach ($FilePath in $_) {
            if (-not (Get-Item $FilePath)) {
                throw "The file [$FilePath] was not found."
            } else { $true }
        }
    })]
    [string[]]
    $SupplementalFilePaths,
    [Parameter(Mandatory=$false, ParameterSetName = 'SelectFiles')]
    [switch]
    $SelectSupplementalFiles
)

begin {
    function Get-File {
        [CmdletBinding()]
        [OutputType([psobject[]])]
        param (
            [Parameter(Mandatory=$false)]
            [switch]
            $SupplementalFiles
        ) 

        [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
        $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $OpenFileDialog.Title = 'Select a file'
        $OpenFileDialog.InitialDirectory = $PSScriptRoot
        if ($SupplementalFiles) {
            $OpenFileDialog.filter = "All Files| *.*"
            $OpenFileDialog.Multiselect = 'true'
        } else {
            $OpenFileDialog.filter = "PowerShell (*.ps1)| *.ps1"
        }
        $OpenFileDialog.ShowHelp = $true
        $OpenFileDialog.ShowDialog() | Out-Null
        if ($SupplementalFiles) {
            foreach ($FileName in $OpenFileDialog.FileNames) { Get-Item $FileName }
        } else {
            Get-Item $OpenFileDialog.FileName
        }
    }
}

process {
    # If no PowerShell script specified, prompt the user to select one
    if ($PSScriptPath) {
        $PSScriptName = (Get-Item $PSScriptPath).Name
    } else {
        try {
            $PSScriptPath = Get-File
            $PSScriptName = $PSScriptPath.Name
        } catch { exit } 
    }
    Write-Verbose "PowerShell script selected: `n$PSScriptPath"

    # Name of the target exe, leave "exe" out, and replace spaces with underscores
    $target = ($PSScriptName).TrimEnd(".ps1") -replace " ", '_'
    
    # Create temp directory to store all files
    $Temp = New-Item "$PSScriptRoot\$target$(Get-Date -Format "HHmmss")" -ItemType Directory -Force

    # Copy the PowerShell script to our temp directory
    Copy-Item $PSScriptPath $Temp

    if ($PSCmdlet.ParameterSetName -eq 'SelectFiles') {
        if ($SelectSupplementalFiles) {
            # Prompt user to select supplemental files
            $SupplementalFilePaths = (Get-File -SupplementalFiles).FullName
            $SupplementalFiles = (Get-Item $SupplementalFilePaths).Name
            Write-Verbose "Supplemental files: `n$SupplementalFilePaths"
        } else {
            Write-Verbose 'Not using supplemental files'
        }
    } else {
        if ($SupplementalFilePaths) {
            # Get the names of the files the user gave
            $SupplementalFilePaths = (Get-Item $SupplementalFilePaths).FullName
            $SupplementalFiles = (Get-Item $SupplementalFilePaths).Name
            Write-Verbose "Supplemental files: `n$SupplementalFilePaths"
        }
    }

    if ($SupplementalFiles) {
        # Copy supplemental files to temp directory
        Copy-Item $SupplementalFilePaths $Temp
    }

    $exe = "$PSScriptRoot\$target.exe"
    Write-Verbose "Target EXE: $exe"

    # create the sed file used by iexpress
    $sed = "$Temp\$target.sed"
    New-Item $sed -type file -force

    # populate the sed with config info
    Add-Content $sed "[Version]"
    Add-Content $sed "Class=IEXPRESS"
    Add-Content $sed "sedVersion=3"
    Add-Content $sed "[Options]"
    Add-Content $sed "PackagePurpose=InstallApp"
    Add-Content $sed "ShowInstallProgramWindow=0"
    Add-Content $sed "HideExtractAnimation=1"
    Add-Content $sed "UseLongFileName=1"
    Add-Content $sed "InsideCompressed=0"
    Add-Content $sed "CAB_FixedSize=0"
    Add-Content $sed "CAB_ResvCodeSigning=0"
    Add-Content $sed "RebootMode=N"
    Add-Content $sed "TargetName=%TargetName%"
    Add-Content $sed "FriendlyName=%FriendlyName%"
    Add-Content $sed "AppLaunched=%AppLaunched%"
    Add-Content $sed "PostInstallCmd=%PostInstallCmd%"
    Add-Content $sed "SourceFiles=SourceFiles"
    Add-Content $sed "[Strings]"
    Add-Content $sed "TargetName=$exe"
    Add-Content $sed "FriendlyName=$target"
    Add-Content $sed "AppLaunched=cmd /c PowerShell -ExecutionPolicy Bypass -File `"$PSScriptName`""
    Add-Content $sed "PostInstallCmd=<None>"
    Add-Content $sed "FILE0=$PSScriptName"
    # Add the ps1 and supplemental files
    If ($SupplementalFiles) {
        ForEach ($file in $SupplementalFiles) {
            $index = ([array]::IndexOf($SupplementalFiles, $file) + 1)
            Add-Content $sed "FILE$index=$file"
        }
    }
    Add-Content $sed "[SourceFiles]"
    Add-Content $sed "SourceFiles0=$Temp"
    Add-Content $sed "[SourceFiles0]"
    Add-Content $sed "%FILE0%="
    # Add the ps1 and supplemental files
    If ($SupplementalFiles) {
        ForEach ($file in $SupplementalFiles) {
            $index = ([array]::IndexOf($SupplementalFiles, $file) + 1)
            Add-Content $sed "%FILE$index%="
        }
    }

    Write-Verbose "SED file contents: `n$(Get-Content $sed)"

    # Call IExpress to create exe from the sed we just created
    $IExpress = "C:\WINDOWS\SysWOW64\iexpress"
    $Args = "/N $sed"
    Start-Process $IExpress $Args -Wait

    # Clean up
    Remove-Item $Temp -Recurse -Force
}