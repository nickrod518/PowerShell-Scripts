function ConvertTo-Domain {
	[cmdletbinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string] $UserPrincipalName
    )

	# Extract domain from user email
	($UserPrincipalName.Split('@')[1]).Split('.')[0]
}
		
function ConvertTo-FormattedUserName {
	[cmdletbinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string] $UserPrincipalName
    )

	# Replace .'s and @'s with _'s to get a SPO URL friendly name
	$UserPrincipalName -replace '([.|@]+)', '_'
}

function Remove-SpecialCharacters {
	[cmdletbinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string]$String
    )

    # Replace # and % with _ to get a SPO URL friendly name
    #$NewString = $String -replace '([#|%]+)', '_'
    $NewString = $String.Replace('#', '_').Replace('%', '_')
	if ($NewString -ne $String) {
		Write-Warning "Special character '#' or '%' was replaced with '_' in $String, new name is $NewString"
	}

	Write-Output $NewString
}

function Move-Folder {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
		[string]$SourceFolderPath,
			
		[Parameter(Mandatory = $true)]
		[string]$DestinationFolderPath
    )

    # Try Move-Item first, and use robocopy if that fails
	Try {
		Move-Item $SourceFolderPath $DestinationFolderPath -Force -ErrorAction Stop
		Write-Verbose "Successfully moved folder from [$SourceFolderPath] to [$DestinationFolderPath]."
	} Catch {
		robocopy $SourceFolderPath $DestinationFolderPath /MOVE /E /COPYALL /r:6 /w:5
		if ($LASTEXITCODE -lt 8) {
			Write-Verbose "Successfully moved folder from [$SourceFolderPath] to [$DestinationFolderPath] using robocopy."
		} else {
			Write-Error "Error while moving folder from [$SourceFolderPath] to [$DestinationFolderPath] using robocopy. `n$_"
		}
	}
}

function Test-OneDriveSite {
    [cmdletbinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string] $UserPrincipalName,

        [Parameter(Mandatory = $false)]
        [string] $TenantDomain = (ConvertTo-Domain $UserPrincipalName)
    )

    $URL = "https://$TenantDomain-my.sharepoint.com/personal/$(ConvertTo-FormattedUserName $UserPrincipalName)"

    # Test if the site exists
    try {
        Get-SPOSite -Identity $URL | Out-Null
        Write-Verbose "OneDrive site exists for $UserPrincipalName."
        $true
    } catch {
        Write-Verbose "OneDrive site not found for $UserPrincipalName."
        $false
    }
}

function Test-OneDrivePath {
    [CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[Parameter(Mandatory = $true)]
		[Microsoft.SharePoint.Client.Web]$Web,
				
		[Parameter(Mandatory = $true)]
		[string]$RelativeUrl,
        
        [Parameter(Mandatory = $false)]
        [switch]$Directory
	)

    $Context = $Web.Context

    if ($Directory) {
        $Path = $Web.GetFolderByServerRelativeUrl($RelativeUrl)
    } else {
        $Path = $Web.GetFileByServerRelativeUrl($RelativeUrl)
    }

    $Context.Load($Path)

    try {
        $Context.ExecuteQuery()
        return $true
    } catch [Microsoft.SharePoint.Client.ServerException] {
        return $false
    } catch {
        Write-Error "An unhandled exception occured while testing path [$RelativeUrl]: `n$_"
        $_ | select *
		return $false
    }
}

function New-OneDriveSite {
    [cmdletbinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string] $UserPrincipalName,

        [Parameter(Mandatory = $false)]
        [string] $TenantDomain = (ConvertTo-Domain $UserPrincipalName)
    )

    begin { }

    process {
        if (-not (Test-OneDriveSite $UserPrincipalName)) {
            if ($pscmdlet.ShouldProcess($UserPrincipalName, 'Provision OneDrive site')) {
                $URL = "https://$TenantDomain-my.sharepoint.com/personal/$(ConvertTo-FormattedUserName $UserPrincipalName)"

                Write-Verbose "Provisioning OneDrive site for $UserPrincipalName..."
            
                # Try to provision a OneDrive site
                try {
                    Write-Verbose "Site creation request submitted for $UserPrincipalName..."
                    Request-SPOPersonalSite -UserEmails $UserPrincipalName
                    Write-Verbose "Success processing SPO personal site request for $UserPrincipalName!"
                } catch { 
                    Write-Error "Error processing SPO personal site request for $UserPrincipalName!"
                    return
                }

                # Check every 10 seconds for 10 minutes if the site exists
                $EndTime = (Get-Date -Format mm) - 50
                while (((Get-Date -Format mm) - 60) -lt $EndTime) {
                    Start-Sleep -Seconds 10
                    try {
                        $Site = Get-SPOSite -Identity $URL
                        Write-Verbose "Site for $UserPrincipalName is now available for at $URL!"
                        return $Site
                    } catch { }
                }

                Write-Error "Site $URL is still not available after waiting 10 minutes."
            }
        }
    }

    end { }
}
	
function Set-OneDriveAdmin {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[Parameter(Mandatory = $true)]
		[string]$User,
				
		[Parameter(Mandatory = $true)]
		[string]$Admin,
				
		[Parameter(Mandatory = $true)]
		[ValidateSet('Add', 'Remove')]
		[string]$Action,

        [Parameter(Mandatory = $false)]
        [string] $TenantDomain = (ConvertTo-Domain $UserPrincipalName)
	)

	$FormattedName = ConvertTo-FormattedUserName $User
			
	switch ($Action) {
		Add {
			$Verb = 'Adding'
			$Set = $true
		}
		Remove {
			$Verb = 'Removing'
			$Set = $false
		}
	}

    $SiteURL = "https://$TenantDomain-my.sharepoint.com/personal/$FormattedName"
			
    if ($pscmdlet.ShouldProcess($SiteURL, "$Verb $Admin as OneDrive site collection administrator")) {
		try {
			Set-SPOUser -Site $SiteURL -LoginName $Admin -IsSiteCollectionAdmin $Set
			Write-Verbose "Success $Verb $Admin as OneDrive site collection administrator of $User"
		} catch {
			Write-Error "Error $Verb $Admin as OneDrive site collection administrator of $User`: `n$_"
			$_
		}
    }
}
		
function Set-FolderOwner {
	[CmdletBinding(SupportsShouldProcess = $true)]
	[Parameter(Mandatory = $True)]
	[String]$SourceFolderPath
			
    if ($pscmdlet.ShouldProcess($SourceFolderPath, 'Take ownership and set ACL permissions')) {
		# Take ownership of the folder as the local Administrators group
		Write-Verbose "Taking ownership of $SourceFolderPath..."
		takeown.exe /f $SourceFolderPath /a /r /d Y
			
		# Capture a snapshot of the current ACLs on the user folder
		$CurrentACL = Get-Acl $SourceFolderPath
			
		# Create and add a rule for the SYSTEM group
		$SystemACLPermission = "NT AUTHORITY\SYSTEM", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow"
		$SystemAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $SystemACLPermission
		$CurrentACL.AddAccessRule($SystemAccessRule)
			
		# Create and add a rule for the Domain Admins group
		$DomainAdminsPermission = "CORP\Domain Admins", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow"
		$DomainAdminsRule = New-Object System.Security.AccessControl.FileSystemAccessRule $DomainAdminsPermission
		$CurrentACL.AddAccessRule($DomainAdminsRule)
			
		# Set the new ACLs
		Write-Verbose 'Setting Domain Admins and SYSTEM to have FullControl rights...'
		Set-Acl -Path $SourceFolderPath -AclObject $CurrentACL
    }
}

function New-OneDriveFolder {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[Parameter(Mandatory = $True)]
		[Microsoft.SharePoint.Client.Web]$Web,
				
		[Parameter(Mandatory = $True)]
		[Microsoft.SharePoint.Client.Folder]$ParentFolder,
				
		[Parameter(Mandatory = $True)]
		[String]$FolderRelativeUrl
	)

	$FolderNames = $FolderRelativeUrl.Trim().Split('/', [System.StringSplitOptions]::RemoveEmptyEntries)
	$FolderName = Remove-SpecialCharacters $FolderNames[0]

    if (Test-OneDrivePath -Web $Web -RelativeUrl "$($ParentFolder.ServerRelativeUrl)$FolderRelativeUrl" -Directory) {
        Write-Warning "Skipping [$($ParentFolder.ServerRelativeUrl)$FolderRelativeUrl] because it already exists."
        return $true
	} else {
        if ($pscmdlet.ShouldProcess($FolderName, 'Create folder in OneDrive')) {
		    Write-Verbose "Creating folder [$FolderName] ..."
		    $CurFolder = $ParentFolder.Folders.Add($FolderName)
		    $Web.Context.Load($CurFolder)
		    $Web.Context.ExecuteQuery()
		    Write-Verbose "Folder [$FolderName] has been created succesfully. Url: $($CurFolder.ServerRelativeUrl)"
			
		    if ($FolderNames.Length -gt 1) {
			    $CurFolderUrl = [System.String]::Join('/', $FolderNames, 1, $FolderNames.Length - 1)
			    New-OneDriveFolder -Web $Web -ParentFolder $CurFolder -FolderRelativeUrl $CurFolderUrl
		    }

            return Test-OneDrivePath -Web $Web -RelativeUrl "$($ParentFolder.ServerRelativeUrl)$FolderRelativeUrl" -Directory
        } else {
            Write-Verbose "Generated URL destination of folder would be $FolderRelativeUrl."
            return $true
        }
    }
}
		
function New-OneDriveFile {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[Parameter(Mandatory = $true)]
		[Microsoft.SharePoint.Client.Web]$Web,
				
		[Parameter(Mandatory = $true)]
		[String]$FolderRelativeUrl,
				
		[Parameter(Mandatory = $true)]
		[System.IO.FileInfo]$LocalFile
	)

    $FileUrl = Remove-SpecialCharacters "$FolderRelativeUrl/$($LocalFile.Name)"

    if (Test-OneDrivePath -Web $Web -RelativeUrl $FileUrl) {
        Write-Warning "Skipping [$FileUrl] because it already exists."
        return $true
	} else {
        if ($pscmdlet.ShouldProcess($LocalFile.FullName, 'Upload file to OneDrive')) {
		    try {
			    Write-Verbose "Uploading file [$($LocalFile.FullName)] ..."

			    $FileStream = $LocalFile.OpenRead()
			    [Microsoft.SharePoint.Client.File]::SaveBinaryDirect($Web.Context, $FileUrl, $FileStream, $true)
			    $FileStream.Close()

			    Write-Verbose "File [$($LocalFile.FullName)] has been uploaded succesfully. Url: $FileUrl"
		    } catch [System.Management.Automation.MethodException] {
                $InnerException = $_.Exception.InnerException

                switch ($_.Exception.HResult) {
                    -2146233087 {
                        Write-Warning $InnerException.Message
                        Write-Verbose "Attempting to upload [$($LocalFile.FullName)] again using URI shortening..."

                        try {
                            $ShortenedFileName = $LocalFile.Name.Substring($LocalFile.Name.Length - 10)
                            $List = $Web.Lists.GetByTitle('Documents')
                            New-OneDriveFolder -Web $Web -ParentFolder $List.RootFolder -FolderRelativeUrl 'Shortened'
                            $ShortenedFileUrl = Remove-SpecialCharacters "$($List.RootFolder.ServerRelativeUrl)/Shortened/$ShortenedFileName"
                            New-Item -Path 'C:\ODTemp' -ItemType Directory -Force
                            #TODO this needs to be a unique folder name 
                            Copy-Item -Path $LocalFile.FullName -Destination "C:\ODTemp\$ShortenedFileName"
                            $TempFile = Get-Item -Path "C:\ODTemp\$ShortenedFileName"

                            $FileStream = $TempFile.OpenRead()
                            #TODO output this object?
			                [Microsoft.SharePoint.Client.File]::SaveBinaryDirect($Web.Context, $ShortenedFileUrl, $FileStream, $true)
			                $FileStream.Close()

                            Move-OneDriveFile -Web $Web -Source "$($List.RootFolder.ServerRelativeUrl)/Shortened" -Destination $FileUrl
                            Write-Verbose "File [$($LocalFile.FullName)] has been uploaded succesfully. Url: $FileUrl"
                        } catch {
                            Write-Error "An unhandled exception occured while uploading file using shortened method [$($LocalFile.FullName)]: `n$_"
                        } finally {
                            $FileStream.Close()
                            Remove-Item -Path "C:\ODTemp\$ShortenedFileName" -Recurse -Force
                            #TODO Remove folder too
                        }
                    }
                    default {
                        Write-Error "A [System.Management.Automation.MethodException] exception was caught while uploading file [$($LocalFile.FullName)]: `n$($InnerException.Message)"
                    }
                }
            } catch {
			    Write-Error "An unhandled exception occured while uploading file [$($LocalFile.FullName)]: `n$_"
		    }

            return Test-OneDrivePath -Web $Web -RelativeUrl $FileUrl
        } else {
            Write-Verbose "Generated URL destination of file would be $FileUrl."
            return $true
        }
    }
}

function Move-OneDriveFile {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[Parameter(Mandatory = $True)]
		[Microsoft.SharePoint.Client.Web]$Web,

        [Parameter(Mandatory = $false)]
		[string]$ListName = 'Documents',
				
		[Parameter(Mandatory = $True)]
		[string]$Source,
				
		[Parameter(Mandatory = $True)]
		[string]$Destination
	)

    if ($pscmdlet.ShouldProcess($Source, "Move to $Destination")) {
        try {
            $List = $Web.Lists.GetByTitle($ListName)
            $Query = [Microsoft.SharePoint.Client.CamlQuery]::CreateAllItemsQuery()
            $Query.FolderServerRelativeUrl = $Source
            $Items = $List.GetItems($Query)
            $Web.Context.Load($Items)
            $Web.Context.ExecuteQuery()

            # make sure this works
            if ($Items.Count -gt 1) {
                foreach ($Item in $Items) {
                    $DestinationFileUrl = $Item['FileRef'].ToString().Replace($Source, $Destination)
                    $Item.File.MoveTo($DestinationFileUrl, [Microsoft.SharePoint.Client.MoveOperations]::Overwrite)
                    $Web.Context.ExecuteQuery()
                    Write-Verbose "Successfully moved and renamed [$($Item['FileRef'])] to [$DestinationFileUrl]"
                }
            } else {
                $Items.File.MoveTo($Destination, [Microsoft.SharePoint.Client.MoveOperations]::Overwrite)
                $Web.Context.ExecuteQuery()
                Write-Verbose "Successfully moved and renamed [$($Items['FileRef'])] to [$Destination]"
            }
        } catch {
            Write-Error "An unhandled exception occured while collecting items at [$Source]: `n$_"
        }
    }
}

function Copy-OneDriveDirectory {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[Parameter(Mandatory = $True)]
		[String]$Url,
				
		[Parameter(Mandatory = $True)]
		[PSCredential]$Credential,
				
		[Parameter(Mandatory = $True)]
		[String]$SourceFolderPath,
				
		[Parameter(Mandatory = $False)]
		[int]$TryLimit = 5,

        [Parameter(Mandatory = $False)]
		[int]$TryDelay = 3
	)

    . 'C:\Scripts\Dependencies\Get-FolderSize.ps1'

    Write-Verbose "Upload size: $("{0:N2}" -f ((Get-FolderSize -Path $SourceFolderPath).TotalMBytes)) MB"

    $Web = Get-SharePointWeb -Url $Url -Credential $Credential
    $List = $Web.Lists.GetByTitle('Documents')
			
	$UploadError = @()

	Get-ChildItem $SourceFolderPath -Recurse | ForEach-Object {
        $Uploaded = $False
		$Try = 0

        while ((-not $Uploaded) -and ($Try -lt $TryLimit)) {
            # Sleep between tries
            if ($Try) { Start-Sleep $TryDelay }

		    if ($_.PSIsContainer -eq $true) {
			    $FolderRelativeUrl = $_.FullName.Replace($SourceFolderPath, '').Replace('\', '/')
			    $Uploaded = New-OneDriveFolder -Web $Web -ParentFolder $List.RootFolder -FolderRelativeUrl $FolderRelativeUrl
		    } else {
			    $FolderRelativeUrl = $List.RootFolder.ServerRelativeUrl + $_.DirectoryName.Replace($SourceFolderPath, '').Replace('\', '/')
				$Uploaded = New-OneDriveFile -Web $Web -FolderRelativeUrl $FolderRelativeUrl -LocalFile $_
		    }

            $Try++
        }

        if (-not $Uploaded) { $UploadError += "Error: [$($_.FullName)] => $FolderRelativeUrl" }
	}
			
	if ($UploadError.Count) {
		Write-Warning "Upload completed with [$($UploadError.Count)] errors."
		$UploadError | ForEach-Object { Write-Warning $_ }
	} else {
		Write-Verbose 'Upload completed.'
	}
}

function Import-SharePointClientComponents {
    [CmdletBinding()]
	param()

    try {
	    # Requires SharePoint client components SDK: https://www.microsoft.com/en-us/download/details.aspx?id=35585
	    Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\15\ISAPI\Microsoft.SharePoint.Client.dll"
	    Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\15\ISAPI\Microsoft.SharePoint.Client.Runtime.dll"
    } catch {
	    Write-Error "SharePoint client components not found! `n$_"
    }
}

function Get-SharePointWeb {
    [CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$Url,

        [Parameter(Mandatory = $false)]
		[string]$ListName = 'Documents',
			
		[Parameter(Mandatory = $true)]
		[PSCredential]$Credential
	)

    $Context = New-Object Microsoft.SharePoint.Client.ClientContext($Url)
    $Context.Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($Credential.UserName, $Credential.Password)
    $Web = $Context.Web
    $Context.Load($Web)
    $List = $Web.Lists.GetByTitle($ListName)
    $Context.Load($List.RootFolder)
    $Context.ExecuteQuery()

    Write-Output $Web
}

function Get-SharePointContext {
    [CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$Url,

        [Parameter(Mandatory = $false)]
		[string]$ListName = 'Documents',
			
		[Parameter(Mandatory = $true)]
		[PSCredential]$Credential
	)

    $Context = New-Object Microsoft.SharePoint.Client.ClientContext($Url)
    $Context.Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($Credential.UserName, $Credential.Password)
    $Web = $Context.Web
    $Context.Load($Web)
    $List = $Web.Lists.GetByTitle($ListName)
    $Context.Load($List.RootFolder)
    $Context.ExecuteQuery()

    Write-Output $Context
}

function Move-UserDataToOneDrive {
    [CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$UserEmail,
			
		[Parameter(Mandatory = $true)]
		[PSCredential]$Credential,
			
		[Parameter(Mandatory = $true)]
		[string]$SourceFolderPath,

        [Parameter(Mandatory = $false)]
		[string]$ArchivePath,
			
		[Parameter(Mandatory = $true)]
		[string]$LogDirectory
	)
		
	$Date = (Get-Date).ToString('yyyyMMdd-HHmm')
	Start-Transcript "$LogDirectory\$UserEmail-$Date.log"

    Import-SharePointClientComponents
		
	$TenantDomain = ConvertTo-Domain $Credential.UserName
	$FormattedUserName = ConvertTo-FormattedUserName $UserEmail
	$URL = "https://$TenantDomain-my.sharepoint.com/personal/$FormattedUserName"
		
	Connect-SPOService -Url "https://$TenantDomain-admin.sharepoint.com" -Credential $Credential

	# Make sure the user has a site before proceeding
    New-OneDriveSite -UserPrincipalName $UserEmail -TenantDomain $TenantDomain
        
	# Add admin as site admin
	Set-OneDriveAdmin -User $UserEmail -Admin $Credential.UserName -Action Add -TenantDomain $TenantDomain
		
	# Take ownership of all files in source folder
	Set-FolderOwner -SourceFolderPath $SourceFolderPath
		
	# Begin uploading files
	Copy-OneDriveDirectory -Url $URL -Credential $Credential -SourceFolderPath $SourceFolderPath -TryLimit 1 -TryDelay 1
		
	# Remove admin as site admin
	Set-OneDriveAdmin -User $UserEmail -Admin $Credential.UserName -Action Remove -TenantDomain $TenantDomain

    # Move the user's folder to the archive
    if ($ArchivePath) { Move-Folder -SourceFolderPath $SourceFolderPath -DestinationFolderPath $ArchivePath }

	Disconnect-SPOService
	Stop-Transcript
}

Export-ModuleMember -Function *