#Requires -Version 3

[CmdletBinding(SupportsShouldProcess = $true)]
param (
	[Parameter(
        Mandatory = $true,
        ParameterSetName = 'UsersFromCSV'
    )]
	[string]$UsersCSVPath = '.\users.csv',

    [Parameter(
        Mandatory = $true,
        ParameterSetName = 'SingleUser'
    )]
    [string]$UserEmail,

    [Parameter(
        Mandatory = $true,
        ParameterSetName = 'SingleUser'
    )]
    [string]$SourceFolderPath,

    [Parameter(Mandatory = $false)]
	[int]$MaxJobs = 10,

    [Parameter(Mandatory = $false)]
	[switch]$Archive
)

begin {
	# Create logs folder
	New-Item -ItemType Directory ".\logs" -Force
	$LogDirectory = (New-Item -ItemType Directory ".\logs\Migration-$((Get-Date).ToString('yyyyMMdd'))" -Force).FullName
	Start-Transcript "$LogDirectory\Migration-$((Get-Date).ToString('yyyyMMdd-hhmm')).log"

    # Look in my repo
    Import-Module 'C:\Scripts\JobManagement.psm1' -Force
    $Global:SuppressJobResults = $true
    # Look in my repo
    Import-Module 'C:\Scripts\OneDrive.psm1' -Force
    # https://gallery.technet.microsoft.com/scriptcenter/Get-FolderSize-b3d317f5
    . 'C:\Scripts\Dependencies\Get-FolderSize.ps1'
	
    Get-Credential -Message 'MSO admin service account credentials'
}

process {
    if ($PSCmdlet.ParameterSetName -eq 'UsersFromCSV') {
	    foreach ($User in (Import-Csv $UsersCSVPath)) {
		    Limit-Job -MaxJobs $MaxJobs
		    Clear-CompletedJob
		
		    $UserEmail = $User.Email
		    $SourceFolderPath = $User.DataPath
            $SourceFolderSize = "$("{0:N2}" -f ((Get-FolderSize -Path $SourceFolderPath).TotalMBytes)) MB"

            if ($pscmdlet.ShouldProcess($UserEmail, "Migrate [$SourceFolderPath] ($SourceFolderSize) to OneDrive")) {
                # Upload files
		        if (Test-Path $SourceFolderPath) {
			        $NotEmpty = try { Get-ChildItem $SourceFolderPath -ErrorAction Stop } catch { $true }
			        if ($NotEmpty) {
                        if ($Archive) { $ArchivePath = "\\Path\To\Archive\$UserEmail" }
                        Start-Job -Name "$UserEmail" -ScriptBlock ${Function:Move-UserDataToOneDrive} `
                            -ArgumentList $UserEmail, $Credential, $SourceFolderPath, $ArchivePath, $LogDirectory `
                            -InitializationScript {
                                Import-Module 'C:\Scripts\OneDrive.psm1'
                                $VerbosePreference = 'Continue'
                            } | Out-Null
			        } else {
				        Write-Warning 'Source directory is empty.'
			        }
		        } else {
			        Write-Warning 'Source directory not found.'
		        }
            }
	    }
    } else {
        $SourceFolderSize = "$("{0:N2}" -f ((Get-FolderSize -Path $SourceFolderPath).TotalMBytes)) MB"

        if ($pscmdlet.ShouldProcess($UserEmail, "Migrate [$SourceFolderPath] ($SourceFolderSize) to OneDrive")) {
            # Upload files
		    if (Test-Path $SourceFolderPath) {
                $NotEmpty = try { Get-ChildItem $SourceFolderPath -ErrorAction Stop } catch { $true }
			    if ($NotEmpty) {
                    if ($Archive) { $ArchivePath = "\\Path\To\Archive\$UserEmail" }
                    Start-Job -Name "$UserEmail" -ScriptBlock ${Function:Move-UserDataToOneDrive} `
                        -ArgumentList $UserEmail, $Credential, $SourceFolderPath, $ArchivePath, $LogDirectory `
                        -InitializationScript {
                            Import-Module 'C:\Scripts\OneDrive.psm1'
                            $VerbosePreference = 'Continue'
                        } | Out-Null
			    } else {
				    Write-Warning 'Source directory is empty.'
			    }
		    } else {
			    Write-Warning 'Source directory not found.'
		    }
        }
    }
}

end {
	Wait-CompletedJob
	Stop-Transcript
}