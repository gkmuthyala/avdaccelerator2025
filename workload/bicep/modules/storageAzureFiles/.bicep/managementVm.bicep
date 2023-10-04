targetScope = 'subscription'

// ========== //
// Parameters //
// ========== //

@sys.description('AVD disk encryption set resource ID to enable server side encyption.')
param diskEncryptionSetResourceId string

@sys.description('AVD workload subscription ID, multiple subscriptions scenario.')
param workloadSubsId string

@sys.description('Virtual machine time zone.')
param computeTimeZone string

@sys.description('Required, The service providing domain services for Azure Virtual Desktop.')
param identityServiceProvider string

@sys.description('Resource Group Name for Azure Files.')
param serviceObjectsRgName string

@sys.description('AVD subnet ID.')
param subnetId string

@sys.description('Enable accelerated networking on the session host VMs.')
param enableAcceleratedNetworking bool

@sys.description('Specifies the securityType of the virtual machine. Must be TrustedLaunch or ConfidentialVM enable UefiSettings.')
param securityType string

@sys.description('Specifies whether secure boot should be enabled on the virtual machine. This parameter is part of the UefiSettings. securityType should be set to TrustedLaunch to enable UefiSettings.')
param secureBootEnabled bool

@sys.description('Specifies whether virtual TPM should be enabled on the virtual machine. This parameter is part of the UefiSettings.  securityType should be set to TrustedLaunch to enable UefiSettings.')
param vTpmEnabled bool

@sys.description('Location where to deploy compute services.')
param location string

@sys.description('This property can be used by user in the request to enable or disable the Host Encryption for the virtual machine. This will enable the encryption for all the disks including Resource/Temp disk at host itself. For security reasons, it is recommended to set encryptionAtHost to True. Restrictions: Cannot be enabled if Azure Disk Encryption (guest-VM encryption using bitlocker/DM-Crypt) is enabled on your VMs.')
param encryptionAtHost bool

@sys.description('Session host VM size.')
param mgmtVmSize string

@sys.description('OS disk type for session host.')
param osDiskType string

@sys.description('Market Place OS image')
param osImage object

//@sys.description('Set to deploy image from Azure. Compute Gallery')
//param useSharedImage bool

//@sys.description('Source custom image ID.')
//param imageTemplateDefinitionId string

@sys.description('Storage Managed Identity Resource ID.')
param storageManagedIdentityResourceId string

@sys.description('Local administrator username.')
param vmLocalUserName string

@sys.description('AD domain name.')
param identityDomainName string

@sys.description('Keyvault name to get credentials from.')
param wrklKvName string

@sys.description('AVD session host domain join credentials.')
param domainJoinUserName string

@sys.description('OU path to join AVd VMs.')
param ouPath string

@sys.description('Application Security Group (ASG) for the session hosts.')
param applicationSecurityGroupResourceId string

@sys.description('Tags to be applied to resources')
param tags object

@sys.description('Name for management virtual machine. for tools and to join Azure Files to domain.')
param managementVmName string

@sys.description('Do not modify, used to set unique value for resource deployment.')
param time string = utcNow()

// =========== //
// Variable declaration //
// =========== //

var varManagedDisk = empty(diskEncryptionSetResourceId) ? {
    storageAccountType: osDiskType
} : {
    diskEncryptionSet: {
        id: diskEncryptionSetResourceId
    }
    storageAccountType: osDiskType
}

// =========== //
// Deployments //
// =========== //

// Call on the KV.
resource avdWrklKeyVaultget 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
    name: wrklKvName
    scope: resourceGroup('${workloadSubsId}', '${serviceObjectsRgName}')
}

// Provision temporary VM and add it to domain.
module managementVm '../../../../../carml/1.3.0/Microsoft.Compute/virtualMachines/deploy.bicep' = {
    scope: resourceGroup('${workloadSubsId}', '${serviceObjectsRgName}')
    name: 'MGMT-VM-${time}'
    params: {
        name: managementVmName
        location: location
        timeZone: computeTimeZone
        systemAssignedIdentity: false
        userAssignedIdentities: {
            '${storageManagedIdentityResourceId}': {}
        }
        encryptionAtHost: encryptionAtHost
        availabilityZone: []
        osType: 'Windows'
        //licenseType: 'Windows_Client'
        vmSize: mgmtVmSize
        securityType: securityType
        secureBootEnabled: secureBootEnabled
        vTpmEnabled: vTpmEnabled
        imageReference: osImage
        osDisk: {
            createOption: 'fromImage'
            deleteOption: 'Delete'
            diskSizeGB: 128
            managedDisk: varManagedDisk
        }
        adminUsername: vmLocalUserName
        adminPassword: avdWrklKeyVaultget.getSecret('vmLocalUserPassword')
        nicConfigurations: [
            {
                nicSuffix: 'nic-01-'
                deleteOption: 'Delete'
                enableAcceleratedNetworking: enableAcceleratedNetworking
                ipConfigurations: !empty(applicationSecurityGroupResourceId)  ? [
                    {
                        name: 'ipconfig01'
                        subnetResourceId: subnetId
                        applicationSecurityGroups: [
                            {
                                id: applicationSecurityGroupResourceId
                            }
                        ] 
                    }
                ] : [
                    {
                        name: 'ipconfig01'
                        subnetResourceId: subnetId
                    }
                ]
            }
        ]
        // Join domain
        allowExtensionOperations: true
        extensionDomainJoinPassword: avdWrklKeyVaultget.getSecret('domainJoinUserPassword')
        extensionDomainJoinConfig: {
            enabled: (identityServiceProvider == 'AAD') ? false: true
            settings: {
                name: identityDomainName
                ouPath: !empty(ouPath) ? ouPath : null
                user: domainJoinUserName
                restart: 'true'
                options: '3'
            }
        }
        // Azure AD (AAD) Join.
        extensionAadJoinConfig: {
            enabled: (identityServiceProvider == 'AAD') ? true: false
        }
        tags: tags
    }
    dependsOn: [
    ]
}

// // Introduce wait for management VM to be ready.
// module managementVmWait '../../../../../carml/1.3.0/Microsoft.Resources/deploymentScripts/deploy.bicep' = {
//     scope: resourceGroup('${workloadSubsId}', '${serviceObjectsRgName}')
//     name: 'MGMT-VM-Wait-${time}'
//     params: {
//         name: 'MGMT-VM-Wait-${time}'
//         location: location
//         azPowerShellVersion: '8.3.0'
//         cleanupPreference: 'Always'
//         timeout: 'PT10M'
//         retentionInterval: 'PT1H'
//         scriptContent: '''
//         Write-Host "Start"
//         Get-Date
//         Start-Sleep -Seconds 120
//         Write-Host "Stop"
//         Get-Date
//         '''
//     }
//     dependsOn: [
//         managementVm
//     ]
// } 

// =========== //
//   Outputs   //
// =========== //
