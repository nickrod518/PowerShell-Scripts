function Remove-OldProfiles {
	[CmdletBinding(
		SupportsShouldProcess = $true,
		ConfirmImpact = 'High'
	)]
	Param (
		[Parameter(
			Mandatory = $false,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
		[string[]]$ComputerName = 'localhost',
		
		[Parameter(
			Mandatory = $false
		)]
		[int]$DaysOld = 180
	)
	
	begin {
		. 'C:\MSIshare\Scripts\Get-ServerList.ps1'
        . 'C:\MSIshare\Scripts\Tools\Get-FolderSize.ps1'
		
		# https://helgeklein.com/free-tools/delprof2-user-profile-deletion-tool/
		$DelProf2 = 'C:\Tools\DelProf2.exe'
		
		function Get-UserProfiles {
			[CmdletBinding()]
			param (
				[Parameter(
					Mandatory = $false,
					ValueFromPipeline = $true,
					ValueFromPipelineByPropertyName = $true
				)]
				[string]$ComputerName = 'localhost'
			)
			
			Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                # Get all user profiles on this PC and let the user select one to migrate
				$RegKeyProfileList = 'Registry::HKey_Local_Machine\Software\Microsoft\Windows NT\CurrentVersion\ProfileList\*'
				
				# Return each profile on this computer
				Get-ItemProperty -Path $RegKeyProfileList | ForEach-Object {
					$UserObject = New-Object -TypeName PSObject
					$UserObject | Add-Member -MemberType NoteProperty -Name UserName -Value $null
					$UserObject | Add-Member -MemberType NoteProperty -Name SID -Value $_.PSChildName
					$UserObject | Add-Member -MemberType NoteProperty -Name Path -Value $_.ProfileImagePath
                    
					try {
						$SID = New-Object System.Security.Principal.SecurityIdentifier($_.PSChildName)
						$UserObject.UserName = $SID.Translate([System.Security.Principal.NTAccount]).Value
					} catch {
						Write-Warning "Error while translating $SID to a user name."
					} finally {
						Write-Output $UserObject
					}
				}
			}
		}
	}
	
	process {
		foreach ($Computer in $ComputerName) {
			Write-Verbose "Processing $Computer..."
            
            $Profiles = Get-UserProfiles -ComputerName $Computer
            $SumSize = (Get-FolderSize "\\$Computer\c$\users").TotalGBytes
            
            $ProfilesObject = New-Object -TypeName PSObject
			$ProfilesObject | Add-Member -MemberType NoteProperty -Name Computer -Value $Computer
			$ProfilesObject | Add-Member -MemberType NoteProperty -Name BeforeCount -Value $Profiles.Count
			$ProfilesObject | Add-Member -MemberType NoteProperty -Name BeforeSizeGB -Value $SumSize
            $ProfilesObject | Add-Member -MemberType NoteProperty -Name AfterCount -Value $null
            $ProfilesObject | Add-Member -MemberType NoteProperty -Name AfterSizeGB -Value $null
			
			Write-Verbose "Before: Found $($Profiles.Count) profiles with a total size of $SumSize GB."
			
			$Command = "$DelProf2 /c:$Computer /d:$DaysOld"
			
			if ($pscmdlet.ShouldProcess($Computer, 'Remove-OldProfiles')) {
				# The real deal
				cmd /c "$Command /l" | Write-Verbose
			} else {
				cmd /c "$Command /l" | Write-Verbose
			}
            
            $Profiles = Get-UserProfiles -ComputerName $Computer
            $SumSize = (Get-FolderSize "\\$Computer\c$\users").TotalGBytes
            
			$ProfilesObject.AfterCount = $Profiles.Count
            $ProfilesObject.AfterSizeGB = $SumSize
            
            Write-Verbose "After: Found $($Profiles.Count) profiles with a total size of $SumSize GB."
            
            Write-Output $ProfilesObject
		}
	}
}

$Results = Get-ServerList -Verbose | Remove-OldProfiles -DaysOld 180 -WhatIf -Verbose
$Results | Format-Table -AutoSize