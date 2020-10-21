$storageAccountTemplateFile = "https://raw.githubusercontent.com/srozemuller/Azure/main/AzureStorageAccount/azuredeploy.json"
$storageAccountTemplateParameters = "https://raw.githubusercontent.com/srozemuller/Azure/main/AzureStorageAccount/azuredeploy.parameters.json"
$backupFolder = "$env:Temp\KeyVaultBackup"
$location = "West Europe"

$backupLocationTag = "BackupLocation"
$backupContainerTag = "BackupContainer"

$global:parameters = @{
    resourceGroupName = "RG-PRD-Backups-001"
    location          = $location
}
function backup-keyVaultItems($keyvaultName) {
    #######Parameters
    #######Setup backup directory
    If ((test-path $backupFolder)) {
        Remove-Item $backupFolder -Recurse -Force

    }
    ####### Backup items
    New-Item -ItemType Directory -Force -Path "$($backupFolder)\$($keyvaultName)" | Out-Null
    Write-Output "Starting backup of KeyVault to a local directory."
    ###Certificates
    $certificates = Get-AzKeyVaultCertificate -VaultName $keyvaultName 
    foreach ($cert in $certificates) {
        Backup-AzKeyVaultCertificate -Name $cert.name -VaultName $keyvaultName -OutputFile "$backupFolder\$keyvaultName\certificate-$($cert.name)" | Out-Null
    }
    ###Secrets
    $secrets = Get-AzKeyVaultSecret -VaultName $keyvaultName
    foreach ($secret in $secrets) {
        #Exclude any secrets automatically generated when creating a cert, as these cannot be backed up   
        if (! ($certificates.Name -contains $secret.name)) {
            Backup-AzKeyVaultSecret -Name $secret.name -VaultName $keyvaultName -OutputFile "$backupFolder\$keyvaultName\secret-$($secret.name)" | Out-Null
        }
    }
    #keys
    $keys = Get-AzKeyVaultKey -VaultName $keyvaultName
    foreach ($kvkey in $keys) {
        #Exclude any keys automatically generated when creating a cert, as these cannot be backed up   
        if (! ($certificates.Name -contains $kvkey.name)) {
            Backup-AzKeyVaultKey -Name $kvkey.name -VaultName $keyvaultName -OutputFile "$backupFolder\$keyvaultName\key-$($kvkey.name)" | Out-Null
        }
    }
}
$keyvaults = Get-AzKeyVault 
    if ($keyvaults) {
        if ($null -eq (get-AzResourceGroup $global:parameters.resourceGroupName -ErrorAction SilentlyContinue)) {
            New-AzResourceGroup @global:parameters
        }
        if ($null -eq ($keyvaults | ? { $_.Tags.Keys -match $BackupLocationTag })) {
            # if no backuplocation tags is available at any of the keyVaults we will create one first
            $deployment = New-AzResourceGroupDeployment -ResourceGroupName $global:parameters.resourceGroupName -TemplateUri $storageAccountTemplateFile -TemplateParameterUri $storageAccountTemplateParameters
            $backupLocation = $deployment.outputs.Get_Item("storageAccount").value
            if ($deployment.ProvisioningState -eq "Succeeded") {
                foreach ($keyvault in $keyvaults) {
                    $containerName = $keyvault.VaultName.Replace("-", $null).ToLower()
                    if (!(Get-aztag -ResourceId $keyvault.ResourceId  | ? { $_.Tags.Keys -match $BackupLocationTag }  )) {
                        Update-AzTag $keyvault.ResourceId -operation Merge -Tag @{BackupLocation = $backupLocation; BackupContainer = $containerName }
                    }
                }
            }    
        }
        else {
            foreach ($keyvault in $keyvaults) {
                $backupLocation = (get-azkeyvault -VaultName $keyvault.vaultname | ? { $_.Tags.Keys -match $BackupLocationTag}).tags.Get_Item($BackupLocationTag)
                $storageAccount = get-AzStorageAccount | ? { $_.StorageAccountName -eq $backupLocation }
                if ($null -eq (Get-aztag -ResourceId $keyvault.ResourceId  | ? { $_.Tags.Keys -match $BackupContainerTag }  )) {
                    $containerName = $keyvault.VaultName.Replace("-", $null).ToLower()
                    Update-AzTag $keyvault.ResourceId -operation Merge -Tag @{BackupContainer = $containerName }
                }
                $containerName = (get-azkeyvault -VaultName $keyvault.vaultname | ? { $_.Tags.Keys -match $backupContainerTag }).tags.Get_Item($backupContainerTag)
                if ($null -eq (Get-AzStorageContainer -Name $containerName -Context $storageAccount.context)) {
                    New-AzStorageContainer -Name $containerName -Context $storageAccount.context
                }
                backup-keyVaultItems -keyvaultName $keyvault.VaultName
                foreach ($file in (get-childitem "$($backupFolder)\$($keyvault.VaultName)")) {
                    Set-AzStorageBlobContent -File $file.FullName -Container $containerName -Blob $file.name -Context $storageAccount.context -Force
                }
            }
        }
    }
