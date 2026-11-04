@description('location')
param location string = resourceGroup().location

@description('StorageAccount Name')
param storageName string

@description('Container Name')
param containerName string = 'data'

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-08-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties:{
    accessTier:'Hot'
    allowBlobPublicAccess:false
    allowSharedKeyAccess:false
    publicNetworkAccess:'Disabled'
    supportsHttpsTrafficOnly:true
    minimumTlsVersion:'TLS1_2'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2025-08-01' = {
  parent: storageAccount
  name: 'default'
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-08-01' = {
  parent: blobService
  name: containerName
  properties: {
    publicAccess: 'None'
  }
}

//StorageAccountId
output storageID string = storageAccount.id
