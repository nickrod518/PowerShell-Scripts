[CmdletBinding(SupportsShouldProcess = $true)]
Param(
    [Parameter(
        Mandatory = $true,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true
    )]
    [string[]]$ComputerName
)

foreach ($Computer in $ComputerName) {
    $CPULoad = Get-WmiObject -Class win32_processor -ComputerName $Computer |
    Measure-Object -Property LoadPercentage -Average | Select-Object Average

    $MemLoad = Get-WmiObject -Class win32_operatingsystem -ComputerName $Computer |
    Select-Object @{
        Name = "MemoryUsage"
        Expression = { "{0:N2}" -f ((($_.TotalVisibleMemorySize - $_.FreePhysicalMemory) * 100) / $_.TotalVisibleMemorySize) }
    }

    New-Object -TypeName PSObject -Property @{
        ComputerName = $Computer
        CPUUsage = $CPULoad.Average
        MemoryUsage = $MemLoad.MemoryUsage
    }
}