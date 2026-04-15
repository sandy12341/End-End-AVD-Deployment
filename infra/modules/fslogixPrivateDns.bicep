// ─────────────────────────────────────────────────────────────────────────────
// FSLogix Private Endpoint + Private DNS
//
// Deploys:
//   1. Private endpoint for the FSLogix storage account (file sub-resource)
//      placed in the private endpoint subnet.
//   2. Private DNS zone: privatelink.file.core.windows.net
//   3. VNet link — links the DNS zone to the spoke VNet so session hosts
//      resolve the storage account FQDN to its private IP automatically.
//   4. DNS zone group on the private endpoint — auto-registers the A record
//      in the zone when the endpoint is provisioned.
//
// Scope: Greenfield and isolated Brownfield (CreateNew DNS mode).
// Enterprise hub-spoke DNS: set privateDnsZoneMode = 'Skip' and register
// the A record in your central zone manually or via policy.
// ─────────────────────────────────────────────────────────────────────────────

@description('Azure region')
param location string

@description('Resource ID of the FSLogix storage account')
param storageAccountId string

@description('Resource ID of the private endpoint subnet (snet-avd-privateendpoints)')
param privateEndpointSubnetId string

@description('Resource ID of the spoke VNet — used to link the private DNS zone')
param vnetId string

@description('DNS zone management mode. CreateNew creates and links the zone. Skip deploys the PE only.')
@allowed(['CreateNew', 'Skip'])
param privateDnsZoneMode string = 'CreateNew'

@description('Tags for all resources')
param tags object = {}

var storageAccountName = last(split(storageAccountId, '/'))
var privateEndpointName = 'pe-${storageAccountName}-file'
// Use environment() to stay compatible with sovereign clouds (Azure Government, China, etc.)
var privateDnsZoneName = 'privatelink.file.${environment().suffixes.storage}'

// ── 1. Private Endpoint ───────────────────────────────────────────────────────

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: privateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: storageAccountId
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }
}

// ── 2. Private DNS Zone ───────────────────────────────────────────────────────

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (privateDnsZoneMode == 'CreateNew') {
  name: privateDnsZoneName
  location: 'global'
  tags: tags
}

// ── 3. VNet Link ─────────────────────────────────────────────────────────────
// Links the DNS zone to the spoke VNet so all resources in the VNet
// resolve privatelink.file.core.windows.net via Azure Private DNS.

resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (privateDnsZoneMode == 'CreateNew') {
  parent: privateDnsZone
  name: 'link-${last(split(vnetId, '/'))}'
  location: 'global'
  tags: tags
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

// ── 4. DNS Zone Group ─────────────────────────────────────────────────────────
// Attaches the DNS zone to the private endpoint.
// Azure automatically creates/removes the A record in the zone
// when the endpoint is provisioned or deleted.

resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = if (privateDnsZoneMode == 'CreateNew') {
  parent: privateEndpoint
  name: 'fslogix-dns-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-file-core-windows-net'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

output privateEndpointId string = privateEndpoint.id
output privateEndpointName string = privateEndpoint.name
// Private IP is assigned by Azure after provisioning — not directly available
// as a Bicep compile-time value. Retrieve post-deployment via:
//   az network private-endpoint show -n <name> -g <rg> --query 'customDnsConfigs[0].ipAddresses[0]'
