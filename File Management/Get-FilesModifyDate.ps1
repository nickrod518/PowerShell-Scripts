# Get the path this script is running from
$ScriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent

# Array to store our info in
$Output = @()

# Servers we're checking
$Servers = @('server01', 'server02')

# Path we're checking
$Path = 'ShareName'

# Loop through each server
ForEach ($Server in $Servers) {
    $Output += Get-ChildItem "\\$Server\$Path" -Recurse | Where { $_.Extension -eq '.bak' }
}
 
# Create csv at script root with output
$Output | select FullName, LastWriteTime | Export-Csv "$ScriptPath\Backups.csv" -NoTypeInformation