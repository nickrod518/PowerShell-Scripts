# Throttle concurrent jobs
function Limit-Job {
	[CmdletBinding()]
	param ([int]$MaxJobs = 2)

    $Messaged = $false

    while ((($Jobs = Get-Job -State Running) | Measure-Object).Count -ge $MaxJobs) {
        if (-not $Messaged) {
            Write-Verbose "Waiting on jobs to complete before starting more (limit is $MaxJobs): $($Jobs.Name)"
            $Messaged = $true
        }

        Start-Sleep -Seconds 1
    }
}
	
# Clear completed jobs
function Clear-CompletedJob {
	[CmdletBinding()]
	param ()

	foreach ($Job in Get-Job) {
		if ($Job.State -eq 'Completed') {
            if ($Global:SuppressJobResults) {
                Write-Verbose "$($Job.Name) job completed."
            } else {
                Write-Verbose "$($Job.Name) job completed with the following results:"
                Receive-Job $Job
            }
			Remove-Job $Job
		}
	}
}

# Wait for the remaining jobs to complete
function Wait-CompletedJob {
	[CmdletBinding()]
	param ()

    $OldCount = 0
    while ($Jobs = Get-Job) {
        $JobCount = ($Jobs | Measure-Object).Count
        if ($JobCount -ne $OldCount) {
            Write-Verbose "Waiting on $JobCount job(s) to complete: $($Jobs.Name)"
            $OldCount = $JobCount
        }

		Clear-CompletedJob
		Start-Sleep -Seconds 1
	}

    Write-Verbose 'All jobs completed.'
}

Export-ModuleMember -Function *