# Root path to search for files
$RootPath = 'C:\temp\test'
# File extension to filter by
$Extension = 'exe.config'

# Pairs of strings to search and replace - left is original found using regex and right is new
$ReplaceSearchPairs = @{
    # Search and replace all userID lines
    '^<add key="userID" value=.*$' = '<add key="userID" value="NewUser"/>'
    # Search and replace all password lines
    '^<add key="password" value=.*$' = '<add key="password" value="NewPass"/>'
}

# Get all the files with the given extension in the given path
$Files = Get-ChildItem -Path $RootPath -Filter "*.$Extension" -Recurse

foreach ($File in $Files.FullName) {
    try {
        foreach ($SearchString in $ReplaceSearchPairs.GetEnumerator()) {
            (Get-Content -Path $File -ErrorAction Stop) | ForEach-Object {
                $_ -replace $SearchString.Name, $SearchString.Value
            } | Set-Content -Path $File
        }
    } catch {
        Write-Error "There was a problem setting the content of [$($File)]`n`n$($_.Error.Message)"
    }
}