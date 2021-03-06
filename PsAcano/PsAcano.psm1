# .ExternalHelp PsAcano.psm1-Help.xml
function Open-AcanoAPI {
    Param (
        [parameter(ParameterSetName="GET",Mandatory=$true,Position=1)]
        [parameter(ParameterSetName="POST",Mandatory=$true,Position=1)]
        [parameter(ParameterSetName="PUT",Mandatory=$true,Position=1)]
        [parameter(ParameterSetName="DELETE",Mandatory=$true,Position=1)]
        [string]$NodeLocation,
        [parameter(ParameterSetName="POST",Mandatory=$true)]
        [switch]$POST,
        [parameter(ParameterSetName="PUT",Mandatory=$true)]
        [switch]$PUT,
        [parameter(ParameterSetName="DELETE",Mandatory=$true)]
        [switch]$DELETE,
        [parameter(ParameterSetName="POST",Mandatory=$false)]
        [parameter(ParameterSetName="PUT",Mandatory=$false)]
        [parameter(ParameterSetName="DELETE",Mandatory=$false)]
        [string]$Data,
        [parameter(ParameterSetName="POST",Mandatory=$false)]
        [switch]$ReturnResponse
    )

    $webclient = New-Object System.Net.WebClient
    $credCache = new-object System.Net.CredentialCache
    $credCache.Add($script:APIAddress, "Basic", $script:creds)

    $webclient.Headers.Add("user-agent", "PSAcano Powershell Module")
    $webclient.Credentials = $credCache

    try {
        if ($POST) {
            $webclient.Headers.Add("Content-Type","application/x-www-form-urlencoded")
            $response = $webclient.UploadString($script:APIAddress+$NodeLocation,"POST",$Data)

            if ($ReturnResponse) {
                return [xml]$response
            }
            else {
                $res = $webclient.ResponseHeaders.Get("Location")

                return $res.Substring($res.Length-36)
            }
        } elseif ($PUT) {
            $webclient.Headers.Add("Content-Type","application/x-www-form-urlencoded")

            return $webclient.UploadString($script:APIAddress+$NodeLocation,"PUT",$Data)
        } elseif ($DELETE){
            $webclient.Headers.Add("Content-Type","application/x-www-form-urlencoded")

            return $webclient.UploadString($script:APIAddress+$NodeLocation,"DELETE",$Data)
        } else {
            return [xml]$webclient.DownloadString($script:APIAddress+$NodeLocation)
        }
    }
    catch [Net.WebException]{
        if ($_.Exception.Response.StatusCode.Value__ -eq 400) {
            [System.IO.StreamReader]$failure = $_.Exception.Response.GetResponseStream()
            $AcanoFailureReasonRaw = $failure.ReadToEnd()
            $stripbefore = $AcanoFailureReasonRaw.Remove(0,38)
            $AcanoFailureReason = $stripbefore.Remove($stripbefore.Length-20)
          
            Write-Error "Error: API returned reason: $AcanoFailureReason" -ErrorId $AcanoFailureReason -TargetObject $NodeLocation
        }
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function New-AcanoSession {
    Param (
        [parameter(Mandatory=$true)]
        [string]$APIAddress,
        [parameter(Mandatory=$false)]
        [string]$Port = $null,
        [parameter(Mandatory=$true)]
        [PSCredential]$Credential,
        [parameter(Mandatory=$false)]
        [switch]$IgnoreSSLTrust
    )

    if ($Port -ne $null){
        $script:APIAddress = "https://"+$APIAddress+":"+$Port+"/"
    } else {
        $script:APIAddress = "https://"+$APIAddress+"/"
        $port = 443
    }

    $script:creds = $Credential

    if ($IgnoreSSLTrust) {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    }

    $connectionstatus = Get-AcanoSystemStatus
    $ver = $connectionstatus.softwareVersion
    $ut = $connectionstatus.uptimeSeconds
    if ($connectionstatus -ne $null) {
        Write-Information "Successfully connected to the Acano Server at $APIAddress`:$port running version $ver. Uptime is $ut seconds."
        return $true
    }
    else {
        throw "Could not connect to the Acano Server at $APIAddress`:$port"
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanocoSpaces {
[CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Filter,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$TenantFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$CallLegProfileFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/coSpaces"
    $modifiers = 0

    if ($Filter -ne "") {
        $nodeLocation += "?filter=$Filter"
        $modifiers++
    }

    if ($TenantFilter -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }

        $nodeLocation += "tenantFilter=$TenantFilter"
        $modifiers++
    }

    if ($CallLegProfileFilter -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }

        $nodeLocation += "callLegProfileFilter=$CallLegProfileFilter"
        $modifiers++
    }

    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
            
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).coSpaces.coSpace
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanocoSpace {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) 

    { 

        "getAll"  {
            Get-AcanocoSpaces
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/coSpaces/$Identity").coSpace
        } 
    } 
}

# .ExternalHelp PsAcano.psm1-Help.xml
function New-AcanocoSpace {
    Param (
        [parameter(Mandatory=$true)]
        [string]$Name,
        [parameter(Mandatory=$true)]
        [string]$Uri,
        [parameter(Mandatory=$false)]
        [string]$SecondaryUri,
        [parameter(Mandatory=$false)]
        [string]$CallId,
        [parameter(Mandatory=$false)]
        [string]$CdrTag,
        [parameter(Mandatory=$false)]
        [string]$Passcode,
        [parameter(Mandatory=$false)]
        [string]$DefaultLayout,
        [parameter(Mandatory=$false)]
        [string]$TenantID,
        [parameter(Mandatory=$false)]
        [string]$CallLegProfile,
        [parameter(Mandatory=$false)]
        [string]$CallProfile,
        [parameter(Mandatory=$false)]
        [string]$CallBrandingProfile,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$RequireCallID="true",
        [parameter(Mandatory=$false)]
        [string]$Secret
    )

    $nodeLocation = "/api/v1/coSpaces"
    $data = "name=$Name&uri=$Uri"

    if ($SecondaryUri -ne "") {
        $data += "&secondaryUri=$SecondaryUri"
    }

    if ($CallID -ne "") {
        $data += "&callId=$CallId"
    }

    if ($CdrTag -ne "") {
        $data += "&cdrTag=$CdrTag"
    }

    if ($Passcode -ne "") {
        $data += "&passcode=$Passcode"
    }

    if ($DefaultLayout -ne "") {
        $data += "&defaultLayout=$DefaultLayout"
    }

    if ($TenantID -ne "") {
        $data += "&tenantId=$TenantID"
    }

    if ($CallLegProfile -ne "") {
        $data += "&callLegProfile=$CallLegProfile"
    }

    if ($CallProfile -ne "") {
        $data += "&callProfile=$CallProfile"
    }

    if ($CallBrandingProfile -ne "") {
        $data += "&callBrandingProfile=$CallBrandingProfile"
    }

    if ($Secret -ne "") {
        $data += "&secret=$Secret"
    }

    $data += "&requireCallID="+$RequireCallID

    [string]$NewcoSpaceID = Open-AcanoAPI $nodeLocation -POST -Data $data

    Get-AcanocoSpace $NewcoSpaceID.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Set-AcanocoSpace {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [string]$Name,
        [parameter(Mandatory=$false)]
        [string]$Uri,
        [parameter(Mandatory=$false)]
        [string]$SecondaryUri,
        [parameter(Mandatory=$false)]
        [string]$CallId,
        [parameter(Mandatory=$false)]
        [string]$CdrTag,
        [parameter(Mandatory=$false)]
        [string]$Passcode,
        [parameter(Mandatory=$false)]
        [string]$DefaultLayout,
        [parameter(Mandatory=$false)]
        [string]$TenantId,
        [parameter(Mandatory=$false)]
        [string]$CallLegProfile,
        [parameter(Mandatory=$false)]
        [string]$CallProfile,
        [parameter(Mandatory=$false)]
        [string]$CallBrandingProfile,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$RequireCallId,
        [parameter(Mandatory=$false)]
        [string]$Secret,
        [parameter(Mandatory=$false)]
        [switch]$RegenerateSecret
    )

    $nodeLocation = "/api/v1/coSpaces/$Identity"
    $data = ""
    $modifiers = 0
    
    if ($Name -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "name=$Name"
        $modifiers++
    }
    
    if ($Uri -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "uri=$Uri"
        $modifiers++
    }
    
    if ($SecondaryURI -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "secondaryUri=$SecondaryUri"
        $modifiers++
    }

    if ($CallID -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "callID=$CallId"
        $modifiers++
    }

    if ($CdrTag -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "cdrTag=$CdrTag"
        $modifiers++
    }

    if ($Passcode -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "passcode=$Passcode"
        $modifiers++
    }

    if ($DefaultLayout -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "defaultLayout=$DefaultLayout"
        $modifiers++
    }

    if ($TenantID -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "tenantId=$TenantId"
        $modifiers++
    }

    if ($CallLegProfile -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "callLegProfile=$CallLegProfile"
        $modifiers++
    }

    if ($CallProfile -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "callProfile=$CallProfile"
        $modifiers++
    }

    if ($CallBrandingProfile -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "callBrandingProfile=$CallBrandingProfile"
        $modifiers++
    }

    if ($Secret -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "secret=$Secret"
        $modifiers++
    }

    if ($RequireCallID -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "requireCallID="+$RequireCallId
        $modifiers++
    }

    if ($modifiers -gt 0) {
            $data += "&"
        }
    $data += "regenerateSecret="+$RegenerateSecret.toString()

    Open-AcanoAPI $nodeLocation -PUT -Data $data

    Get-AcanocoSpace $Identity
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Remove-AcanocoSpace { 
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove coSpace")) {
        Open-AcanoAPI "api/v1/coSpaces/$Identity" -DELETE
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanocoSpaceMembers {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$true,Position=1)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Filter,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$CallLegProfileFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    
    $nodeLocation = "api/v1/coSpaces/$Identity/coSpaceUsers"
    $modifiers = 0

    if ($Filter -ne "") {
        $nodeLocation += "?filter=$Filter"
        $modifiers++
    }

    if ($CallLegProfileFilter -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "callLegProfileFilter=$CallLegProfileFilter"
        $modifiers++
    }

    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).coSpaceUsers.coSpaceUser | fl
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanocoSpaceMember {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(ParameterSetName="getSingle",Mandatory=$true)]
        [parameter(ParameterSetName="getAll",Mandatory=$false)]
        [string]$coSpaceMemberID
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanocoSpaceMembers $Identity
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/coSpaces/$Identity/coSpaceUsers/$coSpaceMemberID").coSpaceUser
        }
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function New-AcanocoSpaceMember {
    Param (
        [parameter(Mandatory=$true)]
        [string]$Identity,
        [parameter(Mandatory=$true)]
        [string]$UserJid,
        [parameter(Mandatory=$false)]
        [string]$CallLegProfile,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanDestroy,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanAddRemoveMember,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanChangeName,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanChangeUri,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanChangeCallId,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanChangePasscode,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanPostMessage,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanRemoveSelf,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanDeleteAllMessages
    )

    $nodeLocation = "/api/v1/coSpaces/$Identity/coSpaceUsers"
    $data = "userJid=$UserJid"

    if ($CallLegProfile -ne "") {
        $data += "&callLegProfile=$CallLegProfile"
    }

    if ($CanDestroy -ne "") {
        $data += "&canDestroy="+$CanDestroy
    }

    if ($CanAddRemoveMember -ne "") {
        $data += "&canAddRemoveMember="+$CanAddRemoveMember
    }

    if ($CanChangeName -ne "") {
        $data += "&canChangeName="+$CanChangeName
    }

    if ($CanChangeUri -ne "") {
        $data += "&canChangeUri="+$CanChangeUri
    }

    if ($CanChangeCallId -ne "") {
        $data += "&canChangeCallId="+$CanChangeCallId
    }

    if ($CanChangePasscode -ne "") {
        $data += "&canChangePasscode="+$CanChangePasscode
    }

    if ($CanPostMessage -ne "") {
        $data += "&canPostMessage="+$CanPostMessage
    }

    if ($CanRemoveSelf -ne "") {
        $data += "&canRemoveSelf="+$CanRemoveSelf
    }

    if ($CanDeleteAllMessages -ne "") {
        $data += "&canDeleteAllMessages="+$CanDeleteAllMessages
    }

    [string]$NewcoSpaceMemberID = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanocoSpaceMember $Identity -coSpaceMemberID $NewcoSpaceMemberID.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Set-AcanocoSpaceMember {
    Param (
        [parameter(Mandatory=$true)]
        [string]$Identity,
        [parameter(Mandatory=$true)]
        [string]$coSpaceMemberId,
        [parameter(Mandatory=$false)]
        [string]$CallLegProfile,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanDestroy,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanAddRemoveMember,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanChangeName,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanChangeUri,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanChangeCallId,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanChangePasscode,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanPostMessage,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanRemoveSelf,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanDeleteAllMessages
    )

    $nodeLocation = "/api/v1/coSpaces/$Identity/coSpaceUsers/$coSpaceMemberId"
    $data = ""
    $modifiers = 0
    
    if ($CallLegProfile -ne "") {
            $data += "callLegProfile=$CallLegProfile"
            $modifiers++
    }

    if ($CanDestroy -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "canDestroy=$CanDestroy"
        $modifiers++
    }

    if ($CanAddRemoveMember -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "canAddRemoveMember=$CanAddRemoveMember"
        $modifiers++
    }

    if ($CanChangeName -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "canChangeName=$CanChangeName"
        $modifiers++
    }

    if ($CanChangeUri -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "canChangeUri=$CanChangeUri"
        $modifiers++
    }

    if ($CanChangeCallId -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "canChangeCallId=$CanChangeCallId"
        $modifiers++
    }

    if ($CanChangePasscode -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "canChangePasscode=$CanChangePasscode"
        $modifiers++
    }

    if ($CanPostMessage -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
            $data += "canPostMessage=$CanPostMessage"
            $modifiers++
    }

    if ($CanRemoveSelf -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "canRemoveSelf=$CanRemoveSelf"
        $modifiers++
    }

    if ($CanDeleteAllMessages -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "canDeleteAllMessages=$CanDeleteAllMessages"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data

    Get-AcanocoSpaceMember $Identity -coSpaceMemberID $coSpaceMemberId
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Remove-AcanocoSpaceMember {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true)]
        [string]$Identity,
        [parameter(Mandatory=$true)]
        [string]$UserId
    )

    if ($PSCmdlet.ShouldProcess("$UserId","Remove user from cospace with id $Identity")) {
        Open-AcanoAPI "api/v1/coSpaces/$Identity/coSpaceUsers/$UserId" -DELETE
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function New-AcanocoSpaceMessage {
    Param (
        [parameter(Mandatory=$true)]
        [string]$Identity,
        [parameter(Mandatory=$true)]
        [string]$Message,
        [parameter(Mandatory=$true)]
        [string]$From
    )

    $nodeLocation = "/api/v1/coSpaces/$Identity/messages"
    $data = "message=$Message"
    $data += "&from=$From"

    [string]$NewcoSpaceMessage = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    ## NOT IMPLEMENTED YET Get-AcanocoSpaceMember -coSpaceID $coSpaceId -coSpaceUserID $NewcoSpaceMessage.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Remove-AcanocoSpaceMessages {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [string]$MinAge,
        [parameter(Mandatory=$false)]
        [string]$MaxAge
    )

    $nodeLocation = "/api/v1/coSpaces/$Identity/messages"
    $data = ""
    $modifiers = 0

    if ($MinAge -ne "") {
        $data += "minAge=$MinAge"
        $modifiers++
    }

    if ($MaxAge -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "maxAge=$MaxAge"
    }

    if ($PSCmdlet.ShouldProcess("$Identity","Remove messages in coSpace")) {
        if ($modifiers -gt 0) {
            Open-AcanoAPI $nodeLocation -DELETE -Data $data
        } else {
            Open-AcanoAPI $nodeLocation -DELETE
        }
    } 
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanocoSpaceAccessMethods {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$true,Position=1)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Filter,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$CallLegProfileFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    
    $nodeLocation = "api/v1/coSpaces/$Identity/accessMethods"
    $modifiers = 0

    if ($Filter -ne "") {
        $nodeLocation += "?filter=$Filter"
        $modifiers++
    }

    if ($CallLegProfileFilter -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "callLegProfileFilter=$CallLegProfileFilter"
        $modifiers++
    }

    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).accessMethods.accessMethod | fl
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanocoSpaceAccessMethod {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(ParameterSetName="getSingle",Mandatory=$true)]
        [parameter(ParameterSetName="getAll",Mandatory=$false)]
        [string]$coSpaceAccessMethodID
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanocoSpaceAccessMethods $Identity
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/coSpaces/$Identity/accessMethods/$coSpaceAccessMethodID").accessMethod
        }
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function New-AcanocoSpaceAccessMethod {
    Param (
        [parameter(Mandatory=$true)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [string]$Uri,
        [parameter(Mandatory=$false)]
        [string]$CallId,
        [parameter(Mandatory=$false)]
        [string]$Passcode,
        [parameter(Mandatory=$false)]
        [string]$CallLegProfile,
        [parameter(Mandatory=$false)]
        [string]$Secret,
        [parameter(Mandatory=$false)]
        [string]$Scope
    )

    $nodeLocation = "/api/v1/coSpaces/$Identity/accessMethods"
    $data = ""
    $modifiers = 0

    if ($Uri -ne "") {
        $data += "?uri=$Uri"
        $modifiers++
    }

    if ($CallId -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        } else {
            $data += "?"
        }
        $data += "callId=$CallId"
        $modifiers++
    }

    if ($Passcode -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        } else {
            $data += "?"
        }
        $data += "passcode=$Passcode"
        $modifiers++
    }

    if ($CallLegProfile -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        } else {
            $data += "?"
        }
        $data += "callLegProfile=$CallLegProfile"
        $modifiers++
    }

    if ($Secret -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        } else {
            $data += "?"
        }
        $data += "secret=$Secret"
        $modifiers++
    }

    if ($Scope -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        } else {
            $data += "?"
        }
        $data += "scope=$Scope"
    }

    [string]$NewcoSpaceAccessMethod = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanocoSpaceAccessMethod $Identity -coSpaceAccessMethodID $NewcoSpaceAccessMethod.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Set-AcanocoSpaceAccessMethod {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$true)]
        [string]$coSpaceAccessMethodID,
        [parameter(Mandatory=$false)]
        [string]$Uri,
        [parameter(Mandatory=$false)]
        [string]$CallId,
        [parameter(Mandatory=$false)]
        [string]$Passcode,
        [parameter(Mandatory=$false)]
        [string]$CallLegProfile,
        [parameter(Mandatory=$false)]
        [string]$Secret,
        [parameter(Mandatory=$false)]
        [switch]$RegenerateSecret,
        [parameter(Mandatory=$false)]
        [string]$Scope
    )

    $nodeLocation = "/api/v1/coSpaces/$Identity/accessMethods/$coSpaceAccessMethodID"
    $data = ""
    $modifiers = 0

    if ($Uri -ne "") {
        $nodeLocation += "?uri=$Uri"
        $modifiers++
    }

    if ($CallId -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        } else {
            $data += "?"
        }
        $data += "callId=$CallId"
        $modifiers++
    }

    if ($Passcode -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        } else {
            $data += "?"
        }
        $data += "passcode=$Passcode"
        $modifiers++
    }

    if ($CallLegProfile -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        } else {
            $data += "?"
        }
        $data += "callLegProfile=$CallLegProfile"
        $modifiers++
    }

    if ($Secret -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        } else {
            $data += "?"
        }
        $data += "secret=$Secret"
        $modifiers++
    }

    if ($RegenerateSecret) {
        if ($modifiers -gt 0) {
            $data += "&"
        } else {
            $data += "?"
        }
        $data += "regenerateSecret=true"
        $modifiers++
    }

    if ($Scope -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        } else {
            $data += "?"
        }
        $data += "scope=$Scope"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanocoSpaceAccessMethod $Identity -coSpaceAccessMethodID $coSpaceAccessMethodID

}

# .ExternalHelp PsAcano.psm1-Help.xml
function Remove-AcanocoSpaceAccessMethod {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true)]
        [string]$Identity,
        [parameter(Mandatory=$true)]
        [string]$coSpaceAccessMethodID
    )

    if ($PSCmdlet.ShouldProcess("$coSpaceAccessMethodID","Remove access method from coSpace $Identity")) {
        Open-AcanoAPI "api/v1/coSpaces/$Identity/accessMethods/$coSpaceAccessMethodID" -DELETE
    }
}

function Start-AcanocoSpaceCallDiagnosticsGeneration {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    Open-AcanoAPI "api/v1/coSpaces/$Identity/diagnostics" -POST

}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoOutboundDialPlanRules {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Filter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/outboundDialPlanRules"
    $modifiers = 0

    if ($Filter -ne "") {
        $nodeLocation += "?filter=$Filter"
        $modifiers++
    }

    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).outboundDialPlanRules.outboundDialPlanRule
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoOutboundDialPlanRule {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoOutboundDialPlanRules
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/outboundDialPlanRules/$Identity").outboundDialPlanRule
        } 
    }  
}

function New-AcanoOutboundDialPlanRule {
    [CmdletBinding(DefaultParameterSetName="NoCallbridgeId")]
    Param (
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$true)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$true)]
        [string]$Domain,
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$false)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$false)]
        [string]$LocalContactDomain,
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$false)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$false)]
        [string]$LocalFromDomain,
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$false)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$false)]
        [string]$SipProxy,
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$false)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$false)]
        [ValidateSet("sip","lync","avaya")]
        [string]$TrunkType,
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$false)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$false)]
        [string]$Priority,
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$false)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$false)]
        [ValidateSet("stop","continue")]
        [string]$FailureAction,
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$false)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$false)]
        [ValidateSet("auto","encrypted","unencrypted")]
        [string]$SipControlEncryption,
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$false)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$true)]
        [ValidateSet("global","callbridge")]
        [string]$Scope,
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$false)]
        [string]$CallBridgeId,
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$false)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$false)]
        [string]$Tenant,
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$false)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$false)]
        [ValidateSet("default","traversal")]
        [string]$CallRouting
    )

    $nodeLocation = "/api/v1/outboundDialPlanRules"
    $data = "domain=$Domain"

    if ($LocalContactDomain -ne "") {
        $data += "&localContactDomain=$LocalContactDomain"
    }

    if ($LocalFromDomain -ne "") {
        $data += "&localFromDomain=$LocalFromDomain"
    }

    if ($SipProxy -ne "") {
        $data += "&sipProxy=$SipProxy"
    }

    if ($TrunkType -ne "") {
        $data += "&trunkType=$TrunkType"
    }

    if ($Priority -ne "") {
        $data += "&priority=$Priority"
    }
    
    if ($FailureAction -ne "") {
        $data += "&failureAction=$FailureAction"
    }

    if ($SipControlEncryption -ne "") {
        $data += "&sipControlEncryption=$SipControlEncryption"
    }

    if ($Scope -ne "") {
        $data += "&scope=$Scope"
    }

    if ($CallBridgeId -ne "") {
        $data += "&callBridge=$CallBridgeId"
    }

    if ($Tenant -ne "") {
        $data += "&tenant=$Tenant"
    }

    if ($CallRouting -ne "") {
        $data += "&callRouting=$CallRouting"
    }

    [string]$NewOutboundDialPlanRuleId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoOutboundDialPlanRule $NewOutboundDialPlanRuleId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoOutboundDialPlanRule {
    [CmdletBinding(DefaultParameterSetName="NoCallbridgeId")]
    Param (
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$true,Position=1)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$false)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$false)]
        [string]$Domain,
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$false)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$false)]
        [string]$LocalContactDomain,
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$false)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$false)]
        [string]$LocalFromDomain,
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$false)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$false)]
        [string]$SipProxy,
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$false)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$false)]
        [ValidateSet("sip","lync","avaya")]
        [string]$TrunkType,
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$false)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$false)]
        [string]$Priority,
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$false)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$false)]
        [ValidateSet("stop","continue")]
        [string]$FailureAction,
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$false)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$false)]
        [ValidateSet("auto","encrypted","unencrypted")]
        [string]$SipControlEncryption,
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$false)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$true)]
        [ValidateSet("global","callbridge")]
        [string]$Scope,
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$false)]
        [string]$CallBridgeId,
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$false)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$false)]
        [string]$Tenant,
        [parameter(ParameterSetName="NoCallbridgeId",Mandatory=$false)]
        [parameter(ParameterSetName="CallbridgeId",Mandatory=$false)]
        [ValidateSet("default","traversal")]
        [string]$CallRouting
    )

    $nodeLocation = "/api/v1/outboundDialPlanRules/$Identity"
    $modifiers = 0
    $data = ""

    if ($Domain -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "domain=$Domain"
        $modifiers++
    }

    if ($LocalContactDomain -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "localContactDomain=$LocalContactDomain"
        $modifiers++
    }

    if ($LocalFromDomain -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "localFromDomain=$LocalFromDomain"
        $modifiers++
    }

    if ($SipProxy -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "sipProxy=$SipProxy"
        $modifiers++
    }

    if ($TrunkType -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "trunkType=$TrunkType"
        $modifiers++
    }

    if ($Priority -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "priority=$Priority"
        $modifiers++
    }
    
    if ($FailureAction -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "failureAction=$FailureAction"
        $modifiers++
    }

    if ($SipControlEncryption -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "sipControlEncryption=$SipControlEncryption"
        $modifiers++
    }

    if ($Scope -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "scope=$Scope"
        $modifiers++
    }

    if ($CallBridgeId -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "callBridge=$CallBridgeId"
        $modifiers++
    }

    if ($Tenant -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "tenant=$Tenant"
        $modifiers++
    }

    if ($CallRouting -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "callRouting=$CallRouting"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoOutboundDialPlanRule $Identity
}

function Remove-AcanoOutboundDialPlanRule {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove outbound dial plan rule")) {
        Open-AcanoAPI "/api/v1/outboundDialPlanRules/$Identity" -DELETE
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoInboundDialPlanRules {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Filter,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$TenantFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/inboundDialPlanRules"
    $modifiers = 0

    if ($Filter -ne "") {
        $nodeLocation += "?filter=$Filter"
        $modifiers++
    }

    if ($TenantFilter -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "tenantFilter=$TenantFilter"
        $modifiers++
    }

    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).inboundDialPlanRules.inboundDialPlanRule
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoInboundDialPlanRule {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoInboundDialPlanRules
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/inboundDialPlanRules/$Identity").inboundDialPlanRule
        } 
    }
}

function New-AcanoInboundDialPlanRule {
    Param (
        [parameter(Mandatory=$true)]
        [string]$Domain,
        [parameter(Mandatory=$false)]
        [string]$Priority,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ResolveToUsers,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ResolveTocoSpaces,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ResolveToIvrs,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ResolveToLyncConferences,
        [parameter(Mandatory=$false)]
        [string]$Tenant
    )


    $nodeLocation = "/api/v1/inboundDialPlanRules"
    $data = "domain=$Domain"

    if ($Priority -ne "") {
        $data += "&priority=$Priority"
    }
    
    if ($ResolveToUsers -ne "") {
        $data += "&resolveToUsers="+$ResolveToUsers
    }

    if ($ResolveTocoSpaces -ne "") {
        $data += "&resolveTocoSpaces="+$ResolveTocoSpaces
    }

    if ($ResolveToIvrs -ne "") {
        $data += "&resolveToIvrs="+$ResolveToIvrs
    }

    if ($ResolveToLyncConferences -ne "") {
        $data += "&resolveToLyncConferences="+$ResolveToLyncConferences
    }

    if ($Tenant -ne "") {
        $data += "&tenant=$Tenant"
    }

    [string]$NewInboundDialPlanRuleId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoInboundDialPlanRule $NewInboundDialPlanRuleId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoInboundDialPlanRule {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [string]$Domain,
        [parameter(Mandatory=$false)]
        [string]$Priority,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ResolveToUsers,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ResolveTocoSpaces,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ResolveToIvrs,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ResolveToLyncConferences,
        [parameter(Mandatory=$false)]
        [string]$Tenant
    )


    $nodeLocation = "/api/v1/inboundDialPlanRules/$Identity"
    $data = ""
    $modifiers = 0

    if ($Domain -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "domain=$Domain"
        $modifiers++
    }

    if ($Priority -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "priority=$Priority"
        $modifiers++
    }
    
    if ($ResolveToUsers -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "resolveToUsers=$ResolveToUsers"
        $modifiers++
    }

    if ($ResolveTocoSpaces -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "resolveTocoSpaces=$ResolveTocoSpaces"
        $modifiers++
    }

    if ($ResolveToIvrs -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "resolveToIvrs=$ResolveToIvrs"
        $modifiers++
    }

    if ($ResolveToLyncConferences -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "resolveToLyncConferences=$ResolveToLyncConferences"
        $modifiers++
    }

    if ($Tenant -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "tenant=$Tenant"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoInboundDialPlanRule $Identity
}

function Remove-AcanoInboundDialPlanRule {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove inbound dial plan rule")) {
        Open-AcanoAPI "/api/v1/inboundDialPlanRules/$Identity" -DELETE
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoCallForwardingDialPlanRules {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Filter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/forwardingDialPlanRules"
    $modifiers = 0

    if ($Filter -ne "") {
        $nodeLocation += "?filter=$Filter"
        $modifiers++
    }

    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).forwardingDialPlanRules.forwardingDialPlanRule
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoCallForwardingDialPlanRule {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoCallForwardingDialPlanRules
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/forwardingDialPlanRules/$Identity").forwardingDialPlanRule
        } 
    }
}

function New-AcanoCallForwardingDialPlanRule {
    Param (
        [parameter(Mandatory=$true)]
        [string]$MatchPattern,
        [parameter(Mandatory=$false)]
        [string]$DestinationDomain,
        [parameter(Mandatory=$false)]
        [ValidateSet("forward","reject")]
        [string]$Action,
        [parameter(Mandatory=$false)]
        [ValidateSet("regenerate","preserve")]
        [string]$CallerIdMode,
        [parameter(Mandatory=$false)]
        [string]$Priority,
        [parameter(Mandatory=$false)]
        [string]$Tenant
    )

    $nodeLocation = "/api/v1/forwardingDialPlanRules"
    $data = "matchPattern=$MatchPattern"

    if ($DestinationDomain -ne "") {
        $data += "&destinationDomain=$DestinationDomain"
    }

    if ($Action -ne "") {
        $data += "&action=$Action"
    }
    
    if ($CallerIdMode -ne "") {
        $data += "&callerIdMode=$CallerIdMode"
    }

    if ($Priority -ne "") {
        $data += "&priority=$Priority"
    }

    if ($Tenant -ne "") {
        $data += "&tenant=$Tenant"
    }

    [string]$NewCallForwardingPlanRuleId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoCallForwardingDialPlanRule $NewCallForwardingPlanRuleId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoCallForwardingDialPlanRule {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [string]$MatchPattern,
        [parameter(Mandatory=$false)]
        [string]$DestinationDomain,
        [parameter(Mandatory=$false)]
        [ValidateSet("forward","reject")]
        [string]$Action,
        [parameter(Mandatory=$false)]
        [ValidateSet("regenerate","preserve")]
        [string]$CallerIdMode,
        [parameter(Mandatory=$false)]
        [string]$Priority,
        [parameter(Mandatory=$false)]
        [string]$Tenant
    )

    $nodeLocation = "/api/v1/forwardingDialPlanRules/$Identity"
    $modifiers = 0
    $data = ""

    if ($MatchPattern -ne "") {
        if ($modifiers -gt 0) {
            $data += ""
        }
        $data += "matchPattern=$MatchPattern"
        $modifiers++
    }

    if ($DestinationDomain -ne "") {
        if ($modifiers -gt 0) {
            $data += ""
        }
        $data += "destinationDomain=$DestinationDomain"
        $modifiers++
    }

    if ($Action -ne "") {
        if ($modifiers -gt 0) {
            $data += ""
        }
        $data += "action=$Action"
        $modifiers++
    }

    if ($CallerIdMode -ne "") {
        if ($modifiers -gt 0) {
            $data += ""
        }
        $data += "callerIdMode=$CallerIdMode"
        $modifiers++
    }

    if ($Priority -ne "") {
        if ($modifiers -gt 0) {
            $data += ""
        }
        $data += "priority=$Priority"
        $modifiers++
    }

    if ($Tenant -ne "") {
        if ($modifiers -gt 0) {
            $data += ""
        }
        $data += "tenant=$Tenant"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoCallForwardingDialPlanRule $Identity
}

function Remove-AcanoCallForwardingDialPlanRule {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove call forwarding rule")) {
        Open-AcanoAPI "/api/v1/forwardingDialPlanRules/$Identity" -DELETE
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoCalls {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$coSpaceFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$TenantFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/calls"
    $modifiers = 0

    if ($coSpaceFilter -ne "") {
        $nodeLocation += "?coSpacefilter=$coSpaceFilter"
        $modifiers++
    }

    if ($TenantFilter -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "tenantFilter=$TenantFilter"
        $modifiers++
    }

    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).calls.call
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoCall {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoCalls
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/calls/$Identity").call
        } 
    }
}

function New-AcanoCall {
    Param (
        [parameter(Mandatory=$true)]
        [string]$CoSpaceId,
        [parameter(Mandatory=$false)]
        [string]$Name,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$Locked,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$Recording,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$AllowAllMuteSelf,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$AllowAllPresentationContribution,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$JoinAudioMuteOverride
    )

    $nodeLocation = "/api/v1/calls"
    $data = "coSpace=$CoSpaceId"

    if ($Name -ne "") {
        $data += "&name=$Name"
    }

    if ($Locked -ne "") {
        $data += "&locked=$Locked"
    }

    if ($Recording -ne "") {
        $data += "&recording=$Recording"
    }

    if ($AllowAllMuteSelf -ne "") {
        $data += "&allowAllMuteSelf=$AllowAllMuteSelf"
    }

    if ($AllowAllPresentationContribution -ne "") {
        $data += "&allowAllPresentationContribution=$AllowAllPresentationContribution"
    }

    if ($JoinAudioMuteOverride -ne "") {
        $data += "&joinAudioMuteOverride=$JoinAudioMuteOverride"
    }

    [string]$NewCallId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoCall $NewCallId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoCall {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [string]$Name,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$Locked,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$Recording,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$AllowAllMuteSelf,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$AllowAllPresentationContribution,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$JoinAudioMuteOverride
    )

    $nodeLocation = "/api/v1/calls/$Identity"
    $data = ""
    $modifiers = 0

    if ($Name -ne "") {
        $data += "name=$Name"
        $modifiers++
    }

    if ($Locked -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "locked=$Locked"
        $modifiers++
    }

    if ($Recording -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "recording=$Recording"
    }

    if ($AllowAllMuteSelf -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "allowAllMuteSelf=$AllowAllMuteSelf"
    }

    if ($AllowAllPresentationContribution -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "allowAllPresentationContribution=$AllowAllPresentationContribution"
    }

    if ($JoinAudioMuteOverride -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "joinAudioMuteOverride=$JoinAudioMuteOverride"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoCall $Identity
}

function Remove-AcanoCall {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove call")) {
        Open-AcanoAPI "/api/v1/calls/$Identity" -DELETE
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoCallProfiles {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/callProfiles"
    $modifiers = 0

    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).callProfiles.callProfile
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoCallProfile {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoCallProfiles
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/callProfiles/$Identity").callProfile | fl
        } 
    }
}

function New-AcanoCallProfile {
    Param (
        [parameter(Mandatory=$false)]
        [string]$ParticipantLimit,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$MessageBoardEnabled,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$Locked,
        [parameter(Mandatory=$false)]
        [ValidateSet("disabled","manual","automatic")]
        [string]$RecordingMode
    )

    $nodeLocation = "/api/v1/callProfiles"
    $data = ""
    $modifiers = 0

    if ($ParticipantLimit -ne "") {
        $data += "participantLimit=$ParticipantLimit"
        $modifiers++
    }

    if ($MessageBoardEnabled -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "messageBoardEnabled=$MessageBoardEnabled"
        $modifiers++
    }

    if ($RecordingMode -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "recordingMode=$RecordingMode"
        $modifiers++
    }

    if ($Locked -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "locked=$Locked"
    }

    [string]$NewCallProfileId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoCallProfile -$NewCallProfileId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoCallProfile {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [string]$ParticipantLimit,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$MessageBoardEnabled,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$Locked,
        [parameter(Mandatory=$false)]
        [ValidateSet("disabled","manual","automatic")]
        [string]$RecordingMode
    )

    $nodeLocation = "/api/v1/callProfiles/$Identity"
    $data = ""
    $modifiers = 0

    if ($ParticipantLimit -ne "") {
        $data += "participantLimit=$ParticipantLimit"
        $modifiers++
    }

    if ($MessageBoardEnabled -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "messageBoardEnabled=$MessageBoardEnabled"
        $modifiers++
    }

    if ($RecordingMode -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "recordingMode=$RecordingMode"
        $modifiers++
    }

    if ($Locked -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "locked=$Locked"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoCallProfile $Identity
}

function Remove-AcanoCallProfile {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove call profile")) {
        Open-AcanoAPI "/api/v1/callProfiles/$Identity" -DELETE
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoCallLegs {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Filter,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$TenantFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$ParticipantFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$OwnerIDSet,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [ValidateSet("All","packetLoss","excessiveJitter","highRoundTripTime")]
        [string[]]$Alarms,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$CallID,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$ActiveLayoutFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$AvailableVideoStreamsLowerBound,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$AvailableVideoStreamsUpperBound,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    if ($CallID -ne "") {
        $nodeLocation = "api/v1/calls/$CallID/callLegs"
    } else {
        $nodeLocation = "api/v1/callLegs"
    }

    $modifiers = 0

    if ($Filter -ne "") {
        $nodeLocation += "?filter=$Filter"
        $modifiers++
    }

    if ($TenantFilter -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "tenantFilter=$TenantFilter"
        $modifiers++
    }

    if ($ParticipantFilter -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "participantFilter=$ParticipantFilter"
        $modifiers++
    }

    if ($OwnerIdSet -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "ownerIdSet=$OwnerIdSet"
        $modifiers++
    }

    if ($Alarms -ne $null) {
        if ($Alarms.Contains("All") -or $Alarms.Contains("all")) {
            $Alarmstring = "all"
        } else {
            $i = 0
            foreach ($Alarm in $Alarms) {
                if ($i -eq 0) {
                    $Alarmstring = $Alarm
                } else {
                    $Alarmstring += "|$Alarm"
                }
                $i++
            }
        }

        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "alarms=$Alarmstring"
        $modifiers++
    }

    if ($ActiveLayoutFilter -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        
        $nodeLocation += "activeLayoutFilter=$ActiveLayoutFilter"
        $modifiers++
    }

    if ($AvailableVideoStreamsLowerBound -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        
        $nodeLocation += "availableVideoStreamsLowerBound=$AvailableVideoStreamsLowerBound"
        $modifiers++
    }

    if ($AvailableVideoStreamsUpperBound -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        
        $nodeLocation += "availableVideoStreamsUpperBound=$AvailableVideoStreamsUpperBound"
        $modifiers++
    }

    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).callLegs.callLeg
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoCallLeg {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoCallLegs
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/callLegs/$Identity").callLeg
        } 
    }
}

function New-AcanoCallLeg {
    Param (
        [parameter(Mandatory=$true)]
        [string]$Identity,
        [parameter(Mandatory=$true)]
        [string]$RemoteParty,
        [parameter(Mandatory=$false)]
        [string]$Bandwidth,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$Confirmation,
        [parameter(Mandatory=$false)]
        [string]$OwnerId,
        [parameter(Mandatory=$false)]
        [ValidateSet("allEqual","speakerOnly","telepresence","stacked","allEqualQuarters","allEqualNinths","allEqualSixteenths","allEqualTwentyFifths","onePlusFive","onePlusSeven","onePlusNine","automatic")]
        [string]$ChosenLayout,
        [parameter(Mandatory=$false)]
        [string]$CallLegProfileId,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$NeedsActivation,
        [parameter(Mandatory=$false)]
        [ValidateSet("allEqual","speakerOnly","telepresence","stacked","allEqualQuarters","allEqualNinths","allEqualSixteenths","allEqualTwentyFifths","onePlusFive","onePlusSeven","onePlusNine","automatic")]
        [string]$DefaultLayout,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$EndCallAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$MuteOthersAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$VideoMuteOthersAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$MuteSelfAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$VideoMuteSelfAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ChangeLayoutAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ParticipantLabels,
        [parameter(Mandatory=$false)]
        [ValidateSet("dualStream","singleStream")]
        [string]$PresentationDisplayMode,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$PresentationContributionAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$PresentationViewingAllowed,
        [parameter(Mandatory=$false)]
        [string]$JoinToneParticipantThreshold,
        [parameter(Mandatory=$false)]
        [string]$LeaveToneParticipantThreshold,
        [parameter(Mandatory=$false)]
        [ValidateSet("auto","disabled")]
        [string]$VideoMode,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$RxAudioMute,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$TxAudioMute,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$RxVideoMute,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$TxVideoMute,
        [parameter(Mandatory=$false)]
        [ValidateSet("optional","required","prohibited")]
        [string]$SipMediaEncryption,
        [parameter(Mandatory=$false)]
        [string]$AudioPacketSizeMs,
        [parameter(Mandatory=$false)]
        [ValidateSet("deactivate","disconnect","remainActivated")]
        [string]$DeactivationMode,
        [parameter(Mandatory=$false)]
        [string]$DeactivationModeTime,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$TelepresenceCallsAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$SipPresentationChannelEnabled,
        [parameter(Mandatory=$false)]
        [string]$DtmfSequence,
        [parameter(Mandatory=$false)]
        [ValidateSet("serverOnly","serverAndClient")]
        [string]$BfcpMode
    )

    $nodeLocation = "/api/v1/calls/$Identity/callLegs"
    $data = "remoteParty=$RemoteParty"

    if ($Bandwidth -ne "") {
        $data += "&bandwidth=$Bandwidth"
    }

    if ($Confirmation -ne "") {
        $data += "&confirmation=$Confirmation"
    }

    if ($OwnerId -ne "") {
        $data += "&ownerId=$OwnerId"
    }

    if ($ChosenLayout -ne "") {
        $data += "&chosenLayout=$ChosenLayout"
    }

    if ($CallLegProfileId -ne "") {
        $data += "&callLegProfile=$CallLegProfileId"
    }

    if ($NeedsActivation -ne "") {
        $data += "&needsActivation=$NeedsActivation"
    }

    if ($DefaultLayout -ne "") {
        $data += "&defaultLayout=$DefaultLayout"
    }

    if ($EndCallAllowed -ne "") {
        $data += "&endCallAllowed=$EndCallAllowed"
    }

    if ($MuteOthersAllowed -ne "") {
        $data += "&muteOthersAllowed=$MuteOthersAllowed"
    }

    if ($VideoMuteOthersAllowed -ne "") {
        $data += "&videoMuteOthersAllowed=$VideoMuteOthersAllowed"
    }

    if ($MuteSelfAllowed -ne "") {
        $data += "&muteSelfAllowed=$MuteSelfAllowed"
    }

    if ($VideoMuteSelfAllowed -ne "") {
        $data += "&videoMuteSelfAllowed=$VideoMuteSelfAllowed"
    }

    if ($ChangeLayoutAllowed -ne "") {
        $data += "&changeLayoutAllowed=$ChangeLayoutAllowed"
    }

    if ($ParticipantLabels -ne "") {
        $data += "&participantLabels=$ParticipantLabels"
    }

    if ($PresentationDisplayMode -ne "") {
        $data += "&presentationDisplayMode=$PresentationDisplayMode"
    }

    if ($PresentationContributionAllowed -ne "") {
        $data += "&presentationContributionAllowed=$PresentationContributionAllowed"
    }

    if ($PresentationViewingAllowed -ne "") {
        $data += "&presentationViewingAllowed=$PresentationViewingAllowed"
    }

    if ($JoinToneParticipantThreshold -ne "") {
        $data += "&joinToneParticipantThreshold=$JoinToneParticipantThreshold"
    }

    if ($LeaveToneParticipantThreshold -ne "") {
        $data += "&leaveToneParticipantThreshold=$LeaveToneParticipantThreshold"
    }

    if ($VideoMode -ne "") {
        $data += "&videoMode=$VideoMode"
    }

    if ($RxAudioMute -ne "") {
        $data += "&rxAudioMute=$RxAudioMute"
    }

    if ($TxAudioMute -ne "") {
        $data += "&txAudioMute=$TxAudioMute"
    }

    if ($RxVideoMute -ne "") {
        $data += "&rxVideoMute=$RxVideoMute"
    }

    if ($TxVideoMute -ne "") {
        $data += "&txVideoMute=$TxVideoMute"
    }

    if ($SipMediaEncryption -ne "") {
        $data += "&sipMediaEncryption=$SipMediaEncryption"
    }

    if ($AudioPacketSizeMs -ne "") {
        $data += "&audioPacketSizeMs=$AudioPacketSizeMs"
    }

    if ($DeactivationMode -ne "") {
        $data += "&deactivationMode=$DeactivationMode"
    }

    if ($DeactivationModeTime -ne "") {
        $data += "&deactivationModeTime=$DeactivationModeTime"
    }

    if ($TelepresenceCallsAllowed -ne "") {
        $data += "&telepresenceCallsAllowed=$TelepresenceCallsAllowed"
    }

    if ($SipPresentationChannelEnabled -ne "") {
        $data += "&sipPresentationChannelEnabled=$SipPresentationChannelEnabled"
    }

    if ($BfcpMode -ne "") {
        $data += "&bfcpMode=$BfcpMode"
    }

    if ($DtmfSequence -ne "") {
        $data += "&dtmfSequence=$DtmfSequence"
    }

    [string]$NewCallLegId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoCallLeg $NewCallLegId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoCallLeg {
    Param (
        [parameter(Mandatory=$true)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [string]$OwnerId,
        [parameter(Mandatory=$false)]
        [ValidateSet("allEqual","speakerOnly","telepresence","stacked","allEqualQuarters","allEqualNinths","allEqualSixteenths","allEqualTwentyFifths","onePlusFive","onePlusSeven","onePlusNine","automatic")]
        [string]$ChosenLayout,
        [parameter(Mandatory=$false)]
        [string]$CallLegProfileId,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$NeedsActivation,
        [parameter(Mandatory=$false)]
        [ValidateSet("allEqual","speakerOnly","telepresence","stacked","allEqualQuarters","allEqualNinths","allEqualSixteenths","allEqualTwentyFifths","onePlusFive","onePlusSeven","onePlusNine","automatic")]
        [string]$DefaultLayout,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$EndCallAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$MuteOthersAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$VideoMuteOthersAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$MuteSelfAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$VideoMuteSelfAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ChangeLayoutAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ParticipantLabels,
        [parameter(Mandatory=$false)]
        [ValidateSet("dualStream","singleStream")]
        [string]$PresentationDisplayMode,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$PresentationContributionAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$PresentationViewingAllowed,
        [parameter(Mandatory=$false)]
        [string]$JoinToneParticipantThreshold,
        [parameter(Mandatory=$false)]
        [string]$LeaveToneParticipantThreshold,
        [parameter(Mandatory=$false)]
        [ValidateSet("auto","disabled")]
        [string]$VideoMode,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$RxAudioMute,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$TxAudioMute,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$RxVideoMute,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$TxVideoMute,
        [parameter(Mandatory=$false)]
        [ValidateSet("optional","required","prohibited")]
        [string]$SipMediaEncryption,
        [parameter(Mandatory=$false)]
        [string]$AudioPacketSizeMs,
        [parameter(Mandatory=$false)]
        [ValidateSet("deactivate","disconnect","remainActivated")]
        [string]$DeactivationMode,
        [parameter(Mandatory=$false)]
        [string]$DeactivationModeTime,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$TelepresenceCallsAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$SipPresentationChannelEnabled,
        [parameter(Mandatory=$false)]
        [string]$DtmfSequence,
        [parameter(Mandatory=$false)]
        [ValidateSet("serverOnly","serverAndClient")]
        [string]$BfcpMode
    )

    $nodeLocation = "/api/v1/callLegs/$Identity"
    $data = ""
    $modifiers = 0

    if ($OwnerId -ne "") {
        $data += "&ownerId=$OwnerId"
        $modifiers++
    }

    if ($ChosenLayout -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "chosenLayout=$ChosenLayout"
        $modifiers++
    }

    if ($CallLegProfileId -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "callLegProfile=$CallLegProfileId"
        $modifiers++
    }

    if ($NeedsActivation -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "needsActivation=$NeedsActivation"
        $modifiers++
    }

    if ($DefaultLayout -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "defaultLayout=$DefaultLayout"
        $modifiers++
    }

    if ($EndCallAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "endCallAllowed=$EndCallAllowed"
        $modifiers++
    }

    if ($MuteOthersAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "muteOthersAllowed=$MuteOthersAllowed"
        $modifiers++
    }

    if ($VideoMuteOthersAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "videoMuteOthersAllowed=$VideoMuteOthersAllowed"
        $modifiers++
    }

    if ($MuteSelfAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "muteSelfAllowed=$MuteSelfAllowed"
        $modifiers++
    }

    if ($VideoMuteSelfAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "videoMuteSelfAllowed=$VideoMuteSelfAllowed"
        $modifiers++
    }

    if ($ChangeLayoutAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "changeLayoutAllowed=$ChangeLayoutAllowed"
        $modifiers++
    }

    if ($ParticipantLabels -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "participantLabels=$ParticipantLabels"
        $modifiers++
    }

    if ($PresentationDisplayMode -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "presentationDisplayMode=$PresentationDisplayMode"
        $modifiers++
    }

    if ($PresentationContributionAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "presentationContributionAllowed=$PresentationContributionAllowed"
        $modifiers++
    }

    if ($PresentationViewingAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "presentationViewingAllowed=$PresentationViewingAllowed"
        $modifiers++
    }

    if ($JoinToneParticipantThreshold -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "joinToneParticipantThreshold=$JoinToneParticipantThreshold"
        $modifiers++
    }

    if ($LeaveToneParticipantThreshold -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "leaveToneParticipantThreshold=$LeaveToneParticipantThreshold"
        $modifiers++
    }

    if ($VideoMode -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "videoMode=$VideoMode"
        $modifiers++
    }

    if ($RxAudioMute -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "rxAudioMute=$RxAudioMute"
        $modifiers++
    }

    if ($TxAudioMute -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "txAudioMute=$TxAudioMute"
        $modifiers++
    }

    if ($RxVideoMute -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "rxVideoMute=$RxVideoMute"
        $modifiers++
    }

    if ($TxVideoMute -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "txVideoMute=$TxVideoMute"
        $modifiers++
    }

    if ($SipMediaEncryption -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "sipMediaEncryption=$SipMediaEncryption"
        $modifiers++
    }

    if ($AudioPacketSizeMs -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "audioPacketSizeMs=$AudioPacketSizeMs"
        $modifiers++
    }

    if ($DeactivationMode -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "deactivationMode=$DeactivationMode"
        $modifiers++
    }

    if ($DeactivationModeTime -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "deactivationModeTime=$DeactivationModeTime"
        $modifiers++
    }

    if ($TelepresenceCallsAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "telepresenceCallsAllowed=$TelepresenceCallsAllowed"
        $modifiers++
    }

    if ($SipPresentationChannelEnabled -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "sipPresentationChannelEnabled=$SipPresentationChannelEnabled"
        $modifiers++
    }

    if ($DtmfSequence -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "dtmfSequence=$DtmfSequence"
        $modifiers++
    }

    if ($BfcpMode -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "bfcpMode=$BfcpMode"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoCallLeg $Identity
}

function Remove-AcanoCallLeg {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove call leg")) {
        Open-AcanoAPI "/api/v1/callLegs/$Identity" -DELETE
    }
}

function New-AcanoCallLegParticipant {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$true)]
        [string]$RemoteParty,
        [parameter(Mandatory=$false)]
        [string]$Bandwidth,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$Confirmation,
        [parameter(Mandatory=$false)]
        [string]$OwnerId,
        [parameter(Mandatory=$false)]
        [ValidateSet("allEqual","speakerOnly","telepresence","stacked","allEqualQuarters","allEqualNinths","allEqualSixteenths","allEqualTwentyFifths","onePlusFive","onePlusSeven","onePlusNine","automatic")]
        [string]$ChosenLayout,
        [parameter(Mandatory=$false)]
        [string]$CallLegProfileId,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$NeedsActivation,
        [parameter(Mandatory=$false)]
        [ValidateSet("allEqual","speakerOnly","telepresence","stacked","allEqualQuarters","allEqualNinths","allEqualSixteenths","allEqualTwentyFifths","onePlusFive","onePlusSeven","onePlusNine","automatic")]
        [string]$DefaultLayout,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$EndCallAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$MuteOthersAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$VideoMuteOthersAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$MuteSelfAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$VideoMuteSelfAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ChangeLayoutAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ParticipantLabels,
        [parameter(Mandatory=$false)]
        [ValidateSet("dualStream","singleStream")]
        [string]$PresentationDisplayMode,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$PresentationContributionAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$PresentationViewingAllowed,
        [parameter(Mandatory=$false)]
        [string]$JoinToneParticipantThreshold,
        [parameter(Mandatory=$false)]
        [string]$LeaveToneParticipantThreshold,
        [parameter(Mandatory=$false)]
        [ValidateSet("auto","disabled")]
        [string]$VideoMode,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$RxAudioMute,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$TxAudioMute,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$RxVideoMute,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$TxVideoMute,
        [parameter(Mandatory=$false)]
        [ValidateSet("optional","required","prohibited")]
        [string]$SipMediaEncryption,
        [parameter(Mandatory=$false)]
        [string]$AudioPacketSizeMs,
        [parameter(Mandatory=$false)]
        [ValidateSet("deactivate","disconnect","remainActivated")]
        [string]$DeactivationMode,
        [parameter(Mandatory=$false)]
        [string]$DeactivationModeTime,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$TelepresenceCallsAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$SipPresentationChannelEnabled,
        [parameter(Mandatory=$false)]
        [string]$DtmfSequence,
        [parameter(Mandatory=$false)]
        [ValidateSet("serverOnly","serverAndClient")]
        [string]$BfcpMode
    )

    $nodeLocation = "/api/v1/calls/$Identity/participants"
    $data = "remoteParty=$RemoteParty"

    if ($Bandwidth -ne "") {
        $data += "&bandwidth=$Bandwidth"
    }

    if ($Confirmation -ne "") {
        $data += "&confirmation=$Confirmation"
    }

    if ($OwnerId -ne "") {
        $data += "&ownerId=$OwnerId"
    }

    if ($ChosenLayout -ne "") {
        $data += "&chosenLayout=$ChosenLayout"
    }

    if ($CallLegProfileId -ne "") {
        $data += "&callLegProfile=$CallLegProfileId"
    }

    if ($NeedsActivation -ne "") {
        $data += "&needsActivation=$NeedsActivation"
    }

    if ($DefaultLayout -ne "") {
        $data += "&defaultLayout=$DefaultLayout"
    }

    if ($EndCallAllowed -ne "") {
        $data += "&endCallAllowed=$EndCallAllowed"
    }

    if ($MuteOthersAllowed -ne "") {
        $data += "&muteOthersAllowed=$MuteOthersAllowed"
    }

    if ($VideoMuteOthersAllowed -ne "") {
        $data += "&videoMuteOthersAllowed=$VideoMuteOthersAllowed"
    }

    if ($MuteSelfAllowed -ne "") {
        $data += "&muteSelfAllowed=$MuteSelfAllowed"
    }

    if ($VideoMuteSelfAllowed -ne "") {
        $data += "&videoMuteSelfAllowed=$VideoMuteSelfAllowed"
    }

    if ($ChangeLayoutAllowed -ne "") {
        $data += "&changeLayoutAllowed=$ChangeLayoutAllowed"
    }

    if ($ParticipantLabels -ne "") {
        $data += "&participantLabels=$ParticipantLabels"
    }

    if ($PresentationDisplayMode -ne "") {
        $data += "&presentationDisplayMode=$PresentationDisplayMode"
    }

    if ($PresentationContributionAllowed -ne "") {
        $data += "&presentationContributionAllowed=$PresentationContributionAllowed"
    }

    if ($PresentationViewingAllowed -ne "") {
        $data += "&presentationViewingAllowed=$PresentationViewingAllowed"
    }

    if ($JoinToneParticipantThreshold -ne "") {
        $data += "&joinToneParticipantThreshold=$JoinToneParticipantThreshold"
    }

    if ($LeaveToneParticipantThreshold -ne "") {
        $data += "&leaveToneParticipantThreshold=$LeaveToneParticipantThreshold"
    }

    if ($VideoMode -ne "") {
        $data += "&videoMode=$VideoMode"
    }

    if ($RxAudioMute -ne "") {
        $data += "&rxAudioMute=$RxAudioMute"
    }

    if ($TxAudioMute -ne "") {
        $data += "&txAudioMute=$TxAudioMute"
    }

    if ($RxVideoMute -ne "") {
        $data += "&rxVideoMute=$RxVideoMute"
    }

    if ($TxVideoMute -ne "") {
        $data += "&txVideoMute=$TxVideoMute"
    }

    if ($SipMediaEncryption -ne "") {
        $data += "&sipMediaEncryption=$SipMediaEncryption"
    }

    if ($AudioPacketSizeMs -ne "") {
        $data += "&audioPacketSizeMs=$AudioPacketSizeMs"
    }

    if ($DeactivationMode -ne "") {
        $data += "&deactivationMode=$DeactivationMode"
    }

    if ($DeactivationModeTime -ne "") {
        $data += "&deactivationModeTime=$DeactivationModeTime"
    }

    if ($TelepresenceCallsAllowed -ne "") {
        $data += "&telepresenceCallsAllowed=$TelepresenceCallsAllowed"
    }

    if ($SipPresentationChannelEnabled -ne "") {
        $data += "&sipPresentationChannelEnabled=$SipPresentationChannelEnabled"
    }

    if ($BfcpMode -ne "") {
        $data += "&bfcpMode=$BfcpMode"
    }

    if ($DtmfSequence -ne "") {
        $data += "&dtmfSequence=$DtmfSequence"
    }

    [string]$NewCallLegParticipantId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoParticipant $NewCallLegParticipantId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoCallLegProfiles {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Filter,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [ValidateSet("unreferenced","referenced","")]
        [string]$UsageFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/callLegProfiles"


    $modifiers = 0

    if ($Filter -ne "") {
        $nodeLocation += "?filter=$Filter"
        $modifiers++
    }

    if ($UsageFilter -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "usageFilter=$UsageFilter"
        $modifiers++
    }

    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).callLegProfiles.callLegProfile
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoCallLegProfile {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoCallLegProfiles
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/callLegProfiles/$Identity").callLegProfile
        } 
    }
}

function New-AcanoCallLegProfile {
    Param (
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$NeedsActivation,
        [parameter(Mandatory=$false)]
        [ValidateSet("allEqual","speakerOnly","telepresence","stacked","allEqualQuarters","allEqualNinths","allEqualSixteenths","allEqualTwentyFifths","onePlusFive","onePlusSeven","onePlusNine","automatic")]
        [string]$DefaultLayout,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$EndCallAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$MuteOthersAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$VideoMuteOthersAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$MuteSelfAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$AllowMuteSelfAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$VideoMuteSelfAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ChangeLayoutAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ParticipantLabels,
        [parameter(Mandatory=$false)]
        [ValidateSet("dualStream","singleStream")]
        [string]$PresentationDisplayMode,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$PresentationContributionAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$PresentationViewingAllowed,
        [parameter(Mandatory=$false)]
        [string]$JoinToneParticipantThreshold,
        [parameter(Mandatory=$false)]
        [string]$LeaveToneParticipantThreshold,
        [parameter(Mandatory=$false)]
        [ValidateSet("auto","disabled")]
        [string]$VideoMode,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$RxAudioMute,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$TxAudioMute,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$RxVideoMute,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$TxVideoMute,
        [parameter(Mandatory=$false)]
        [ValidateSet("optional","required","prohibited")]
        [string]$SipMediaEncryption,
        [parameter(Mandatory=$false)]
        [string]$AudioPacketSizeMs,
        [parameter(Mandatory=$false)]
        [ValidateSet("deactivate","disconnect","remainActivated")]
        [string]$DeactivationMode,
        [parameter(Mandatory=$false)]
        [string]$DeactivationModeTime,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$TelepresenceCallsAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$SipPresentationChannelEnabled,
        [parameter(Mandatory=$false)]
        [ValidateSet("serverOnly","serverAndClient")]
        [string]$BfcpMode,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CallLockAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$RecordingControlAllowed
    )

    $nodeLocation = "/api/v1/callLegProfiles"
    $data = ""
    $modifiers = 0

    if ($NeedsActivation -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "needsActivation=$NeedsActivation"
        $modifiers++
    }

    if ($DefaultLayout -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "defaultLayout=$DefaultLayout"
        $modifiers++
    }

    if ($EndCallAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "endCallAllowed=$EndCallAllowed"
        $modifiers++
    }

    if ($MuteOthersAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "muteOthersAllowed=$MuteOthersAllowed"
        $modifiers++
    }

    if ($VideoMuteOthersAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "videoMuteOthersAllowed=$VideoMuteOthersAllowed"
        $modifiers++
    }

    if ($MuteSelfAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "muteSelfAllowed=$MuteSelfAllowed"
        $modifiers++
    }

    if ($AllowMuteSelfAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "allowMuteSelfAllowed=$AllowMuteSelfAllowed"
        $modifiers++
    }

    if ($VideoMuteSelfAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "videoMuteSelfAllowed=$VideoMuteSelfAllowed"
        $modifiers++
    }

    if ($ChangeLayoutAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "changeLayoutAllowed=$ChangeLayoutAllowed"
        $modifiers++
    }

    if ($ParticipantLabels -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "participantLabels=$ParticipantLabels"
        $modifiers++
    }

    if ($PresentationDisplayMode -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "presentationDisplayMode=$PresentationDisplayMode"
        $modifiers++
    }

    if ($PresentationContributionAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "presentationContributionAllowed=$PresentationContributionAllowed"
        $modifiers++
    }

    if ($PresentationViewingAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "presentationViewingAllowed=$PresentationViewingAllowed"
        $modifiers++
    }

    if ($JoinToneParticipantThreshold -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "joinToneParticipantThreshold=$JoinToneParticipantThreshold"
        $modifiers++
    }

    if ($LeaveToneParticipantThreshold -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "leaveToneParticipantThreshold=$LeaveToneParticipantThreshold"
        $modifiers++
    }

    if ($VideoMode -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "videoMode=$VideoMode"
        $modifiers++
    }

    if ($RxAudioMute -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "rxAudioMute=$RxAudioMute"
        $modifiers++
    }

    if ($TxAudioMute -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "txAudioMute=$TxAudioMute"
        $modifiers++
    }

    if ($RxVideoMute -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "rxVideoMute=$RxVideoMute"
        $modifiers++
    }

    if ($TxVideoMute -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "txVideoMute=$TxVideoMute"
        $modifiers++
    }

    if ($SipMediaEncryption -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "sipMediaEncryption=$SipMediaEncryption"
        $modifiers++
    }

    if ($AudioPacketSizeMs -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "audioPacketSizeMs=$AudioPacketSizeMs"
        $modifiers++
    }

    if ($DeactivationMode -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "deactivationMode=$DeactivationMode"
        $modifiers++
    }

    if ($DeactivationModeTime -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "deactivationModeTime=$DeactivationModeTime"
        $modifiers++
    }

    if ($TelepresenceCallsAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "telepresenceCallsAllowed=$TelepresenceCallsAllowed"
        $modifiers++
    }

    if ($SipPresentationChannelEnabled -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "sipPresentationChannelEnabled=$SipPresentationChannelEnabled"
        $modifiers++
    }

    if ($BfcpMode -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "bfcpMode=$BfcpMode"
        $modifiers++
    }

    if ($RecordingControlAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "recordingControlAllowed=$RecordingControlAllowed"
        $modifiers++
    }

    if ($CallLockAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "callLockAllowed=$CallLockAllowed"
    }

    [string]$NewCallLegProfileId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoCallLegProfile $NewCallLegProfileId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoCallLegProfile {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$NeedsActivation,
        [parameter(Mandatory=$false)]
        [ValidateSet("allEqual","speakerOnly","telepresence","stacked","allEqualQuarters","allEqualNinths","allEqualSixteenths","allEqualTwentyFifths","onePlusFive","onePlusSeven","onePlusNine","automatic")]
        [string]$DefaultLayout,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$EndCallAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$MuteOthersAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$VideoMuteOthersAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$MuteSelfAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$AllowMuteSelfAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$VideoMuteSelfAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ChangeLayoutAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ParticipantLabels,
        [parameter(Mandatory=$false)]
        [ValidateSet("dualStream","singleStream")]
        [string]$PresentationDisplayMode,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$PresentationContributionAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$PresentationViewingAllowed,
        [parameter(Mandatory=$false)]
        [string]$JoinToneParticipantThreshold,
        [parameter(Mandatory=$false)]
        [string]$LeaveToneParticipantThreshold,
        [parameter(Mandatory=$false)]
        [ValidateSet("auto","disabled")]
        [string]$VideoMode,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$RxAudioMute,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$TxAudioMute,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$RxVideoMute,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$TxVideoMute,
        [parameter(Mandatory=$false)]
        [ValidateSet("optional","required","prohibited")]
        [string]$SipMediaEncryption,
        [parameter(Mandatory=$false)]
        [string]$AudioPacketSizeMs,
        [parameter(Mandatory=$false)]
        [ValidateSet("deactivate","disconnect","remainActivated")]
        [string]$DeactivationMode,
        [parameter(Mandatory=$false)]
        [string]$DeactivationModeTime,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$TelepresenceCallsAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$SipPresentationChannelEnabled,
        [parameter(Mandatory=$false)]
        [ValidateSet("serverOnly","serverAndClient")]
        [string]$BfcpMode,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CallLockAllowed,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$RecordingControlAllowed
    )

    $nodeLocation = "/api/v1/callLegProfiles/$Identity"
    $data = ""
    $modifiers = 0

    if ($NeedsActivation -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "needsActivation=$NeedsActivation"
        $modifiers++
    }

    if ($DefaultLayout -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "defaultLayout=$DefaultLayout"
        $modifiers++
    }

    if ($EndCallAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "endCallAllowed=$EndCallAllowed"
        $modifiers++
    }

    if ($MuteOthersAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "muteOthersAllowed=$MuteOthersAllowed"
        $modifiers++
    }

    if ($VideoMuteOthersAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "videoMuteOthersAllowed=$VideoMuteOthersAllowed"
        $modifiers++
    }

    if ($MuteSelfAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "muteSelfAllowed=$MuteSelfAllowed"
        $modifiers++
    }

    if ($AllowMuteSelfAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "allowMuteSelfAllowed=$AllowMuteSelfAllowed"
        $modifiers++
    }

    if ($VideoMuteSelfAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "videoMuteSelfAllowed=$VideoMuteSelfAllowed"
        $modifiers++
    }

    if ($ChangeLayoutAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "changeLayoutAllowed=$ChangeLayoutAllowed"
        $modifiers++
    }

    if ($ParticipantLabels -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "participantLabels=$ParticipantLabels"
        $modifiers++
    }

    if ($PresentationDisplayMode -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "presentationDisplayMode=$PresentationDisplayMode"
        $modifiers++
    }

    if ($PresentationContributionAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "presentationContributionAllowed=$PresentationContributionAllowed"
        $modifiers++
    }

    if ($PresentationViewingAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "presentationViewingAllowed=$PresentationViewingAllowed"
        $modifiers++
    }

    if ($JoinToneParticipantThreshold -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "joinToneParticipantThreshold=$JoinToneParticipantThreshold"
        $modifiers++
    }

    if ($LeaveToneParticipantThreshold -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "leaveToneParticipantThreshold=$LeaveToneParticipantThreshold"
        $modifiers++
    }

    if ($VideoMode -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "videoMode=$VideoMode"
        $modifiers++
    }

    if ($RxAudioMute -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "rxAudioMute=$RxAudioMute"
        $modifiers++
    }

    if ($TxAudioMute -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "txAudioMute=$TxAudioMute"
        $modifiers++
    }

    if ($RxVideoMute -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "rxVideoMute=$RxVideoMute"
        $modifiers++
    }

    if ($TxVideoMute -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "txVideoMute=$TxVideoMute"
        $modifiers++
    }

    if ($SipMediaEncryption -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "sipMediaEncryption=$SipMediaEncryption"
        $modifiers++
    }

    if ($AudioPacketSizeMs -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "audioPacketSizeMs=$AudioPacketSizeMs"
        $modifiers++
    }

    if ($DeactivationMode -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "deactivationMode=$DeactivationMode"
        $modifiers++
    }

    if ($DeactivationModeTime -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "deactivationModeTime=$DeactivationModeTime"
        $modifiers++
    }

    if ($TelepresenceCallsAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "telepresenceCallsAllowed=$TelepresenceCallsAllowed"
        $modifiers++
    }

    if ($SipPresentationChannelEnabled -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "sipPresentationChannelEnabled=$SipPresentationChannelEnabled"
        $modifiers++
    }

    if ($BfcpMode -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "bfcpMode=$BfcpMode"
        $modifiers++
    }

    if ($RecordingControlAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "recordingControlAllowed=$RecordingControlAllowed"
        $modifiers++
    }

    if ($CallLockAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "callLockAllowed=$CallLockAllowed"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoCallLegProfile $Identity
}

function Remove-AcanoCallLegProfile {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove call leg profile")) {
        Open-AcanoAPI "/api/v1/callLegProfiles/$Identity" -DELETE
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoCallLegProfileUsages {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    return (Open-AcanoAPI "api/v1/callLegProfiles/$Identity/usage").callLegProfileUsage

}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoCallLegProfileTrace {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    return (Open-AcanoAPI "api/v1/callLegs/$Identity/callLegProfileTrace").callLegProfileTrace

}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoDialTransforms {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Filter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/dialTransforms"
    $modifiers = 0

    if ($Filter -ne "") {
        $nodeLocation += "?filter=$Filter"
        $modifiers++
    }

    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "?limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).dialTransforms.dialTransform
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoDialTransform {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoDialTransforms
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/dialTransforms/$Identity").dialTransform
        }
    }
}

function New-AcanoDialTransform {
    Param (
        [parameter(Mandatory=$false)]
        [ValidateSet("raw","strip","phone")]
        [string]$Type="raw",
        [parameter(Mandatory=$false)]
        [string]$Match,
        [parameter(Mandatory=$false)]
        [string]$Transform,
        [parameter(Mandatory=$false)]
        [string]$Priority,
        [parameter(Mandatory=$false)]
        [ValidateSet("accept","acceptPhone","deny")]
        [string]$Action
    )

    $nodeLocation = "/api/v1/dialTransforms"
    $data = "type=$type"

    if ($Match -ne "") {
        $data += "&match=$Match"
    }

    if ($Transform -ne "") {
        $data += "&transform=$Transform"
    }

    if ($Priority -ne "") {
        $data += "&priority=$Priority"
    }

    if ($Action -ne "") {
        $data += "&Action=$Action"
    }

    $data

    [string]$NewDialTransformId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoDialTransform $NewDialTransformId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoDialTransform {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [ValidateSet("raw","strip","phone")]
        [string]$Type,
        [parameter(Mandatory=$false)]
        [string]$Match,
        [parameter(Mandatory=$false)]
        [string]$Transform,
        [parameter(Mandatory=$false)]
        [string]$Priority,
        [parameter(Mandatory=$false)]
        [ValidateSet("accept","acceptPhone","deny")]
        [string]$Action
    )

    $nodeLocation = "/api/v1/dialTransforms/$Identity"
    $data = ""
    $modifiers = 0
    

    if ($Type -ne "") {
        $data = "type=$Type"
        $modifiers++
    }

    if ($Match -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "match=$Match"
        $modifiers++
    }

    if ($Transform -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "transform=$Transform"
        $modifiers++
    }

    if ($Priority -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "priority=$Priority"
        $modifiers++
    }

    if ($Action -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "Action=$Action"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoDialTransform $Identity
}

function Remove-AcanoDialTransform {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove dial transform rule")) {
        Open-AcanoAPI "/api/v1/dialTransforms/$Identity" -DELETE
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoCallBrandingProfiles {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [ValidateSet("unreferenced","referenced","")]
        [string]$UsageFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/callBrandingProfiles"


    $modifiers = 0

    if ($UsageFilter -ne "") {
        $nodeLocation += "?usageFilter=$UsageFilter"
        $modifiers++
    }

    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "?limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).callBrandingProfiles.callBrandingProfile
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoCallBrandingProfile {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoCallBrandingProfiles
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/callBrandingProfiles/$Identity").callBrandingProfile
        }
    }
}

function New-AcanoCallBrandingProfile {
    Param (
        [parameter(Mandatory=$false)]
        [string]$InvitationTemplate,
        [parameter(Mandatory=$false)]
        [string]$ResourceLocation
    )

    $nodeLocation = "/api/v1/callBrandingProfiles"
    $data = ""
    $modifiers = 0

    if ($InvitationTemplate -ne "") {
        $data += "invitationTemplate=$InvitationTemplate"
        $modifiers++
    }

    if ($ResourceLocation -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "resourceLocation=$ResourceLocation"
    }

    [string]$NewCallBrandingProfileId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoCallBrandingProfile $NewCallBrandingProfileId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoCallBrandingProfile {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [string]$InvitationTemplate,
        [parameter(Mandatory=$false)]
        [string]$ResourceLocation
    )

    $nodeLocation = "/api/v1/callBrandingProfiles/$Identity"
    $data = ""
    $modifiers = 0

    if ($InvitationTemplate -ne "") {
        $data += "invitationTemplate=$InvitationTemplate"
        $modifiers++
    }

    if ($ResourceLocation -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "resourceLocation=$ResourceLocation"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoCallBrandingProfile $Identity
}

function Remove-AcanoCallBrandingProfile {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove call branding profile")) {
        Open-AcanoAPI "/api/v1/CallBrandingProfiles/$Identity" -DELETE
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoDtmfProfiles {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [ValidateSet("unreferenced","referenced","")]
        [string]$UsageFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/dtmfProfiles"


    $modifiers = 0

    if ($UsageFilter -ne "") {
        $nodeLocation += "?usageFilter=$UsageFilter"
        $modifiers++
    }

    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "?limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).dtmfProfiles.dtmfProfile
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoDtmfProfile {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoDtmfProfiles
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/dtmfProfiles/$Identity").dtmfProfile
        }
    }
}

function New-AcanoDtmfProfile {
    Param (
        [parameter(Mandatory=$false)]
        [string]$LockCall,
        [parameter(Mandatory=$false)]
        [string]$UnlockCall,
        [parameter(Mandatory=$false)]
        [string]$NextLayout,
        [parameter(Mandatory=$false)]
        [string]$PreviousLayout,
        [parameter(Mandatory=$false)]
        [string]$MuteSelfAudio,
        [parameter(Mandatory=$false)]
        [string]$UnmuteSelfAudio,
        [parameter(Mandatory=$false)]
        [string]$ToggleMuteSelfAudio,
        [parameter(Mandatory=$false)]
        [string]$MuteAllExceptSelfAudio,
        [parameter(Mandatory=$false)]
        [string]$UnMuteAllExceptSelfAudio,
        [parameter(Mandatory=$false)]
        [string]$StartRecording,
        [parameter(Mandatory=$false)]
        [string]$StopRecording,
        [parameter(Mandatory=$false)]
        [string]$AllowAllMuteSelf,
        [parameter(Mandatory=$false)]
        [string]$CancelAllowAllMuteSelf,
        [parameter(Mandatory=$false)]
        [string]$AllowAllPresentationContribution,
        [parameter(Mandatory=$false)]
        [string]$CancelAllowAllPresentationContribution,
        [parameter(Mandatory=$false)]
        [string]$MuteAllNewAudio,
        [parameter(Mandatory=$false)]
        [string]$UnMuteAllNewAudio,
        [parameter(Mandatory=$false)]
        [string]$DefaultMuteAllNewAudio,
        [parameter(Mandatory=$false)]
        [string]$MuteAllNewAndAllExceptSelfAudio,
        [parameter(Mandatory=$false)]
        [string]$UnMuteAllNewAndAllExceptSelfAudio,
        [parameter(Mandatory=$false)]
        [string]$EndCall
    )

    $nodeLocation = "/api/v1/dtmfProfiles"
    $data = ""
    $modifiers = 0

    if ($LockCall -ne "") {
        $data += "lockCall=$LockCall"
        $modifiers++
    }

    if ($UnlockCall -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "unlockCall=$UnlockCall"
        $modifiers++
    }

    if ($NextLayout -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "nextLayout=$NextLayout"
        $modifiers++
    }

    if ($PreviousLayout -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "previousLayout=$PreviousLayout"
        $modifiers++
    }

    if ($MuteSelfAudio -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "muteSelfAudio=$MuteSelfAudio"
        $modifiers++
    }

    if ($UnMuteSelfAudio -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "unmuteSelfAudio=$UnMuteSelfAudio"
        $modifiers++
    }

    if ($ToggleMuteSelfAudio -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "toggleMuteSelfAudio=$ToggleMuteSelfAudio"
        $modifiers++
    }

    if ($MuteAllExceptSelfAudio -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "muteAllExceptSelfAudio=$MuteAllExceptSelfAudio"
        $modifiers++
    }

    if ($UnMuteAllExceptSelfAudio -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "unmuteAllExceptSelfAudio=$UnMuteAllExceptSelfAudio"
        $modifiers++
    }

    if ($StartRecording -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "startRecording=$StartRecording"
        $modifiers++
    }

    if ($StopRecording -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "stopRecording=$StopRecording"
        $modifiers++
    }

    if ($AllowAllMuteSelf -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "allowAllMuteSelf=$AllowAllMuteSelf"
        $modifiers++
    }

    if ($CancelAllowAllMuteSelf -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "cancelAllowAllMuteSelf=$CancelAllowAllMuteSelf"
        $modifiers++
    }

    if ($AllowAllPresentationContribution -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "allowAllPresentationContribution=$AllowAllPresentationContribution"
        $modifiers++
    }

    if ($CancelAllowAllPresentationContribution -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "cancelAllowAllPresentationContribution=$CancelAllowAllPresentationContribution"
        $modifiers++
    }

    if ($MuteAllNewAudio -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "muteAllNewAudio=$MuteAllNewAudio"
        $modifiers++
    }

    if ($UnMuteAllNewAudio -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "unmuteAllNewAudio=$UnMuteAllNewAudio"
        $modifiers++
    }

    if ($MuteAllNewAndAllExceptSelfAudio -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "muteAllNewAndAllExceptSelfAudio=$MuteAllNewAndAllExceptSelfAudio"
        $modifiers++
    }

    if ($UnMuteAllNewAndAllExceptSelfAudio -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "unmuteAllNewAndAllExceptSelfAudio=$UnMuteAllNewAndAllExceptSelfAudio"
        $modifiers++
    }

    if ($EndCall -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "endCall=$EndCall"
    }

    [string]$NewDtmfProfileId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoDtmfProfile $NewDtmfProfileId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoDtmfProfile {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [string]$LockCall,
        [parameter(Mandatory=$false)]
        [string]$UnlockCall,
        [parameter(Mandatory=$false)]
        [string]$NextLayout,
        [parameter(Mandatory=$false)]
        [string]$PreviousLayout,
        [parameter(Mandatory=$false)]
        [string]$MuteSelfAudio,
        [parameter(Mandatory=$false)]
        [string]$UnmuteSelfAudio,
        [parameter(Mandatory=$false)]
        [string]$ToggleMuteSelfAudio,
        [parameter(Mandatory=$false)]
        [string]$MuteAllExceptSelfAudio,
        [parameter(Mandatory=$false)]
        [string]$UnMuteAllExceptSelfAudio,
        [parameter(Mandatory=$false)]
        [string]$StartRecording,
        [parameter(Mandatory=$false)]
        [string]$StopRecording,
        [parameter(Mandatory=$false)]
        [string]$AllowAllMuteSelf,
        [parameter(Mandatory=$false)]
        [string]$CancelAllowAllMuteSelf,
        [parameter(Mandatory=$false)]
        [string]$AllowAllPresentationContribution,
        [parameter(Mandatory=$false)]
        [string]$CancelAllowAllPresentationContribution,
        [parameter(Mandatory=$false)]
        [string]$MuteAllNewAudio,
        [parameter(Mandatory=$false)]
        [string]$UnMuteAllNewAudio,
        [parameter(Mandatory=$false)]
        [string]$DefaultMuteAllNewAudio,
        [parameter(Mandatory=$false)]
        [string]$MuteAllNewAndAllExceptSelfAudio,
        [parameter(Mandatory=$false)]
        [string]$UnMuteAllNewAndAllExceptSelfAudio,
        [parameter(Mandatory=$false)]
        [string]$EndCall
    )

    $nodeLocation = "/api/v1/dtmfProfiles/$Identity"
    $data = ""
    $modifiers = 0

    if ($LockCall -ne "") {
        $data += "lockCall=$LockCall"
        $modifiers++
    }

    if ($UnlockCall -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "unlockCall=$UnlockCall"
        $modifiers++
    }

    if ($NextLayout -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "nextLayout=$NextLayout"
        $modifiers++
    }

    if ($PreviousLayout -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "previousLayout=$PreviousLayout"
        $modifiers++
    }

    if ($MuteSelfAudio -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "muteSelfAudio=$MuteSelfAudio"
        $modifiers++
    }

    if ($UnMuteSelfAudio -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "unmuteSelfAudio=$UnMuteSelfAudio"
        $modifiers++
    }

    if ($ToggleMuteSelfAudio -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "toggleMuteSelfAudio=$ToggleMuteSelfAudio"
        $modifiers++
    }

    if ($MuteAllExceptSelfAudio -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "muteAllExceptSelfAudio=$MuteAllExceptSelfAudio"
        $modifiers++
    }

    if ($UnMuteAllExceptSelfAudio -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "unmuteAllExceptSelfAudio=$UnMuteAllExceptSelfAudio"
        $modifiers++
    }

    if ($StartRecording -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "startRecording=$StartRecording"
        $modifiers++
    }

    if ($StopRecording -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "stopRecording=$StopRecording"
        $modifiers++
    }

    if ($AllowAllMuteSelf -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "allowAllMuteSelf=$UnMuteAllEAllowAllMuteSelfxceptSelfAudio"
        $modifiers++
    }

    if ($CancelAllowAllMuteSelf -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "cancelAllowAllMuteSelf=$CancelAllowAllMuteSelf"
        $modifiers++
    }

    if ($AllowAllPresentationContribution -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "allowAllPresentationContribution=$AllowAllPresentationContribution"
        $modifiers++
    }

    if ($CancelAllowAllPresentationContribution -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "cancelAllowAllPresentationContribution=$CancelAllowAllPresentationContribution"
        $modifiers++
    }

    if ($MuteAllNewAudio -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "muteAllNewAudio=$MuteAllNewAudio"
        $modifiers++
    }

    if ($UnMuteAllNewAudio -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "unmuteAllNewAudio=$UnMuteAllNewAudio"
        $modifiers++
    }

    if ($MuteAllNewAndAllExceptSelfAudio -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "muteAllNewAndAllExceptSelfAudio=$MuteAllNewAndAllExceptSelfAudio"
        $modifiers++
    }

    if ($UnMuteAllNewAndAllExceptSelfAudio -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "unmuteAllNewAndAllExceptSelfAudio=$UnMuteAllNewAndAllExceptSelfAudio"
        $modifiers++
    }

    if ($EndCall -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "endCall=$EndCall"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoDtmfProfile $Identity
}

function Remove-AcanoDtmfProfile {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove DTMF profile")) {
        Open-AcanoAPI "/api/v1/dtmfProfiles/$Identity" -DELETE
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoIvrs {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Filter,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$TenantFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/ivrs"
    $modifiers = 0

    if ($Filter -ne "") {
        $nodeLocation += "?filter=$Filter"
        $modifiers++
    }

    if ($TenantFilter -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "tenantFilter=$TenantFilter"
        $modifiers++
    }

    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).ivrs.ivr
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoIvr {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoIvrs
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/ivrs/$Identity").ivr
        }
    }
}

function New-AcanoIvr {
    Param (
        [parameter(Mandatory=$true)]
        [string]$Uri,
        [parameter(Mandatory=$false)]
        [string]$Tenant,
        [parameter(Mandatory=$false)]
        [string]$TenantGroup,
        [parameter(Mandatory=$false)]
        [string]$IvrBrandingProfile,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ResolveCoSpaceCallIds,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ResolveLyncConferenceIds
    )

    $nodeLocation = "/api/v1/ivrs"
    $data = "uri=$Uri"

    if ($Tenant -ne "") {
        $data += "&tenant=$Tenant"
    }

    if ($TenantGroup -ne "") {
        $data += "&tenantgroup=$TenantGroup"
    }

    if ($IvrBrandingProfile -ne "") {
        $data += "&ivrBrandingProfile=$IvrBrandingProfile"
    }

    if ($ResolveCoSpaceCallIds -ne "") {
        $data += "&resolveCoSpaceCallIds=$ResolveCoSpaceCallIds"
    }

    if ($ResolveLyncConferenceIds -ne "") {
        $data += "&reesolveLyncConferenceIds=$ResolveLyncConferenceIds"
    }

    [string]$NewIvrId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoIvr $NewIvrId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoIvr {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [string]$Uri,
        [parameter(Mandatory=$false)]
        [string]$Tenant,
        [parameter(Mandatory=$false)]
        [string]$TenantGroup,
        [parameter(Mandatory=$false)]
        [string]$IvrBrandingProfile,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ResolveCoSpaceCallIds,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ResolveLyncConferenceIds
    )

    $nodeLocation = "/api/v1/ivrs/$Identity"
    $data = ""
    $modifiers = 0

    if ($Uri -ne "") {
        $data += "uri=$Uri"
        $modifiers++
    }

    if ($Tenant -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "tenant=$Tenant"
        $modifiers++
    }

    if ($TenantGroup -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "tenantGroup=$TenantGroup"
        $modifiers++
    }

    if ($IvrBrandingProfile -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "ivrBrandingProfile=$IvrBrandingProfile"
        $modifiers++
    }

    if ($ResolveCoSpaceCallIds -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "resolveCoSpaceCallIds=$ResolveCoSpaceCallIds"
        $modifiers++
    }

    if ($ResolveLyncConferenceIds -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "resolveLyncConferenceIds=$ResolveLyncConferenceIds"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoIvr $Identity
}

function Remove-AcanoIvr {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove IVR")) {
        Open-AcanoAPI "/api/v1/ivrs/$Identity" -DELETE
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoIvrBrandingProfiles {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Filter,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$TenantFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/ivrBrandingProfiles"
    $modifiers = 0

    if ($Filter -ne "") {
        $nodeLocation += "?filter=$Filter"
        $modifiers++
    }

    if ($TenantFilter -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "tenantFilter=$TenantFilter"
        $modifiers++
    }

    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).ivrBrandingProfiles.ivrBrandingProfile
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoIvrBrandingProfile {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoIvrBrandingProfiles
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/ivrBrandingProfiles/$Identity").ivrBrandingProfile
        }
    }
}

function New-AcanoIvrBrandingProfile {
    Param (
        [parameter(Mandatory=$false)]
        [string]$ResourceLocation
    )

    $nodeLocation = "/api/v1/ivrBrandingProfiles"
    $data = ""

    if ($ResourceLocation -ne "") {
        $data += "resourceLocation=$ResourceLocation"
    }

    [string]$NewIvrBrandingProfileId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoIvrBrandingProfile $NewIvrBrandingProfileId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoIvrBrandingProfile {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [string]$ResourceLocation
    )

    $nodeLocation = "/api/v1/ivrBrandingProfiles/$Identity"
    $data = ""

    if ($ResourceLocation -ne "") {
        $data += "resourceLocation=$ResourceLocation"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoIvrBrandingProfile $Identity
}

function Remove-AcanoIvrBrandingProfile {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove IVR Branding profile")) {
        Open-AcanoAPI "/api/v1/ivrBrandingProfiles/$Identity" -DELETE
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoParticipants {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Filter,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$TenantFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$callBridgeFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/participants"

    $modifiers = 0

    if ($Filter -ne "") {
        $nodeLocation += "?filter=$Filter"
        $modifiers++
    }

    if ($TenantFilter -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "tenantFilter=$TenantFilter"
        $modifiers++
    }

    if ($CallBridgeFilter -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "callBridgeFilter=$CallBridgeFilter"
        $modifiers++
    }

    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).participants.participant
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoParticipant {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoParticipants
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/participants/$Identity").participant
        }
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoParticipantCallLegs {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    return (Open-AcanoAPI "api/v1/participants/$Identity/callLegs").callLeg

}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoUsers {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Filter,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$TenantFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/users"
    $modifiers = 0

    if ($Filter -ne "") {
        $nodeLocation += "?filter=$Filter"
        $modifiers++
    }

    if ($TenantFilter -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "tenantFilter=$TenantFilter"
        $modifiers++
    }

    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).users.user
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoUser {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoUsers
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/users/$Identity").user
        }
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoUsercoSpaces {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    return (Open-AcanoAPI "api/v1/users/$Identity/usercoSpaces").userCoSpaces.userCoSpace

}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoUserProfiles {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [ValidateSet("unreferenced","referenced","")]
        [string]$UsageFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/userProfiles"


    $modifiers = 0

    if ($UsageFilter -ne "") {
        $nodeLocation += "?usageFilter=$UsageFilter"
        $modifiers++
    }

    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).userProfiles.userProfile
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoUserProfile {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoUserProfiles
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/userProfiles/$Identity").userProfile
        }
    }
}

function New-AcanoUserProfile {
    Param (
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$canCreateCoSpaces,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanCreateCalls,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanUseExternalDevices,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanMakePhoneCalls,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$UserToUserMessagingAllowed
    )

    $nodeLocation = "/api/v1/userProfiles"
    $data = ""
    $modifiers = 0

    if ($canCreateCoSpaces -ne "") {
        $data += "canCreateCoSpaces=$canCreateCoSpaces"
        $modifiers++
    }

    if ($CanCreateCalls -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "canCreateCalls=$canCreateCalls"
        $modifiers++
    }

    if ($CanUseExternalDevices -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "canUseExternalDevices=$CanUseExternalDevices"
        $modifiers++
    }

    if ($CanMakePhoneCalls -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "canMakePhoneCalls=$CanMakePhoneCalls"
        $modifiers++
    }

    if ($UserToUserMessagingAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "userToUserMessagingAllowed=$UserToUserMessagingAllowed"
    }

    [string]$NewUserProfileId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoUserProfile $NewUserProfileId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoUserProfile {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$canCreateCoSpaces,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanCreateCalls,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanUseExternalDevices,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$CanMakePhoneCalls,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$UserToUserMessagingAllowed
    )

    $nodeLocation = "/api/v1/userProfiles/$Identity"
    $data = ""
    $modifiers = 0

    if ($canCreateCoSpaces -ne "") {
        $data += "canCreateCoSpaces=$canCreateCoSpaces"
        $modifiers++
    }

    if ($CanCreateCalls -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "canCreateCalls=$canCreateCalls"
        $modifiers++
    }

    if ($CanUseExternalDevices -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "canUseExternalDevices=$CanUseExternalDevices"
        $modifiers++
    }

    if ($CanMakePhoneCalls -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "canMakePhoneCalls=$CanMakePhoneCalls"
        $modifiers++
    }

    if ($UserToUserMessagingAllowed -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "userToUserMessagingAllowed=$UserToUserMessagingAllowed"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoUserProfile $Identity
}

function Remove-AcanoUserProfile {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove user profile")) {
        Open-AcanoAPI "/api/v1/userProfiles/$Identity" -DELETE
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoSystemStatus {
    return (Open-AcanoAPI "api/v1/system/status").status
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoSystemAlarms {
    return (Open-AcanoAPI "api/v1/system/alarms").alarms.alarm
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoSystemAlarm {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    return (Open-AcanoAPI "api/v1/system/alarms/$Identity").alarm
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoSystemDatabaseStatus {
    return (Open-AcanoAPI "api/v1/system/database").database
}

function Get-AcanoCdrRecieverUris {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/system/cdrRecievers"
    $modifiers = 0

    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).cdrRecievers.cdrReciever
}

function Get-AcanoCdrRecieverUri {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoCdrRecieverUris
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/system/cdrRecievers/$Identity").cdrReciever
        }
    }
}

function New-AcanoCdrRecieverUri {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Uri
    )

    $nodeLocation = "/api/v1/system/cdrRecievers"
    $data = "uri=$Uri"

    [string]$NewCdrRecieverUriId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoCdrRecieverUri $NewCdrRecieverUriId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoCdrRecieverUri {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [string]$Uri
    )

    $nodeLocation = "/api/v1/system/cdrRecievers/$Identity"
    $data = ""

    if ($Uri -ne "") {
        $data += "uri=$Uri"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoCdrRecieverUri $Identity
}

function Remove-AcanoCdrRecieverUri {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove CDR reciever")) {
        Open-AcanoAPI "/api/v1/system/cdrRecievers/$Identity" -DELETE
    }
}

function Get-AcanoLegacyCdrReceiverUri {
    return (Open-AcanoAPI "api/v1/system/cdrReceiver").cdrReceiver
}

function Set-AcanoLegacyCdrRecieverUri {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
     Param (
        [parameter(Mandatory=$false,Position=1)]
        [string]$Uri
    )

    $nodeLocation = "/api/v1/system/cdrReciever"
    $data = ""

    if ($Uri -ne "") {
        $data += "&uri=$Uri"
        
        [string]$NewCdrRecieverUri = Open-AcanoAPI $nodeLocation -POST -Data $data
    } 
    
    else {
        if ($PSCmdlet.ShouldProcess("Legacy CDR Reciever","Remove")) {
            Open-AcanoAPI $nodeLocation -PUT -Data $data
        }
    }

    Get-AcanoLegacyCdrReceiverUri
}

function Remove-AcanoLegacyCdrRecieverUri {
    ##Triggers a PUT on Set-AcanoLegacyCdrRecieverUri, which effectively removes the CDR reciever.
    Set-AcanoLegacyCdrRecieverUri
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoGlobalProfile {
    return (Open-AcanoAPI "api/v1/system/profiles").profiles
}

function Set-AcanoGlobalProfile {
    Param (
        [parameter(Mandatory=$false)]
        [string]$CallLegProfile,
        [parameter(Mandatory=$false)]
        [string]$CallProfile,
        [parameter(Mandatory=$false)]
        [string]$DtmfProfile,
        [parameter(Mandatory=$false)]
        [string]$UserProfile,
        [parameter(Mandatory=$false)]
        [string]$IvrBrandingProfile,
        [parameter(Mandatory=$false)]
        [string]$CallBrandingProfile
    )

    $nodeLocation = "/api/v1/system/profiles"
    $data = ""
    $modifiers = 0

    if ($CallLegProfile -ne "") {
        if ($CallLegProfile -eq $null){
            $data += "callLegProfile="
        }
        else {
            $data += "callLegProfile=$CallLegProfile"
        }
        $modifiers++
    }

    if ($CallProfile -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }

        if ($CallProfile -eq $null){
            $data += "callProfile="
        }
        else {
            $data += "callProfile=$CallProfile"
        }

        $modifiers++
    }

    if ($DtmfProfile -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }

        if ($DtmfProfile -eq $null){
            $data += "dtmfProfile="
        }
        else {
            $data += "dtmfProfile=$DtmfProfile"
        }

        $modifiers++
    }

    if ($UserProfile -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }

        if ($UserProfile -eq $null){
            $data += "userProfile="
        }
        else {
            $data += "userProfile=$UserProfile"
        }

        $modifiers++
    }

    if ($IvrBrandingProfile -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }

        if ($IvrBrandingProfile -eq $null){
            $data += "ivrBrandingProfile="
        }
        else {
            $data += "ivrBrandingProfile=$IvrBrandingProfile"
        }

        $modifiers++
    }

    if ($CallBrandingProfile -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }

        if ($CallBrandingProfile -eq $null){
            $data += "callBrandingProfile="
        }
        else {
            $data += "callBrandingProfile=$CallBrandingProfile"
        }
    }
    $data

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoGlobalProfile
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoTurnServers {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Filter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/turnServers"
    $modifiers = 0

    if ($Filter -ne "") {
        $nodeLocation += "?filter=$Filter"
        $modifiers++
    }
    
    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).turnServers.turnServer
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoTurnServer {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoTurnServers
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/turnServers/$Identity").turnServer
        }
    }
}

function Get-AcanoTurnServerStatus {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    return (Open-AcanoAPI "api/v1/turnServers/$Identity/status").turnServer.host
}

function New-AcanoTurnServer {
    Param (
        [parameter(Mandatory=$false)]
        [string]$ServerAddress,
        [parameter(Mandatory=$false)]
        [string]$ClientAddress,
        [parameter(Mandatory=$false)]
        [string]$Username,
        [parameter(Mandatory=$false)]
        [string]$Password,
        [parameter(Mandatory=$false)]
        [ValidateSet("acano","lyncEdge","standard")]
        [string]$Type,
        [parameter(Mandatory=$false)]
        [string]$NumRegistrations,
        [parameter(Mandatory=$false)]
        [string]$TcpPortNumberOverride
    )

    $nodeLocation = "/api/v1/turnServers"
    $data = ""
    $modifiers = 0

    if ($ServerAddress -ne "") {
        $data += "serverAddress=$ServerAddress"
        $modifiers++
    }

    if ($ClientAddress -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "clientAddress=$ClientAddress"
        $modifiers++
    }

    if ($Username -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "username=$Username"
        $modifiers++
    }

    if ($Password -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "password=$Password"
        $modifiers++
    }

    if ($Type -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "type=$Type"
        $modifiers++
    }

    if ($NumRegistrations -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "numRegistrations=$NumRegistrations"
        $modifiers++
    }

    if ($TcpPortNumberOverride -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "tcpPortNumberOverride=$TcpPortNumberOverride"
    }

    [string]$NewTurnServerId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoTurnServer $NewTurnServerId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoTurnServer {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [string]$ServerAddress,
        [parameter(Mandatory=$false)]
        [string]$ClientAddress,
        [parameter(Mandatory=$false)]
        [string]$Username,
        [parameter(Mandatory=$false)]
        [string]$Password,
        [parameter(Mandatory=$false)]
        [ValidateSet("acano","lyncEdge","standard")]
        [string]$Type,
        [parameter(Mandatory=$false)]
        [string]$NumRegistrations,
        [parameter(Mandatory=$false)]
        [string]$TcpPortNumberOverride
    )

    $nodeLocation = "/api/v1/turnServers/$Identity"
    $data = ""
    $modifiers = 0

    if ($ServerAddress -ne "") {
        $data += "serverAddress=$ServerAddress"
        $modifiers++
    }

    if ($ClientAddress -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "clientAddress=$ClientAddress"
        $modifiers++
    }

    if ($Username -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "username=$Username"
        $modifiers++
    }

    if ($Password -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "password=$Password"
        $modifiers++
    }

    if ($Type -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "type=$Type"
        $modifiers++
    }

    if ($NumRegistrations -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "numRegistrations=$NumRegistrations"
        $modifiers++
    }

    if ($TcpPortNumberOverride -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "tcpPortNumberOverride=$TcpPortNumberOverride"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoTurnServer $Identity
}

function Remove-AcanoTurnServer {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove TURN server")) {
        Open-AcanoAPI "/api/v1/turnServers/$Identity" -DELETE
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoWebBridges {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Filter,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$TenantFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/webBridges"
    $modifiers = 0

    if ($Filter -ne "") {
        $nodeLocation += "?filter=$Filter"
        $modifiers++
    }

    if ($TenantFilter -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "tenantFilter=$TenantFilter"
        $modifiers++
    }

    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).webBridges.webBridge
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoWebBridge {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoWebBridges
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/webBridges/$Identity").webBridge
        }
    }
}

function New-AcanoWebBridge {
    Param (
        [parameter(Mandatory=$false)]
        [string]$Url,
        [parameter(Mandatory=$false)]
        [string]$ResourceArchive,
        [parameter(Mandatory=$false)]
        [string]$Tenant,
        [parameter(Mandatory=$false)]
        [string]$TenantGroup,
        [parameter(Mandatory=$false)]
        [ValidateSet("disabled","secure","legacy")]
        [string]$IdEntryMode,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$AllowWebLinkAccess,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ShowSignIn,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ResolveCoSpaceCallIds,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ResolveLyncConferenceIds
    )

    $nodeLocation = "/api/v1/webBridges"
    $data = ""
    $modifiers = 0

    if ($Url -ne "") {
        $data += "url=$Url"
        $modifiers++
    }

    if ($ResourceArchive -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "resourceArchive=$ResourceArchive"
        $modifiers++
    }

    if ($Tenant -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "tenant=$Tenant"
        $modifiers++
    }

    if ($TenantGroup -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "tenantGroup=$TenantGroup"
        $modifiers++
    }

    if ($IdEntryMode -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "idEntryMode=$IdEntryMode"
        $modifiers++
    }

    if ($AllowWebLinkAccess -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "allowWebLinkAccess=$AllowWebLinkAccess"
        $modifiers++
    }

    if ($ShowSignIn -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }

        $data += "showSignIn=$ShowSignIn"
        $modifiers++
    }

    if ($ResolveCoSpaceCallIds -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "resolveCoSpaceCallIds=$ResolveCoSpaceCallIds"
        $modifiers++
    }

    if ($ResolveLyncConferenceIds -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "resolveLyncConferenceIds=$ResolveLyncConferenceIds"
    }

    [string]$NewWebBridgeId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoWebBridge $NewWebBridgeId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoWebBridge {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [string]$Url,
        [parameter(Mandatory=$false)]
        [string]$ResourceArchive,
        [parameter(Mandatory=$false)]
        [string]$Tenant,
        [parameter(Mandatory=$false)]
        [string]$TenantGroup,
        [parameter(Mandatory=$false)]
        [ValidateSet("disabled","secure","legacy")]
        [string]$IdEntryMode,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$AllowWebLinkAccess,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ShowSignIn,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ResolveCoSpaceCallIds,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$ResolveLyncConferenceIds
    )

    $nodeLocation = "/api/v1/webBridges/$Identity"
    $data = ""
    $modifiers = 0

    if ($Url -ne "") {
        $data += "url=$Url"
        $modifiers++
    }

    if ($ResourceArchive -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "resourceArchive=$ResourceArchive"
        $modifiers++
    }

    if ($Tenant -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "tenant=$Tenant"
        $modifiers++
    }

    if ($TenantGroup -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "tenantGroup=$TenantGroup"
        $modifiers++
    }

    if ($IdEntryMode -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "idEntryMode=$IdEntryMode"
        $modifiers++
    }

    if ($AllowWebLinkAccess -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "allowWebLinkAccess=$AllowWebLinkAccess"
        $modifiers++
    }

    if ($ShowSignIn -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "showSignIn=$ShowSignIn"
        $modifiers++
    }

    if ($ResolveCoSpaceCallIds -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "resolveCoSpaceCallIds=$ResolveCoSpaceCallIds"
        $modifiers++
    }

    if ($ResolveLyncConferenceIds -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "resolveLyncConferenceIds=$ResolveLyncConferenceIds"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoWebBridge $Identity
}

function Remove-AcanoWebBridge {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove web bridge")) {
        Open-AcanoAPI "/api/v1/webBridges/$Identity" -DELETE
    }
}

function Update-AcanoWebBridgeCustomization {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    Open-AcanoAPI "/api/v1/webBridges/$Identity/updateCustomization" -POST -ReturnResponse | Out-Null
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoCallBridges {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/callBridges"

    if ($Limit -ne "") {
        $nodeLocation += "?limit=$Limit"
        
        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).callBridges.callBridge
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoCallBridge {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoCallBridges
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/callBridges/$Identity").callBridge
        }
    }
}

function New-AcanoCallBridge {
    Param (
        [parameter(Mandatory=$true)]
        [string]$Name,
        [parameter(Mandatory=$false)]
        [string]$Address,
        [parameter(Mandatory=$false)]
        [string]$SipDomain
    )

    $nodeLocation = "/api/v1/callBridges"
    $data = "name=$Name"

    if ($Address -ne "") {
        $data += "&address=$Address"
    }

    if ($SipDomain -ne "") {
        $data += "&sipDomain=$SipDomain"
    }

    [string]$NewCallBridgeId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoCallBridge $NewCallBridgeId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoCallBridge {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [string]$Name,
        [parameter(Mandatory=$false)]
        [string]$Address,
        [parameter(Mandatory=$false)]
        [string]$SipDomain
    )

    $nodeLocation = "/api/v1/callBridges/$Identity"
    $data = ""
    $modifiers = 0

    if ($Name -ne "") {
        $data += "name=$Name"
        $modifiers++
    }

    if ($Address -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "address=$Address"
        $modifiers++
    }

    if ($SipDomain -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "sipAddress=$SipDomain"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoCallBridge $Identity
}

function Remove-AcanoCallBridge {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove callbridge")) {
        Open-AcanoAPI "/api/v1/callBridges/$Identity" -DELETE
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoXmppServer {
    return (Open-AcanoAPI "api/v1/system/configuration/xmpp").xmpp
}

function Set-AcanoXmppServer {
     Param (
        [parameter(Mandatory=$false)]
        [string]$UniqueName,
        [parameter(Mandatory=$false)]
        [string]$Domain,
        [parameter(Mandatory=$false)]
        [string]$SharedSecret,
        [parameter(Mandatory=$false)]
        [string]$ServerAddressOverride
    )

    $nodeLocation = "/api/v1/system/configuration/xmpp"
    $data = ""
    $modifiers = 0

    if ($UniqueName -ne "") {
        $data += "uniqueName=$UniqueName"
        $modifiers++
    }

    if ($Domain -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "domain=$Domain"
        $modifiers++
    }

    if ($SharedSecret -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "sharedSecret=$SharedSecret"
        $modifiers++
    }

    if ($ServerAddressOverride -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "serverAddressOverride=$ServerAddressOverride"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoXmppServer
}

function Get-AcanoCallBridgeCluster {
    return (Open-AcanoAPI "api/v1/system/configuration/cluster").cluster
}

function Set-AcanoCallBridgeCluster {
     Param (
        [parameter(Mandatory=$false)]
        [string]$UniqueName,
        [parameter(Mandatory=$false)]
        [string]$PeerLinkBitRate,
        [parameter(Mandatory=$false)]
        [string]$ParticipantLimit
    )

    $nodeLocation = "/api/v1/system/configuration/cluster"
    $data = ""
    $modifiers = 0

    if ($UniqueName -ne "") {
        $data += "uniqueName=$UniqueName"
        $modifiers++
    }

    if ($PeerLinkBitRate -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "peerLinkBitRate=$PeerLinkBitRate"
        $modifiers++
    }

    if ($ParticipantLimit -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "participantLimit=$ParticipantLimit"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoCallBridgeCluster
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoSystemDiagnostics {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$CoSpaceFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$CallCorrelatorFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/system/diagnostics"
    $modifiers = 0

    if ($CoSpaceFilter -ne "") {
        $nodeLocation += "?coSpacefilter=$CoSpaceFilter"
        $modifiers++
    }

    if ($CallCorrelatorFilter -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "callCorrelatorFilter=$CallCorrelatorFilter"
        $modifiers++
    }

    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).diagnostics.diagnostic
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoSystemDiagnostic {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    return (Open-AcanoAPI "api/v1/system/diagnostics/$Identity").diagnostic
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoSystemDiagnosticContent {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    return (Open-AcanoAPI "api/v1/system/diagnostics/$Identity/contents").diagnostic
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoLdapServers {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Filter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/ldapServers"
    $modifiers = 0

    if ($Filter -ne "") {
        $nodeLocation += "?filter=$Filter"
        $modifiers++
    }
    
    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).ldapServers.ldapServer
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoLdapServer {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoLdapServers
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/ldapServers/$Identity").ldapServer
        }
    }
}

function New-AcanoLdapServer {
    Param (
        [parameter(Mandatory=$true)]
        [string]$Address,
        [parameter(Mandatory=$true)]
        [string]$PortNumber,
        [parameter(Mandatory=$false)]
        [string]$Username,
        [parameter(Mandatory=$false)]
        [string]$Password,
        [parameter(Mandatory=$true)]
        [ValidateSet("true","false")]
        [string]$Secure
    )

    $nodeLocation = "/api/v1/ldapServers"
    $data = "address=$Address&portNumber=$PortNumber&secure=$Secure"
    $modifiers = 0

    if ($Username -ne "") {
        $data += "&username=$Username"
    }

    if ($Password -ne "") {
        $data += "&password=$Password"
    }

    [string]$NewLdapServerId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoLdapServer $NewLdapServerId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoLdapServer {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [string]$Address,
        [parameter(Mandatory=$false)]
        [string]$PortNumber,
        [parameter(Mandatory=$false)]
        [string]$Username,
        [parameter(Mandatory=$false)]
        [string]$Password,
        [parameter(Mandatory=$false)]
        [ValidateSet("true","false")]
        [string]$Secure
    )

    $nodeLocation = "/api/v1/ldapServers/$Identity"
    $data = ""
    $modifiers = 0

    if ($Address -ne "") {
        $data += "address=$Address"
        $modifiers++
    }

    if ($PortNumber -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "portNumber=$PortNumber"
        $modifiers++
    }

    if ($Username -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "username=$Username"
        $modifiers++
    }

    if ($Password -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "password=$Password"
        $modifiers++
    }

    if ($Secure -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "secure=$Secure"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoLdapServer $Identity
}

function Remove-AcanoLdapServer {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove LDAP server")) {
        Open-AcanoAPI "/api/v1/ldapServers/$Identity" -DELETE
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoLdapMappings {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Filter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/ldapMappings"
    $modifiers = 0

    if ($Filter -ne "") {
        $nodeLocation += "?filter=$Filter"
        $modifiers++
    }
    
    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).ldapMappings.ldapMapping
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoLdapMapping {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoLdapMappings
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/ldapMappings/$Identity").ldapMapping
        }
    }
}

function New-AcanoLdapMapping {
    Param (
        [parameter(Mandatory=$false)]
        [string]$JidMapping,
        [parameter(Mandatory=$false)]
        [string]$NameMapping,
        [parameter(Mandatory=$false)]
        [string]$CdrTagMapping,
        [parameter(Mandatory=$false)]
        [string]$AuthenticationMapping,
        [parameter(Mandatory=$false)]
        [string]$CoSpaceUriMapping,
        [parameter(Mandatory=$false)]
        [string]$CoSpaceSecondaryUriMapping,
        [parameter(Mandatory=$false)]
        [string]$CoSpaceNameMapping,
        [parameter(Mandatory=$false)]
        [string]$CoSpaceCallIdMapping
    )

    $nodeLocation = "/api/v1/ldapMappings"
    $data = ""
    $modifiers = 0

    if ($JidMapping -ne "") {
        $data += "jidMapping=$JidMapping"
        $modifiers++
    }

    if ($NameMapping -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "nameMapping=$NameMapping"
        $modifiers++
    }

    if ($CdrTagMapping -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "cdrTagMapping=$CdrTagMapping"
        $modifiers++
    }

    if ($AuthenticationMapping -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "authenticationMapping=$AuthenticationMapping"
        $modifiers++
    }

    if ($CoSpaceUriMapping -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "coSpaceUriMapping=$CoSpaceUriMapping"
        $modifiers++
    }

    if ($CoSpaceSecondaryUriMapping -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "coSpaceSecondaryUriMapping=$CoSpaceSecondaryUriMapping"
        $modifiers++
    }

    if ($CoSpaceNameMapping -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "coSpaceNameMapping=$CoSpaceNameMapping"
        $modifiers++
    }

    if ($CoSpaceCallIdMapping -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "coSpaceCallIdMapping=$CoSpaceCallIdMapping"
    }

    [string]$NewLdapMappingId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoLdapMapping $NewLdapMappingId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoLdapMapping {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [string]$JidMapping,
        [parameter(Mandatory=$false)]
        [string]$NameMapping,
        [parameter(Mandatory=$false)]
        [string]$CdrTagMapping,
        [parameter(Mandatory=$false)]
        [string]$AuthenticationMapping,
        [parameter(Mandatory=$false)]
        [string]$CoSpaceUriMapping,
        [parameter(Mandatory=$false)]
        [string]$CoSpaceSecondaryUriMapping,
        [parameter(Mandatory=$false)]
        [string]$CoSpaceNameMapping,
        [parameter(Mandatory=$false)]
        [string]$CoSpaceCallIdMapping
    )

    $nodeLocation = "/api/v1/ldapMappings/$Identity"
    $data = ""
    $modifiers = 0

    if ($JidMapping -ne "") {
        $data += "jidMapping=$JidMapping"
        $modifiers++
    }

    if ($NameMapping -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "nameMapping=$NameMapping"
        $modifiers++
    }

    if ($CdrTagMapping -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "cdrTagMapping=$CdrTagMapping"
        $modifiers++
    }

    if ($AuthenticationMapping -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "authenticationMapping=$AuthenticationMapping"
        $modifiers++
    }

    if ($CoSpaceUriMapping -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "coSpaceUriMapping=$CoSpaceUriMapping"
        $modifiers++
    }

    if ($CoSpaceSecondaryUriMapping -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "coSpaceSecondaryUriMapping=$CoSpaceSecondaryUriMapping"
        $modifiers++
    }

    if ($CoSpaceNameMapping -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "coSpaceNameMapping=$CoSpaceNameMapping"
        $modifiers++
    }

    if ($CoSpaceCallIdMapping -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "coSpaceCallIdMapping=$CoSpaceCallIdMapping"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoLdapMapping $Identity
}

function Remove-AcanoLdapMapping {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove LDAP mapping")) {
        Open-AcanoAPI "/api/v1/ldapMappings/$Identity" -DELETE
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoLdapSources {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Filter,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$TenantFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/ldapSources"
    $modifiers = 0

    if ($Filter -ne "") {
        $nodeLocation += "?filter=$Filter"
        $modifiers++
    }

    if ($TenantFilter -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "tenantFilter=$TenantFilter"
        $modifiers++
    }
    
    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).ldapSources.ldapSource
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoLdapSource {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoLdapSources
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/ldapSources/$Identity").ldapSource
        }
    }
}

function New-AcanoLdapSource {
    Param (
        [parameter(Mandatory=$true)]
        [string]$Server,
        [parameter(Mandatory=$true)]
        [string]$Mapping,
        [parameter(Mandatory=$true)]
        [string]$BaseDN,
        [parameter(Mandatory=$false)]
        [string]$Filter,
        [parameter(Mandatory=$false)]
        [string]$Tenant
    )

    $nodeLocation = "/api/v1/ldapSources"
    $data = "server=$Server&mapping=$Mapping&baseDN=$BaseDN"
    $modifiers = 0

    if ($Filter -ne "") {
        $data += "&filter=$Filter"
    }

    if ($Tenant -ne "") {
        $data += "&tenant=$Tenant"
    }

    [string]$NewLdapSourceId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoLdapSource $NewLdapSourceId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoLdapSource {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [string]$Server,
        [parameter(Mandatory=$false)]
        [string]$Mapping,
        [parameter(Mandatory=$false)]
        [string]$BaseDN,
        [parameter(Mandatory=$false)]
        [string]$Filter,
        [parameter(Mandatory=$false)]
        [string]$Tenant
    )

    $nodeLocation = "/api/v1/ldapSources/$Identity"
    $data = ""
    $modifiers = 0

    if ($Server -ne "") {
        $data += "server=$Server"
        $modifiers++
    }

    if ($Mapping -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "mapping=$Mapping"
        $modifiers++
    }

    if ($BaseDN -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "baseDn=$BaseDN"
        $modifiers++
    }

    if ($Filter -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "filter=$Filter"
        $modifiers++
    }

    if ($Tenant -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "tenant=$Tenant"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoLdapSource $Identity
}

function Remove-AcanoLdapSource {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove LDAP source")) {
        Open-AcanoAPI "/api/v1/ldapSources/$Identity" -DELETE
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoLdapSyncs {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/ldapSyncs"

    if ($Limit -ne "") {
        $nodeLocation += "?limit=$Limit"
        
        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).ldapSyncs.ldapSync
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoLdapSync {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoLdapSyncs
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/ldapSyncs/$Identity").ldapSync
        }
    }
}

function New-AcanoLdapSync {
    Param (
        [parameter(Mandatory=$false)]
        [string]$Tenant,
        [parameter(Mandatory=$false)]
        [string]$LdapSource,
        [parameter(Mandatory=$false)]
        [string]$RemoveWhenFinished
    )

    $nodeLocation = "/api/v1/ldapSyncs"
    $data = ""
    $modifiers = 0

    if ($Tenant -ne "") {
        $data += "tenant=$Tenant"
        $modifiers++
    }

    if ($LdapSource -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "ldapSource=$LdapSource"
        $modifiers++
    }

    if ($RemoveWhenFinished -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "removeWhenFinished=$RemoveWhenFinished"
    }

    [string]$NewLdapSyncId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoLdapSync $NewLdapSyncId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Remove-AcanoLdapSync {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Stop ongoing LDAP Sync")) {
        Open-AcanoAPI "/api/v1/ldapSyncs/$Identity" -DELETE
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoExternalDirectorySearchLocations {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$TenantFilter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/directorySearchLocations"
    $modifiers = 0

    if ($TenantFilter -ne "") {
        $nodeLocation += "?tenantFilter=$TenantFilter"
        $modifiers++
    }
    
    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).directorySearchLocations.directorySearchLocation
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoExternalDirectorySearchLocation {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoExternalDirectorySearchLocations
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/directorySearchLocations/$Identity").directorySearchLocation
        }
    }
}

function New-AcanoExternalDirectorySearchLocation {
    Param (
        [parameter(Mandatory=$true)]
        [string]$LdapServer,
        [parameter(Mandatory=$false)]
        [string]$Tenant,
        [parameter(Mandatory=$false)]
        [string]$BaseDN,
        [parameter(Mandatory=$false)]
        [string]$FilterFormat,
        [parameter(Mandatory=$false)]
        [string]$Label,
        [parameter(Mandatory=$false)]
        [string]$Priority,
        [parameter(Mandatory=$false)]
        [string]$FirstName,
        [parameter(Mandatory=$false)]
        [string]$LastName,
        [parameter(Mandatory=$false)]
        [string]$DisplayName,
        [parameter(Mandatory=$false)]
        [string]$Phone,
        [parameter(Mandatory=$false)]
        [string]$Mobile,
        [parameter(Mandatory=$false)]
        [string]$Email,
        [parameter(Mandatory=$false)]
        [string]$Sip,
        [parameter(Mandatory=$false)]
        [string]$Organization
    )

    $nodeLocation = "/api/v1/directorySearchLocations"
    $data = "ldapServer=$LdapServer"

    if ($Tenant -ne "") {
        $data += "&tenant=$Tenant"
    }

    if ($BaseDN -ne "") {
        $data += "&baseDn=$BaseDN"
    }

    if ($FilterFormat -ne "") {
        $data += "&filterFormat=$FilterFormat"
    }

    if ($Label -ne "") {
        $data += "&label=$Label"
    }

    if ($Priority -ne "") {
        $data += "&priority=$Priority"
    }

    if ($FirstName -ne "") {
        $data += "&firstName=$FirstName"
    }

    if ($LastName -ne "") {
        $data += "&lastName=$LastName"
    }

    if ($DisplayName -ne "") {
        $data += "&displayName=$DisplayName"
    }

    if ($Phone -ne "") {
        $data += "&phone=$Phone"
    }

    if ($Mobile -ne "") {
        $data += "&mobile=$Mobile"
    }

    if ($Email -ne "") {
        $data += "&email=$Email"
    }

    if ($Sip -ne "") {
        $data += "&sip=$Sip"
    }

    if ($Organization -ne "") {
        $data += "&organization=$Organization"
    }

    [string]$NewexdirsearchId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoExternalDirectorySearchLocation $NewexdirsearchId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoExternalDirectorySearchLocation {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [string]$LdapServer,
        [parameter(Mandatory=$false)]
        [string]$Tenant,
        [parameter(Mandatory=$false)]
        [string]$BaseDN,
        [parameter(Mandatory=$false)]
        [string]$FilterFormat,
        [parameter(Mandatory=$false)]
        [string]$Label,
        [parameter(Mandatory=$false)]
        [string]$Priority,
        [parameter(Mandatory=$false)]
        [string]$FirstName,
        [parameter(Mandatory=$false)]
        [string]$LastName,
        [parameter(Mandatory=$false)]
        [string]$DisplayName,
        [parameter(Mandatory=$false)]
        [string]$Phone,
        [parameter(Mandatory=$false)]
        [string]$Mobile,
        [parameter(Mandatory=$false)]
        [string]$Email,
        [parameter(Mandatory=$false)]
        [string]$Sip,
        [parameter(Mandatory=$false)]
        [string]$Organization
    )

    $nodeLocation = "/api/v1/directorySearchLocations/$Identity"
    $data = ""
    $modifiers = 0

    if ($Tenant -ne "") {
        $data += "tenant=$Tenant"
        $modifiers++
    }

    if ($LdapServer -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "ldapServer=$LdapServer"
        $modifiers++
    }

    if ($BaseDN -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "baseDn=$BaseDN"
        $modifiers++
    }

    if ($FilterFormat -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "filterFormat=$FilterFormat"
        $modifiers++
    }

    if ($Label -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "label=$Label"
        $modifiers++
    }

    if ($Priority -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "priority=$Priority"
        $modifiers++
    }

    if ($FirstName -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "firstName=$FirstName"
        $modifiers++
    }

    if ($LastName -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "lastName=$LastName"
        $modifiers++
    }

    if ($DisplayName -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "displayName=$DisplayName"
        $modifiers++
    }

    if ($Phone -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "phone=$Phone"
        $modifiers++
    }

    if ($Mobile -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "mobile=$Mobile"
        $modifiers++
    }

    if ($Email -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "email=$Email"
        $modifiers++
    }

    if ($Sip -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "sip=$Sip"
        $modifiers++
    }

    if ($Organization -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "organization=$Organization"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoExternalDirectorySearchLocation $Identity
}

function Remove-AcanoExternalDirectorySearchLocation {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove external directory search location")) {
        Open-AcanoAPI "/api/v1/directorySearchLocations/$Identity" -DELETE
    }
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoTenants {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Filter,
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/tenants"
    $modifiers = 0

    if ($Filter -ne "") {
        $nodeLocation += "?filter=$Filter"
        $modifiers++
    }
    
    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).tenants.tenant
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoTenant {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoTenants
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/tenants/$Identity").tenant
        }
    }
}

function New-AcanoTenant {
    Param (
        [parameter(Mandatory=$true)]
        [string]$Name,
        [parameter(Mandatory=$false)]
        [string]$TenantGroup,
        [parameter(Mandatory=$false)]
        [string]$CallLegProfile,
        [parameter(Mandatory=$false)]
        [string]$CallProfile,
        [parameter(Mandatory=$false)]
        [string]$DtmfProfile,
        [parameter(Mandatory=$false)]
        [string]$IvrBrandingProfile,
        [parameter(Mandatory=$false)]
        [string]$CallBrandingProfile,
        [parameter(Mandatory=$false)]
        [string]$ParticipantLimit,
        [parameter(Mandatory=$false)]
        [string]$UserProfile
    )

    $nodeLocation = "/api/v1/tenants"
    $data = "name=$Name"

    if ($TenantGroup -ne "") {
        $data += "&tenantGroup=$TenantGroup"
    }

    if ($CallLegProfile -ne "") {
        $data += "&callLegProfile=$CallLegProfile"
    }

    if ($CallProfile -ne "") {
        $data += "&callProfile=$CallProfile"
    }

    if ($DtmfProfile -ne "") {
        $data += "&dtmfProfile=$DtmfProfile"
    }

    if ($IvrBrandingProfile -ne "") {
        $data += "&ivrBrandingProfile=$IvrBrandingProfile"
    }

    if ($CallBrandingProfile -ne "") {
        $data += "&callBrandingProfile=$CallBrandingProfile"
    }

    if ($ParticipantLimit -ne "") {
        $data += "&participantLimit=$ParticipantLimit"
    }

    if ($UserProfile -ne "") {
        $data += "&userProfile=$UserProfile"
    }

    [string]$NewTenantId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoTenant $NewTenantId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoTenant {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$false)]
        [string]$Name,
        [parameter(Mandatory=$false)]
        [string]$TenantGroup,
        [parameter(Mandatory=$false)]
        [string]$CallLegProfile,
        [parameter(Mandatory=$false)]
        [string]$CallProfile,
        [parameter(Mandatory=$false)]
        [string]$DtmfProfile,
        [parameter(Mandatory=$false)]
        [string]$IvrBrandingProfile,
        [parameter(Mandatory=$false)]
        [string]$CallBrandingProfile,
        [parameter(Mandatory=$false)]
        [string]$ParticipantLimit,
        [parameter(Mandatory=$false)]
        [string]$UserProfile
    )

    $nodeLocation = "/api/v1/Tenants/$Identity"
    $data = ""
    $modifiers = 0

    if ($TenantGroup -ne "") {
        $data += "tenantgroup=$TenantGroup"
        $modifiers++
    }

    if ($Name -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "name=$Name"
        $modifiers++
    }

    if ($CallLegProfile -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "callLegProfile=$CallLegProfile"
        $modifiers++
    }

    if ($CallProfile -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "callProfile=$CallProfile"
        $modifiers++
    }

    if ($DtmfProfile -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "dtmfProfile=$DtmfProfile"
        $modifiers++
    }

    if ($IvrBrandingProfile -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "ivrBrandingProfile=$IvrBrandingProfile"
        $modifiers++
    }

    if ($CallBrandingProfile -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "callBrandingProfile=$CallBrandingProfile"
        $modifiers++
    }

    if ($ParticipantLimit -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "participantLimit=$ParticipantLimit"
        $modifiers++
    }

    if ($UserProfile -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "userProfile=$UserProfile"
    }

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoTenant $Identity
}

function Remove-AcanoTenant {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove tenant")) {
        Open-AcanoAPI "/api/v1/tenants/$Identity" -DELETE
    }
}

function Get-AcanoTenantGroups {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/tenantGroups"
    $modifiers = 0
    
    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).tenantGroups.tenantGroup
}

function Get-AcanoTenantGroup {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoTenantGroups
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/tenantGroups/$Identity").tenantGroup
        }
    }
}

function New-AcanoTenantGroup {

    $nodeLocation = "/api/v1/tenantGroups"
    $data = ""

    [string]$NewTenantGroupId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoTenantGroup $NewTenantGroupId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Remove-AcanoTenantGroup {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove tenant group")) {
        Open-AcanoAPI "/api/v1/tenantGroups/$Identity" -DELETE
    }
}

function New-AcanoAccessQuery {
    Param (
        [parameter(Mandatory=$false)]
        [string]$Tenant,
        [parameter(Mandatory=$false)]
        [string]$Uri,
        [parameter(Mandatory=$false)]
        [string]$CallId
    )

    $nodeLocation = "/api/v1/accessQuery"
    $data = ""
    $modifiers = 0

    if ($Tenant -ne "") {
        $data += "tenant=$Tenant"
        $modifiers++
    }

    if ($Uri -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "uri=$Uri"
        $modifiers++
    }

    if ($CallId -ne "") {
        if ($modifiers -gt 0) {
            $data += "&"
        }
        $data += "callId=$CallId"
    }

    return (Open-AcanoAPI $nodeLocation -POST -Data $data -ReturnResponse).accessQuery
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoRecorders {
    [CmdletBinding(DefaultParameterSetName="NoOffset")]
    Param (
        [parameter(ParameterSetName="Offset",Mandatory=$true)]
        [parameter(ParameterSetName="NoOffset",Mandatory=$false)]
        [string]$Limit,
        [parameter(ParameterSetName="Offset",Mandatory=$false)]
        [string]$Offset
    )

    $nodeLocation = "api/v1/recorders"
    $modifiers = 0
    
    if ($Limit -ne "") {
        if ($modifiers -gt 0) {
            $nodeLocation += "&"
        } else {
            $nodeLocation += "?"
        }
        $nodeLocation += "limit=$Limit"

        if($Offset -ne ""){
            $nodeLocation += "&offset=$Offset"
        }
    }

    return (Open-AcanoAPI $nodeLocation).recorders.recorder
}

# .ExternalHelp PsAcano.psm1-Help.xml
function Get-AcanoRecorder {
    [CmdletBinding(DefaultParameterSetName="getAll")]
    Param (
        [parameter(ParameterSetName="getSingle",Mandatory=$true,Position=1)]
        [string]$Identity
    )

    switch ($PsCmdlet.ParameterSetName) { 

        "getAll"  {
            Get-AcanoRecorders
        } 

        "getSingle"  {
            return (Open-AcanoAPI "api/v1/recorders/$Identity").recorder
        }
    }
}

function New-AcanoRecorder {
    Param (
        [parameter(Mandatory=$true)]
        [string]$Url
    )

    $nodeLocation = "/api/v1/recorders"
    $data = "Url=$Url"

    [string]$NewRecorderId = Open-AcanoAPI $nodeLocation -POST -Data $data
    
    Get-AcanoRecorder $NewRecorderId.Replace(" ","") ## For some reason POST returns a string starting and ending with a whitespace
}

function Set-AcanoRecorder {
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity,
        [parameter(Mandatory=$true)]
        [string]$Url
    )

    $nodeLocation = "/api/v1/recorders/$Identity"
    $data = "url=$Url"

    Open-AcanoAPI $nodeLocation -PUT -Data $data
    
    Get-AcanoRecorder $Identity
}

function Remove-AcanoRecorder {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [parameter(Mandatory=$true,Position=1)]
        [string]$Identity
    )

    if ($PSCmdlet.ShouldProcess("$Identity","Remove recorder")) {
        Open-AcanoAPI "/api/v1/recorders/$Identity" -DELETE
    }
}