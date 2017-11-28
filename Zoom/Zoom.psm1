$ZoomApiKey = ''
$ZoomApiSecret = ''

function Get-ZoomApiAuth {
    <#
    .SYNOPSIS
    Gets a hashtable for a Zoom Api REST body that includes the api key and secret.

    .EXAMPLE
    $RequestBody = Get-ZoomApiAuth

    .OUTPUTS
    Hashtable
    #>
    [CmdletBinding()]
    Param()

    try {
        if (-not $Global:ZoomApiKey) {
            $Global:ZoomApiKey = if ($PSPrivateMetadata.JobId) {
                Get-AutomationVariable -Name ZoomApiKey
            } else {
                Read-Host 'Enter Zoom Api key'
            }
        }

        if (-not $Global:ZoomApiSecret) {
            $Global:ZoomApiSecret = if ($PSPrivateMetadata.JobId) {
                Get-AutomationVariable -Name ZoomApiSecret
            } else {
                Read-Host 'Enter Zoom Api secret'
            }
        }

        @{
            'api_key' = $Global:ZoomApiKey
            'api_secret' = $Global:ZoomApiSecret
        }
    } catch {
        Write-Error "Problem getting Zoom Api Authorization variables:`n$_"
    }
}

function Get-ZoomTimeZones {
    @{
        'Pacific/Midway' = '"Midway Island, Samoa"'
        'Pacific/Pago_Pago' = 'Pago Pago'
        'Pacific/Honolulu' = 'Hawaii'
        'America/Anchorage' = 'Alaska'
        'America/Vancouver' = 'Vancouver'
        'America/Los_Angeles' = 'Pacific Time (US and Canada)'
        'America/Tijuana' = 'Tijuana'
        'America/Edmonton' = 'Edmonton'
        'America/Denver' = 'Mountain Time (US and Canada)'
        'America/Phoenix' = 'Arizona'
        'America/Mazatlan' = 'Mazatlan'
        'America/Winnipeg' = 'Winnipeg'
        'America/Regina' = 'Saskatchewan'
        'America/Chicago' = 'Central Time (US and Canada)'
        'America/Mexico_City' = 'Mexico City'
        'America/Guatemala' = 'Guatemala'
        'America/El_Salvador' = 'El Salvador'
        'America/Managua' = 'Managua'
        'America/Costa_Rica' = 'Costa Rica'
        'America/Montreal' = 'Montreal'
        'America/New_York' = 'Eastern Time (US and Canada)'
        'America/Indianapolis' = 'Indiana (East)'
        'America/Panama' = 'Panama'
        'America/Bogota' = 'Bogota'
        'America/Lima' = 'Lima'
        'America/Halifax' = 'Halifax'
        'America/Puerto_Rico' = 'Puerto Rico'
        'America/Caracas' = 'Caracas'
        'America/Santiago' = 'Santiago'
        'America/St_Johns' = 'Newfoundland and Labrador'
        'America/Montevideo' = 'Montevideo'
        'America/Araguaina' = 'Brasilia'
        'America/Argentina/Buenos_Aires' = '"Buenos Aires, Georgetown"'
        'America/Godthab' = 'Greenland'
        'America/Sao_Paulo' = 'Sao Paulo'
        'Atlantic/Azores' = 'Azores'
        'Canada/Atlantic' = 'Atlantic Time (Canada)'
        'Atlantic/Cape_Verde' = 'Cape Verde Islands'
        'UTC' = 'Universal Time UTC'
        'Etc/Greenwich' = 'Greenwich Mean Time'
        'Europe/Belgrade' = '"Belgrade, Bratislava, Ljubljana"'
        'CET' = '"Sarajevo, Skopje, Zagreb"'
        'Atlantic/Reykjavik' = 'Reykjavik'
        'Europe/Dublin' = 'Dublin'
        'Europe/London' = 'London'
        'Europe/Lisbon' = 'Lisbon'
        'Africa/Casablanca' = 'Casablanca'
        'Africa/Nouakchott' = 'Nouakchott'
        'Europe/Oslo' = 'Oslo'
        'Europe/Copenhagen' = 'Copenhagen'
        'Europe/Brussels' = 'Brussels'
        'Europe/Berlin' = '"Amsterdam, Berlin, Rome, Stockholm, Vienna"'
        'Europe/Helsinki' = 'Helsinki'
        'Europe/Amsterdam' = 'Amsterdam'
        'Europe/Rome' = 'Rome'
        'Europe/Stockholm' = 'Stockholm'
        'Europe/Vienna' = 'Vienna'
        'Europe/Luxembourg' = 'Luxembourg'
        'Europe/Paris' = 'Paris'
        'Europe/Zurich' = 'Zurich'
        'Europe/Madrid' = 'Madrid'
        'Africa/Bangui' = 'West Central Africa'
        'Africa/Algiers' = 'Algiers'
        'Africa/Tunis' = 'Tunis'
        'Africa/Harare' = '"Harare, Pretoria"'
        'Africa/Nairobi' = 'Nairobi'
        'Europe/Warsaw' = 'Warsaw'
        'Europe/Prague' = 'Prague Bratislava'
        'Europe/Budapest' = 'Budapest'
        'Europe/Sofia' = 'Sofia'
        'Europe/Istanbul' = 'Istanbul'
        'Europe/Athens' = 'Athens'
        'Europe/Bucharest' = 'Bucharest'
        'Asia/Nicosia' = 'Nicosia'
        'Asia/Beirut' = 'Beirut'
        'Asia/Damascus' = 'Damascus'
        'Asia/Jerusalem' = 'Jerusalem'
        'Asia/Amman' = 'Amman'
        'Africa/Tripoli' = 'Tripoli'
        'Africa/Cairo' = 'Cairo'
        'Africa/Johannesburg' = 'Johannesburg'
        'Europe/Moscow' = 'Moscow'
        'Asia/Baghdad' = 'Baghdad'
        'Asia/Kuwait' = 'Kuwait'
        'Asia/Riyadh' = 'Riyadh'
        'Asia/Bahrain' = 'Bahrain'
        'Asia/Qatar' = 'Qatar'
        'Asia/Aden' = 'Aden'
        'Asia/Tehran' = 'Tehran'
        'Africa/Khartoum' = 'Khartoum'
        'Africa/Djibouti' = 'Djibouti'
        'Africa/Mogadishu' = 'Mogadishu'
        'Asia/Dubai' = 'Dubai'
        'Asia/Muscat' = 'Muscat'
        'Asia/Baku' = '"Baku, Tbilisi, Yerevan"'
        'Asia/Kabul' = 'Kabul'
        'Asia/Yekaterinburg' = 'Yekaterinburg'
        'Asia/Tashkent' = '"Islamabad, Karachi, Tashkent"'
        'Asia/Calcutta' = 'India'
        'Asia/Kathmandu' = 'Kathmandu'
        'Asia/Novosibirsk' = 'Novosibirsk'
        'Asia/Almaty' = 'Almaty'
        'Asia/Dacca' = 'Dacca'
        'Asia/Krasnoyarsk' = 'Krasnoyarsk'
        'Asia/Dhaka' = '"Astana, Dhaka"'
        'Asia/Bangkok' = 'Bangkok'
        'Asia/Saigon' = 'Vietnam'
        'Asia/Jakarta' = 'Jakarta'
        'Asia/Irkutsk' = '"Irkutsk, Ulaanbaatar"'
        'Asia/Shanghai' = '"Beijing, Shanghai"'
        'Asia/Hong_Kong' = 'Hong Kong'
        'Asia/Taipei' = 'Taipei'
        'Asia/Kuala_Lumpur' = 'Kuala Lumpur'
        'Asia/Singapore' = 'Singapore'
        'Australia/Perth' = 'Perth'
        'Asia/Yakutsk' = 'Yakutsk'
        'Asia/Seoul' = 'Seoul'
        'Asia/Tokyo' = '"Osaka, Sapporo, Tokyo"'
        'Australia/Darwin' = 'Darwin'
        'Australia/Adelaide' = 'Adelaide'
        'Asia/Vladivostok' = 'Vladivostok'
        'Pacific/Port_Moresby' = '"Guam, Port Moresby"'
        'Australia/Brisbane' = 'Brisbane'
        'Australia/Sydney' = '"Canberra, Melbourne, Sydney"'
        'Australia/Hobart' = 'Hobart'
        'Asia/Magadan' = 'Magadan'
        'SST' = 'Solomon Islands'
        'Pacific/Noumea' = 'New Caledonia'
        'Asia/Kamchatka' = 'Kamchatka'
        'Pacific/Fiji' = '"Fiji Islands, Marshall Islands"'
        'Pacific/Auckland' = '"Auckland, Wellington"'
        'Asia/Kolkata' = '"Mumbai, Kolkata, New Delhi"'
        'Europe/Kiev' = 'Kiev'
        'America/Tegucigalpa' = 'Tegucigalpa'
        'Pacific/Apia' = 'Independent State of Samoa'
    }
}

function Read-ZoomResponse {
    <#
    .SYNOPSIS
    Parses Zoom REST response so errors are returned properly

    .PARAMETER Response
    The JSON response from the Api call.

    .PARAMETER RequestBody
    The hashtable that was sent through the Api call.

    .PARAMETER Endpoint
    Api endpoint Url that was called.

    .PARAMETER RetryOnRequestLimitReached
    If the Api request limit is reached, retry once after 1 second.

    .EXAMPLE
    Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
        Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint -Endpoint $Endpoint
    #>
    [CmdletBinding()]
    Param(
        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true
		)]
        [PSCustomObject]$Response,

        [Parameter(Mandatory = $true)]
        [hashtable]$RequestBody,

        [Parameter(Mandatory = $true)]
        [string]$Endpoint,

        [Parameter(Mandatory = $false)]
        [bool]$RetryOnRequestLimitReached = $true
    )

    $ApiCallInfo = "Api Endpoint: $Endpoint`n"
    $ApiCallInfo += "Api call body:$($RequestBody | Out-String)"

    if ($Response.PSObject.Properties.Name -match 'error') {
        Write-Error -Message "$($Response.error.message)`n$ApiCallInfo" -ErrorId $Response.error.code -Category InvalidOperation

        if ($RetryOnRequestLimitReached -and $Response.error.code -eq 403) {
            Write-Warning "Retrying in one second..."
            Start-Sleep -Seconds 1

            Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
                Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint
        }
    } else {
        Write-Verbose "$($Response.error.message)`nApi call body:$($RequestBody | Out-String)"
        $Response
    }
}

function Get-ZoomUser {
    <#
    .SYNOPSIS
    Gets Zoom users by Id, Email, or All.

    .PARAMETER Id
    Gets Zoom user by their Zoom Id. Will accept an array of Id's.

    .PARAMETER Email
    Gets all Zoom users and then filters by email. Will accept an array of emails.
    
    .PARAMETER LoginType
    Optional, default is Sso. Login type of the email.

    .PARAMETER All
    Default. Return all Zoom users.

    .EXAMPLE
    Get-ZoomUser
    Returns all zoom users.

    .EXAMPLE
    Get-ZoomUser -Email user@company.com
    Searches for and returns specified user if found.

    .OUTPUTS
    PSCustomObject
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    Param(
        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'Id'
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]$Id,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'Email'
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]$Email,

        [Parameter(
            Mandatory = $false,
            ParameterSetName = 'Email'
        )]
        [ValidateSet('Facebook', 'Google', 'Api', 'Zoom', 'Sso')]
        [string]$LoginType = 'Sso',

        [Parameter(
            Mandatory = $false,
            ParameterSetName = 'All'
        )]
        [switch]$All
    )

    if ($PSCmdlet.ParameterSetName -eq 'All') {
        $Endpoint = 'https://api.zoom.us/v1/user/list'

        $RequestBody = Get-ZoomApiAuth
        $RequestBody.Add('page_size', 300)

        $Result = Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
            Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint

        Write-Verbose "There are $($Result.page_count) pages of users"
        for ($Page = 1; $Page -le $Result.page_count; $Page++) {
            $RequestBody = Get-ZoomApiAuth
            $RequestBody.Add('page_size', 300)
            $RequestBody.Add('page_number', $Page)
            Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
                Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint |
                Select-Object -ExpandProperty users

            Start-Sleep -Milliseconds 500
        }
    } elseif ($PSCmdlet.ParameterSetName -eq 'Email') {
        $Endpoint = 'https://api.zoom.us/v1/user/getbyemail'

        $Type = switch ($LoginType) {
            'Facebook' { '0' }
            'Google' { '1' }
            'Api' { '99' }
            'Zoom' { '100' }
            'Sso' { '101' }
        }

        foreach ($User in $Email) {
            $RequestBody = Get-ZoomApiAuth
            $RequestBody.Add('email', $User)
            $RequestBody.Add('login_type', $Type)
            Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
                Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint
        }
    } elseif ($PSCmdlet.ParameterSetName -eq 'Id') {
        $Endpoint = 'https://api.zoom.us/v1/user/get'

        foreach ($User in $Id) {
            $RequestBody = Get-ZoomApiAuth
            $RequestBody.Add('id', $User)
            Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
                Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint
        }
    }
}

function Get-ZoomPendingUser {
    <#
    .SYNOPSIS
    List all the pending users on Zoom.

    .EXAMPLE
    Get-ZoomPendingUser
    Returns all pending Zoom users.

    .OUTPUTS
    PSCustomObject
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    Param()

    $Endpoint = 'https://api.zoom.us/v1/user/pending'

    $RequestBody = Get-ZoomApiAuth
    $RequestBody.Add('page_size', 300)
    $Result = Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
        Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint

    Write-Verbose "There are $($Result.page_count) pages of pending users"
    for ($Page = 1; $Page -le $Result.page_count; $Page++) {
        $RequestBody = Get-ZoomApiAuth
        $RequestBody.Add('page_size', 300)
        $RequestBody.Add('page_number', $Page)
        $Users += Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
            Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint |
            Select-Object -ExpandProperty users
                
        Start-Sleep -Milliseconds 500
    }

    $Users
}

function Remove-ZoomUser {
    <#
    .SYNOPSIS
    Remove Zoom user by Id.

    .PARAMETER Id
    Zoom user Id to remove.

    .PARAMETER Permanently
    Default is no. Switch that specified whether to delete user permanently.

    .EXAMPLE
    Get-ZoomUser -Email user@company.com -Permanently | Remove-ZoomUser
    Permanently remove user@company.com.

    .EXAMPLE
    Remove-ZoomUser -Id 123asdfjkl
    Removes Zoom user with Id 123asdfjkl.
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [switch]$Permanently
    )

    $Endpoint = if ($Permanently) {
        Write-Verbose 'Permanent delete selected.'
        'https://api.zoom.us/v1/user/permanentdelete'
    } else {
        'https://api.zoom.us/v1/user/delete'
    }

    $RequestBody = Get-ZoomApiAuth
    $RequestBody.Add('id', $Id)

    if ($pscmdlet.ShouldProcess($Id, 'Remove Zoom user')) {
        Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
            Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint
    }
}

function Remove-ZoomGroup {
    <#
    .SYNOPSIS
    Remove Zoom group by Id.

    .PARAMETER Id
    Zoom group Id to remove.

    .EXAMPLE
    Get-ZoomGroup -Name TestGroup | Remove-ZoomGroup
    Remove group TestGroup.
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )

    $Endpoint = 'https://api.zoom.us/v1/group/delete'

    $RequestBody = Get-ZoomApiAuth
    $RequestBody.Add('id', $Id)

    if ($pscmdlet.ShouldProcess($Id, 'Remove Zoom group')) {
        Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
            Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint
    }
}

function Test-ZoomUserEmail {
    <#
    .SYNOPSIS
    Test if given email has an existing account.

    .PARAMETER Email
    Zoom user email to test.

    .EXAMPLE
    Test-ZoomUserEmail -Email user@company.com
    Checks to see if account exists for user@company.com.

    .NOTES
    This will return false if the user has an SSO account but not an Email account.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Email
    )

    $Endpoint = 'https://api.zoom.us/v1/user/checkemail'

    $RequestBody = Get-ZoomApiAuth
    $RequestBody.Add('email', $Email)

    Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
        Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint |
        Select-Object -ExpandProperty existed_email
}

function Disable-ZoomUser {
    <#
    .SYNOPSIS
    Deactivate Zoom user with given Id.

    .PARAMETER Id
    Zoom user id to deactivate.

    .EXAMPLE
    Get-ZoomUser -Id user@company.com | Disable-ZoomUserEmail
    Deactivates Zoom user account with email user@company.com.
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )

    $RequestBody = Get-ZoomApiAuth

    $Endpoint = 'https://api.zoom.us/v1/user/deactivate'

    $RequestBody.Add('id', $Id)

    if ($pscmdlet.ShouldProcess($Id, 'Deactivate Zoom user')) {
        Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
            Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint
    }
}

function Get-ZoomGroup {
    <#
    .SYNOPSIS
    Gets Zoom groups by Id, Name, or All.

    .PARAMETER Id
    Gets Zoom group by their Zoom Id.

    .PARAMETER Name
    Gets all Zoom groups and then filters by name.

    .PARAMETER All
    Default. Return all Zoom groups.

    .EXAMPLE
    Get-ZoomGroup
    Returns all zoom groups.

    .EXAMPLE
    Get-ZoomGroup -Name TestGroup
    Searches for and returns specified group if found.

    .OUTPUTS
    PSCustomObject
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    Param(
        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'Id'
		)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(ParameterSetName = 'All')]
        [switch]$All
    )

    $RequestBody = Get-ZoomApiAuth

    $Endpoint = if ($PSCmdlet.ParameterSetName -ne 'Id') {
        'https://api.zoom.us/v1/group/list'
    } else {
        'https://api.zoom.us/v1/group/get'
    }

    if ($PSCmdlet.ParameterSetName -ne 'Id') {
        $Groups = Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
            Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint |
            Select-Object -ExpandProperty groups

        if ($PSCmdlet.ParameterSetName -eq 'Name') {
            $Groups | Where-Object -Property name -eq $Name
        } else {
            $Groups
        }
    } else {
        $RequestBody.Add('id', $Id)
        Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
            Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint
    }
}

function Get-ZoomMeeting {
    <#
    .SYNOPSIS
    List all the scheduled meetings on Zoom for the user Id.

    .PARAMETER Id
    Gets Zoom group by their Zoom Id.

    .EXAMPLE
    Get-ZoomGroup -Name TestGroup
    Searches for and returns specified group if found.

    .OUTPUTS
    PSCustomObject
    #>
    [CmdletBinding()]
    Param(
        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Id
    )

    $RequestBody = Get-ZoomApiAuth

    $Endpoint = 'https://api.zoom.us/v1/meeting/list'

    foreach ($User in $Id) {
        $RequestBody = Get-ZoomApiAuth
        $RequestBody.Add('page_size', 300)
        $RequestBody.Add('host_id', $User)
        $Result = Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post | 
            Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint

        Write-Verbose "There are $($Result.page_count) pages of meetings"
        for ($Page = 1; $Page -le $Result.page_count; $Page++) {
            $RequestBody = Get-ZoomApiAuth
            $RequestBody.Add('host_id', $User)
            $RequestBody.Add('page_size', 300)
            $RequestBody.Add('page_number', $Page)
            $Meetings += Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
                Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint |
                Select-Object -ExpandProperty meetings
                
            Start-Sleep -Milliseconds 500
        }
        
        $Meetings
    }
}

function Get-ZoomUserScheduler {
    <#
    .SYNOPSIS
    List assigned schedule privilege for host users.

    .PARAMETER Id
    The host's user id.

    .PARAMETER Email
    The host's email address.

    .EXAMPLE
    Get-ZoomUser -Email user@company.com | Get-ZoomUserScheduler
    Returns all zoom groups.

    .OUTPUTS
    PSCustomObject
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    Param(
        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'Id'
		)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(ParameterSetName = 'Email')]
        [ValidateNotNullOrEmpty()]
        [string]$Email
    )

    $RequestBody = Get-ZoomApiAuth

    $Endpoint = 'https://api.zoom.us/v1/user/scheduleforhost/list'

    if ($PSCmdlet.ParameterSetName -eq 'Id') {
        $RequestBody.Add('id', $Id)
    } else {
        $RequestBody.Add('host_email', $Email)
    }

    Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
        Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint
}

function Set-ZoomUserAssistant {
    <#
    .SYNOPSIS
    Set a user's assistant which can schedule meeting for them.

    .PARAMETER Id
    The host's user id.

    .PARAMETER Email
    The host's email address.

    .PARAMETER AssistantEmail
    The assistant's email address.

    .EXAMPLE
    Get-ZoomUser -Email user@company.com | Get-ZoomUserAssistant -AssistantEmail assistant@company.com
    Sets assistant@company.com as assistant for user@company.com

    .OUTPUTS
    PSCustomObject
    #>
    [CmdletBinding(
        SupportsShouldProcess = $True,
        DefaultParameterSetName = 'Id'
    )]
    Param(
        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'Id'
		)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(ParameterSetName = 'Email')]
        [ValidateNotNullOrEmpty()]
        [string]$Email,

        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AssistantEmail
    )

    $RequestBody = Get-ZoomApiAuth
    $RequestBody.Add('assistant_email', $AssistantEmail)

    $Endpoint = 'https://api.zoom.us/v1/user/assistant/set'

    if ($PSCmdlet.ParameterSetName -ne 'Id') {
        $RequestBody.Add('id', $Id)
        $Target = $Id
    } else {
        $RequestBody.Add('host_email', $Email)
        $Target = $Email
    }

    if ($pscmdlet.ShouldProcess($Target, 'Set Zoom user assistant')) {
        Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
            Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint
    }
}

function Remove-ZoomUserAssistant {
    <#
    .SYNOPSIS
    Remove assistants for given user.

    .PARAMETER Id
    The host's user id.

    .PARAMETER Email
    The host's email address.

    .EXAMPLE
    Get-ZoomUser -Email user@company.com | Remove-ZoomUserAssistant
    Removes assistants of user@company.com.

    .OUTPUTS
    PSCustomObject
    #>
    [CmdletBinding(
        SupportsShouldProcess = $True,
        DefaultParameterSetName = 'Id'
    )]
    Param(
        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'Id'
		)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(ParameterSetName = 'Email')]
        [ValidateNotNullOrEmpty()]
        [string]$Email
    )

    $RequestBody = Get-ZoomApiAuth

    $Endpoint = 'https://api.zoom.us/v1/user/assistant/delete'

    if ($PSCmdlet.ParameterSetName -ne 'Id') {
        $Assistant = $Id
        $RequestBody.Add('id', $Id)
    } else {
        $Assistant = $Email
        $RequestBody.Add('host_email', $Email)
    }

    if ($pscmdlet.ShouldProcess($Assistant, 'Remove Zoom user assistant')) {
        Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
            Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint
    }
}

function New-ZoomGroup {
    <#
    .SYNOPSIS
    Create a group on Zoom, return the new group info.

    .PARAMETER Name
    Group name, must be unique in one account.

    .EXAMPLE
    New-ZoomGroup -Name TestGroup
    Create new group named TestGroup.

    .OUTPUTS
    PSCustomObject
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $Endpoint = 'https://api.zoom.us/v1/group/create'

    $RequestBody = Get-ZoomApiAuth
    $RequestBody.Add('name', $Name)

    Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
        Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint
}

function Add-ZoomGroupMember {
    <#
    .SYNOPSIS
    Adds members to a group on Zoom.

    .PARAMETER GroupId
    Group ID.

    .PARAMETER Id
    The member IDs, pipeline and arrays are accepted

    .OUTPUTS
    PSCustomObject
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$GroupId,

        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Id
    )

    $Endpoint = 'https://api.zoom.us/v1/group/member/add'

    $RequestBody = Get-ZoomApiAuth
    $RequestBody.Add('id', $GroupId)
    $RequestBody.Add('member_ids', $Id -join ',')

    if ($pscmdlet.ShouldProcess($Id -join ',', "Add Zoom user(s) to $GroupId")) {
        Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
            Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint
    }
}

function Remove-ZoomGroupMember {
    <#
    .SYNOPSIS
    Remove members to a group on Zoom.

    .PARAMETER GroupId
    Group ID.

    .PARAMETER Id
    The member IDs, pipeline and arrays are accepted

    .OUTPUTS
    PSCustomObject
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$GroupId,

        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Id
    )

    $Endpoint = 'https://api.zoom.us/v1/group/member/delete'

    $RequestBody = Get-ZoomApiAuth
    $RequestBody.Add('id', $GroupId)
    $RequestBody.Add('member_ids', $Id -join ',')

    if ($pscmdlet.ShouldProcess($Id -join ',', "Remove Zoom user(s) from $GroupId")) {
        Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
            Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint
    }
}

function Get-ZoomGroupMember {
    <#
    .SYNOPSIS
    Lists the members of a group on Zoom.

    .PARAMETER Id
    Group ID.

    .EXAMPLE
    Get-ZoomGroup -Name TestGroup | Get-ZoomGroupMember
    Gets members of TestGroup.

    .OUTPUTS
    PSCustomObject
    #>
    [CmdletBinding()]
    Param(
        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )

    $Endpoint = 'https://api.zoom.us/v1/group/member/list'

    $RequestBody = Get-ZoomApiAuth
    $RequestBody.Add('id', $Id)
    $RequestBody.Add('page_size', 300)
    $Result = Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
        Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint

    Write-Verbose "There are $($Result.page_count) pages of users"
    for ($Page = 1; $Page -le $Result.page_count; $Page++) {
        $RequestBody = Get-ZoomApiAuth
        $RequestBody.Add('id', $Id)
        $RequestBody.Add('page_size', 300)
        $RequestBody.Add('page_number', $Page)
        $Users += Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
            Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint |
            Select-Object -ExpandProperty members
            
        Start-Sleep -Milliseconds 500
    }

    $Users
}

function Set-ZoomUser {
    <#
    .SYNOPSIS
    Update user info on Zoom via user ID.

    .PARAMETER Id
    Zoom user to update.

    .PARAMETER FirstName
    User's first name.

    .PARAMETER LastName
    User's last name.

    .PARAMETER License
    License type. Basic, Pro, or Corp.

    .PARAMETER Pmi
    Personal Meeting ID, long, length must be 10.

    .PARAMETER EnablePmi
    Specify whether to use Personal Meeting Id for instant meetings. True or False.

    .PARAMETER VanityName
    Personal meeting room name.

    .PARAMETER GroupId
    User Group ID. If set default user group, the parameter’s default value is the default user group.

    .PARAMETER EnterExitChime
    Enable enter/exit chime.

    .PARAMETER EnterExitChimeType
    Enter/exit chime type. All (0) means heard by all including host and attendees, HostOnly (1) means heard by host only.

    .PARAMETER DisableFeedback
    Disable feedback.

    .PARAMETER TimeZone
    The time zone id for user profile. For a list of id's refer to https://zoom.github.io/api/#timezones.
    
    .PARAMETER Department
    Department for user profile, use for reporting.

    .EXAMPLE
    Get-ZoomUser -Id user@company.com | Set-ZoomUser -License Corp
    Sets Zoom license to Corp on user@company.com's account.

    .OUTPUTS
    PSCustomObject
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Id,

        [Parameter(Mandatory = $false)]
        [string]$FirstName,

        [Parameter(Mandatory = $false)]
        [string]$LastName,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Basic', 'Pro', 'Corp')]
        [string]$License,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1000000000, 9999999999)]
        [long]$Pmi,

        [Parameter(Mandatory = $false)]
        [bool]$EnablePmi,

        [Parameter(Mandatory = $false)]
        [string]$VanityName,

        [Parameter(Mandatory = $false)]
        [string]$GroupId,

        [Parameter(Mandatory = $false)]
        [bool]$EnterExitChime,

        [Parameter(Mandatory = $false)]
        [ValidateSet('All', 'HostOnly')]
        [string]$EnterExitChimeType,

        [Parameter(Mandatory = $false)]
        [bool]$DisableFeedback,

        [Parameter(Mandatory = $false)]
        [string]$Department
    )
<#
    DynamicParam {
        # Set the dynamic parameters' name
        $ParameterName = 'TimeZone'
            
        # Create the dictionary 
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        # Create the collection of attributes
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            
        # Create and set the parameters' attributes
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $false

        # Add the attributes to the attributes collection
        $AttributeCollection.Add($ParameterAttribute)

        # Generate and set the ValidateSet
        $ValidatedParams = @()
        (Get-ZoomTimeZones).GetEnumerator() | ForEach-Object {
            $ValidatedParams += $_.Key
            $ValidatedParams += $_.Value
        }
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($ValidatedParams)

        # Add the ValidateSet to the attributes collection
        $AttributeCollection.Add($ValidateSetAttribute)

        # Create and return the dynamic parameter
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    begin {
        $TimeZone = $PSBoundParameters.TimeZone
    }
#>
    process {
        $TimeZone = $PSBoundParameters.TimeZone
        $Endpoint = 'https://api.zoom.us/v1/user/update'

        foreach ($User in $Id) {
            if ($pscmdlet.ShouldProcess($User, 'Update Zoom user info')) {

                $RequestBody = Get-ZoomApiAuth
                $RequestBody.Add('id', $User)
                if ($PSBoundParameters.ContainsKey('FirstName')) { $RequestBody.Add('first_name', $FirstName) }
                if ($PSBoundParameters.ContainsKey('LastName')) { $RequestBody.Add('last_name', $LastName) }
                if ($PSBoundParameters.ContainsKey('License')) {
                    $LicenseType = switch ($License) {
                        'Basic' { 1 }
                        'Pro' { 2 }
                        'Corp' { 3 }
                    }
                    
                    $RequestBody.Add('type', $LicenseType)
                }
                if ($PSBoundParameters.ContainsKey('Pmi')) { $RequestBody.Add('pmi', $Pmi) }
                if ($PSBoundParameters.ContainsKey('EnablePmi')) { $RequestBody.Add('enable_use_pmi', $EnablePmi) }
                if ($PSBoundParameters.ContainsKey('VanityName')) { $RequestBody.Add('vanity_name', $VanityName) }
                if ($PSBoundParameters.ContainsKey('GroupId')) { $RequestBody.Add('group_id', $GroupId) }
                if ($PSBoundParameters.ContainsKey('EnterExitChime')) {
                    $RequestBody.Add('enable_enter_exit_chime', $EnterExitChime)
                }
                if ($PSBoundParameters.ContainsKey('EnterExitChimeType')) {
                    $ChimeType = switch ($EnterExitChimeType) {
                        'All' { 0 }
                        'HostOnly' { 1 }
                    }
                    $RequestBody.Add('option_enter_exit_chime_type', $ChimeType)
                }
                if ($PSBoundParameters.ContainsKey('DisableFeedback')) {
                    $RequestBody.Add('disable_feedback', $DisableFeedback)
                }
                <#if ($PSBoundParameters.ContainsKey('TimeZone')) {
                    $TimeZones = Get-ZoomTimeZones
                    if ($TimeZones.Contains($TimeZone)) { $TimeZone = $TimeZones.$TimeZone }
                    $RequestBody.Add('timezone', $TimeZone)
                }#>
                if ($PSBoundParameters.ContainsKey('Department')) { $RequestBody.Add('dept', $Department) }

                if ($pscmdlet.ShouldProcess($User, 'Set Zoom user settings')) {
                    Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
                        Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint
                }
            }
        }
    }
}

function Set-ZoomUserPicture {
    <#
    .SYNOPSIS
    Upload a new profile picture for the specified Zoom user.

    .PARAMETER Id
    Zoom user to upload a new profile picture for.

    .PARAMETER Path
    Path to profile picture to upload.

    .PARAMETER ByteArray
    Byte array representing the picture.

    .EXAMPLE
    Get-ZoomUser -Id user@company.com | Set-ZoomUserPicture -Path .\picture.jpg
    Uploads new profile picture to user@company.com's account.

    .EXAMPLE
    $ThumbnailByteArray = Get-ADUser UserId -Properties thumbnailPhoto | Select-Object -ExpandProperty thumbnailPhoto
    Get-ZoomUser -Id user@company.com | Set-ZoomUserPicture -ByteArray $ThumbnailByteArray
    Uploads new profile picture to user@company.com's account from their AD thumbnail photo. 

    .OUTPUTS
    PSCustomObject

    .NOTES
    This function uses C# to form the rest call because Invoke-RestMethod was incompatible.
    #>
    [CmdletBinding(
        SupportsShouldProcess = $True,
        DefaultParameterSetName = 'Path'
    )]
    Param(
        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'Path'
		)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [ValidatePattern('.jp*.g$')]
        [string]$Path,

        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'ByteArray'
		)]
        [ValidateNotNullOrEmpty()]
        [byte[]]$ByteArray,

        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'Binary'
		)]
        [ValidateNotNullOrEmpty()]
        $Binary
    )

    $Endpoint = 'https://api.zoom.us/v1/user/uploadpicture'

    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        $FileName = $Path.Split('\')[-1]
        $ByteArray = Get-Content -Path $Path -Encoding Byte
    } else {
        $FileName = 'ProfilePicture.jpg'
    }

    if (-not $Binary) {
        $encoding = [System.Text.Encoding]::GetEncoding('iso-8859-1')
        $encodedFile = $encoding.GetString($ByteArray)
    } else {
        $encodedFile = $Binary
    }

    $newLine = "`r`n"
    $boundary = [guid]::NewGuid()
    
    $RequestBody = (
        "--$boundary",
        "Content-Type: text/plain; charset=utf-8",
        "Content-Disposition: form-data; name=api_key$newLine",
        (Get-ZoomApiAuth).api_key,
    
        "--$boundary",
        "Content-Type: text/plain; charset=utf-8",
        "Content-Disposition: form-data; name=api_secret$newLine",
        (Get-ZoomApiAuth).api_secret,
    
        "--$boundary",
        "Content-Type: text/plain; charset=utf-8",
        "Content-Disposition: form-data; name=id$newLine",
        $Id,
    
        "--$boundary",
        "Content-Type: application/octet-stream",
        "Content-Disposition: form-data; name=pic_file; filename=$FileName; filename*=utf-8''$FileName$newLine",
        $encodedFile,

        "--$boundary--$newLine"
     ) -join $newLine

    if ($pscmdlet.ShouldProcess($Id, 'Update Zoom user picture')) {
        $response = Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post -ContentType "multipart/form-data; boundary=`"$boundary`""

        $ApiCallInfo = "Api Endpoint: $Endpoint`n"
        $ApiCallInfo += "Api call body:$($RequestBody | Out-String)"
    
        if ($response.PSObject.Properties.Name -match 'error') {
            Write-Error -Message "$($response.error.message)`n$ApiCallInfo" -ErrorId $response.error.code -Category InvalidOperation
        } else {
            Write-Verbose "$($response.error.message)`nApi call body:$($RequestBody | Out-String)"
            $response
        }
    }
}

function New-ZoomSSOUser {
    <#
    .SYNOPSIS
    Pre-provision Zoom SSO user account.

    .PARAMETER Email
    New Zoom user email address.

    .PARAMETER License
    License to grant new Zoom user. Basic, Pro, or Corp.

    .PARAMETER FirstName
    User's first name.

    .PARAMETER LastName
    User's last name.

    .PARAMETER Pmi
    Personal Meeting ID, long, length must be 10.

    .PARAMETER GroupId
    User Group ID. If set default user group, the parameter’s default value is the default user group.

    .EXAMPLE
    New-ZoomSSOUser -Email user@company.com -License Pro
    Pre-provisions a Zoom user account for email user@company.com with a Pro license.

    .OUTPUTS
    PSCustomObject
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
        [ValidateNotNullOrEmpty()]
        [string]$Email,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Basic', 'Pro', 'Corp')]
        [string]$License,

        [Parameter(Mandatory = $false)]
        [string]$FirstName,

        [Parameter(Mandatory = $false)]
        [string]$LastName,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(1000000000, 9999999999)]
        [long]$Pmi,

        [Parameter(Mandatory = $false)]
        [string]$GroupId
    )

    $Endpoint = 'https://api.zoom.us/v1/user/ssocreate'

    $LicenseType = switch ($License) {
        'Basic' { 1 }
        'Pro' { 2 }
        'Corp' { 3 }
    }

    $RequestBody = Get-ZoomApiAuth
    $RequestBody.Add('email', $Email)
    if ($PSBoundParameters.ContainsKey('FirstName')) { $RequestBody.Add('first_name', $FirstName) }
    if ($PSBoundParameters.ContainsKey('LastName')) { $RequestBody.Add('last_name', $LastName) }
    $RequestBody.Add('type', $LicenseType)
    if ($PSBoundParameters.ContainsKey('Pmi')) { $RequestBody.Add('pmi', $Pmi) }
    if ($PSBoundParameters.ContainsKey('GroupId')) { $RequestBody.Add('group_id', $GroupId) }
    
    if ($pscmdlet.ShouldProcess($Email, 'New Zoom SSO user')) {
        Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
            Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint
    }
}

function New-ZoomUser {
    <#
    .SYNOPSIS
    Create new Zoom user account.

    .PARAMETER Email
    New Zoom user email address.

    .PARAMETER FirstName
    User's first name.

    .PARAMETER LastName
    User's last name.

    .PARAMETER License
    License type. Basic, Pro, or Corp.

    .PARAMETER GroupId
    User Group ID. If set default user group, the parameter’s default value is the default user group.
    
    .PARAMETER EnterExitChime
    Enable enter/exit chime.

    .PARAMETER EnterExitChimeType
    Enter/exit chime type. All (0) means heard by all including host and attendees, HostOnly (1) means heard by host only.

    .PARAMETER DisableFeedback
    Disable feedback.

    .PARAMETER Department
    Department for user profile, use for reporting.

    .EXAMPLE
    New-ZoomUser -Email user@company.com -License Pro
    Creates a Zoom user account for email user@company.com with a Pro license.

    .OUTPUTS
    PSCustomObject
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Email,

        [Parameter(Mandatory = $false)]
        [string]$FirstName,

        [Parameter(Mandatory = $false)]
        [string]$LastName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Basic', 'Pro', 'Corp')]
        [string]$License,

        [Parameter(Mandatory = $false)]
        [string]$GroupId,
    
        [Parameter(Mandatory = $false)]
        [bool]$EnterExitChime,

        [Parameter(Mandatory = $false)]
        [ValidateSet('All', 'HostOnly')]
        [string]$EnterExitChimeType,

        [Parameter(Mandatory = $false)]
        [bool]$DisableFeedback,

        [Parameter(Mandatory = $false)]
        [string]$Department
    )

    $Endpoint = 'https://api.zoom.us/v1/user/create'

    $LicenseType = switch ($License) {
        'Basic' { 1 }
        'Pro' { 2 }
        'Corp' { 3 }
    }
    
    $ChimeType = switch ($EnterExitChimeType) {
        'All' { 0 }
        'HostOnly' { 1 }
    }

    foreach ($User in $Email) {
        $RequestBody = Get-ZoomApiAuth
        $RequestBody.Add('email', $User)
        $RequestBody.Add('type', $LicenseType)
        if ($PSBoundParameters.ContainsKey('FirstName')) { $RequestBody.Add('first_name', $FirstName) }
        if ($PSBoundParameters.ContainsKey('LastName')) { $RequestBody.Add('last_name', $LastName) }
        if ($PSBoundParameters.ContainsKey('GroupId')) { $RequestBody.Add('group_id', $GroupId) }
        if ($PSBoundParameters.ContainsKey('EnterExitChime')) {
            $RequestBody.Add('enable_enter_exit_chime', $EnterExitChime)
        }
        if ($PSBoundParameters.ContainsKey('EnterExitChimeType')) {
            $RequestBody.Add('option_enter_exit_chime_type', $ChimeType)
        }
        if ($PSBoundParameters.ContainsKey('DisableFeedback')) { $RequestBody.Add('disable_feedback', $DisableFeedback) }
        if ($PSBoundParameters.ContainsKey('Department')) { $RequestBody.Add('dept', $Department) }

        if ($pscmdlet.ShouldProcess($User, 'New Zoom user')) {
            Invoke-RestMethod -Uri $Endpoint -Body $RequestBody -Method Post |
                Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint
        }
    }
}

Export-ModuleMember -Function *