<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2016 v5.2.126
	 Created on:   	7/27/2016 11:37 AM
	 Created by:   	Nick Rodriguez
	 Filename:     	Get-Certificate.ps1
	===========================================================================
	.DESCRIPTION
		Get certificates installed on local or remote computers
	.PARAMETER Name
		Computer name or IP to search. Can be an array or a piped variable.
	.PARAMETER Subject
		Certificate subject name to search for. By default all subjects will be returned. Wildcards supported (e.g. "*DHG*").
	.PARAMETER DaysLeft
		Days left before a certificate expires. To return all certs that expire within 30 days, set this to 30.
	.PARAMETER NotExpired
		Use this switch to only return certificates that have not expired.
#>

function Get-Certificate {
	[cmdletbinding()]
	param (
		[Parameter(
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
		[Alias('ComputerName', 'Computer')]
		[string[]]$Name = 'localhost',

        [PSCredential]$Credential,
		
		[string]$Subject = '*'
	)

    DynamicParam {
        # Set the dynamic parameters' name
        $ParameterName = 'StorePath'
            
        # Create the dictionary 
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        # Create the collection of attributes
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            
        # Create and set the parameters' attributes
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $true
        $ParameterAttribute.Position = 2

        # Add the attributes to the attributes collection
        $AttributeCollection.Add($ParameterAttribute)

        # Generate and set the ValidateSet
        $arrSet = Get-ChildItem -Path 'Cert:' | ForEach-Object {
            $Parent = $_.Location
            Get-ChildItem -Path "Cert:\$Parent" | ForEach-Object {
               Write-Output "Cert:\$Parent\$($_.Name)"
            }
        }
 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)

        # Add the ValidateSet to the attributes collection
        $AttributeCollection.Add($ValidateSetAttribute)

        # Create and return the dynamic parameter
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    begin {
        $StorePath = $PsBoundParameters[$ParameterName]

        $ScriptBlock = {
            [cmdletbinding()]
	        param (
                [string]$StorePath,
		
		        [string]$Subject = '*'
	        )

            # Get all certs in specified store filtering by subject if provided
            Get-ChildItem -Path $StorePath | Where-Object { 
                $_.Subject -like $Subject 
            } | ForEach-Object {
                $ExtensionsFormatted = try { $_.Extensions.Format(1) } catch { }
                $Template = try { ($_.Extensions.Format(0) -replace "(.+)?=(.+)\((.+)?", '$2')[0] } catch { }
                $Days = (New-TimeSpan -End $_.NotAfter).Days

                $Cert = $_.psobject.Copy()
                $Cert | Add-Member -Name ExtensionsFormatted -MemberType NoteProperty -Value $ExtensionsFormatted
                $Cert | Add-Member -Name DaysUntilExpired -MemberType NoteProperty -Value $Days
                $Cert | Add-Member -Name Template -MemberType NoteProperty -Value $Template
                    
                Write-Output $Cert
            }
        }
    }
	
	process {
        if ($Credential) {
            Write-Verbose 'Credentials provided'
			Invoke-Command -ComputerName $Name -ScriptBlock $ScriptBlock -ArgumentList $StorePath, $Subject -Credential $Credential
        } else {
            Write-Verbose 'Credentials not provided'
            Invoke-Command -ComputerName $Name -ScriptBlock $ScriptBlock -ArgumentList $StorePath, $Subject
        }
	}
}

$Computers = @('server01', 'server03')

$Computers | Get-Certificate -Credential $Creds -StorePath Cert:\LocalMachine\AuthRoot |
    Select-Object FriendlyName, DaysUntilExpired, PSComputerName, Template, ExtensionsFormatted | Format-Table -AutoSize