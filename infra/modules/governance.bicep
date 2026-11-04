targetScope = 'resourceGroup'

@description('Built-in policy definition ID')
param policyDefinitionId string = '/providers/Microsoft.Authorization/policyDefinitions/6c112d4e-5bc7-47ae-a041-ea2d9dccd749'

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2025-03-01' = {
  name: 'deny-public-ip'
  properties: {
    displayName: 'Deny Public IP'
    policyDefinitionId: policyDefinitionId
    parameters: {
      listOfResourceTypesNotAllowed: {
        value: [
          'Microsoft.Network/publicIPAddresses'
        ]
      }
    }
    enforcementMode: 'Default'
  }
}
