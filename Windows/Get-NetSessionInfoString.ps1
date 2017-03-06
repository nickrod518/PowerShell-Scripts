$Creds = Get-Credential

$Servers = (Get-ADGroup -Identity 'Domain Controllers' | Get-ADGroupMember).Name

foreach ($Server in $Servers) {
    $Server

    (Invoke-Command -ComputerName $Server -Credential $Creds -ScriptBlock {
        $key = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\DefaultSecurity"
        $name = "SrvsvcSessionInfo"
        (Get-ItemProperty -Path $key -Name $name).SrvsvcSessionInfo
    }) -join ''
}