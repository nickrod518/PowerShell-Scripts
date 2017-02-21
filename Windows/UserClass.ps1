#requires -Version 5.0

class User {
    [string]$Name
    [string]$Domain
    [string]$Computer
    [string]$LastLogin
    [string]$Path
    
    # Constructor
    User([string]$Computer, [string]$Domain, [string]$Name) {
        [string]$this.Name = $Name
        [string]$this.Domain = $Domain
        [string]$this.Computer = $Computer
        [string]$this.LastLogin = $this.GetLastLogin()
        [string]$this.Path = $this.GetProfilePath()
    }

    # Clears all values of the object
    Clear() {
        [string]$this.Name = [string]$null
        [string]$this.Domain = [string]$null
        [string]$this.Computer = [string]$null
        [string]$this.LastLogin = [string]$null
        [string]$this.Path = [string]$null
    }

    [string] GetLastLogin() {
        return [User]::GetLastLogin($this.Domain, $this.Name)
    }

    # Get the last login date of the user according to the local database
    static [string] GetLastLogin([string]$Domain, [string]$Name) {
        $CurrentUser = try { ([ADSI]"WinNT://$Domain/$Name") } catch { }

        if ($CurrentUser.Properties.LastLogin) {
            try {
                return [datetime](-join $CurrentUser.Properties.LastLogin)
            } catch {
                return -join $CurrentUser.Properties.LastLogin
            }
        } else {
            return $null
        }
    }
    
    [string] GetProfilePath() {
        return [User]::GetProfilePath($this.Domain, $this.Name)
    }

    # Get the user's Windows user directory
    static [string] GetProfilePath([string]$Domain, [string]$Name) {
        $UserObject = New-Object System.Security.Principal.NTAccount($Domain, $Name)

        try {
            $SID = $UserObject.Translate([System.Security.Principal.SecurityIdentifier])
        } catch {
            return $_.Exception.Message
        }

        $User = Get-ItemProperty -Path "Registry::HKLM\Software\Microsoft\Windows NT\CurrentVersion\ProfileList\$($SID.Value)"

        return $User.ProfileImagePath
    }

    # Get all users on computer
    static [User[]] GetUsers() {
        [User[]]$Users = @()

        # Get all user profiles on this PC and let the user select which ones to migrate
        $RegKey = 'Registry::HKLM\Software\Microsoft\Windows NT\CurrentVersion\ProfileList\*'

        # Return each profile on this computer
        Get-ItemProperty -Path $RegKey | ForEach-Object {
            try {
                $SID = New-object System.Security.Principal.SecurityIdentifier($_.PSChildName)

                try {
                    $User = $SID.Translate([System.Security.Principal.NTAccount]).Value
                    $Users += [User]::new($env:COMPUTERNAME, $User.Split('\')[0], $User.Split('\')[1])
                } catch {
                    Write-Warning "Error while translating $SID to a user name."
                }
            } catch {
                Write-Warning "Error while translating $($_.PSChildName) to SID."
            }
        }

        return $Users
    }
}