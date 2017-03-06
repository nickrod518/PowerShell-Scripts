function Read-YesOrNo {
    param ([string] $Message)

    $Prompt = Read-Host $Message
    while ('yes', 'no' -notcontains $Prompt) { $Prompt = Read-Host "Please enter either 'yes' or 'no'" }
    if ($Prompt -eq 'yes') { $true } else { $false }
}