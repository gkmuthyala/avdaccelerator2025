targetScope = 'resourceGroup'

// ========== //
// Parameters //
// ========== //

@sys.description('Location where to deploy compute services.')
param location string

@sys.description('AVD workload subscription ID, multiple subscriptions scenario.')
param subscriptionId string

@sys.description('AVD Resource Group Name for the service objects.')
param computeObjectsRgName string

@sys.description('Do not modify, used to set unique value for resource deployment.')
param time string = utcNow()

// =========== //
// Variable declaration //
// =========== //
// Policy Set/Initiative Definition Parameter Variables

// This variable contains a number of objects that load in the custom Azure Policy Defintions that are provided as part of the ESLZ/ALZ reference implementation. 
var varCustomPolicyDefinitions = [
    {
      deploymentName: 'AMD-Policy'
      libDefinition: json(loadTextContent('../../../policies/gpu/policyDefinitions/policy-definition-es-deploy-amd-gpu-driver.json'))
    }
    {
      deploymentName: 'Nvidia-Policy'
      libDefinition: json(loadTextContent('../../../policies/gpu/policyDefinitions/policy-definition-es-deploy-nvidia-gpu-driver.json'))
    }
]
// =========== //
// Deployments //
// =========== //
// call on the keyvault.

// Policy Assignment storage.
module defenderPolicyAssignmentsStorage '../../../../avm/1.0.0/ptn/authorization/policy-assignment/modules/resource-group.bicep' = [for (customPolicyDefinition, i) in varCustomPolicyDefinitions: {
    scope: resourceGroup('${subscriptionId}', '${computeObjectsRgName}')
    name: 'Policy-Assign-${customPolicyDefinition.deploymentName}-${time}' 
    params: {
        name: customPolicyDefinition.libDefinition.name
        displayName: customPolicyDefinition.libDefinition.properties.displayName
        description: customPolicyDefinition.libDefinition.properties.description
        identity: 'SystemAssigned'
        location: location
        policyDefinitionId: gpuPolicyDefinitions[i].outputs.resourceId
    }
}]

// Policy Assignment service objects.
module defenderPolicyAssignmentsServiceObjects '../../../../avm/1.0.0/ptn/authorization/policy-assignment/modules/resource-group.bicep' = [for (customPolicyDefinition, i) in varCustomPolicyDefinitions: {
  scope: resourceGroup('${subscriptionId}', '${computeObjectsRgName}')
  name: 'Policy-Assign-${customPolicyDefinition.deploymentName}-${time}' 
  params: {
      name: customPolicyDefinition.libDefinition.name
      displayName: customPolicyDefinition.libDefinition.properties.displayName
      description: customPolicyDefinition.libDefinition.properties.description
      identity: 'SystemAssigned'
      location: location
      policyDefinitionId: gpuPolicyDefinitions[i].outputs.resourceId
  }
}]

// Policy Assignment pool compute.
module defenderPolicyAssignmentsCompute '../../../../avm/1.0.0/ptn/authorization/policy-assignment/modules/resource-group.bicep' = [for (customPolicyDefinition, i) in varCustomPolicyDefinitions: {
  scope: resourceGroup('${subscriptionId}', '${computeObjectsRgName}')
  name: 'Policy-Assign-${customPolicyDefinition.deploymentName}-${time}' 
  params: {
      name: customPolicyDefinition.libDefinition.name
      displayName: customPolicyDefinition.libDefinition.properties.displayName
      description: customPolicyDefinition.libDefinition.properties.description
      identity: 'SystemAssigned'
      location: location
      policyDefinitionId: gpuPolicyDefinitions[i].outputs.resourceId
  }
}]

// // Policy Remediation Task for GPU extensions.
// module policySetRemediationCompute '../../../../avm/1.0.0/ptn/policy-insights/remediation/modules/resource-group.bicep' = [for (customPolicyDefinition, i) in varCustomPolicyDefinitions : {
//     scope: resourceGroup('${subscriptionId}', '${computeObjectsRgName}')
//     name: 'remediate-${customPolicyDefinition.deploymentName}-${i}'
//     params: {
//       name: '${customPolicyDefinition.deploymentName}-${i}'
//       policyAssignmentId: gpuPolicyAssignmentsCompute[i].outputs.resourceId
//   }
// }]
// =========== //
// Outputs //
// =========== //

