@description('Azure region')
param location string

@description('Storage account name for FSLogix profiles')
param storageAccountName string

@description('File share name')
param fileShareName string = 'fslogix-profiles'

@description('File share quota in GB')
param fileShareQuotaGiB int = 100

@description('Tags for all resources')
param tags object = {}

@description('Session host subnet ID for VNet service endpoint access (used when deployPrivateEndpoint is false)')
param sessionHostSubnetId string = ''

@description('When true, disables public network access on the storage account. A private endpoint must be deployed separately.')
param deployPrivateEndpoint bool = false

// When using a private endpoint, public access is fully disabled and VNet rules are not needed.
// When using a service endpoint, the session host subnet is whitelisted via virtualNetworkRules.
var storageNetworkAcls = deployPrivateEndpoint
  ? {
      defaultAction: 'Deny'
      bypass: 'None'
      virtualNetworkRules: []
    }
  : {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      virtualNetworkRules: !empty(sessionHostSubnetId)
        ? [
            {
              id: sessionHostSubnetId
              action: 'Allow'
            }
          ]
        : []
    }

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    publicNetworkAccess: deployPrivateEndpoint ? 'Disabled' : 'Enabled'
    networkAcls: storageNetworkAcls
  }
}

module storageAccountAuth './fslogixAuth.bicep' = {
  name: 'configure-fslogix-auth'
  params: {
    storageAccountName: storageAccountName
    location: location
    tags: tags
    sessionHostSubnetId: sessionHostSubnetId
    deployPrivateEndpoint: deployPrivateEndpoint
  }
  dependsOn: [fileShare]
}

resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: fileServices
  name: fileShareName
  properties: {
    shareQuota: fileShareQuotaGiB
    enabledProtocols: 'SMB'
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output fileShareName string = fileShare.name
