<#
.Synopsis
    Get info on each partition and logical volume of a machine.
    
#>
[CmdletBinding()]
param(
    [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true,
        Position = 0
    )]
    [string[]]$ComputerName = $env:COMPUTERNAME,

    [pscredential]$Credential
)

foreach ($Computer in $ComputerName) {
    try {
        $WmiObjectParams = @{
            ComputerName = $Computer
            Credential = $creds
            Class = 'Win32_DiskPartition'
            Property = 'Name, DiskIndex, Type'
        }
        $Disks = Get-WmiObject @WmiObjectParams -ErrorAction Stop |
        Select-Object -Property Name, DiskIndex, @{
            Name="GPT"
            Expression = { $_.Type.StartsWith("GPT") } 
        }
    } catch {
        New-Object -TypeName psobject -Property @{
            ComputerName = $Computer
            Error = $_.Exception.Message
            VolumeName = ''
            DiskName = ''
            GPT = ''
            DiskIndex = ''
            DriveLetter = ''
            FreeSpaceGB = ''
            Utilization = ''
            SizeGB = ''
            FileSystem = ''
        }
        continue
    }

    Get-WmiObject Win32_LogicalDisk -ComputerName $Computer -Credential $creds |
    Where-Object -Property DriveType -EQ 3 | Foreach-Object {
        $Query = "Associators of {Win32_LogicalDisk.DeviceID='$($_.DeviceID)'} WHERE ResultRole=Antecedent"
        $Volume = Get-WmiObject -ComputerName $Computer -Credential $creds -Query $Query

        $Disk = $Disks | Where-Object -Property DiskIndex -EQ $Volume.DiskIndex
        
        New-Object -TypeName psobject -Property @{
            ComputerName = $Computer
            Error = ''
            VolumeName = $_.VolumeName
            DiskName = $Disk.Name -join ', '
            GPT = $Disk.GPT -join ', '
            DiskIndex = $Volume.DiskIndex
            DriveLetter = $_.DeviceID
            FreeSpaceGB = [Math]::Round($_.FreeSpace / 1GB, 2)
            Utilization = (1 - (($_.FreeSpace / 1GB) / ($Volume.Size / 1GB))).ToString('P')
            SizeGB = [Math]::Round($Volume.Size / 1GB, 2)
            FileSystem = $_.FileSystem
        }
    }
}