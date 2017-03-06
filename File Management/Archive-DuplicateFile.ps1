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
                # Don't search for duplicates within the directory we're archiving to
                $_.FullName -notlike "$DupeDir\*"
            } | ForEach-Object {
                Write-Host $_.FullName

                # Check if the file name exists in our list
                if ($AllItems.ContainsKey($_.Name)) {

                    # Create an object with details about the item we're about to archive
                    $ArchiveFile = New-Object -TypeName psobject -Property @{
                        Name = $_.Name
                        OriginalPath = $_.FullName
                        ArchivePath = ''
                        LastWriteTime = $_.LastWriteTime
                        Error = ''
                    }
                
                    $PreviousLastWriteTime = $AllItems.($ArchiveFile.Name)[0]
                    $PreviousFullName = $AllItems.($ArchiveFile.Name)[1]

                    # If this file is newer than what was previously found, archive old and add this to list
                    if ($ArchiveFile.LastWriteTime -gt $PreviousLastWriteTime) {
                        Write-Verbose "[$($ArchiveFile.Name)] found already, this one is newer, archiving [$PreviousFullName]..."

                        if ($PSCmdlet.ShouldProcess($PreviousFullName, 'Archive Item')) {
                            # Archive the old item and add the new item to the list
                            $ArchiveFile.ArchivePath = $PreviousFullName.Replace($Dir, $DupeDir)
                            try {
                                New-Item -Path $ArchiveFile.ArchivePath.TrimEnd($_.Name) -ItemType Directory -Force
                                Move-Item -Path $PreviousFullName -Destination $ArchiveFile.ArchivePath -Force
                            } catch {
                                $ArchiveFile.Error = $_.Exception.Message
                            }
                            $ArchiveFile.LastWriteTime = $PreviousLastWriteTime
                            $ArchiveFile.OriginalPath = $PreviousFullName

                            # Update what we have in our list
                            $AllItems.($ArchiveFile.Name)[0] = $PreviousLastWriteTime
                            $AllItems.($ArchiveFile.Name)[1] = $PreviousFullName
                        }

                    # If this file is older than what was previously found, archive it
                    } else {
                        Write-Verbose "[$($ArchiveFile.Name)] found already, this one is older, archiving [$($_.FullName)]..."
                        
                        if ($PSCmdlet.ShouldProcess($_.FullName, 'Archive Item')) {
                            # Archive this item
                            $ArchiveFile.ArchivePath = $_.FullName.Replace($Dir, $DupeDir)
                            try {
                                New-Item -Path $ArchiveFile.ArchivePath.TrimEnd($_.Name) -ItemType Directory -Force
                                Move-Item -Path $_.FullName -Destination $ArchiveFile.ArchivePath -Force
                            } catch {
                                $ArchiveFile.Error = $_.Exception.Message
                            }
                        }
                    }

                    # Log it
                    $ArchiveFile | Export-Csv -Path $Log -Append -NoTypeInformation

                } else {
                    # Item is unique so add it to the list
                    $AllItems.Add($_.Name, @($_.LastWriteTime, $_.FullName))
                }
            }
	    }
    }
}