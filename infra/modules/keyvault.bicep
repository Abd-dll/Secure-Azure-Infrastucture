@description('location')
param location string = resourceGroup().location


@description('Key vault name')
param kvName string

@description('secrent Name')
param secretName string = 'secretTest'

@secure()
param Secret string


resource kVault 'Microsoft.KeyVault/vaults@2026-02-01' = {
  location: location
  name: kvName
  properties: {
    sku: {
      name: 'standard'
      family: 'A'
    }

    tenantId: tenant().tenantId

    enableRbacAuthorization: true
    accessPolicies: []

    publicNetworkAccess: 'Disabled'

    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
    }

    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2026-02-01' = {
  parent:kVault
  name: secretName
  properties:{
    value:Secret
  }
}

//kVault ID
output kVaultID string = kVault.id


