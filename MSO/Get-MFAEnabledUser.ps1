Connect-MsolService

Get-MsolUser -EnabledFilter EnabledOnly -All | ForEach-Object {
    $AuthMethods = $_.StrongAuthenticationMethods
    $DefaultMethod = ($AuthMethods | Where-Object -Property IsDefault -EQ $true).MethodType

    New-Object -TypeName psobject -Property @{
        UserPrincipalName = $_.UserPrincipalName
        RelyingParty = $_.StrongAuthenticationRequirements.RelyingParty
        RememberDevicesNotIssuedBefore = $_.StrongAuthenticationRequirements.RememberDevicesNotIssuedBefore
        State = $_.StrongAuthenticationRequirements.State
        DefaultMethod = $DefaultMethod
        MethodType1 = $AuthMethods[0].MethodType
        MethodType2 = $AuthMethods[1].MethodType
        MethodType3 = $AuthMethods[2].MethodType
        MethodType4 = $AuthMethods[3].MethodType
    }
}