function Send-CatFactMessage {
    <# 
    .SYNOPSIS 
        Send a cat fact to users on a computer.
    .DESCRIPTION 
        Send a random cat fact to any number of computers and all users or a specific user. Supports credential passing.
    .EXAMPLE 
        Send-CatFactMessage
        Sends cat fact message to all users on localhost.
    .EXAMPLE 
        Get-ADComputer -Filter * | Send-CatFactMessage -UserName JDoe -Credential (Get-Credential)
        Send cat fact to jDoe on all AD computers. Prompt user for credentials to run command with.
    .EXAMPLE
        Send-CatFactMessage -ComputerName pc1, pc2, pc3
        Send cat fact to all users on provided computer names.
    .PARAMETER ComputerName 
        The computer name to execute against. Default is local computer.
    .PARAMETER UserName 
        The name the user to display the message to. Default is all users.
    .PARAMETER Credential
        The credential object to execute the command with.
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]$ComputerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $false)]
        [string]$UserName = '*',

        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential
    )

    $CatFact = (ConvertFrom-Json (Invoke-WebRequest -Uri 'http://catfacts-api.appspot.com/api/facts')).facts

    if ($pscmdlet.ShouldProcess("User: $UserName, Computer: $ComputerName", "Send cat fact, $CatFact")) {
        if ($Credential) {
            Write-Verbose "Sending cat fact using credential $($Credential.UserName)"

            Invoke-Command -ComputerName $ComputerName -ScriptBlock { msg $args[0] $args[1] } `
                -ArgumentList $UserName, $CatFact -Credential $Credential
        } else {
            Invoke-Command -ComputerName $ComputerName -ScriptBlock { msg $args[0] $args[1] } `
                -ArgumentList $UserName, $CatFact
        }
    }
}