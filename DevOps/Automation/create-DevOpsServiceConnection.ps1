Param(
    [Parameter(Mandatory = $True)]
    [string]$personalToken,
    
    [Parameter(Mandatory = $True)]
    [string]$organisation,
    
    [Parameter(Mandatory = $True)]
    [string]$ProjectName,

    [Parameter(Mandatory = $True)]
    [string]$managementGroupId,

    [Parameter(Mandatory = $True)]
    [string]$managementGroupName
    
)

$AzureDevOpsAuthenicationHeader = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($personalToken)")) }

## Get ProjectId
$URL = "https://dev.azure.com/$($organisation)/_apis/projects?api-version=6.0"
Try {
    $AzDoProjectNameproperties = (Invoke-RestMethod $URL -Headers $AzureDevOpsAuthenicationHeader -ErrorAction Stop).Value
    Write-Verbose "Collected Azure DevOps Projects"
}
Catch {
    $ErrorMessage = $_ | ConvertFrom-Json
    Throw "Could not collect project: $($ErrorMessage.message)"
}
$ProjectID = ($AzDoProjectNameproperties | Where-Object { $_.Name -eq $ProjectName }).id
Write-Verbose "Collected ID: $AzDoProjectID"


$ConnectionName = "MWP Connection To $ProjectName"
# Create body for the API call
$Body = @{
    data                             = @{
        managementGroupId   = $managementGroupId
        managementGroupName = $managementGroupName
        environment         = "AzureCloud"
        scopeLevel          = "ManagementGroup"
        creationMode        = "Manual"
    }
    name                             = $ConnectionName
    type                             = "AzureRM"
    url                              = "https://management.azure.com/"
    authorization                    = @{
        parameters = @{
            tenantid            = $TenantInfo.Tenant.Id
            serviceprincipalid  = $AADApplication.ApplicationId.Guid
            authenticationType  = "spnKey"
            serviceprincipalkey = $PlainPassword
        
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
