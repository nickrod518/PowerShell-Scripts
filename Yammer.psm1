$Global:YammerAuthToken = "your-auth-token"

function Get-YammerAuthHeader {
    @{ AUTHORIZATION = "Bearer $YammerAuthToken" }
}

function Export-YammerData {
    <#
    .SYNOPSIS
    Export Yammer data.

    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$Path = "$PSScriptRoot\export.zip",

        [Parameter(Mandatory = $false)]
        [ValidateSet('User', 'Group', 'Message', 'MessageVersion', 'Topic', 'UploadedFileVersion', 'DocumentVersion')]
        [string[]]$Model,

        [Parameter(Mandatory = $true)]
        [datetime]$StartDate,

        [Parameter(Mandatory = $false)]
        [datetime]$EndDate,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Csv', 'All')]
        [string]$IncludeFileAttachments
    )

    $Uri = 'https://www.yammer.com/api/v1/export?'

    if ($PSBoundParameters.ContainsKey('Model')) {
        foreach ($Type in $Model) {
            if (-not $Uri.EndsWith('?')) {
                $Uri += '&' 
            }
            $Uri += "model=$Type"
        }
    }

    if ($PSBoundParameters.ContainsKey('StartDate')) {
        if (-not $Uri.EndsWith('?')) {
            $Uri += '&' 
        }
        $Uri += "since=$(Get-Date -Date $StartDate -Format s)"
    }

    if ($PSBoundParameters.ContainsKey('EndDate')) {
        if (-not $Uri.EndsWith('?')) {
            $Uri += '&' 
        }
        $Uri += "until=$(Get-Date -Date $EndDate -Format s)"
    }

    if ($PSBoundParameters.ContainsKey('IncludeFileAttachments')) {
        if (-not $Uri.EndsWith('?')) {
            $Uri += '&' 
        }
        $Uri += "include=$IncludeFileAttachments"
    }

    if ($pscmdlet.ShouldProcess($Uri, 'Export Yammer data')) {
        $authHeader = Get-YammerAuthHeader
        Invoke-RestMethod -Uri $Uri -OutFile $Path -Headers $authHeader
    }
}

function Remove-YammerMessage {
    <#
    .SYNOPSIS
    Delete message from Yammer by message ID.

    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $true)]
        [int]$Id
    )

    $authHeader = Get-YammerAuthHeader
    $Uri = "https://yammer.com/api/v1/messages/$Id"

    if ($pscmdlet.ShouldProcess($Id, 'Delete Yammer message')) { 
        Invoke-RestMethod -Uri $Uri -Method Delete -Headers $authHeader
    }
}

function Get-YammerToken {
    <#
    .SYNOPSIS
    Used to get Yammer API tokens under the current account.

    #>
    $IE = New-Object -ComObject InternetExplorer.Application
    $IE.Navigate('https://www.yammer.com/client_applications')
    $IE.Visible = $true

    Write-Host 'Login and select the app you want to use and provide some information.'
    $ClientId = Read-Host 'Client ID'
    $ClientSecret = Read-Host 'Client secret'

    $IE.Quit()

    $CodeUrl = "https://www.yammer.com/dialog/oauth?client_id=$ClientId"
    $SleepInterval = 1

    $IE = New-Object -ComObject InternetExplorer.Application
    $IE.Navigate($codeUrl)
    $IE.Visible = $true

    while ($IE.LocationUrl -notmatch 'code=') {
        Write-Debug -Message ('Sleeping {0} seconds for access URL' -f $SleepInterval)
        Start-Sleep -Seconds $SleepInterval
    }

    Write-Debug -Message ('Callback URL is: {0}' -f $IE.LocationUrl)
    [Void]($IE.LocationUrl -match '=([\w\.]+)')
    $TempCode = $Matches[1]

    $IE.Quit()

    $Request = Invoke-WebRequest https://www.yammer.com/oauth2/access_token.json?client_id=$ClientId"&"client_secret=$ClientSecret"&"code=$TempCode |
        ConvertFrom-Json

    Write-Host "Temporary code used: $TempCode"
    $AccessToken = $Request.access_token.token

    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Authorization", 'Bearer ' + $AccessToken)

    $Headers

    $CurrentUser = Invoke-RestMethod 'https://www.yammer.com/api/v1/users/current.json' -Headers $Headers
    $AllTokens = Invoke-RestMethod 'https://www.yammer.com/api/v1/oauth/tokens.json'-Headers $Headers
    

    Write-Host $CurrentUser.name
    Write-Host $CurrentUser.network_name
    Write-Host $CurrentUser.email


    foreach ($Token in $AllTokens) {
        $Token | Format-Table user_id, network_name, token -AutoSize
    }
}

function Compare-YammerADUserJobTitle {
    <#
    .SYNOPSIS
    Export all Yammer users and compare to MSO users.

    .NOTES
    Modified from MS script

    #>
    [CmdletBinding()]
    Param(
        $YammerUsers
    )

    $usersAD = Get-ADUser -Filter * -Property Title, mail

    foreach ($user in $YammerUsers) {
        $usersAD | Where-Object {
            $_.mail -eq $user.email -and $_.Title -ne $user.job_title
        } | ForEach-Object {
            New-Object -TypeName psobject -Property @{
                Name              = $user.name
                Id                = $user.id
                SamAccountName    = $_.SamAccountName
                UserPrincipalName = $_.UserPrincipalName
                Email             = $user.email
                TitleAD           = $_.Title
                TitleYammer       = $user.job_title
                ApiUrl            = $user.url
                ADEnabled         = $_.Enabled
                YammerState       = $user.state
            }
        }
    }
}

function Compare-YammerMsoUser {
    <#
    .SYNOPSIS
    Export all Yammer users and compare to MSO users.

    #>
    Param(
        [switch]$UseExistingMsoConnection,

        [Parameter(Mandatory = $true)]
        [pscredential]$Credential
    )

    Write-Progress -Id 1 -Activity "Getting Yammer users..."

    # Export users from Yammer
    $startDate = (Get-Date).AddYears(-20)
    $exportPath = "$env:TEMP\export.zip"
    Export-YammerData -Model User -Path $exportPath -StartDate $startDate
    Expand-Archive -Path $exportPath -DestinationPath "$env:TEMP\export"
    Remove-Item -Path $exportPath
    $users = Import-Csv -Path "$env:TEMP\export\Users.csv"
    Remove-Item -Path "$env:TEMP\export" -Recurse
    $yammerUsers = $users | Where-Object -Property state -eq "active"

    if (-not $UseExistingMsoConnection) {
        Connect-MsolService -Credential $Credential
    }

    Write-Progress -Id 1 -Activity "Getting MSO users..."

    $msoUsers = Get-MsolUser -All | Select-Object UserPrincipalName, ProxyAddresses, ObjectId, IsLicensed

    $userCounter = 0
    $userCount = $msoUsers.Count
    $o365usershash = @{}

    foreach ($msoUser in $msoUsers) {
        $upn = $msoUser.UserPrincipalName

        $GroupProgressParams = @{
            Id               = 1
            Activity         = "Processing user $userCounter of $userCount"
            Status           = "Processing MSO users..."
            CurrentOperation = $upn
            PercentComplete  = ($userCounter / $userCount) * 100
        }
        Write-Progress @GroupProgressParams

        $o365usershash.Add($upn, $msoUser)

        $msoUser.ProxyAddresses | ForEach-Object {
            $email = ($msoUser -Replace "SMTP:(\\*)*", "").Trim()

            if (-not $o365usershash.Contains($email)) {
                $o365usershash.Add($email, $msoUser)
            }
        }

        $userCounter++
    }
    
    $userCounter = 0
    $userCount = $yammerUsers.Count

    $yammerUsers | ForEach-Object {
        $email = $_.email

        $GroupProgressParams = @{
            Id               = 1
            Activity         = "Updating user $userCounter of $userCount"
            Status           = "Updating Yammer users..."
            CurrentOperation = $email
            PercentComplete  = ($userCounter / $userCount) * 100
        }
        Write-Progress @GroupProgressParams

        $enabledInAD = Get-ADUser -Filter { UserPrincipalName -eq $email } -Properties Enabled |
            Select-Object -ExpandProperty Enabled
        $_ | Add-Member -MemberType NoteProperty -Name "ad_enabled" -Value $enabledInAD

        $o365user = $o365usershash[$email]
        $existsInAzure = ($o365user -ne $null)
        $_ | Add-Member -MemberType NoteProperty -Name "azure_exists" -Value $existsInAzure

        if ($existsInAzure) {
            $_ | Add-Member -MemberType NoteProperty -Name "azure_object_id" -Value $o365user.ObjectId
            $_ | Add-Member -MemberType NoteProperty -Name "azure_licensed" -Value $o365user.IsLicensed
        }

        Write-Output $_

        $userCounter++
    }
}

function Get-YammerUser {
    <#
    .SYNOPSIS
    Get Yammer user(s).

    #>
    [CmdletBinding(DefaultParameterSetName = "All")]
    Param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = "Id"
        )]
        [int]$Id,

        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = "UserPrincipalName"
        )]
        [string]$UserPrincipalName,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Current"
        )]
        [switch]$Current,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "All"
        )]
        [switch]$All
    )

    begin {
        function Get-YammerAllUsers {
            [CmdletBinding()]
            param(
                [int]$Page = 1,
                
                [System.Collections.ArrayList]$UserList = (New-Object System.Collections.ArrayList($null))
            )
        
            try {
                $uri = "https://www.yammer.com/api/v1/users.json?page=$Page"
                $authHeader = Get-YammerAuthHeader
                $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $authHeader
            } catch {
                throw $_
                exit
            }
        
            if ($response.Count -ne 0) {
                $UserList.AddRange($response)
        
                if ($UserList.Count % 50 -eq 0) {
                    return Get-YammerAllUsers -Page ($Page + 1) -UserList $UserList
                }
            }
            
            return $UserList
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -ne "All") {
            $uri = "https://www.yammer.com/api/v1/users"
    
            $uri += switch ($PSCmdlet.ParameterSetName) {
                Id {
                    "/$Id.json" 
                }
                UserPrincipalName {
                    "/by_email.json?email=$UserPrincipalName" 
                }
                Current {
                    "/current.json" 
                }
            }
        
            $authHeader = Get-YammerAuthHeader
            Invoke-RestMethod -Uri $uri -Method Get -Headers $authHeader
        } else {
            Get-YammerAllUsers
        }
    }
}

function Remove-YammerUser {
    <#
    .SYNOPSIS
    Suspend or permanently delete Yammer user(s) by ID.

    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [int[]]$Id,

        [Parameter(Mandatory = $false)]
        [switch]$TrueDelete
    )

    begin {
        $Uri = "https://www.yammer.com/api/v1/users/$Id"

        if ($TrueDelete) {
            $Uri += "&delete=TRUE"
        }

        $action = if ($TrueDelete) {
            "Permanently delete" 
        } else {
            "Suspend" 
        }
        $authHeader = Get-YammerAuthHeader
    }

    process {
        foreach ($user in $Id) {
            if ($pscmdlet.ShouldProcess($user, "$action Yammer user")) {
                Invoke-RestMethod -Uri $Uri -Method Delete -Headers $authHeader
            }
        }
    }
}

function Update-YammerUser {
    <#
    .SYNOPSIS
    Set properties of Yammer user.

    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [int]$Id,

        [string]$JobTitle
    )

    $uri = "https://www.yammer.com/api/v1/users/$Id.json"

    $requestBody = @{}

    if ($PSBoundParameters.ContainsKey("JobTitle")) {
        $requestBody.Add("job_title", $JobTitle)
    }

    if ($pscmdlet.ShouldProcess($Id, "Update Yammer user")) {
        $authHeader = Get-YammerAuthHeader
        $jsonRequestBody = $requestBody | ConvertTo-Json
        Invoke-RestMethod -Uri $uri -Body $jsonRequestBody -Method Put -Headers $authHeader -ContentType "application/json"
    }
}

function Get-YammerGroup {
    <#
    .SYNOPSIS
    Get Yammer group(s).

    #>
    [CmdletBinding(DefaultParameterSetName = "All")]
    Param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = "Id"
        )]
        [int]$Id,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "All"
        )]
        [switch]$All
    )

    begin {
        function Get-YammerAllGroups {
            [CmdletBinding()]
            param(
                [int]$Page = 1,
                
                [System.Collections.ArrayList]$GroupList = (New-Object System.Collections.ArrayList($null))
            )
        
            try {
                $uri = "https://www.yammer.com/api/v1/groups.json?page=$Page"
                $authHeader = Get-YammerAuthHeader
                $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $authHeader
            } catch {
                throw $_
                exit
            }
        
            if ($response.Count -ne 0) {
                $GroupList.AddRange($response)
        
                if ($GroupList.Count % 50 -eq 0) {
                    return Get-YammerAllGroups -Page ($Page + 1) -GroupList $GroupList
                }
            }
            
            return $GroupList
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -ne "All") {
            $uri = "https://www.yammer.com/api/v1/groups/$Id.json"
        
            $authHeader = Get-YammerAuthHeader
            Invoke-RestMethod -Uri $uri -Method Get -Headers $authHeader
        } else {
            Get-YammerAllGroups
        }
    }
}

function Get-YammerGroupMember {
    <#
    .SYNOPSIS
    Get all members of a Yammer group specified by AD.

    #>
    [CmdletBinding()]
    Param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [int]$Id
    )

    begin {
        function Get-YammerAllMembers {
            [CmdletBinding()]
            param(
                [int]$Id,

                [int]$Page = 1,
                
                [System.Collections.ArrayList]$MemberList = (New-Object System.Collections.ArrayList($null))
            )
        
            try {
                # $uri = "https://www.yammer.com/api/v1/users/in_group/$Id.json?page=$Page"
                # We're using the undocumented endpoint below because it supports the is_admin property
                $uri = "https://www.yammer.com/api/v1/groups/$Id/members.json?page=$Page"
                $authHeader = Get-YammerAuthHeader
                $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $authHeader
                $users = if ($response.users) {
                    $response.users 
                } else {
                    $null 
                }
            } catch {
                throw $_
                exit
            }
        
            if ($users.Count -ne 0) {
                $MemberList.AddRange($users)
        
                if ($MemberList.Count % 50 -eq 0) {
                    return Get-YammerAllMembers -Id $Id -Page ($Page + 1) -MemberList $MemberList
                }
            }
            
            return $MemberList
        }
    }

    process {
        Get-YammerAllMembers -Id $Id
    }
}

function Send-YammerMessage {
    <#
    .SYNOPSIS
    Post message to Yammer user, group, or reply.

    #>
    [CmdletBinding(
        SupportsShouldProcess = $true,
        DefaultParameterSetName = "User"
    )]
    Param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = "User"
        )]
        [int[]]$Id,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Group"
        )]
        [int]$GroupId,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Reply"
        )]
        [int]$ReplyId,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $uri = "https://www.yammer.com/api/v1/messages.json"

    $requestBody = @{}

    switch ($PSCmdlet.ParameterSetName) {
        User {
            $requestBody.Add("direct_to_user_ids", $Id) 
        }
        Group {
            $requestBody.Add("group_id", $GroupId) 
        }
        Reply {
            $requestBody.Add("replied_to_id", $ReplyId) 
        }
    }

    $requestBody.Add("body", $Message)
    
    $jsonBody = $requestBody | ConvertTo-Json

    if ($pscmdlet.ShouldProcess($jsonBody, "Send Yammer message")) {
        $authHeader = Get-YammerAuthHeader
        Invoke-RestMethod -Uri $uri -Body $jsonBody -Method Post -Headers $authHeader -ContentType "application/json"
    }
}

Export-ModuleMember -Function *