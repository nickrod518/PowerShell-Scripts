function Find-ServiceAccount {
	[CmdletBinding(SupportsShouldProcess = $true)]
	Param (
		[Parameter(
			Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
		[string[]]$Name,

        [Parameter(
			Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
		[string[]]$ComputerName,

        [Parameter(
			Mandatory = $false,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
		[PSCredential]$Credential = (Get-Credential)
	)

    $Results = @()

    foreach ($ServiceAccount in $Name) {
        $Found = New-Object -TypeName psobject -Property @{
            Name = $ServiceAccount
            Services = @()
            SchTasks = @()
        }

        Write-Verbose "Searching services on [$ComputerName] for [$ServiceAccount]..."
        $Found.Services = Get-WmiObject -Class Win32_Service -ComputerName $ComputerName -Credential $Credential |
            Where-Object { $_.StartName -match $ServiceAccount } |
            Select-Object DisplayName, StartName, State, ProcessId, PSComputerName
        
        Write-Verbose "Searching scheduled tasks on [$ComputerName] for [$ServiceAccount]..."
        $Found.SchTasks = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            schtasks.exe /query /s localhost /V /FO CSV | ConvertFrom-Csv
        } | Where-Object { $_.'Run As User' -match $ServiceAccount } |
            Select-Object TaskName, Status, 'Task To Run', Comment, 'Run As User', PSComputerName

        $Results += $Found
    }

    $Results
}