function Send-CatFactMessage {
    <# 
    .SYNOPSIS 
        Send a cat fact to users on a computer.

    .DESCRIPTION 
        Send a random cat fact to any number of computers and all users or a specific user. Supports credential passing.
    
    .EXAMPLE 
        Send-CatFactMessage -PlayAudio
        Sends cat fact message to all users on localhost and outputs fact through speakers.
    
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
    
    .PARAMETER PlayAudio
        Use Windows Speech Synthesizer to output the fact using text to speech.
    
    .PARAMETER DisplaySeconds
        Seconds to display the message on the user's screen. Default is 0, which waits for the user to click a button.
    
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
        [switch]$PlayAudio,

        [Parameter(Mandatory = $false)]
        [int]$DisplaySeconds = 0,

        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $CatFact = Invoke-RestMethod -Uri 'https://catfact.ninja/fact' -Method Get |
        Select-Object -ExpandProperty fact

    if ($pscmdlet.ShouldProcess("User: $UserName, Computer: $ComputerName", "Send cat fact, $CatFact")) {
        $ScriptBlock = {
            param (
                [Parameter(Mandatory = $true)]
                [string]$UserName,

                [Parameter(Mandatory = $true)]
                [string]$CatFact,

                [Parameter(Mandatory = $true)]
                [bool]$PlayAudio = $false,

                [Parameter(Mandatory = $true)]
                [int]$DisplaySeconds
            )

            if ($DisplaySeconds -gt 0) {
                msg $UserName /time:$DisplaySeconds $CatFact
            } else {
                msg $UserName $CatFact
            }

            if ($PlayAudio) {
                Add-Type -AssemblyName System.Speech
                $SpeechSynth = New-Object System.Speech.Synthesis.SpeechSynthesizer
                $SpeechSynth.Speak($CatFact)
            }
        }

        $Params = @{
            'ComputerName' = $ComputerName
            'ScriptBlock' = $ScriptBlock
            'ArgumentList' = @($UserName, $CatFact, $PlayAudio, $DisplaySeconds)
            'AsJob' = $true
        }
        if ($Credential) { $Params.Add('Credential', $Credential) }
        
        Invoke-Command @Params

        Get-Job | Wait-Job | Receive-Job
        Get-Job | Remove-Job
    }
}