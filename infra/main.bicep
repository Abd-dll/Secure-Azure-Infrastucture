targetScope = 'resourceGroup'

@description('kVault ID')
var kVaultID = keyvault.outputs.kVaultID

@description('storageID')
var storageID = storage.outputs.storageID

@description('vNet Object Reference')
var vNet = network.outputs.vNet

@description('Ssh Key')
param sshKey string

@description('workloadSubnetId')
var workloadSubnetId = network.outputs.workloadSubnetId

@description('privateEndpointSubnetId')
var privateSubnetId = network.outputs.privateEndpointSubnetId

@description('vmSize')
param vmSize string

@description('Storage Accout Name')
param storageName string

@description('Key vault name')
param kvName string

@secure()
param Secret string

@description('Managed Identity ID')
var vm_Identity = compute.outputs.vmPrincipalId

module network './modules/network.bicep' = {
  name:'Network_Deployment'
}

module compute './modules/compute.bicep' = {
  name:'Compute_Deployment'
  params: {
    sshKey: sshKey
    workloadSubnetId: workloadSubnetId
    vmSize:vmSize
  }

}

module storage './modules/storage.bicep' ={
  name:'storage_Deployment'
  params:{
    storageName:storageName
  }
}

module keyvault './modules/keyvault.bicep' ={
  name:'keyvault_Deployment'
  params:{
    Secret: Secret
    kvName: kvName
  }
}

module privateEndpoint './modules/private-endpoints.bicep'={
  name:'private_endpoint_Deploymeny'
  params: {
    keyVaultId: kVaultID
    privateEndpointSubnetId: privateSubnetId
    storageAccountId: storageID
    vNet: vNet
  }
}

module roleAssignments './modules/identity.bicep' = {
  name:'Identity_Deployment'
  params: {
    kvName: kvName
    storageName: storageName
    vMManagedID: vm_Identity
  }
}

module governance './modules/governance.bicep' = {
  name: 'Governance_Deployment'
}

module monitoring './modules/monitoring.bicep' = {
  name:'Monitoring_Deployment'
  params: {
    kvName: kvName
    storageName: storageName
  }
}
