#Requires –Version 3

function Get-DisabledUser {
	param (
		[Parameter(Mandatory = $true)]
		[string]$UsersFilePath,
		
		[Parameter(Mandatory = $false)]
		[ValidateSet('Email', 'FullName', 'UserID')]
		[string]$ListType = 'Email'
	)
	
	begin {
		Import-Module ActiveDirectory
		
		$Users = Get-Content -Path $UsersFilePath
		$ADUsers = Get-ADUser -SearchBase 'OU=Users,DC=company,DC=LOCAL' -Filter *
		$Results = @()
	}
	
	process {
		foreach ($User in $Users) {
			switch ($ListType) {
				'Email' { $SearchProperty = 'UserPrincipalName' }
				'FullName' { $SearchProperty = 'Name' }
				'UserID' { $SearchProperty = 'SamAccountName' }
			}
			
			$FoundUser = $ADUsers | Where-Object { $_.$SearchProperty -eq $User }
			
			$Results += New-Object -TypeName PSObject -Property @{
				SearchProperty = $User
				UserPrincipalName = $FoundUser.UserPrincipalName
				Name = $FoundUser.Name
				SamAccountName = $FoundUser.SamAccountName
				Enabled = if ($FoundUser.Enabled) { $true } else { $false }
			}
		}
		$Results | Sort-Object Enabled | Format-Table -AutoSize
	}
}

Get-DisabledUser -UsersFilePath C:\TestUsers.txt -ListType Email