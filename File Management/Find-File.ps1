<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2016 v5.2.126
	 Created on:   	8/10/2016 10:49 AM
	 Created by:   	Nick Rodriguez
	 Organization: 	DHG
	 Filename:     	Find-File.ps1
	===========================================================================
	.DESCRIPTION
		Search computer for file names matching given string.
#>

function Find-File {
	[CmdletBinding(
		SupportsShouldProcess = $true
	)]
	Param (
		[Parameter(
			Mandatory = $false,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
		[string[]]$ComputerName = $env:COMPUTERNAME,
		
		[Parameter(
			Mandatory = $true
		)]
		[string[]]$FileName
	)
	
	foreach ($Computer in $ComputerName) {
		foreach ($Name in $FileName) {
			Write-Verbose "Searching $Computer for $Name..."
			Get-ChildItem -Path "\\$Computer\c$" -File -Recurse -Force -ErrorAction Continue | Where-Object {
				$_.Name -like $Name
			} | Select-Object FullName
		}
	}
}

Find-File -FileName '*maid*' -Verbose