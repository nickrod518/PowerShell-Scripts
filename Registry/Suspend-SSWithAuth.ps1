[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null

#Get User's DN
$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
$objSearcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry
$objSearcher.Filter = "(&(objectCategory=user)(SamAccountname=$($env:USERNAME)))"
$objSearcher.SearchScope = "Subtree"
$obj = $objSearcher.FindOne()
$User = $obj.Properties["distinguishedname"]

#Now get the members of the group
$Group = "Workstation Admins"
$objSearcher.Filter = "(&(objectCategory=group)(SamAccountname=$Group))"
$objSearcher.SearchScope = "Subtree"
$obj = $objSearcher.FindOne()
[String[]]$Members = $obj.Properties["member"]

If ($Members -notcontains $User) {
    [System.Windows.Forms.MessageBox]::Show("You are not authorized to run this.", "Suspend Screensaver", 0)
} Else {
    [string]$regPath = 'HKCU:\Software\Policies\Microsoft\Windows\Control Panel\Desktop\'
    [string]$status = "Time before screen saver default settings are restored:"

    # validate input; must be between 15-240
    do { [int]$minutes = Read-Host "Minutes to suspend screen saver (15-240)" }
    while ((15..240) -notcontains $minutes)

    [Int32]$seconds = $minutes * 60
    [string]$message = "Screen saver suspended for $minutes minutes..."

    # function for setting screen saver properties... saves lines later
    function Set-SS {
        Set-ItemProperty -Path $regPath -Name ScreenSaveTimeOut -Value $args[0]
        Set-ItemProperty -Path $regPath -Name ScreenSaveActive -Value $args[1]
        Set-ItemProperty -Path $regPath -Name ScreenSaverIsSecure -Value $args[2]
    }

    # disable screen saver
    Set-SS 0 0 0

    ForEach ($sec in (1..$seconds)) {
        # update progress bar every second
        Write-Progress -Activity $message -Status $status -SecondsRemaining ($seconds - $sec)

        # disable screen saver every 5 minutes
        If ( !($sec % 300) ) { Set-SS 0 0 0 }

        Start-Sleep -Seconds 1

        # restore screen saver during last second... literally
        If ($sec -eq $seconds) { Set-SS 900 1 1 }
    }
}
