# define the proper headers for the users and unity files, so we can validate the files are in the correct csv format
$correctHeaders = @(
	'Valid', 'Headers', 'To', 'Check', 'For'
)

function Validate-CSVHeaders ($correctHeaders) {
    # validate the headers are identical if the user chooses
    [ValidateSet('Yes','No')]$validateHeaders = Read-Host "Validate headers?"
    if ($validateHeaders -eq 'Yes') {
	    # put all the headers into a comma separated array
	    $headers = (Get-Content $fileName | Select-Object -First 1).Split(",")
	    for ($i = 0; $i -lt $headers.Count; $i++) {
		
		    # trim any leading white space and compare the headers
		    if ($headers[$i].TrimStart() -ne $correctHeaders[$i]) {
			    Add-Content $Script:logOutput "$(Get-Date) - $fileName failed to validate headers because header number $i showed $($headers[$i].TrimStart()) instead of $($correctHeaders[$i])."
			    Write-Host "$fileName failed to validate headers because header number $i showed $($headers[$i].TrimStart()) instead of $($correctHeaders[$i]); please try again."
			    Import $type
		    }
	    }
    }
}

Validate-CSVHeaders $correctHeaders