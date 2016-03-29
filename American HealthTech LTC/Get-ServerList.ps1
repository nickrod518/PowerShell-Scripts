Function Get-ServerList {
    Add-PSSnapin citrix* -ErrorAction SilentlyContinue | Out-Null
    Get-PSSnapin citrix* -ErrorAction SilentlyContinue | Out-Null
    $Groups = Get-XAWorkerGroup
    
    Write-Host "Select a server group:`n"
    
    $Menu = @{}
    Write-Host "1. Single Server"
    $Menu.Add(1, "Single Server")
    for ($i = 2; $i -le ($Groups.Count + 1); $i++) {
        Write-Host "$i. $($Groups[$i - 2].WorkerGroupName)"
        $Menu.Add($i, ($Groups[$i - 2].WorkerGroupName))
    }

    [int]$Choice = Read-Host "`nEnter selection"    
    while(-not $Menu.ContainsKey($Choice)) {
    	$Choice = Read-Host "Please choose a valid number from the list."
    }
    
    $Continue = Read-Host "`nYou chose $($Menu[$Choice]); continue (yes/no)?"
    while("yes","no" -notcontains $Continue) {
    	$Continue = Read-Host "You chose $($Menu[$Choice]); continue (yes/no)?"
    }

    if ($Continue -eq 'no') {
        Exit
    }
    
    Clear-Host
    if ($Choice -ne 1) {
        Write-Host "You selected $($Menu[$Choice]):"
        $Group = $Groups | where { $_.WorkerGroupName -eq $Menu[$Choice] }
        $Group.ServerNames | ForEach-Object {
            Write-Host $_
        }
        Return $Group.ServerNames
    } else {
        $Server = Read-Host "Enter the name of a server"
        Write-Host "Deploying to $Server."
        Return $Server
    }   
}