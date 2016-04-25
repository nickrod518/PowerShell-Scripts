<#
.SYNOPSIS
    Convert a PowerShell script into a deployable exe using iexpress.

.DESCRIPTION
    Takes one PowerShell script and any number of supplementary files and create an exe using Windows's built in iexpress program.
    If you use one of the parameters that allows you to provide a folder, the script will zip that folder and add it as a supplemental file.
    Upon running the exe, the directory will first be unzipped and made available with the same structure, retaining relative path calls.
    Verbose output is available for most of the processes in this script if you call it using the -Verbose parameter.

.PARAMETER PSScriptPath
    Path string to PowerShell script that you want to use as the first thing iexpress calls when the exe is run.
    If blank, you will be prompted with a file browse dialog where you can select a file.

.PARAMETER SupplementalFilePaths
    Array of comma separated supplemental file paths that you want to include as resources.

.PARAMETER SelectSupplementalFiles
    Use this flag to be prompted to select the supplementary files in an Open File Dialog.

.PARAMETER SupplementalDirectoryPath
    Path to a directory that will be zipped and added as a supplementary file. 
    When the exe is run, this script will first be unzipped and all files are available.

.PARAMETER SelectSupplementalDirectory
    Use this flag to be prompted to select a directory in an Open File Dialog that will be zipped and added as a supplementary file.
    When the exe is run, this script will first be unzipped and all files are available.

.PARAMETER KeepTempDir
    Keep the temp directory around after the exe is created. It is available at the root of C:.

.PARAMETER x64
    Use the 64-bit iexpress path so that 64-bit PowerShell is consequently called.

.OUTPUTS
    An exe file in the same directory as the ps1 script you specify

.EXAMPLE
    .\Create-EXEFrom.ps1 -PSScriptPath .\test.ps1 -SupplementalFilePaths '..\test2.ps1', .\ps1toexe.ps1
    # Creates an exe using the provided PowerShell script and supplemental files.

.EXAMPLE
    .\Create-EXEFrom.ps1 -SelectSupplementalFiles
    # Prompts the user to select the PowerShell script and supplemental files using an Open File Dialog.

.EXAMPLE
    .\Create-EXEFrom.ps1 -SupplementalDirectoryPath 'C:\Temp\MyTestDir' -KeepTempDir
    # Zips MyTestDir and attaches it to the exe. When the exe is run, but before the user's script gets run, 
    # it will be extracted to the same directory as the user's script. Temp directory used during exe creation
    # will be left intact for user inspection or debugging purposes.

.NOTES
    Created by Nick Rodriguez

    Requires iexpress, which is included in most versions of Windows (https://en.wikipedia.org/wiki/IExpress).

    Version 1.6 - 4/25/16
        -Changed name of RemoveTempDir param to be a switch named KeepTempDir
        -Added ability to use the exe's root path in your PS script with "Split-Path -Parent $Args[0]"

    Version 1.5 - 4/6/16
        -Added RunAs flag so iexpress is started as admin

    Version 1.4 - 3/29/16
        -Added x64 switch for creating exe using 64-bit iexpress.
    
    Version 1.3 - 2/29/16
        -Added PS Version 2.0 support

    Version 1.2 - 2/27/16
        -Added parameter for leaving temp directory intact - useful for bug smashing.
        -Added options for selecting or specifying an entire directory as a supplemental file.
        -Added functions for zipping, unzipping, testing .NET version (related to zipping), and GUI for selecting directory.

    Version 1.1 - 2/27/16
        -Removed $PSScriptRoot references in process block, which were causing errors when run from ISE.
        -New target exe destination is directory of target ps1.
        -Changed location of temp directory to root of C: to prevent issues with path names containing spaces.
        -Changed method of getting target name from trimming to replacing to prevent cutting off chars of file name.

    Version 1.0 - 2/26/16

#>

[CmdletBinding(DefaultParameterSetName = 'NoSupplementalFiles')]
param (
    [Parameter(Mandatory=$false)]
    [ValidateScript({
        if ((Get-Item $_).Extension -ne '.ps1') {
            throw "[$_] is not a PowerShell script (ps1)."
        } else { $true }
    })]
    [string]
    $PSScriptPath,

    [Parameter(Mandatory=$false, ParameterSetName = 'SpecifyFiles')]
    [ValidateScript({
        foreach ($FilePath in $_) {
            if (-not (Get-Item $FilePath)) {
                throw "[$FilePath] was not found."
            } else { $true }
        }
    })]
    [string[]]
    $SupplementalFilePaths,

    [Parameter(Mandatory=$false, ParameterSetName = 'SelectFiles')]
    [switch]
    $SelectSupplementalFiles,

    [Parameter(Mandatory=$false, ParameterSetName = 'SpecifyDirectory')]
    [ValidateScript({
        if (-not (Get-Item $_).PSIsContainer) {
            throw "[$_] is not a directory."
        } else { $true }
    })]
    [string]
    $SupplementalDirectoryPath,

    [Parameter(Mandatory=$false, ParameterSetName = 'SelectDirectory')]
    [switch]
    $SelectSupplementalDirectory,

    [Parameter(Mandatory=$false)]
    [bool]
    $RemoveTempDir = $true,

    [Parameter(Mandatory=$false)]
    [switch]
    $x64
)

begin {
    # use 32-bit iexpress for wider compatibility unless user specifies otherwise
    if ($x64) {
        $IExpress = "C:\WINDOWS\System32\iexpress"
    } else {
        $IExpress = "C:\WINDOWS\SysWOW64\iexpress"
    }

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
        # PSScriptRoot will be null if run from the ISE or PS Version < 3.0
        $OpenFileDialog.InitialDirectory = $PSScriptRoot
        if ($SupplementalFiles) {
            $OpenFileDialog.Title = 'Select one or more files'
            $OpenFileDialog.filter = "All Files| *.*"
            $OpenFileDialog.Multiselect = 'true'
        } else {
            $OpenFileDialog.Title = 'Select a file'
            $OpenFileDialog.filter = "PowerShell (*.ps1)| *.ps1"
        }
        $OpenFileDialog.ShowHelp = $true
        $OpenFileDialog.ShowDialog() | Out-Null
        try {
            if ($SupplementalFiles) {
                foreach ($FileName in $OpenFileDialog.FileNames) { Get-Item $FileName }
            } else {
                Get-Item $OpenFileDialog.FileName
            }
        } catch {
            Write-Warning 'Open File Dialog was closed or cancelled without selecting any files'
        }
    }

    function Get-Directory {
        [CmdletBinding()]
        [OutputType([psobject])]
        param()

        [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
        $OpenDirectoryDialog = New-Object Windows.Forms.FolderBrowserDialog
        $OpenDirectoryDialog.ShowDialog() | Out-Null
        try {
            Get-Item $OpenDirectoryDialog.SelectedPath
        } catch {
            Write-Warning 'Open Directory Dialog was closed or cancelled without selecting a Directory'
        }
    }

    function Test-NETVersion {
        $NETPath = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Client'

        # Get the .NET version, or leave null if less than 4
        try { $NETVersion = (Get-ItemProperty $NETPath -ErrorAction SilentlyContinue).Version } catch { }

        # Return true if .NET client is at least version 4.5
        if ($NETVersion -ge 4.5) {
            Write-Verbose 'Client .NET is version 4.5 or greater'
            $true 
        } else {
            Write-Verbose 'Client .NET is less than version 4.5'
            $false 
        }
    }
    
    function Test-PSVersion {
        # Return true if PowerShell is at least version 3
        if ($PSVersionTable.PSVersion.Major -ge 3) {
            Write-Verbose 'PowerShell is version 3 or greater'
            $true
        } else {
            Write-Verbose 'PowerShell is less than version 3'
            $false
        }
    }

    # This zip method is not as reliable, and slower, but we must use it if .NET 4.5+ is not available
    function Zip-FileOld {
        [CmdletBinding()]
        [OutputType([string])]
        param (
            [Parameter(Mandatory=$true)]
            [string]
            $SourceDirectoryPath,
            [Parameter(Mandatory=$true)]
            [string]
            $DestinationDirectoryPath
        )

        Write-Verbose 'Using shell application based zip process'

        # Get the full path of the source zip archive
        $SourceDirectoryFullPath = (Get-Item $SourceDirectoryPath).FullName
        Write-Verbose "Full path of source directory: $SourceDirectoryFullPath"
        
        $TargetZipPath = "$DestinationDirectoryPath\$($SourceDirectoryFullPath.Split('\')[-1]).zip"

        # Create empty zip file that is not read only
        Set-Content $TargetZipPath ([byte[]] @(80, 75, 5, 6 + (,0 * 18))) -Encoding Byte
        (Get-Item $TargetZipPath).IsReadOnly = $false

        $Shell = New-Object -ComObject Shell.Application
        $ZipFile = $Shell.NameSpace($TargetZipPath)
        Write-Verbose "Zip file location: $TargetZipPath"

        # User Force parameter to make sure we get hidden items too
        Get-ChildItem $SourceDirectoryFullPath -Force | ForEach-Object {
            # Skip empty directories
            if (($_.Mode -like 'd-----') -and (-not (Get-ChildItem $_.FullName | Measure-Object).Count)) {
                Write-Verbose "$($_.Name) is an empty directory; skipping"
            } else {
                # Copy file into zip
                $ZipFile.CopyHere($_.FullName)
                Write-Verbose "Copied $($_.Name) into zip"

                # Limitation of shell, wait to make sure each file is copied before continuing
                while ($ZipFile.Items().Item($_.Name) -eq $null) {
                    Start-Sleep -Milliseconds 500
                }
            }
        }

        # Return the path of the zip file
        $TargetZipPath
    }

    # This zip method requires .NET 4.5+, so we check for that
    function Zip-File {
        [CmdletBinding()]
        [OutputType([string])]
        param (
            [Parameter(Mandatory=$true)]
            [string]
            $SourceDirectoryPath,
            [Parameter(Mandatory=$true)]
            [string]
            $DestinationDirectoryPath
        )

        Write-Verbose 'Using assembly based zip process'

        # Get the full path of the source zip archive
        $SourceDirectoryFullPath = (Get-Item $SourceDirectoryPath).FullName
        Write-Verbose "Full path of source directory: $SourceDirectoryFullPath"

        $TargetZipPath = "$DestinationDirectoryPath\$($SourceDirectoryFullPath.Split('\')[-1]).zip"

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::CreateFromDirectory($SourceDirectoryFullPath, $TargetZipPath)
        Write-Verbose "Zip file location: $TargetZipPath"

        # Return the path of the zip file
        $TargetZipPath
    }

    # We need to make this function available to the exe, so save it to a variable for later
    $UnZipFunction = {
        function UnZip-File {
            [CmdletBinding()]
            param (
                [Parameter(Mandatory=$true)]
                [string]
                $SourceZipPath
            )

            $Shell = New-Object -ComObject Shell.Application

            # Get the full path of the source zip archive
            $SourceZipFullPath = (Get-Item $SourceZipPath).FullName
            Write-Verbose "Full path of zip archive: $SourceZipFullPath"

            # Create the destination folder with the same name as the source
            $DestinationDirectory = (New-Item ($SourceZipFullPath -replace '.zip', '') -ItemType Directory -Force).FullName
            Write-Verbose "Destination for zip archive contents: $DestinationDirectory"

            # UnZip files answering yes to all prompts
            $Shell.NameSpace($DestinationDirectory).CopyHere($Shell.NameSpace($SourceZipFullPath).Items(), 16) 
        }
    }
}

process {
    # If no PowerShell script specified, prompt the user to select one
    if ($PSScriptPath) {
        $PSScriptName = (Get-Item $PSScriptPath).Name
    } else {
        try {
            $PSScriptPath = (Get-File).FullName
            $PSScriptName = $PSScriptPath.Split('\')[-1]
        } catch { exit } 
    }
    Write-Verbose "PowerShell script selected: $PSScriptPath"

    # Name of the extensionless target, replace spaces with underscores
    $Target = ($PSScriptName -replace '.ps1', '') -replace " ", '_'
    
    # Get the directory the script was found in
    $ScriptRoot = $PSScriptPath.Substring(0, $PSScriptPath.LastIndexOf('\'))

    # Create temp directory to store all files
    $Temp = New-Item "C:\$Target$(Get-Date -Format "HHmmss")" -ItemType Directory -Force
    Write-Verbose "Using temp directory $Temp"

    # Copy the PowerShell script to our temp directory
    Copy-Item $PSScriptPath $Temp

    Write-Verbose "Using Parameter Set: $($PSCmdlet.ParameterSetName)"

    if ($PSCmdlet.ParameterSetName -eq 'NoSupplementalFiles') {
        Write-Verbose 'Not using supplemental files'

    } else {
        if ($PSCmdlet.ParameterSetName -eq 'SelectFiles') {
            # Prompt user to select supplemental files
            $SupplementalFilePaths = (Get-File -SupplementalFiles).FullName
            $SupplementalFiles = (Get-Item $SupplementalFilePaths).Name
            Write-Verbose "Supplemental files: `n$SupplementalFilePaths"

            # Copy supplemental files to temp directory
            Copy-Item $SupplementalFilePaths $Temp

        } elseif ($PSCmdlet.ParameterSetName -eq 'SpecifyFiles') {
            # Get the paths of the files the user supplied
            $SupplementalFilePaths = (Get-Item $SupplementalFilePaths).FullName
            $SupplementalFiles = (Get-Item $SupplementalFilePaths).Name
            Write-Verbose "Supplemental files: `n$SupplementalFilePaths"

            # Copy supplemental files to temp directory
            Copy-Item $SupplementalFilePaths $Temp

        } elseif ($PSCmdlet.ParameterSetName -eq 'SelectDirectory') {
            # Prompt user to select supplemental directory
            $SupplementalDirectoryPath = (Get-Directory).FullName
            Write-Verbose "Supplemental directory: $SupplementalDirectoryPath"
            if ((Test-NETVersion) -and (Test-PSVersion)) {
                $SupplementalFilePaths = Zip-File -SourceDirectoryPath $SupplementalDirectoryPath -DestinationDirectoryPath $Temp
            } else {
                $SupplementalFilePaths = Zip-FileOld -SourceDirectoryPath $SupplementalDirectoryPath -DestinationDirectoryPath $Temp
            }
            $SupplementalFiles = $SupplementalFilePaths.Split('\')[-1]

            # Move supplemental zip to temp directory
            Move-Item $SupplementalFilePaths $Temp
        } elseif ($PSCmdlet.ParameterSetName -eq 'SpecifyDirectory') {
            # Get the path of the directory the user supplied
            $SupplementalDirectoryPath = (Get-Item $SupplementalDirectoryPath).FullName
            Write-Verbose "Supplemental directory: $SupplementalDirectoryPath"
            if ((Test-NETVersion) -and (Test-PSVersion)) {
                $SupplementalFilePaths = Zip-File -SourceDirectoryPath $SupplementalDirectoryPath -DestinationDirectoryPath $Temp
            } else {
                $SupplementalFilePaths = Zip-FileOld -SourceDirectoryPath $SupplementalDirectoryPath -DestinationDirectoryPath $Temp
            }
            $SupplementalFiles = $SupplementalFilePaths.Split('\')[-1]

            # Move supplemental zip to temp directory
            Move-Item $SupplementalFilePaths $Temp

        }
    }
    
    # If creating 64-bit exe, append to name to clarify
    if ($x64) {
        $EXE = "$ScriptRoot\$Target (x64).exe"
    } else {
        $EXE = "$ScriptRoot\$Target.exe"
    }
    Write-Verbose "Target EXE: $EXE"

    # create the sed file used by iexpress
    $SED = "$Temp\$Target.sed"
    New-Item $SED -ItemType File -Force | Out-Null

    # populate the sed with config info
    Add-Content $SED "[Version]"
    Add-Content $SED "Class=IEXPRESS"
    Add-Content $SED "sedVersion=3"
    Add-Content $SED "[Options]"
    Add-Content $SED "PackagePurpose=InstallApp"
    Add-Content $SED "ShowInstallProgramWindow=0"
    Add-Content $SED "HideExtractAnimation=1"
    Add-Content $SED "UseLongFileName=1"
    Add-Content $SED "InsideCompressed=0"
    Add-Content $SED "CAB_FixedSize=0"
    Add-Content $SED "CAB_ResvCodeSigning=0"
    Add-Content $SED "RebootMode=N"
    Add-Content $SED "TargetName=%TargetName%"
    Add-Content $SED "FriendlyName=%FriendlyName%"
    Add-Content $SED "AppLaunched=%AppLaunched%"
    Add-Content $SED "PostInstallCmd=%PostInstallCmd%"
    Add-Content $SED "SourceFiles=SourceFiles"
    Add-Content $SED "[Strings]"
    Add-Content $SED "TargetName=$EXE"
    Add-Content $SED "FriendlyName=$Target"

    # If we've zipped a file, we need to modify things
    if ('SelectDirectory', 'SpecifyDirectory' -contains $PSCmdlet.ParameterSetName) {
        $IndexOffset = 2
        # Create a script to unzip the user's zip
        $UnZipScript = New-Item "$Temp\UnZip.ps1" -ItemType File -Force
        Add-Content $UnZipScript $UnZipFunction
        Add-Content $UnZipScript "UnZip-File `'$SupplementalFiles`'"
        # If we're dealing with a zip file, we need to set the primary command to unzip the user's files
        Add-Content $SED "AppLaunched=cmd /c PowerShell -ExecutionPolicy Bypass -File `"$UnZipScript`""
        # After we've staged our files, run the user's script
        Add-Content $SED "PostInstallCmd=cmd /c for /f `"skip=1 tokens=1* delims=`" %i in (`'wmic process where `"name=`'$target.exe`'`" get ExecutablePath`') do PowerShell -ExecutionPolicy Bypass -Command Clear-Host; `".\$PSScriptName`" `"%i`" & exit"
        Add-Content $SED "FILE0=UnZip.ps1"
        Add-Content $SED "FILE1=$PSScriptName"
    } else {
        $IndexOffset = 1
        Add-Content $SED "AppLaunched=cmd /c for /f `"skip=1 tokens=1* delims=`" %i in (`'wmic process where `"name=`'$target.exe`'`" get ExecutablePath`') do PowerShell -ExecutionPolicy Bypass -Command Clear-Host; `".\$PSScriptName`" `"%i`" & exit"
        Add-Content $SED "PostInstallCmd=<None>"
        Add-Content $SED "FILE0=$PSScriptName"
    }
    
    # Add the ps1 and supplemental files
    If ($SupplementalFiles) {
        $Index = $IndexOffset
        ForEach ($File in $SupplementalFiles) {
            $Index++
            Add-Content $SED "FILE$Index=$File"
        }
    }
    Add-Content $SED "[SourceFiles]"
    Add-Content $SED "SourceFiles0=$Temp"
    
    Add-Content $SED "[SourceFiles0]"
    Add-Content $SED "%FILE0%="
    if ('SelectDirectory', 'SpecifyDirectory' -contains $PSCmdlet.ParameterSetName) {
        # We've already specified this file, so leave it blank here
        Add-Content $SED "%FILE1%="
    }
    # Add the ps1 and supplemental files
    If ($SupplementalFiles) {
        $Index = $IndexOffset
        ForEach ($File in $SupplementalFiles) {
            $Index++
            Add-Content $SED "%FILE$Index%="
        }
    }

    Write-Verbose "SED file contents: `n$(Get-Content $SED | Out-String)"

    # Call IExpress to create exe from the sed we just created (run as admin)
    Start-Process $IExpress "/N $SED" -Wait -Verb RunAs

    # Clean up unless user specified not to
    if (-not $KeepTempDir) { Remove-Item $Temp -Recurse -Force }
}