# https://support.microsoft.com/en-us/kb/3108269

# Connect to MS Online
Connect-MsolService

# Get the license name
$licenseObj = Get-MsolAccountSku | Where-Object {$_.SkuPartNumber -eq "PLANNERSTANDALONE"} 
$license = $licenseObj.AccountSkuId

# Give license to all users
#Get-MSOLUser | Set-MsolUserLicense -AddLicenses $license 

# Give license based on department and whether they're active
$Department = Get-MSOLUser -All | Where-Object { ($_.Department -like "*Department*") -and ($_.isLicensed -eq 'True')  } 
$Department | Set-MsolUserLicense -AddLicenses $license -Verbose

# Verify licenses
$Department | Select-Object DisplayName, Licenses