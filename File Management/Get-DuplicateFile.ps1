function Get-DuplicateFile {
	[CmdletBinding(SupportsShouldProcess = $true)]
	Param (
		[Parameter(
			Mandatory = $false,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
        [ValidateScript({
            if (Test-Path -Path $_ -PathType Container) {
                $true
            } else {
                throw "[$_] is not a valid directory."
                $false
            }
        })]
		[string[]]$Directory = '.'
	)
	
    begin {
        $AllItems = @()
    }

    process {
	    foreach ($Dir in $Directory) {
		    Write-Verbose "Getting all files within [$Dir]..."
		    $AllItems += Get-ChildItem -Path $Dir -File -Recurse -Force -ErrorAction Continue
	    }

        $AllItems | Group-Object -Property Name | Where-Object { $_.Count -gt 1 } | ForEach-Object {
            $_.Group | ForEach-Object { $_ }
        }
    }
}