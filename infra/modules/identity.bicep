@description('ManagedIdentity ID')
param vMManagedID string


@description('Vault Name')
param kvName string

@description('StorageAccount Name')
param storageName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-08-01' existing = {
  name: storageName
}

var blobRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
)

var kvRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4633458b-17de-408a-b874-0445c86b69e6'
)

resource roleAssignments_Blob 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, vMManagedID, blobRoleId)
  scope: storageAccount
  properties: {
    principalId: vMManagedID
    roleDefinitionId: blobRoleId
    principalType: 'ServicePrincipal'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2026-02-01' existing = {
  name: kvName
}


resource roleAssignments_kVaultt 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, vMManagedID, kvRoleId)
  scope: keyVault
  properties: {
    principalId: vMManagedID
    roleDefinitionId: kvRoleId
    principalType: 'ServicePrincipal'
  }
}
