function Send-CatFactMessage {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string[]]$ComputerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $false)]
        [string]$UserName = '*',

        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential
    )

    

    $CatFact = (ConvertFrom-Json (Invoke-WebRequest -Uri 'http://catfacts-api.appspot.com/api/facts')).facts

    Write-Verbose "Sending cat fact to user $UserName on computer $ComputerName"
    Write-Verbose "Fact: $CatFact"

    if ($Credential ) {
        Write-Verbose "Sending cat fact using credential $($Credential.UserName)"

        Invoke-Command -ComputerName $ComputerName -ScriptBlock { msg $args[0] $args[1] } `
            -ArgumentList $UserName, $CatFact -Credential $Credential
    } else {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock { msg $args[0] $args[1] } `
            -ArgumentList $UserName, $CatFact
    }
}