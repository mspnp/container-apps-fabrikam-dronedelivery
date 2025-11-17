targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The location to deploy all resources.')
@minLength(1)
param location string

@description('The resource ID of log analytics sink used by all the resources in the microservices. Will also be used for the app platform resources.')
@minLength(40)
param logAnalyticsResourceId string

/*** EXISTING RESOURCES ***/

@description('Resource group of the provided log analytics workspace.')
resource laResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  name: split(logAnalyticsResourceId, '/')[4]
  scope: subscription(split(logAnalyticsResourceId, '/')[2])
}

resource la 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: split(logAnalyticsResourceId, '/')[8]
  scope: laResourceGroup
}

/*** RESOURCES ***/

@description('The Azure Container Apps Environment')
resource cae 'Microsoft.App/managedEnvironments@2025-02-02-preview' = {
  name: 'cae-shipping-dronedelivery'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'azure-monitor' // Uses diagnostics settings below
      logAnalyticsConfiguration: null
    }
    zoneRedundant: true
    workloadProfiles: null
    vnetConfiguration: null
    infrastructureResourceGroup: null
  }
}

@description('Azure diagnostics for Container Apps Environment')
resource dsCae 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: cae
  properties: {
    workspaceId: la.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

/*** OUTPUT ***/

output id string = cae.id
