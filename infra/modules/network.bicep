@description('Azure region for the VNet')
param location string

@description('Name of the VNet')
param vnetName string

@description('VNet address prefix')
param vnetAddressPrefix string = '10.20.0.0/16'

@description('Session hosts subnet name')
param sessionHostSubnetName string = 'snet-avd-sessionhosts'

@description('Session hosts subnet prefix')
param sessionHostSubnetPrefix string = '10.20.1.0/24'

@description('Private endpoints subnet name')
param privateEndpointSubnetName string = 'snet-avd-privateendpoints'

@description('Private endpoints subnet prefix')
param privateEndpointSubnetPrefix string = '10.20.2.0/24'

@description('Optional resource ID of the hub virtual network to peer with the new spoke VNet.')
param hubVnetResourceId string = ''

@description('When true, omits the Microsoft.Storage service endpoint from the session host subnet. Set to true when a private endpoint is used for FSLogix storage.')
param removeStorageServiceEndpoint bool = false

@description('Tags for all resources')
param tags object = {}

var hubVnetSegments = split(hubVnetResourceId, '/')
var hubVnetResourceGroupName = !empty(hubVnetResourceId) ? hubVnetSegments[4] : ''
var hubVnetName = !empty(hubVnetResourceId) ? hubVnetSegments[8] : ''

resource natGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: '${vnetName}-natgw-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource natGateway 'Microsoft.Network/natGateways@2024-01-01' = {
  name: '${vnetName}-natgw'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpAddresses: [
      { id: natGatewayPublicIp.id }
    ]
    idleTimeoutInMinutes: 4
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: sessionHostSubnetName
        properties: {
          addressPrefix: sessionHostSubnetPrefix
          networkSecurityGroup: {
            id: nsgSessionHosts.id
          }
          natGateway: {
            id: natGateway.id
          }
          serviceEndpoints: removeStorageServiceEndpoint ? [] : [
            {
              service: 'Microsoft.Storage'
            }
          ]
        }
      }
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          networkSecurityGroup: {
            id: nsgPrivateEndpoints.id
          }
        }
      }
    ]
  }
}

// 3A: NSG for private endpoint subnet — deny all inbound, allow all outbound
resource nsgPrivateEndpoints 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: 'nsg-avd-privateendpoints'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// 3B: Session host NSG — AllowRDP removed (AVD uses reverse-connect; no inbound RDP required)
// Break-glass access via Azure Serial Console or Run Command.
resource nsgSessionHosts 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: 'nsg-avd-sessionhosts'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-01-01' = if (!empty(hubVnetResourceId)) {
  parent: vnet
  name: '${vnet.name}-to-${hubVnetName}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hubVnetResourceId
    }
  }
}

module hubPeering './hubPeering.bicep' = if (!empty(hubVnetResourceId)) {
  name: '${vnetName}-hub-peering'
  scope: resourceGroup(hubVnetResourceGroupName)
  params: {
    hubVnetName: hubVnetName
    spokeVnetName: vnet.name
    spokeVnetResourceId: vnet.id
  }
}

output vnetId string = vnet.id
output sessionHostSubnetId string = vnet.properties.subnets[0].id
output privateEndpointSubnetId string = vnet.properties.subnets[1].id
