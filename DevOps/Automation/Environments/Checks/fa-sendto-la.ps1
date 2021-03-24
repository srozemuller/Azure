<#
  .SYNOPSIS
    This function will trigger a logic app which will send a message to a MS Teams channel.
  .DESCRIPTION
    Script receives from other functions input like title, message, type and severity. If everything is filled the info will be send to our monitorsystem.
#>

using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$LogicAppUri = "url to Logic App"
# These are the variables from the DevOps environment
$Email = $Request.Body.BuildRequestedForEmail
$Status = $Request.Body.Status

$ProjectName = $Request.Body.TeamProject
$BuildNumber = $Request.Body.BuildNumber
$VMadminUsername = $Request.Body.VMadminUsername
$VMadminPassword = $Request.Body.VMadminPassword
$VirtualMachineName = $Request.Body.VirtualMachineName
$PublicIp = $Request.Body.PublicIp

$JsonBody = @{
    account = @{
        name = $Email
    }
    text = @{
        Message = "Job $BuildNumber has status $Status."
        Title = "Update from $ProjectName"
        VmName = $VirtualMachineName
        VmUserName = $VMadminUsername
        VmPassword = $VMadminPassword
        VmPublicIp = $PublicIp
    }  
}

$Body = $JsonBody | Convertto-Json -depth 2
$Headers = @{
    'Content-Type' = 'application/json'
}
$Request = invoke-webrequest -URI $LogicAppUri -Body $Body -Method 'Post' -Headers $Headers
Write-Warning $Request
Write-Output $Request
if ($Request.StatusCode -eq '201') {
    $Status = [HttpStatusCode]::Created
}
else {
    $Status = [HttpStatusCode]::BadRequest
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = $Status
        Body = $body
    }
)
