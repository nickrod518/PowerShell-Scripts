# Verify we can get the api key and secret before loading the module
try {
    $ApiKey = Get-Content -Path "$PSScriptRoot\api_key" -ErrorAction Stop
    $ApiSecret = Get-Content -Path "$PSScriptRoot\api_secret" -ErrorAction Stop
} catch {
    Write-Error "There was a problem getting the API key and secret. $_"
    exit
}

function Get-ZoomAuthHeader {
    <#
    .SYNOPSIS
    Gets a hashtable for a new REST body that includes the api key and secret.

    .EXAMPLE
    $Headers = Get-ZoomAuthHeader

    .OUTPUTS
    Hashtable
    #>
    [CmdletBinding()]
    Param()

    @{
        'api_key' = $ApiKey
        'api_secret' = $ApiSecret
    }
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
        [Parameter(ParameterSetName = 'Id')]
        [ValidateNotNullOrEmpty()]
        [string[]]$Id,

        [Parameter(ParameterSetName = 'Email')]
        [ValidateNotNullOrEmpty()]
        [string[]]$Email,

        [Parameter(ParameterSetName = 'All')]
        [switch]$All
    )

    $Endpoint = if ($PSCmdlet.ParameterSetName -ne 'Id') {
        'https://api.zoom.us/v1/user/list'
    } else {
        'https://api.zoom.us/v1/user/get'
    }

    if ($PSCmdlet.ParameterSetName -ne 'Id') {
        $Headers = Get-ZoomAuthHeader
        $Result = Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse

        Write-Verbose "There are $($Result.page_count) pages of users"
        foreach ($Page in $Result.page_count) {
            $Headers.Add('page_size', 300)
            $Headers.Add('page_number', $Page)
            $Users += (Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse).users
        }

        if ($PSCmdlet.ParameterSetName -eq 'Email') {
            foreach ($User in $Email) {
                $Users | Where-Object -Property email -eq $User
            }
        } else {
            $Users
        }
    } else {
        foreach ($User in $Id) {
            $Headers = Get-ZoomAuthHeader
            $Headers.Add('id', $User)
            Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
        }
    }
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

    $Headers = Get-ZoomAuthHeader
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

    $Headers = Get-ZoomAuthHeader
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

    $Headers = Get-ZoomAuthHeader
    $Headers.Add('email', $Email)

    Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
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

    $Headers = Get-ZoomAuthHeader

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

    $Headers = Get-ZoomAuthHeader

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

function Set-ZoomUserAssistant {
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

    $Headers = Get-ZoomAuthHeader
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

    $Headers = Get-ZoomAuthHeader

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
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $Endpoint = 'https://api.zoom.us/v1/group/create'

    $Headers = Get-ZoomAuthHeader
    $Headers.Add('name', $Name)

    Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
}

function Add-ZoomGroupMember {
    [CmdletBinding()]
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

    $Headers = Get-ZoomAuthHeader
    $Headers.Add('id', $GroupId)

    foreach ($User in $Id) {
        $MemberIds += "$User,"
    }
    $Headers.Add('member_ids', $MemberIds.TrimEnd(','))

    Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
}

function Remove-ZoomGroupMember {
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

    $Headers = Get-ZoomAuthHeader
    $Headers.Add('id', $GroupId)

    foreach ($User in $Id) {
        $MemberIds += "$User,"
    }
    $Headers.Add('member_ids', $MemberIds)

    if ($pscmdlet.ShouldProcess($MemberIds, "Remove Zoom user from $GroupId")) {
        Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
    }
}

function Get-ZoomGroupMember {
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

    $Headers = Get-ZoomAuthHeader
    $Headers.Add('id', $Id)
    $Headers.Add('page_size', 300)
    $Result = Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse

    Write-Verbose "There are $($Result.page_count) pages of users"
    foreach ($Page in $Result.page_count) {
        $Headers = Get-ZoomAuthHeader
        $Headers.Add('id', $Id)
        $Headers.Add('page_size', 300)
        $Headers.Add('page_number', $Page)
        $Users += (Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse).members
    }

    $Users
}

function Set-ZoomUserLicense {
    <#
    .SYNOPSIS
    Set license for Zoom user.

    .PARAMETER Id
    Zoom user to set license for.

    .PARAMETER License
    License type. Basic, Pro, or Corp.

    .EXAMPLE
    Get-ZoomUser -Id user@company.com | Set-ZoomUserLicense -License Corp
    Sets Zoom license to Corp on user@company.com's account.

    .OUTPUTS
    PSCustomObject
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    Param(
        [Parameter(
            Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true
		)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Id,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Basic', 'Pro', 'Corp')]
        [string]$License
    )

    $Endpoint = 'https://api.zoom.us/v1/user/update'

    $Type = switch ($License) {
        'Basic' { 1 }
        'Pro' { 2 }
        'Corp' { 3 }
    }

    foreach ($User in $Id) {
        $Headers = Get-ZoomAuthHeader
        $Headers.Add('id', $User)
        $Headers.Add('type', $Type)

        Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
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

    $Headers = Get-ZoomAuthHeader
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

    .EXAMPLE
    New-ZoomSSOUser -Email user@company.com -License Pro
    Pre-provisions a Zoom user account for email user@company.com with a Pro license.

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
        [string[]]$Email,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Basic', 'Pro', 'Corp')]
        [string]$License
    )

    $Endpoint = 'https://api.zoom.us/v1/user/ssocreate'

    $Type = switch ($License) {
        'Basic' { 1 }
        'Pro' { 2 }
        'Corp' { 3 }
    }

    foreach ($User in $Email) {
        $Headers = Get-ZoomAuthHeader
        $Headers.Add('email', $User)
        $Headers.Add('type', $Type)

        Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
    }
}

Export-ModuleMember -Function *