
@description('Location')
param location string = resourceGroup().location

@description('Vault Name')
param kvName string

@description('StorageAccount Name')
param storageName string


resource logAnWorkspace 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: 'law-secureinfra-dev'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}


resource kVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: kvName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageName
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' existing = {
  parent: storageAccount
  name: 'default'
}


// Key Vault -> AZKVAuditLogs
resource kvDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  dependsOn:[
    logAnWorkspace
  ]
  name: 'diag-kv-secureinfra'
  scope: kVault
  properties: {
    workspaceId: logAnWorkspace.id
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
    ]
  }
}

// Blob Storage -> StorageBlobLogs
resource blobDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  dependsOn:[
    logAnWorkspace
  ]
  name: 'diag-blob-secureinfra'
  scope: blobService
  properties: {
    workspaceId: logAnWorkspace.id
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
  }
}



resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'email_Notif'
  location: 'global'
  properties: {
    enabled: true
    groupShortName: 'admin'
    emailReceivers: [
      {
        name: 'admin'
        emailAddress: 'traoreman635@gmail.com'
        useCommonAlertSchema: true
      }
    ]
  }
}



resource kvAlertRule 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  dependsOn: [
    logAnWorkspace
    kvDiagnostics
  ]
  name: 'Non_Authorized_Key_Vault_Access'
  location: location
  properties: {
    displayName: 'Unauthorized Key Vault Access'
    description: 'Detects HTTP 403 responses on Key Vault.'
    enabled: true
    severity: 2
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    scopes: [
      logAnWorkspace.id
    ]
    criteria: {
      allOf: [
        {
          query: format('''
            AZKVAuditLogs
            | where HttpStatusCode == 403
            | where _ResourceId =~ '{0}'
          ''', kVault.id)
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroup.id
      ]
    }
  }
}


resource blobAlertRule 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: 'Non_Authorized_Blob_Access'
  location: location
  properties: {
    displayName: 'Unauthorized Blob Storage Access'
    description: 'Detects HTTP 401 and 403 responses on Blob Storage.'
    enabled: true
    severity: 2
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    scopes: [
      logAnWorkspace.id
    ]
    criteria: {
      allOf: [
        {
          query: format('''
            StorageBlobLogs
            | where StatusCode in ('401', '403')
            | where _ResourceId =~ '{0}'
          ''', blobService.id)
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroup.id
      ]
    }
  }
    dependsOn: [
    logAnWorkspace
    blobDiagnostics
  ]
}
