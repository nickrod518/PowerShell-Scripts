begin {
    $RootDirectory = '\\server\users'
    [long] $Script:Threshold = 5GB

    function Format-Size {
        param (
            [Parameter(Mandatory = $true)]
            [long] $Size
        )

        if ($Threshold -gt 1GB) {
            "{0:N2}" -f ($Size / 1GB) + ' GB'
        } else {
            "{0:N2}" -f ($Size) + ' MB'
        }
    }

    function Measure-Content {
        param (
            [Parameter(Mandatory = $true)]
            [string] $DirectoryPath
        )

        $Contents = Get-ChildItem $DirectoryPath -Recurse -Force -ErrorAction Continue | Where-Object { $_.PSIsContainer -eq $false }
        [long] ($Contents | Measure-Object -Property Length -Sum | Select-Object Sum).Sum
    }


    function Measure-Directory {
        param (
            [Parameter(Mandatory = $true)]
            [string] $RootDirectory
        )

        Write-Output "Measuring children of $RootDirectory`n`n"

        $LargeDirectories = @()

        Get-ChildItem $RootDirectory | Where-Object { $_.PSIsContainer -eq $true } | ForEach-Object {
            Write-Output "Measuring $_"

            [long] $Size = Measure-Content $_.FullName

            if ($Size -gt $Threshold) {
                $LargeDirectories += New-Object psobject -Property @{
                    Size = Format-Size $Size
                    Path = $_.FullName
                    Directory = $_.Name
                }
            }
        }

        $Script:LargeDirectories
    }
}

process {
    Start-Transcript ".\logs\DirectoryLargerThan$(Format-Size $Threshold)-$(Get-Date -Format yyyy-MM-dd-HHmm).txt"
    Measure-Directory $RootDirectory
    Write-Output "`n`n`n`nThere are $($Results.Count) directories larger than $(Format-Size $Threshold)`n"
    $LargeDirectories | Format-Table -AutoSize
}

end { Stop-Transcript }