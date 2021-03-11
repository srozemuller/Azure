# This script is a part of a blogpost which can be found at: 

Param(
    [Parameter(Mandatory = $True)]
    [string]$personalToken,
    
    [Parameter(Mandatory = $True)]
    [string]$organisation,
    
    [Parameter(Mandatory = $True)]
    [string]$ProjectName,

    [Parameter(Mandatory = $True, ParameterSetName = 'ManagementGroup')]
    [string]$ManagementGroupId,

    [Parameter(Mandatory = $True, ParameterSetName = 'ManagementGroup')]
    [string]$ManagementGroupName,
 
    [Parameter(Mandatory = $True, ParameterSetName = 'Subscription')]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $True, ParameterSetName = 'Subscription')]
    [string]$SubscriptionName,

    [Parameter(Mandatory = $True)]
    [string]$TenantId,
    
    [Parameter(Mandatory = $True)]
    [string]$ApplicationId,
    
    [Parameter(Mandatory = $True)]
    [string]$ApplicationSecret
    
)

$AzureDevOpsAuthenicationHeader = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($personalToken)")) }

## Get ProjectId
$URL = "https://dev.azure.com/$($organisation)/_apis/projects?api-version=6.0"
Try {
    $ProjectNameproperties = (Invoke-RestMethod $URL -Headers $AzureDevOpsAuthenicationHeader -ErrorAction Stop).Value
    Write-Verbose "Collected Azure DevOps Projects"
}
Catch {
    $ErrorMessage = $_ | ConvertFrom-Json
    Throw "Could not collect project: $($ErrorMessage.message)"
}
$ProjectID = ($ProjectNameproperties | Where-Object { $_.Name -eq $ProjectName }).id
Write-Verbose "Collected ID: $ProjectID"
$ConnectionName = "Connection To $ProjectName"

switch ($PsCmdlet.ParameterSetName) {
    ManagementGroup { 
        $data = @{
            managementGroupId   = "$managementGroupId"
            managementGroupName = "$managementGroupName"
            environment         = "AzureCloud"
            scopeLevel          = "ManagementGroup"
            creationMode        = "Manual"
        }
    }
    Subscription { 
        $data = @{
            SubscriptionId   = $SubscriptionId
            SubscriptionName = $SubscriptionName
            environment      = "AzureCloud"
            scopeLevel       = "Subscription"
            creationMode     = "Manual"
        }
    }
}
# Create body for the API call
$Body = @{
    data                             = $data
    name                             = $ConnectionName
    type                             = "AzureRM"
    url                              = "https://management.azure.com/"
    authorization                    = @{
        parameters = @{
            tenantid            = $TenantId
            serviceprincipalid  = $ApplicationId
            authenticationType  = "spnKey"
            serviceprincipalkey = $ApplicationSecret
        
        }
        scheme     = "ServicePrincipal"
    }
    isShared                         = $false
    isReady                          = $true
    serviceEndpointProjectReferences = @(
        @{
            projectReference = @{
                id   = $ProjectID
                name = $ProjectName
            }
            name             = $ConnectionName
        }
    )
}

$URL = "https://dev.azure.com/$organisation/$ProjectName/_apis/serviceendpoint/endpoints?api-version=6.0-preview.4"
$Parameters = @{
    Uri         = $URL
    Method      = "POST"
    Body        = ($Body | ConvertTo-Json -Depth 3)
    Headers     = $AzureDevOpsAuthenicationHeader
    ContentType = "application/json"
    Erroraction = "Stop"
}
try {
    Write-Verbose "Creating Connection"
    $Result = Invoke-RestMethod @Parameters
    Write-Host "$($Result.name) service connection created"
}
Catch {
    $ErrorMessage = $_ | ConvertFrom-Json
    Throw "Could not create Connection: $($ErrorMessage.message)"
}
