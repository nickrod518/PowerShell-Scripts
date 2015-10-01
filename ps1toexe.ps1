# ps1 file to run
$ps1 = (Read-Host "PowerShell script").TrimEnd(".ps1") + ".ps1"
# name of the target exe, leave "exe" out, and replace spaces with underscores
$target = (Read-Host "Target name").TrimEnd(".exe") -replace " ", '_'
# supplemental files to be packaged
[array]$files = (Read-Host "Supplemental files separated by commas (leave blank if N/A)").split(",") | %{$_.trim()}

$exe = "$PSScriptRoot\$target.exe"
$sed = "$PSScriptRoot\$target.sed"

# create the sed file used by iexpress
New-Item $sed -type file -force

# populate the sed with config info
Add-Content $sed "[Version]"
Add-Content $sed "Class=IEXPRESS"
Add-Content $sed "sedVersion=3"
Add-Content $sed "[Options]"
Add-Content $sed "PackagePurpose=InstallApp"
Add-Content $sed "ShowInstallProgramWindow=0"
Add-Content $sed "HideExtractAnimation=1"
Add-Content $sed "UseLongFileName=1"
Add-Content $sed "InsideCompressed=0"
Add-Content $sed "CAB_FixedSize=0"
Add-Content $sed "CAB_ResvCodeSigning=0"
Add-Content $sed "RebootMode=N"
Add-Content $sed "TargetName=%TargetName%"
Add-Content $sed "FriendlyName=%FriendlyName%"
Add-Content $sed "AppLaunched=%AppLaunched%"
Add-Content $sed "PostInstallCmd=%PostInstallCmd%"
Add-Content $sed "SourceFiles=SourceFiles"
Add-Content $sed "[Strings]"
Add-Content $sed "TargetName=$exe"
Add-Content $sed "FriendlyName=$target"
Add-Content $sed "AppLaunched=cmd /c PowerShell -ExecutionPolicy Bypass -File `"$ps1`""
Add-Content $sed "PostInstallCmd=<None>"
Add-Content $sed "FILE0=$ps1"
# add the ps1 and supplemental files
If ($files -ne "") {
    ForEach ($file in $files) {
        $index = ([array]::IndexOf($files, $file) + 1)
        Add-Content $sed "FILE$index=$file"
    }
}
Add-Content $sed "[SourceFiles]"
Add-Content $sed "SourceFiles0=$PSScriptRoot"
Add-Content $sed "[SourceFiles0]"
Add-Content $sed "%FILE0%="
# add the ps1 and supplemental files
If ($files -ne "") {
    ForEach ($file in $files) {
        $index = ([array]::IndexOf($files, $file) + 1)
        Add-Content $sed "%FILE$index%="
    }
}

# call iexpress to create exe from the sed we just created
$iexpress = "C:\WINDOWS\SysWOW64\iexpress"
$args = "/N $sed"
Start-Process -Wait $iexpress $args

# delete the sed
Remove-Item $sed