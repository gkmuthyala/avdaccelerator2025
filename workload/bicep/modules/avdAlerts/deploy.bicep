
metadata name = 'AVD AMBA alerts'
metadata description = 'This module deploys avd amba alerts'
metadata owner = 'Azure/avdaccelerator'

targetScope = 'subscription'

// ========== //
// Parameters //
// ========== //
@sys.description('Location where to deploy AVD management plane.')
param location string

@sys.description('AVD Resource Group Name for monitoring resources.')
param monitoringRgName string

@sys.description('AVD Resource Group Name for compute resources.')
param computeObjectsRgName string

@description('Location of needed scripts to deploy solution.')
param artifactsLocation string = 'https://raw.githubusercontent.com/Azure/azure-monitor-baseline-alerts/main/patterns/avd/scripts/'

@description('SaS token if needed for script location.')
@secure()
param artifactsLocationSasToken string = ''

@description('Telemetry Opt-Out') // Change this to true to opt out of Microsoft Telemetry
param enableTelemetry bool = false

@sys.description('The name of the resource group to deploy. (Default: AVD1)')
param alertNamePrefix string = 'AVD'

@description('Determine if you would like to set all deployed alerts to auto-resolve.')
param autoResolveAlert bool = true

@description('The Distribution Group that will receive email alerts for AVD.')
param distributionGroup string

@description('First car of deployment type')
param deploymentEnvironment string

@description('the id of the log analytics workspace')
param avdAlaWorkspaceId string

@description('resource ID of the host pool')
param hostPoolResourceID string

@sys.description('Tags to be applied to resources')
param tags object

@sys.description('Do not modify, used to set unique value for resource deployment.')
param time string = utcNow()

var rgResourceId = resourceId('Microsoft.Resources/resourceGroups', computeObjectsRgName)

@description('Array that has the host pool and resource group IDs')
var hostPoolInfo = [
  {
      colHostPoolName: hostPoolResourceID
      colVMResGroup: rgResourceId
      
  }
]

var HostPoolResourceIDArray = [hostPoolResourceID]


// Calling AMBA for AVD alerts
module alerting '../../../../azure-monitor-baseline-alerts/patterns/avd/templates/deploy.bicep' = { 
  name: 'AVD-Alerting-${time}'
  params: {
    _ArtifactsLocation: artifactsLocation
    _ArtifactsLocationSasToken: artifactsLocationSasToken
    optoutTelemetry: enableTelemetry ? false : true
    AlertNamePrefix: alertNamePrefix
    DistributionGroup: distributionGroup
    LogAnalyticsWorkspaceResourceId: avdAlaWorkspaceId
    ResourceGroupName: monitoringRgName
    ResourceGroupStatus: 'Existing'
    AllResourcesSameRG: false
    AutoResolveAlert: autoResolveAlert
    Environment: deploymentEnvironment
    Location: location
    AVDResourceGroupId: rgResourceId
    HostPools: HostPoolResourceIDArray
    HostPoolInfo: hostPoolInfo
    Tags: tags
  } 
}

