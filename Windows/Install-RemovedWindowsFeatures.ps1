# Get server index numbers
dism /get-wiminfo /wimfile:d:\sources\install.wim

# Change feature name and final index number
Install-WindowsFeature -Name RDS-Gateway -Source wim:D:\sources\install.wim:1