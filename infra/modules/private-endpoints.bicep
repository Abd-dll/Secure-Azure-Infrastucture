@description('Deployment location')
param location string = resourceGroup().location

@description('Private Endpoint names')
param pName string[] = [
  'kvault_endp'
  'storage_endp'
]

@description('vNet resource reference object')
param vNet object

@description('Subnet resource ID')
param privateEndpointSubnetId string

@description('Key Vault resource ID')
param keyVaultId string

@description('Storage Account resource ID')
param storageAccountId string

var targetResources = [
  {
    id: keyVaultId
    groupId: 'vault'
    memberName: 'default'
    ip: '10.40.2.30'
  }
  {
    id: storageAccountId
    groupId: 'blob'
    memberName: 'blob'
    ip: '10.40.2.20'
  }
]

resource privateEndpoints 'Microsoft.Network/privateEndpoints@2025-09-01' = [
  for (pvName, i) in pName: {
    name: pvName
    location: location
    properties: {
      subnet: {
        id: privateEndpointSubnetId
      }
      ipConfigurations: [
        {
          name: 'config${i}'
          properties: {
            groupId: targetResources[i].groupId
            memberName: targetResources[i].memberName
            privateIPAddress: targetResources[i].ip
          }
        }
      ]
      privateLinkServiceConnections: [
        {
          name: 'connection${i}'
          properties: {
            privateLinkServiceId: targetResources[i].id
            groupIds: [
              targetResources[i].groupId
            ]
          }
        }
      ]
    }
  }
]


resource storageDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
}

resource keyVaultDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
}


resource storageDnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  name: 'LinktoSnet'
  parent: storageDnsZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: vNet
  }
}

resource kVaultDnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  name: 'LinktoSnet'
  parent: keyVaultDnsZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: vNet
  }
}


resource storageZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-09-01' = {
  name: 'storageDnsGroup'
  parent: privateEndpoints[1]
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'storageDnsGroup'
        properties: {
          privateDnsZoneId: storageDnsZone.id
        }
      }
    ]
  }
}

resource kVaultZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-09-01' = {
  name: 'kVaultDnsGroup'
  parent: privateEndpoints[0]
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'kVaultDnsGroup'
        properties: {
          privateDnsZoneId: keyVaultDnsZone.id
        }
      }
    ]
  }
}



output kVaultPrivateEndpoint string = privateEndpoints[0].id
output storagePrivateEndpoint string = privateEndpoints[1].id
