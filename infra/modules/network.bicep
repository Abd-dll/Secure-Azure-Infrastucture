@description('vNet Name')
param vnetName string = 'vnet-secureinfra-dev'


@description('Subnets name')
param subnetNames array = [
  'snet-workload','snet-private-endpoints'
]

param nsgName string = 'nsg-workload-dev'


@description('location')
param location string = resourceGroup().location



resource vNet 'Microsoft.Network/virtualNetworks@2025-09-01' = {
  name:vnetName
  location:location
  properties:{
    addressSpace:{
      addressPrefixes:[
        '10.40.0.0/16'
      ]
    }
  }

}

@batchSize(1)
resource subnets 'Microsoft.Network/virtualNetworks/subnets@2025-09-01' = [
  for (subnetName, i) in subnetNames: {
    parent: vNet
    name : subnetName
    properties: {
      addressPrefix: i == 0 ? '10.40.1.0/24' : '10.40.2.0/27'
      networkSecurityGroup: i == 0 ? {
        id: nsg.id
      } : null
    }
  }
]

resource nsg 'Microsoft.Network/networkSecurityGroups@2025-09-01' = {
  name:nsgName
  location:location
  properties:{
    securityRules:[
      {
        name:'default-deny-in'
        properties:{
          access: 'Deny'
          direction: 'Inbound'
          priority: 1000
          protocol: '*'
          sourceAddressPrefix:'*'
          destinationAddressPrefix:'*'
          sourcePortRange:'*'
          destinationPortRange:'*'
        }
      }
      {
        name: 'Allow-SSH-BastionDeveloper'
        properties: {
          priority: 700
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '10.40.1.0/24'
        }
      }
      {
        name: 'default-deny-out'
        properties:{
          access: 'Deny'
          direction: 'Outbound'
          priority: 900
          protocol: '*'
          sourceAddressPrefix:'*'
          destinationAddressPrefix:'*'
          sourcePortRange:'*'
          destinationPortRange:'*'
        }
      }
      {
        name:'allow_workload_privateendpoint'
        properties:{
          access: 'Allow'
          direction: 'Outbound'
          priority: 800
          protocol: 'Tcp'
          sourcePortRange:'*'
          destinationPortRange:'443'
          sourceAddressPrefix:'10.40.1.0/24'
          destinationAddressPrefix:'10.40.2.0/27'
        }
      }
    ]
  }
}

// VNet Resource ID
output vnetId string = vNet.id

// NSG Resource ID
output nsgId string = nsg.id

// Subnet Resource IDs
output workloadSubnetId string = subnets[0].id
output privateEndpointSubnetId string = subnets[1].id

//VNet Object ID
output vNet object = vNet
