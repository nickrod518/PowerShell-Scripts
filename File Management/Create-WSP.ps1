$project = Read-Host "Folder to convert to a WSP"
$ddf = $project + ".ddf"
$cab = $project + ".cab"

# delete any preexisting ddf
if (Test-Path $ddf) {
    Clear-Content $ddf
} else {
    $ddf = New-Item -type file $ddf
}

# delete any preexisting cab
if (Test-Path $cab) {
    Remove-Item $cab
}

# create the ddf
Add-Content $ddf ".OPTION EXPLICIT"
Add-Content $ddf ".Set CabinetNameTemplate=$cab"
Add-Content $ddf ".Set Cabinet=on"
Add-Content $ddf ".Set Compress=on`n`n"

# add the manifest and any other files in the top most directory of the project
Get-ChildItem $project -File | ForEach-Object {
    $trash, $file = $_.FullName -split $project, 2
    $file = $project + $file
    $file = $([char]34) + $file + $([char]34)

    Add-Content $ddf $file
}

# create a new destination directory for each sub directory
Get-ChildItem $project -Directory -Recurse | ForEach-Object {

    # if the directory has no files, skip it
    if ($_.GetFiles().Count) {

        $trash, $folder = $_.FullName -split $project, 2
        $folder = $folder.TrimStart('\')
        $folder = $([char]34) + $folder + $([char]34)

        Add-Content $ddf "`n`n.Set DestinationDir=$folder"

        # place the files for each sub directory under its destination directory entry
        Get-ChildItem $_.FullName -File | ForEach-Object {
            $trash, $file = $_.FullName -split $project, 2
            $file = $project + $file
            $file = $([char]34) + $file + $([char]34)

            Add-Content $ddf $file
        }
    }
}

# create the cab file
Start-Process MakeCab -ArgumentList "/F ""$ddf""" -Wait

# clean up
Move-Item "disk1\$cab" .
Remove-Item -Force "disk1"
Remove-Item $ddf
Remove-Item ".\setup.inf"
Remove-Item ".\setup.rpt"

# rename to wsp
Rename-Item $cab ($project + ".wsp")
