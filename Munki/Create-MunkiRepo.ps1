$Script = {
    # Remove the port 80 binding on "Default Web Site" because we'll need that for our Munki repo
    Try {
        $Binding = Get-WebBinding -Port 80 -Name "Default Web Site"
        Write-Verbose "Port 80 binding found on Default Web Site - removing..."
        $Binding | Remove-WebBinding
    } Catch {
        Write-Verbose "Port 80 binding not found on Default Web Site - moving on..."
    }

    # Check if the Munki repo already exists
    $MunkiExists = $false
    Get-Website -Name "Munki" | ForEach-Object { 
        If ($_.Name -eq "Munki") { $MunkiExists = $true } 
    }

    # Create the Munki repo if it doesn't exist
    If ($MunkiExists) {
        Write-Verbose "Munki repo already exists - moving on..."
    } else {
        Write-Verbose "Munki repo doesn't exist - creating..."

        # Create site directory
        New-Item -ItemType Directory "R:\repo" -Force

        # Create the new Munki website
        New-Website -Name "Munki" -PhysicalPath "R:\"

        # Set MIME types
        Add-WebConfigurationProperty -PSPath IIS:\Sites\Munki -Filter system.webServer/staticContent -Name '.' -Value `
            @{ fileExtension = '.'; mimeType = 'application/octet-stream' }, # Accept all extensions
            @{ fileExtension = '*'; mimeType = 'application/octet-stream' } # Accept all files

        # Allow Directory Browsing
        Set-WebConfigurationProperty -PSPath IIS:\sites\Munki -Filter system.webServer/directoryBrowse -Name enabled -Value 'true'
    }
}

Invoke-Command -ComputerName server01 -ScriptBlock $Script