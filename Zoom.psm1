# Verify we can get the api key and secret before loading the module
try {
    $ApiKey = Get-Content -Path "$PSScriptRoot\api_key" -ErrorAction Stop
    $ApiSecret = Get-Content -Path "$PSScriptRoot\api_secret" -ErrorAction Stop
} catch {
    Write-Error "There was a problem getting the API key and secret. $_"
    exit
}

function Get-ZoomAuthHeader {
    [CmdletBinding()]
    Param()

    @{
        'api_key' = $ApiKey
        'api_secret' = $ApiSecret
    }
}

function Read-ZoomResponse {
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
    [CmdletBinding(DefaultParameterSetName = 'All')]
    Param(
        [Parameter(ParameterSetName = 'Id')]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(ParameterSetName = 'Email')]
        [ValidateNotNullOrEmpty()]
        [string]$Email,

        [Parameter(ParameterSetName = 'All')]
        [switch]$All
    )

    $Headers = Get-ZoomAuthHeader

    $Endpoint = if ($PSCmdlet.ParameterSetName -ne 'Id') {
        'https://api.zoom.us/v1/user/list'
    } else {
        'https://api.zoom.us/v1/user/get'
    }

    if ($PSCmdlet.ParameterSetName -ne 'Id') {
        $Result = Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse

        Write-Verbose "There are $($Result.page_count) pages of users"
        foreach ($Page in $Result.page_count) {
            $Headers = Get-ZoomAuthHeader
            $Headers.Add('page_size', 300)
            $Headers.Add('page_number', $Page)
            $Users += (Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse).users
        }

        if ($PSCmdlet.ParameterSetName -eq 'Email') {
            $Users | Where-Object -Property email -eq $Email
        } else {
            $Users
        }
    } else {
        $Headers.Add('id', $Id)
        Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
    }
}

function Remove-ZoomUser {
    [CmdletBinding()]
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
        'https://api.zoom.us/v1/user/permanentdelete'
    } else {
        'https://api.zoom.us/v1/user/delete'
    }

    $Headers = Get-ZoomAuthHeader
    $Headers.Add('id', $Id)

    Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
}

function Remove-ZoomGroup {
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

    $Endpoint = 'https://api.zoom.us/v1/group/delete'

    $Headers = Get-ZoomAuthHeader
    $Headers.Add('id', $Id)

    Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
}

function Test-ZoomUserEmail {
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

    $Headers = Get-ZoomAuthHeader

    $Endpoint = 'https://api.zoom.us/v1/user/deactivate'

    $Headers.Add('id', $Id)

    Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
}

function Get-ZoomGroup {
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
        [string]$Email
    )

    $Headers = Get-ZoomAuthHeader

    $Endpoint = 'https://api.zoom.us/v1/user/assistant/delete'

    if ($PSCmdlet.ParameterSetName -ne 'Id') {
        $Headers.Add('id', $Id)
    } else {
        $Headers.Add('host_email', $Email)
    }

    Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
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
    $Headers.Add('member_ids', $MemberIds)

    Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
}

function Remove-ZoomGroupMember {
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

    $Endpoint = 'https://api.zoom.us/v1/group/member/delete'

    $Headers = Get-ZoomAuthHeader
    $Headers.Add('id', $GroupId)

    foreach ($User in $Id) {
        $MemberIds += "$User,"
    }
    $Headers.Add('member_ids', $MemberIds)

    Invoke-RestMethod -Uri $Endpoint -Body $Headers -Method Post | Read-ZoomResponse
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

    $Headers = Get-ZoomAuthHeader
    $Headers.Add('id', $Id)
    $Headers.Add('pic_file', $FileContent)

    Invoke-RestMethod -Uri $Endpoint -Method Post -Body $Headers -ContentType 'multipart/form-data'
}

function Set-ZoomUserIntern {
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

    foreach ($UserId in $Id) {
        Set-ZoomUserLicense -Id $UserId -License Basic

        $Groups = Get-ZoomGroup
        $InternGroupId = ($Groups | Where-Object -Property name -eq 'Interns/Temps').group_id
        $OtherGroupIds = ($Groups | Where-Object -Property name -ne 'Interns/Temps').group_id

        $OtherGroupIds | ForEach-Object {
            Remove-ZoomGroupMember -GroupId $_ -Id $UserId
        }

        $UserId | Add-ZoomGroupMember -GroupId $InternGroupId
    }
}

function New-ZoomSSOUser {
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