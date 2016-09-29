function Get-Program {
<#
.Synopsis
Generates a list of installed programs on a computer

.DESCRIPTION
This function generates a list by querying the registry and returning the installed programs of a local or remote computer.

.NOTES   
Name: Get-Program
Author: Nick Rodriguez

.PARAMETER ComputerName
The computer to which connectivity will be checked

.PARAMETER DisplayName
The program name to search for (supports wildcards)

.PARAMETER CSVExportPath
If used, results will be exported to a CSV with the given path

.EXAMPLE
Get-Program -DisplayName 'Microsoft*'

Description:
Will generate a list of installed programs with DisplayName starting with Microsoft on local machine

.EXAMPLE
Get-Program -ComputerName server01, server02 -DisplayName 'Adobe*'

Description:
Will generate a list of installed programs with DisplayName starting with Adobe on server01 and server02

.EXAMPLE
Get-Program -ComputerName Server01

Description:
Will gather the list of programs from Server01 and their properties

.EXAMPLE
'server01', 'server02' | Get-Program

Description
Will retrieve the installed programs on server01/02 that are passed on to the function through the pipeline and also retrieves the uninstall string for each program
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            Position = 0
        )]
        [string[]]$ComputerName = $env:COMPUTERNAME,

        [string]$DisplayName = '*',

        [string]$CSVExportPath,

        [pscredential]$Credential
    )

    begin {
        $Programs = @()

        $ScriptBlock = {
            [cmdletbinding()]
	        param (
                [string]$DisplayName
            )

            $RegistryLocation = @(
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\',
                'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\'
            )

            
            foreach ($CurrentReg in $RegistryLocation) {
                Get-ChildItem -Path $CurrentReg | ForEach-Object {
                    Get-ItemProperty -Path "HKLM:\$_" | Where-Object { $_.DisplayName -like $DisplayName }
                }
            }
        }
    }

    process {
        $Programs = if ($Credential) {
            Write-Verbose 'Credentials provided'
			Invoke-Command -ComputerName $ComputerName -ScriptBlock $ScriptBlock -ArgumentList $DisplayName -Credential $Credential
        } else {
            Write-Verbose 'Credentials not provided'
            Invoke-Command -ComputerName $ComputerName -ScriptBlock $ScriptBlock -ArgumentList $DisplayName
        }

        if ($CSVExportPath) { $Programs | Export-Csv -Path $CSVExportPath -NoTypeInformation -Append }

        Write-Output $Programs
    }
}