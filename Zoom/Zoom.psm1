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

    @{
        'api_key' = Get-Content -Path "$PSScriptRoot\api_key"
        'api_secret' = Get-Content -Path "$PSScriptRoot\api_secret"
    }
}

function Set-ZoomApiAuth {
    <#
    .SYNOPSIS
    Set the Zoom Api key/secret to the files in the same directory as the module.

    .PARAMETER Key
    Optional, sets a new Api key.
    
    .PARAMETER Secret
    Optional, sets a new Api secret.

    .EXAMPLE
    Set-ZoomApi -Key 'mysupersecretapikey' -Secret 'mysupersecretapisecret'
    Sets your Zoom api key and secret to the files in the module directory.

    .EXAMPLE
    Set-ZoomApi
    User is prompted to enter both key and secret.

    .OUTPUTS
    Creates/overrides api_key and api_secret files in module directory.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Key,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Secret
    )

    if ($PSBoundParameters.Keys.Count -eq 0) {
        Read-Host 'Enter your Zoom Api key' | Set-Content -Path "$PSScriptRoot\api_key"
        Read-Host 'Enter your Zoom Api secret' | Set-Content -Path "$PSScriptRoot\api_secret"
    } else {
        switch ($PSBoundParameters.Keys) {
            'Key' { $Key | Set-Content -Path "$PSScriptRoot\api_key" }
            'Secret' { $Secret | Set-Content -Path "$PSScriptRoot\api_secret" }
        }
    }
}

# Verify we can get the api key and secret before continuing to load the module
try {
    Get-ZoomApiAuth -ErrorAction Stop
} catch {
    Set-ZoomApiAuth
}

function Get-ZoomTimeZones {
    $TimeZones = @{}
    Import-Csv -Path "$PSScriptRoot\timezones.csv" -Delimiter ',' | ForEach-Object {
        $TimeZones.Add($_.name, $_.id)
    }
    $TimeZones
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
        [string]$Endpoint
    )

    $ApiCallInfo = "Api Endpoint: $Endpoint`n"
    $ApiCallInfo += "Api call body:$($RequestBody | Out-String)"

    if ($Response.PSObject.Properties.Name -match 'error') {
        Write-Error -Message "$($Response.error.message)`n$ApiCallInfo" -ErrorId $Response.error.code -Category InvalidOperation
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

    process{
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
                if ($PSBoundParameters.ContainsKey('TimeZone')) {
                    $TimeZones = Get-ZoomTimeZones
                    if ($TimeZones.Contains($TimeZone)) { $TimeZone = $TimeZones.$TimeZone }
                    $RequestBody.Add('timezone', $TimeZone)
                }
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
            ParameterSetName = 'Path'
		)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [ValidatePattern('.jp*.g$')]
        [string]$Path,

        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'Id'
		)]
        [ValidateNotNullOrEmpty()]
        [byte[]]$ByteArray
    )

    $Endpoint = 'https://api.zoom.us/v1/user/uploadpicture'
    $ApiAuth = Get-ZoomApiAuth

    $Boundary = [guid]::NewGuid()

    $Source = @"
    using System;
    using System.IO;
    using System.Collections.Generic;
    using System.Threading;
    using System.Threading.Tasks;
    using System.Net;
    using System.Net.Http;
    using System.Net.Http.Headers;

    namespace Zoom
    {
        public static class Tools
        {
            public static string UploadUserPicture(string Id, byte[] byteArray, string fileName)
            {
                Uri webService = new Uri(@"$Endpoint");
                HttpRequestMessage requestMessage = new HttpRequestMessage(HttpMethod.Post, webService);
                requestMessage.Headers.ExpectContinue = false;

                MultipartFormDataContent multiPartContent = new MultipartFormDataContent("$Boundary");

                HttpContent apiKeyContent = new StringContent(@"$($ApiAuth.api_key)");
                multiPartContent.Add(apiKeyContent, "api_key");

                HttpContent apiSecretContent = new StringContent(@"$($ApiAuth.api_secret)");
                multiPartContent.Add(apiSecretContent, "api_secret");

                HttpContent idContent = new StringContent(Id);
                multiPartContent.Add(idContent, "id");

                ByteArrayContent byteArrayContent = new ByteArrayContent(byteArray);
                byteArrayContent.Headers.Add("Content-Type", "application/octet-stream");
                multiPartContent.Add(byteArrayContent, "pic_file", fileName);

                requestMessage.Content = multiPartContent;
    
                HttpClient httpClient = new HttpClient();
                httpClient.Timeout = new TimeSpan(0, 2, 0);
                try
                {
                    Task<HttpResponseMessage> httpRequest = httpClient.SendAsync(requestMessage, HttpCompletionOption.ResponseContentRead, CancellationToken.None);
                    HttpResponseMessage httpResponse = httpRequest.Result;
                    HttpStatusCode statusCode = httpResponse.StatusCode;
                    HttpContent responseContent = httpResponse.Content;
    
                    if (responseContent != null)
                    {
                        Task<String> stringContentsTask = responseContent.ReadAsStringAsync();
                        String stringContents = stringContentsTask.Result;
                        return stringContents;
                    }
                    else
                    {
                        return "No response.";
                    }
                }
                catch (Exception ex)
                {
                    return ex.Message;
                }
            }
        }
    }
"@

    $Assemblies = (
        # Assemblies can be found downloaded from .NET Framework 4.6.2 Dev Pack
        # https://www.microsoft.com/en-us/download/confirmation.aspx?id=53321
        'C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.6.2\System.Net.dll',
        'C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.6.2\System.Net.Http.dll'
    )

    # Only load the Zoom.Tools type if it isn't already loaded
    if (-not ([System.Management.Automation.PSTypeName]'Zoom.Tools').Type) {
        Add-Type -TypeDefinition $Source -Language CSharp -ReferencedAssemblies $Assemblies
    }

    if ($pscmdlet.ShouldProcess($Id, 'Update Zoom user picture')) {
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $ByteArray = Get-Content -Path $Path -Encoding Byte
            $FileName = $Path.Split('\')[-1]
        } else {
            $FileName = 'ProfilePicture.jpg'
        }

        $RequestBody = Get-ZoomApiAuth
        $RequestBody.Add('id', $Id)
        $RequestBody.Add('file_name', $FileName)
        $RequestBody.Add('byte_array', $ByteArray)

        [Zoom.Tools]::UploadUserPicture($Id, $ByteArray, $FileName) | ConvertFrom-Json |
            Read-ZoomResponse -RequestBody $RequestBody -Endpoint $Endpoint
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