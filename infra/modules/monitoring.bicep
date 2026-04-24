@description('Azure region')
param location string

@description('Log Analytics workspace name')
param workspaceName string

@description('Retention in days')
param retentionDays int = 30

@description('Data Collection Rule name for guest telemetry')
param dataCollectionRuleName string = 'dcr-avd-monitoring'

@description('Tags for all resources')
param tags object = {}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionDays
  }
}

resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: dataCollectionRuleName
  location: location
  tags: tags
  kind: 'Windows'
  properties: {
    dataSources: {
      performanceCounters: [
        {
          name: 'vmInsightsPerfCounters'
          streams: [
            'Microsoft-InsightsMetrics'
            'Microsoft-Perf'
          ]
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
            '\\Processor Information(_Total)\\% Processor Time'
            '\\Memory\\Available MBytes'
            '\\LogicalDisk(_Total)\\% Free Space'
            '\\LogicalDisk(_Total)\\Avg. Disk sec/Transfer'
            '\\LogicalDisk(_Total)\\Disk Transfers/sec'
            '\\Network Interface(*)\\Bytes Total/sec'
          ]
        }
      ]
      windowsEventLogs: [
        {
          name: 'vmInsightsWindowsEvents'
          streams: [
            'Microsoft-WindowsEvent'
          ]
          xPathQueries: [
            'Application!*[System[(Level=1 or Level=2 or Level=3)]]'
            'System!*[System[(Level=1 or Level=2 or Level=3)]]'
          ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: 'logAnalyticsDestination'
          workspaceResourceId: logAnalytics.id
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-InsightsMetrics'
        ]
        destinations: [
          'logAnalyticsDestination'
        ]
      }
      {
        streams: [
          'Microsoft-Perf'
        ]
        destinations: [
          'logAnalyticsDestination'
        ]
      }
      {
        streams: [
          'Microsoft-WindowsEvent'
        ]
        destinations: [
          'logAnalyticsDestination'
        ]
      }
    ]
  }
}

output workspaceId string = logAnalytics.id
output workspaceName string = logAnalytics.name
output dataCollectionRuleId string = dataCollectionRule.id
output dataCollectionRuleName string = dataCollectionRule.name
