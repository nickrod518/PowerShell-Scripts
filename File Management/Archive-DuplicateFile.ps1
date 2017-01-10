function Archive-DuplicateFile {
	[CmdletBinding(SupportsShouldProcess = $true)]
	Param (
		[Parameter(
			Mandatory = $false,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
        [ValidateScript({
            if (Test-Path -Path $_ -PathType Container) {
                $true
            } else {
                throw "[$_] is not a valid directory."
                $false
            }
        })]
		[string[]]$Directory = '.'
	)
	
    begin {
        $AllItems = @{}
    }

    process {
	    foreach ($Dir in $Directory) {
            # Create directory to store older duplicate files
            $DupeDir = New-Item -Path $Dir\__DuplicateFilesArchive -ItemType Directory -Force

            # Create log to store details of archived files
            $Log = New-Item -Path $DupeDir\__ArchiveLog.csv -ItemType File -Force

		    Write-Verbose "Getting all files within [$Dir]..."
            Get-ChildItem -Path $Dir -File -Recurse -Exclude $DupeDir -Force -ErrorAction Continue | Where-Object {
                $_.FullName -notlike "$DupeDir\*"
            } | ForEach-Object {
                # Check if the file name exists in our list
                if ($AllItems.ContainsKey($_.Name)) {
                    $ArchiveFile = New-Object -TypeName psobject -Property @{
                        Name = $_.Name
                        Path = $_.FullName
                        LastWriteTime = $_.LastWriteTime
                    }
                
                    $CurrLastWriteTime = $AllItems.($_.Name)[0]
                    $CurrFullName = $AllItems.($_.Name)[1]

                    # If this file is newer than what was previously found, archive old and add this to list
                    if ($_.LastWriteTime -gt $CurrLastWriteTime) {
                        Write-Verbose "[$($_.Name)] found in list already, this one is newer, archiving older copy..."

                        If ($PSCmdlet.ShouldProcess($CurrFullName, 'Archive Item')) {
                            # Archive the old item and log it
                            $ArchiveFile.LastWriteTime = $CurrLastWriteTime
                            $ArchiveFile.Path = $CurrFullName
                            $ArchiveFile | Export-Csv -Path $Log -Append -NoTypeInformation
                            Move-Item -Path $CurrFullName -Destination $DupeDir
                        }

                        # Add our new item to the list
                        $CurrLastWriteTime = $_.LastWriteTime
                        $CurrFullName = $_.FullName

                    # If this file is older than what was previously found, archive it
                    } else {
                        Write-Verbose "[$($_.Name)] found in list already, this one has older date, archiving..."
                        If ($PSCmdlet.ShouldProcess($_.FullName, 'Archive Item')) {
                            # Archive this item and log it
                            $ArchiveFile | Export-Csv -Path $Log -Append -NoTypeInformation
                            Move-Item -Path $_.FullName -Destination $DupeDir
                        }
                    }
                } else {
                    Write-Verbose "Adding [$($_.Name)] to list..."
                    $AllItems.Add($_.Name, @($_.LastWriteTime, $_.FullName))
                }
            }
	    }
    }
}