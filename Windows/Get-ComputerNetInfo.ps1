function Get-ComputerNetInfo {
    param (
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )] 
        [string[]]$ComputerName = $env:COMPUTERNAME
    )

    process {
        foreach ($Computer in $ComputerName ) {
            # Get hostname and IP address from DNS provider
            Write-Verbose "Getting DNS providor info for $Computer..."
            $DNSHostEntry = [System.Net.Dns]::GetHostEntry($Computer)
            $HostName = $DNSHostEntry.HostName
            $IPAddress = $DNSHostEntry.AddressList.IPAddressToString.Split('.', 1)[0]

            # Get MAC from WMI class
            Write-Verbose "Getting WMI providor info for $Computer..."
            $NetAdapter = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $Computer
            $MACAddress = ($NetAdapter | Where-Object {$_.IpAddress -eq $IPAddress}).MACAddress 

            # Create and output a custom psobject with the net info
            $NetInfo = New-Object -TypeName psobject
            $NetInfo | Add-Member -MemberType NoteProperty -Name DNSHostName -Value $HostName
            $NetInfo | Add-Member -MemberType NoteProperty -Name IPAddress -Value $IPAddress
            $NetInfo | Add-Member -MemberType NoteProperty -Name MACAddress -Value $MACAddress
            Write-Output $NetInfo
        }
    }
}