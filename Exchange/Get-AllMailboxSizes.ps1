$Creds = Get-Credential

# If you get an Access Denied message but you're a member of Exchange Online Admins, 
# make sure you don't have MFA enabled
$ExchangeOnlineSession = New-PSSession -ConfigurationName Microsoft.Exchange `
    -ConnectionUri https://outlook.office365.com/powershell-liveid/ `
    -Credential $Creds -Authentication Basic -AllowRedirection

Import-PSSession $ExchangeOnlineSession

$LogDirectory = (New-Item -ItemType Directory "$PSScriptRoot\Logs" -Force).FullName
$Date = (Get-Date).ToString('yyyyMMdd-HHmm')
$CsvPath = "$LogDirectory\$($MyInvocation.MyCommand.Name)-$Date.csv"

Get-Mailbox -ResultSize Unlimited |
    Get-MailboxStatistics |
    Select-Object DisplayName, StorageLimitStatus, ItemCount, `
        @{
            name = "TotalItemSize (MB)"
            expression = { [math]::Round( `
                ($_.TotalItemSize.ToString().Split("(")[1].Split(" ")[0].Replace(",","")/1MB),2)
            }
        } |
    Sort-Object "TotalItemSize (MB)" -Descending |
    Export-CSV $CsvPath -NoTypeInformation