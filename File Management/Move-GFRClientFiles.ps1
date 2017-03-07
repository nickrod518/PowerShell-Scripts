[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({
        # Validate the path
        if (Test-Path -Path $_) {
            # Validate the directory contains files
            if ((Get-ChildItem -Path $_ -File).Count) {
                $true
            } else {
                throw "Docs directory is empty"
            }
        } else {
            throw "Invalid path given: $_"
        }
    })]
    [string] $DocsPath,

    [Parameter(Mandatory = $true)]
    [ValidateScript({
        # Validate the path
        if (Test-Path -Path $_) {
            # Validate the file has the .xml extension
            if ((Get-Item -Path $_).Extension -eq '.xml') {
                $true
            } else {
                throw "HitList given does not have the '.xml' extension"
            }
        } else {
            throw "Invalid path given: $_"
        }
    })]
    [string] $HitListPath,

    [Parameter(Mandatory = $false)]
    [switch] $Copy
)

begin {
    Write-Verbose "Gathering files within $DocsPath..."
    $Docs = Get-ChildItem -Path $DocsPath -File
    $DocsCount = $Docs.Count
    Write-Verbose "$DocsCount files found."

    Write-Verbose "Importing HitList from $HitListPath (this may take a while depending on the size of the file)..."
    $HitList = [xml] (Get-Content -Path $HitListPath)
    $HitListCount = $HitList.dcs.dc.Count
    Write-Verbose "$HitListCount entries found."

    $HitListDictionary = @{}
}

process {
    $Counter = 1
    foreach ($Doc in $HitList.dcs.dc) {
        $ClientName = $Doc.i1.'#cdata-section'
        $FileName = "$($Doc.doc_name).$($Doc.tp)"

        Write-Progress -Activity "Processing HitList..." -Status "($Counter / $HitListCount)" `
            -PercentComplete ($Counter / $HitListCount * 100) -CurrentOperation "$ClientName - $FileName"

        $HitListDictionary.Add($FileName, $ClientName)
        $Counter++
    }

    if ($Copy) { Write-Verbose "Script run in 'Copy' mode - source files will remain intact." }

    $Counter = 1
    foreach ($File in $Docs) {
        try {
            $Client = $HitListDictionary.($File.Name)
            $ClientDirectory = "$DocsPath\$Client"

            Write-Progress -Activity "Processing Docs..." -Status "($Counter / $DocsCount)" `
                -PercentComplete ($Counter / $DocsCount * 100) -CurrentOperation $File.FullName

            if (-not (Test-Path -Path $ClientDirectory)) {
                New-Item -Path $ClientDirectory -ItemType Directory
            }
            if ($Copy) {
                Copy-Item -Path $File.FullName -Destination $ClientDirectory
            } else {
                Move-Item -Path $File.FullName -Destination $ClientDirectory
            }
        } catch {
            Write-Error -Message "Error processing $($File.FullName): $($_.Exception.Message)"
        } finally {
            $Counter++
        }
    }
}