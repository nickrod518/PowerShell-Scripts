function Get-ZoomApiAuth {
    <#
    .SYNOPSIS
    Gets a hashtable for a Zoom Api REST body that includes the api key and secret.

    .EXAMPLE
    $Headers = Get-ZoomApiAuth

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
    Set-ZoomApi -Key 'mysupersecretapikey' -Secret 'mysupersecretapisecret
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

function Read-ZoomResponse {
    <#
    .SYNOPSIS
    Parses Zoom REST response so errors are returned properly

    .EXAMPLE
    Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
    #>
    [CmdletBinding()]
    Param(
        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true
		)]
        [PSCustomObject]$Response
    )

    if ($Response.PSObject.Properties.Name -match 'error') {
        Write-Error -Message $Response.error.message -ErrorId $Response.error.code
    } else {
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

        $Headers = Get-ZoomApiAuth
        $Headers.Add('page_size', 300)

        $Result = Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse

        Write-Verbose "There are $($Result.page_count) pages of users"
        for ($Page = 1; $Page -le $Result.page_count; $Page++) {
            $Headers = Get-ZoomApiAuth
            $Headers.Add('page_size', 300)
            $Headers.Add('page_number', $Page)
            (Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse).users
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
            $Headers = Get-ZoomApiAuth
            $Headers.Add('email', $User)
            $Headers.Add('login_type', $Type)
            Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
        }
    } elseif ($PSCmdlet.ParameterSetName -eq 'Id') {
        $Endpoint = 'https://api.zoom.us/v1/user/get'

        foreach ($User in $Id) {
            $Headers = Get-ZoomApiAuth
            $Headers.Add('id', $User)
            Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
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

    $Headers = Get-ZoomApiAuth
    $Headers.Add('page_size', 300)
    $Result = Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse

    Write-Verbose "There are $($Result.page_count) pages of pending users"
    for ($Page = 1; $Page -le $Result.page_count; $Page++) {
        $Headers = Get-ZoomApiAuth
        $Headers.Add('page_size', 300)
        $Headers.Add('page_number', $Page)
        $Users += (Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse).users
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

    $Headers = Get-ZoomApiAuth
    $Headers.Add('id', $Id)

    if ($pscmdlet.ShouldProcess($Id, 'Remove Zoom user')) {
        Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
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

    $Headers = Get-ZoomApiAuth
    $Headers.Add('id', $Id)

    if ($pscmdlet.ShouldProcess($Id, 'Remove Zoom group')) {
        Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
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
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Email
    )

    $Endpoint = 'https://api.zoom.us/v1/user/checkemail'

    $Headers = Get-ZoomApiAuth
    $Headers.Add('email', $Email)

    (Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse).existed_email
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

    $Headers = Get-ZoomApiAuth

    $Endpoint = 'https://api.zoom.us/v1/user/deactivate'

    $Headers.Add('id', $Id)

    if ($pscmdlet.ShouldProcess($Id, 'Deactivate Zoom user')) {
        Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
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

    $Headers = Get-ZoomApiAuth

    $Endpoint = if ($PSCmdlet.ParameterSetName -ne 'Id') {
        'https://api.zoom.us/v1/group/list'
    } else {
        'https://api.zoom.us/v1/group/get'
    }

    if ($PSCmdlet.ParameterSetName -ne 'Id') {
        $Groups = (Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse).groups

        if ($PSCmdlet.ParameterSetName -eq 'Name') {
            $Groups | Where-Object -Property name -eq $Name
        } else {
            $Groups
        }
    } else {
        $Headers.Add('id', $Id)
        Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
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

    $Headers = Get-ZoomApiAuth

    $Endpoint = 'https://api.zoom.us/v1/meeting/list'

    foreach ($User in $Id) {
        $Headers = Get-ZoomApiAuth
        $Headers.Add('page_size', 300)
        $Headers.Add('host_id', $User)
        $Result = Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse

        Write-Verbose "There are $($Result.page_count) pages of meetings"
        for ($Page = 1; $Page -le $Result.page_count; $Page++) {
            $Headers = Get-ZoomApiAuth
            $Headers.Add('host_id', $User)
            $Headers.Add('page_size', 300)
            $Headers.Add('page_number', $Page)
            $Meetings += (Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse).meetings
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

    $Headers = Get-ZoomApiAuth

    $Endpoint = 'https://api.zoom.us/v1/user/scheduleforhost/list'

    if ($PSCmdlet.ParameterSetName -eq 'Id') {
        $Headers.Add('id', $Id)
    } else {
        $Headers.Add('host_email', $Email)
    }

    Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
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
    [CmdletBinding(DefaultParameterSetName = 'Id')]
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

    $Headers = Get-ZoomApiAuth
    $Headers.Add('assistant_email', $AssistantEmail)

    $Endpoint = 'https://api.zoom.us/v1/user/assistant/set'

    if ($PSCmdlet.ParameterSetName -ne 'Id') {
        $Headers.Add('id', $Id)
    } else {
        $Headers.Add('host_email', $Email)
    }

    Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
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

    $Headers = Get-ZoomApiAuth

    $Endpoint = 'https://api.zoom.us/v1/user/assistant/delete'

    if ($PSCmdlet.ParameterSetName -ne 'Id') {
        $Assistant = $Id
        $Headers.Add('id', $Id)
    } else {
        $Assistant = $Email
        $Headers.Add('host_email', $Email)
    }

    if ($pscmdlet.ShouldProcess($Assistant, 'Remove Zoom user assistant')) {
        Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
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

    $Headers = Get-ZoomApiAuth
    $Headers.Add('name', $Name)

    Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
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

    $Headers = Get-ZoomApiAuth
    $Headers.Add('id', $GroupId)
    $Headers.Add('member_ids', $Id -join ',')

    if ($pscmdlet.ShouldProcess($Id -join ',', "Add Zoom user(s) to $GroupId")) {
        Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
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

    $Headers = Get-ZoomApiAuth
    $Headers.Add('id', $GroupId)
    $Headers.Add('member_ids', $Id -join ',')

    if ($pscmdlet.ShouldProcess($Id -join ',', "Remove Zoom user(s) from $GroupId")) {
        Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
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

    $Headers = Get-ZoomApiAuth
    $Headers.Add('id', $Id)
    $Headers.Add('page_size', 300)
    $Result = Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse

    Write-Verbose "There are $($Result.page_count) pages of users"
    for ($Page = 1; $Page -le $Result.page_count; $Page++) {
        $Headers = Get-ZoomApiAuth
        $Headers.Add('id', $Id)
        $Headers.Add('page_size', 300)
        $Headers.Add('page_number', $Page)
        $Users += (Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse).members
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
        [string]$GroupId
    )

    $Endpoint = 'https://api.zoom.us/v1/user/update'

    foreach ($User in $Id) {
        if ($pscmdlet.ShouldProcess($User, 'Update Zoom user info')) {

            $Headers = Get-ZoomApiAuth
            $Headers.Add('id', $User)
            if ($PSBoundParameters.ContainsKey('FirstName')) { $Headers.Add('first_name', $FirstName) }
            if ($PSBoundParameters.ContainsKey('LastName')) { $Headers.Add('last_name', $LastName) }
            if ($PSBoundParameters.ContainsKey('License')) {
                $Type = switch ($License) {
                    'Basic' { 1 }
                    'Pro' { 2 }
                    'Corp' { 3 }
                }
                
                $Headers.Add('type', $Type)
            }
            if ($PSBoundParameters.ContainsKey('Pmi')) { $Headers.Add('pmi', $Pmi) }
            if ($PSBoundParameters.ContainsKey('EnablePmi')) { $Headers.Add('enable_use_pmi', $EnablePmi) }
            if ($PSBoundParameters.ContainsKey('VanityName')) { $Headers.Add('vanity_name', $VanityName) }
            if ($PSBoundParameters.ContainsKey('GroupId')) { $Headers.Add('group_id', $GroupId) }

            Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
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

    .EXAMPLE
    Get-ZoomUser -Id user@company.com | Set-ZoomUserPicture -Path .\picture.jpg
    Uploads new profile picture to user@company.com's account.

    .OUTPUTS
    PSCustomObject

    .NOTES
    This function does not work in its current state.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [ValidatePattern('.jp*.g$')]
        [string]$Path
    )

    Write-Warning "This function is experimental and may not work."

    $Endpoint = 'https://api.zoom.us/v1/user/uploadpicture'

    $Bytes = [IO.File]::ReadAllBytes($Path)
    $Encoding = [System.Text.Encoding]::ASCII
    $FileContent = $Encoding.GetString($Bytes)

    <#$boundary = [System.Guid]::NewGuid().ToString()
    $LF = "`n"
    $bodyLines = (
        "--$boundary",
        "api_key: Uo4sjR8IQcOBWCUqxFlM_g",
        "--$boundary",
        "api_secret: 0PxInW592LrbpM0wxoDd3NesO5VbU7OKm8lT",
        "--$boundary",
        "id: $Id",
        "--$boundary",
        "Content-Disposition: form-data; name=`"pic_file`"$LF",
        $FileContent,
        "--$boundary--$LF"
        ) -join $LF
    $bodyLines = (
        "api_key: Uo4sjR8IQcOBWCUqxFlM_g",
        "api_secret: 0PxInW592LrbpM0wxoDd3NesO5VbU7OKm8lT",
        "id: $Id",
        "--$boundary",
        "Content-Disposition: form-data; name=`"pic_file`"$LF",
        $FileContent,
        "--$boundary--$LF"
        ) -join $LF#>

    $Headers = Get-ZoomApiAuth
    $Headers.Add('id', $Id)
    $Headers.Add('pic_file', $FileContent)



    #Invoke-WebRequest -Headers $Headers -Method Post -Uri $Endpoint -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $bodyLines
    Invoke-RestMethod -Uri $Endpoint -Method Post -Body $Headers -ContentType 'multipart/form-data'
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

    $Type = switch ($License) {
        'Basic' { 1 }
        'Pro' { 2 }
        'Corp' { 3 }
    }

    $Headers = Get-ZoomApiAuth
    $Headers.Add('email', $Email)
    if ($PSBoundParameters.ContainsKey('FirstName')) { $Headers.Add('first_name', $FirstName) }
    if ($PSBoundParameters.ContainsKey('LastName')) { $Headers.Add('last_name', $LastName) }
    $Headers.Add('type', $Type)
    if ($PSBoundParameters.ContainsKey('Pmi')) { $Headers.Add('pmi', $Pmi) }
    if ($PSBoundParameters.ContainsKey('GroupId')) { $Headers.Add('group_id', $GroupId) }
    
    if ($pscmdlet.ShouldProcess($Email, 'New Zoom SSO user')) {
        Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
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
        [string]$GroupId
    )

    $Endpoint = 'https://api.zoom.us/v1/user/create'

    $Type = switch ($License) {
        'Basic' { 1 }
        'Pro' { 2 }
        'Corp' { 3 }
    }

    foreach ($User in $Email) {
        $Headers = Get-ZoomApiAuth
        $Headers.Add('email', $User)
        $Headers.Add('type', $Type)
        if ($PSBoundParameters.ContainsKey('FirstName')) { $Headers.Add('first_name', $FirstName) }
        if ($PSBoundParameters.ContainsKey('LastName')) { $Headers.Add('last_name', $LastName) }
        if ($PSBoundParameters.ContainsKey('GroupId')) { $Headers.Add('group_id', $GroupId) }

        if ($pscmdlet.ShouldProcess($User, 'New Zoom user')) {
            Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
        }
    }
}

Export-ModuleMember -Function *