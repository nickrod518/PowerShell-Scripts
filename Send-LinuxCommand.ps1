[CmdletBinding(SupportsShouldProcess = $true)]
Param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Linux1', 'Linux2', 'All'
    )]
    [string[]]$Server,
    [switch]$Sudo,
    [switch]$Update,
    [switch]$Upgrade,
    [switch]$DistUpgrade,
    [switch]$Clean,
    [string[]]$Install,
    [string]$Command,
    [switch]$Reboot,
    [switch]$AsJob,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [PSCredential]$Credential
)

$PLinkPath = '\\192.168.1.4\data\Programs\plink.exe'
if (-not (Test-Path -Path $PLinkPath)) {
    Write-Warning "$PLinkPath not found, downloading..."
    try {
        Invoke-WebRequest -Uri 'https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe' -OutFile $PLinkPath
    } catch {
        Write-Warning "Unable to download PLink."
        Pause
        exit
    }
}

$UserName = $Creds.GetNetworkCredential().UserName
$Password = $Creds.GetNetworkCredential().Password

$ServerList = @{
    'Linux1' = '192.168.1.2';
    'Linux2' = '192.168.1.3';
}

$Commands = @("hostname")
if ($Command) { $Commands += $Command }
if ($Sudo) { $Commands += "echo $Password | sudo -S true;" }
if ($Update) { $Commands += "sudo apt -y update;" }
if ($Upgrade) { $Commands += "sudo apt -y upgrade;" }
if ($DistUpgrade) { $Commands += "sudo apt -y dist-upgrade;" }
if ($Clean) { $Commands += @("sudo apt -y autoremove;", "sudo apt -y autoclean;") }
if ($Install) { $Commands += "sudo apt -y install $Install;" }
if ($Reboot) { $Commands += "sudo shutdown -r;" }

# Make sure the end of each line contains a semicolon
$Commands = $Commands | ForEach-Object { "$($_.ToString().TrimEnd(';'));" }

if ($Server -eq 'All') { $Server = $ServerList.Keys }

foreach ($ComputerName in $Server) {
    if ($PSCmdlet.ShouldProcess($Server, "Run the following commands:`n$(($Commands | Out-String) -replace $Password, '***')")) {
        if ($AsJob) {
            Write-Verbose "Running commands as job..."
            Start-Job -Name "$ComputerName Update" -ScriptBlock {
                param($IP, $UserName, $Password, $Commands, $PLinkPath)

                Set-Alias plink $PLinkPath
            Write-Output 'y' | plink -ssh $ServerList.$ComputerName -l $Username -pw $Password exit
            plink -batch -ssh $ServerList.$ComputerName -l $UserName -pw $Password $Commands
            } -ArgumentList $ServerList.$ComputerName, $UserName, $Password, $Commands, $PLinkPath
        } else {
            Set-Alias plink $PLinkPath
            Write-Output 'y' | plink -ssh $ServerList.$ComputerName -l $Username -pw $Password exit
            plink -batch -ssh $ServerList.$ComputerName -l $UserName -pw $Password $Commands
        }
    }
}

if ($AsJob) {
    Write-Verbose "Waiting for jobs to finish..."
    Get-Job | Wait-Job | Receive-Job
    Get-Job | Remove-Job -Force
}