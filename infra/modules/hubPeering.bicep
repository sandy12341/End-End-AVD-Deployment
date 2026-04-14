targetScope = 'resourceGroup'

@description('Name of the existing hub virtual network that will receive the reverse peering connection.')
param hubVnetName string

@description('Name of the spoke virtual network created for the deployment.')
param spokeVnetName string

@description('Resource ID of the spoke virtual network created for the deployment.')
param spokeVnetResourceId string

resource hubVnet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: hubVnetName
}

resource hubToSpokePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-01-01' = {
  parent: hubVnet
  name: '${hubVnetName}-to-${spokeVnetName}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spokeVnetResourceId
    }
  }
}
