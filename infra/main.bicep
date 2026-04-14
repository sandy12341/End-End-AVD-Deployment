// ─────────────────────────────────────────────────────────────────────
// Azure Virtual Desktop + Landing Zone — Main Deployment
// Deploys: VNet, Host Pool, Workspace, Session Hosts (Entra ID join),
//          FSLogix storage, and Log Analytics monitoring
// ─────────────────────────────────────────────────────────────────────

targetScope = 'resourceGroup'

// ── Parameters ──

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Deployment prefix used for naming')
@maxLength(6)
param deploymentPrefix string = 'avd1'

@description('Environment name')
@allowed(['dev', 'test', 'prod'])
param environment string = 'dev'

@description('Number of session host VMs')
@minValue(1)
@maxValue(10)
param sessionHostCount int = 1

@description('VM size for session hosts')
param vmSize string = 'Standard_D2ads_v5'

@description('Image source for the session host OS image.')
@allowed(['Marketplace', 'AzureComputeGallery'])
param imageSource string = 'Marketplace'

@description('Marketplace image publisher for session hosts when imageSource is Marketplace.')
param marketplaceImagePublisher string = 'microsoftwindowsdesktop'

@description('Marketplace image offer for session hosts when imageSource is Marketplace.')
param marketplaceImageOffer string = 'windows-11'

@description('Marketplace image SKU for session hosts when imageSource is Marketplace.')
param marketplaceImageSku string = 'win11-24h2-avd'

@description('Marketplace image version for session hosts when imageSource is Marketplace.')
param marketplaceImageVersion string = 'latest'

@description('Azure Compute Gallery subscription ID for session hosts when imageSource is AzureComputeGallery.')
param galleryImageSubscriptionId string = subscription().subscriptionId

@description('Azure Compute Gallery resource group name for session hosts when imageSource is AzureComputeGallery.')
param galleryImageResourceGroupName string = ''

@description('Azure Compute Gallery name for session hosts when imageSource is AzureComputeGallery.')
param galleryName string = ''

@description('Azure Compute Gallery image definition name for session hosts when imageSource is AzureComputeGallery.')
param galleryImageDefinitionName string = ''

@description('Azure Compute Gallery image version for session hosts when imageSource is AzureComputeGallery.')
param galleryImageVersion string = 'latest'

@description('Preferred AVD delivery mode. Leave empty to preserve the legacy desktop-only behavior driven by hostPoolType.')
@allowed(['', 'PersonalDesktop', 'PooledRemoteApp', 'PooledDesktopAndRemoteApp'])
param avdMode string = ''

@description('Host pool type')
@allowed(['Personal', 'Pooled'])
param hostPoolType string = 'Pooled'

@description('Authentication type for session host sign-in and join flow')
@allowed(['EntraID', 'HybridJoin'])
param authenticationType string = 'EntraID'

@description('Active Directory domain FQDN (required for HybridJoin)')
param domainFqdn string = ''

@description('Domain join service account in DOMAIN\\username or username@domain format (required for HybridJoin)')
param domainJoinUsername string = ''

@description('Domain join service account password (required for HybridJoin)')
@secure()
param domainJoinPassword string = ''

@description('Optional OU path where computer accounts should be created for HybridJoin (for example OU=AVD,DC=contoso,DC=com)')
param domainJoinOuPath string = ''

@description('Local admin username for session hosts')
param adminUsername string

@description('Local admin password for session hosts')
@secure()
param adminPassword string

@description('Deploy FSLogix profile storage')
param deployFSLogix bool = true

@description('Storage account name for FSLogix profiles (must be globally unique, 3-24 chars, lowercase/numbers only)')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('Deploy monitoring (Log Analytics)')
param deployMonitoring bool = true

@description('Choose whether to use an existing VNet or create a new spoke VNet for the deployment.')
@allowed(['UseExistingVnet', 'CreateNewVnet'])
param networkMode string = 'UseExistingVnet'

@description('Name of the existing virtual network to use')
param existingVnetName string = ''

@description('Resource group name that contains the existing virtual network')
param existingVnetResourceGroupName string = resourceGroup().name

@description('Name of the existing subnet for session hosts')
param sessionHostSubnetName string = ''

@description('Name of the existing subnet reserved for private endpoints')
param privateEndpointSubnetName string = ''

@description('Name of the new spoke virtual network to create when networkMode is CreateNewVnet.')
param newVnetName string = ''

@description('Address prefix for the new spoke virtual network when networkMode is CreateNewVnet.')
param newVnetAddressPrefix string = '10.20.0.0/16'

@description('Name of the session host subnet to create when networkMode is CreateNewVnet.')
param newSessionHostSubnetName string = 'snet-avd-sessionhosts'

@description('Address prefix for the session host subnet when networkMode is CreateNewVnet.')
param newSessionHostSubnetPrefix string = '10.20.1.0/24'

@description('Name of the private endpoint subnet to create when networkMode is CreateNewVnet.')
param newPrivateEndpointSubnetName string = 'snet-avd-privateendpoints'

@description('Address prefix for the private endpoint subnet when networkMode is CreateNewVnet.')
param newPrivateEndpointSubnetPrefix string = '10.20.2.0/24'

@description('Resource ID of the existing hub virtual network to peer with when networkMode is CreateNewVnet.')
param hubVnetResourceId string = ''

@description('Host pool name')
param hostPoolName string

@description('Comma or newline separated Entra Object IDs to grant AVD access. Leave empty to skip role assignments.')
param avdUserObjectIds string = ''

@description('Typed access assignments for the desktop application group. Each item must include principalId and principalType.')
param desktopAccessAssignments array = []

@description('Typed access assignments for the RemoteApp application group. Each item must include principalId and principalType.')
param remoteAppAccessAssignments array = []

@description('RemoteApp definitions used when avdMode publishes RemoteApps. Each item must include name and filePath and can optionally include friendlyName, description, commandLineSetting, and commandLineArguments.')
param remoteApps array = []

@description('Per-deployment seed used to keep session host computer names unique across redeployments in the same resource group.')
param deploymentInstanceSeed string = utcNow('u')

// ── Variables ──

var namingPrefix = '${deploymentPrefix}-${environment}'
var effectiveAvdMode = empty(avdMode) ? (hostPoolType == 'Personal' ? 'PersonalDesktop' : 'PooledDesktop') : avdMode
var effectiveHostPoolType = effectiveAvdMode == 'PersonalDesktop' ? 'Personal' : 'Pooled'
var publishDesktop = effectiveAvdMode == 'PersonalDesktop' || effectiveAvdMode == 'PooledDesktop' || effectiveAvdMode == 'PooledDesktopAndRemoteApp'
var publishRemoteApps = effectiveAvdMode == 'PooledRemoteApp' || effectiveAvdMode == 'PooledDesktopAndRemoteApp'
var effectiveExistingVnetResourceGroupName = empty(existingVnetResourceGroupName) ? resourceGroup().name : existingVnetResourceGroupName
var desktopAppGroupName = 'dag-avd-${namingPrefix}'
var remoteAppGroupName = 'rag-avd-${namingPrefix}'
var normalizedAvdUserObjectIds = [for oid in split(replace(replace(avdUserObjectIds, '\r\n', ','), '\n', ','), ','): trim(oid)]
var legacyAccessAssignments = [for oid in normalizedAvdUserObjectIds: {
  principalId: oid
  principalType: 'User'
}]
var desktopEffectiveAssignments = union(desktopAccessAssignments, publishDesktop ? legacyAccessAssignments : [])
var remoteAppEffectiveAssignments = union(remoteAppAccessAssignments, publishRemoteApps ? legacyAccessAssignments : [])
var vmLoginEffectiveAssignments = union(desktopEffectiveAssignments, remoteAppEffectiveAssignments)
var sessionHostImageReference = imageSource == 'AzureComputeGallery'
  ? {
      id: resourceId(galleryImageSubscriptionId, galleryImageResourceGroupName, 'Microsoft.Compute/galleries/images/versions', galleryName, galleryImageDefinitionName, galleryImageVersion)
    }
  : {
      publisher: marketplaceImagePublisher
      offer: marketplaceImageOffer
      sku: marketplaceImageSku
      version: marketplaceImageVersion
    }
var tags = {
  Environment: environment
  Project: 'AVD-Landing-Zone'
  DeployedBy: 'Bicep'
}

module network 'modules/network.bicep' = if (networkMode == 'CreateNewVnet') {
  name: 'deploy-network'
  params: {
    location: location
    vnetName: newVnetName
    vnetAddressPrefix: newVnetAddressPrefix
    sessionHostSubnetName: newSessionHostSubnetName
    sessionHostSubnetPrefix: newSessionHostSubnetPrefix
    privateEndpointSubnetName: newPrivateEndpointSubnetName
    privateEndpointSubnetPrefix: newPrivateEndpointSubnetPrefix
    hubVnetResourceId: hubVnetResourceId
    tags: tags
  }
}

resource existingVnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = if (networkMode == 'UseExistingVnet') {
  name: existingVnetName
  scope: resourceGroup(effectiveExistingVnetResourceGroupName)
}

resource existingSessionHostSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = if (networkMode == 'UseExistingVnet') {
  parent: existingVnet
  name: sessionHostSubnetName
}

resource existingPrivateEndpointSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = if (networkMode == 'UseExistingVnet') {
  parent: existingVnet
  name: privateEndpointSubnetName
}

var vnetId = networkMode == 'CreateNewVnet' ? network!.outputs.vnetId : existingVnet.id
var sessionHostSubnetId = networkMode == 'CreateNewVnet' ? network!.outputs.sessionHostSubnetId : existingSessionHostSubnet.id
var privateEndpointSubnetId = networkMode == 'CreateNewVnet' ? network!.outputs.privateEndpointSubnetId : existingPrivateEndpointSubnet.id

// ── Host Pool + Workspace ──

module hostPool 'modules/hostpool.bicep' = {
  name: 'deploy-hostpool'
  params: {
    location: location
    hostPoolName: hostPoolName
    hostPoolType: effectiveHostPoolType
    workspaceName: 'ws-avd-${namingPrefix}'
    desktopAppGroupName: desktopAppGroupName
    remoteAppGroupName: remoteAppGroupName
    publishDesktop: publishDesktop
    publishRemoteApps: publishRemoteApps
    authenticationType: authenticationType
    remoteApps: remoteApps
    tags: tags
  }
}

// ── Session Hosts (auto-registered via host pool token) ──

module sessionHosts 'modules/sessionhosts.bicep' = {
  name: 'deploy-sessionhosts'
  params: {
    location: location
    sessionHostCount: sessionHostCount
    vmSize: vmSize
    imageReference: sessionHostImageReference
    subnetId: sessionHostSubnetId
    hostPoolName: hostPool.outputs.hostPoolName
    adminUsername: adminUsername
    adminPassword: adminPassword
    authenticationType: authenticationType
    domainFqdn: domainFqdn
    domainJoinUsername: domainJoinUsername
    domainJoinPassword: domainJoinPassword
    domainJoinOuPath: domainJoinOuPath
    deploymentInstanceSeed: deploymentInstanceSeed
    vmNamePrefix: 'vm-avd-${namingPrefix}'
    tags: tags
  }
}

// ── FSLogix Storage ──

module fslogix 'modules/fslogix.bicep' = if (deployFSLogix) {
  name: 'deploy-fslogix'
  params: {
    location: location
    storageAccountName: storageAccountName
    sessionHostSubnetId: sessionHostSubnetId
    tags: tags
  }
}

// ── Monitoring ──

module monitoring 'modules/monitoring.bicep' = if (deployMonitoring) {
  name: 'deploy-monitoring'
  params: {
    location: location
    workspaceName: 'log-avd-${namingPrefix}'
    tags: tags
  }
}

// ── AVD User Role Assignments (native Bicep) ──

resource desktopAppGroup 'Microsoft.DesktopVirtualization/applicationGroups@2024-04-08-preview' existing = if (publishDesktop) {
  name: desktopAppGroupName
}

resource remoteAppGroup 'Microsoft.DesktopVirtualization/applicationGroups@2024-04-08-preview' existing = if (publishRemoteApps) {
  name: remoteAppGroupName
}

// Desktop Virtualization User on the Desktop App Group
resource desktopAvdUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for assignment in desktopEffectiveAssignments: if (publishDesktop && !empty(string(assignment.principalId))) {
  name: guid(resourceGroup().id, desktopAppGroupName, string(assignment.principalType), string(assignment.principalId), '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63')
  scope: desktopAppGroup
  dependsOn: [
    hostPool
  ]
  properties: {
    principalId: string(assignment.principalId)
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63')
    principalType: string(assignment.principalType)
  }
}]

// Desktop Virtualization User on the RemoteApp Group
resource remoteAppAvdUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for assignment in remoteAppEffectiveAssignments: if (publishRemoteApps && !empty(string(assignment.principalId))) {
  name: guid(resourceGroup().id, remoteAppGroupName, string(assignment.principalType), string(assignment.principalId), '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63')
  scope: remoteAppGroup
  dependsOn: [
    hostPool
  ]
  properties: {
    principalId: string(assignment.principalId)
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63')
    principalType: string(assignment.principalType)
  }
}]

// Virtual Machine User Login on the Resource Group
resource vmLoginRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for assignment in vmLoginEffectiveAssignments: if (authenticationType == 'EntraID' && !empty(string(assignment.principalId)) && string(assignment.principalType) != 'ServicePrincipal') {
  name: guid(resourceGroup().id, string(assignment.principalType), string(assignment.principalId), 'fb879df8-f326-4884-b1cf-06f3ad86be52')
  properties: {
    principalId: string(assignment.principalId)
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'fb879df8-f326-4884-b1cf-06f3ad86be52')
    principalType: string(assignment.principalType)
  }
}]

// ── Outputs ──

output hostPoolName string = hostPool.outputs.hostPoolName
output workspaceId string = hostPool.outputs.workspaceId
output desktopAppGroupId string = hostPool.outputs.desktopAppGroupId
output remoteAppGroupId string = hostPool.outputs.remoteAppGroupId
output publishedAppGroupIds array = hostPool.outputs.publishedAppGroupIds
output vnetId string = vnetId
output privateEndpointSubnetId string = privateEndpointSubnetId
output sessionHostVmNames array = sessionHosts.outputs.vmNames
output fslogixStorageAccount string = deployFSLogix ? fslogix!.outputs.storageAccountName : 'N/A'
output logAnalyticsWorkspace string = deployMonitoring ? monitoring!.outputs.workspaceName : 'N/A'
output effectiveAvdMode string = effectiveAvdMode
output avdRolesAssigned bool = length(desktopEffectiveAssignments) > 0 || length(remoteAppEffectiveAssignments) > 0
