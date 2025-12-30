targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The location to deploy all resources.')
@minLength(1)
param location string

@description('The resource ID of log analytics sink used by all the resources in the microservices. Will also be used for the app platform resources.')
@minLength(40)
param logAnalyticsResourceId string

/*** EXISTING RESOURCES ***/

@description('Resource group of the provided Log Analytics workspace.')
resource laResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  name: split(logAnalyticsResourceId, '/')[4]
  scope: subscription(split(logAnalyticsResourceId, '/')[2])
}

resource la 'Microsoft.OperationalInsights/workspaces@2025-07-01' existing = {
  name: split(logAnalyticsResourceId, '/')[8]
  scope: laResourceGroup
}

/*** RESOURCES ***/

@description('The Azure Container Apps environment')
resource cae 'Microsoft.App/managedEnvironments@2025-10-02-preview' = {
  name: 'cae-shipping-dronedelivery'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'azure-monitor' // Uses diagnostics settings below
      logAnalyticsConfiguration: null
    }
    zoneRedundant: false // Production readiness change: Enable zone redundancy for higher availability. See https://learn.microsoft.com/azure/container-apps/zone-redundant. This requires a virtual network based deployment.
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
    publicNetworkAccess: 'Enabled' // Production readiness change: Front your service with a WAF and only expose this environment to your private network.
    vnetConfiguration: null // Production readiness change: Use a custom virtual network with Network Security Groups and UDR-based routing through Azure Firewall for enhanced security control. See https://learn.microsoft.com/azure/container-apps/vnet-custom
    ingressConfiguration: null
    appInsightsConfiguration: null
    daprAIConnectionString: null
    diskEncryptionConfiguration: null
    openTelemetryConfiguration: null
    customDomainConfiguration: null
    peerAuthentication: {
      mtls: {
        enabled: false
      }
    }
    peerTrafficConfiguration: {
      encryption: {
        enabled: false
      }
    }
    infrastructureResourceGroup: null
  }
}

@description('Azure diagnostics for the Container Apps environment')
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
