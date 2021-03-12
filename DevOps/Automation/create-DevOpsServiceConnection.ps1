<#
    .SYNOPSIS
    Creates a DevOps service connection through REST API
    .DESCRIPTION
    The scrip will help you creating an Azure DevOps service connection through the REST API. 
    .PARAMETER PersonalToken
    Personal Access Token. Check https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page
    .PARAMETER Organisation
    The Azure DevOps organisation name
    .PARAMETER ProjectName
    The Azure DevOps project where the service connection will be made
    .PARAMETER ManagementGroupId
    The management group id created in the tenant
    .PARAMETER ManagementGroupName
    The management group name created in the tenant
    .PARAMETER SubscriptionId
    The subscription id in the tenant where to connect
    .PARAMETER SubscriptionName
    The subscription name in the tenant where to connect
    .PARAMETER TenantId
    The tenant id where to connect
    .PARAMETER ApplicationId
    The application id (service principal) in the Azure AD 
    .PARAMETER ApplicationSecret
    The application secret, in plain text
    .EXAMPLE
    create-DevOpsServiceConnection.ps1 -personalToken xxx -organisation DevOpsOrganisation -ProjectName WVD -ManagementGroupId MGTGROUP1 -ManagementGroupName 'MGT GROUP 1' -TenantId xxx-xxx -ApplicationId xxx-xxx-xxx -ApplicationSecret 'verysecret'
#>

Param(
    [Parameter(Mandatory = $True)]
    [string]$PersonalToken,
    
    [Parameter(Mandatory = $True)]
    [string]$Organisation,
    
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
