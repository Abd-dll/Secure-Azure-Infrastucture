
param nicName string = 'snet-workload'
param vmName string = 'vm_workload_dev'

@description('Resource ID du subnet workload')
param workloadSubnetId string

@description('Location')
param location string = resourceGroup().location

@description('ssh pub key')
@minLength(1)
param sshKey string

@description('VM Size')
param vmSize string

@description('AdminName')
param adminUsername string = 'vm_workload_dev'

resource nic 'Microsoft.Network/networkInterfaces@2025-09-01' = {
  name:nicName
  location:location
  properties:{
    ipConfigurations:[
      {
        name:'config1'
        properties:{
          privateIPAllocationMethod:'Dynamic'
          subnet:{
            id:workloadSubnetId
          }
        }
      }
    ]
  }
}

resource vM 'Microsoft.Compute/virtualMachines@2025-04-01' = {
  name: vmName
  location: location
  identity:{
    type: 'SystemAssigned'
  }
  properties:{
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            primary: true
          }
        }
      ]
    }
    hardwareProfile:{
      vmSize:vmSize
    }
    osProfile:{
      computerName:'azure-infra'
      adminUsername : adminUsername
      linuxConfiguration:{
        disablePasswordAuthentication:true
        ssh:{
          publicKeys:[
            {
              path:'/home/${adminUsername}/.ssh/authorized_keys'
              keyData:sshKey
            }
          ]
        }
      }
    }
    storageProfile:{
      osDisk:{
        createOption: 'FromImage'
        managedDisk:{
          storageAccountType:'Standard_LRS'
        }
      }
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
    }
  }
}


// Nic Resource Id
output nic string = nic.id


// VM Resource Id
output vM string = vM.id

// Managed Identity ID
output vmPrincipalId string = vM.identity.principalId

output vmObject object = vM
