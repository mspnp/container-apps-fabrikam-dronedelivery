targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The location to deploy all resources.')
@minLength(1)
param location string

/*** RESOURCES ***/

@description('Log analytics workspace used for Application Insights and Azure Diagnostics.')
resource la 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'la-shipping-dronedelivery'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

@description('The Azure Container Apps Environment')
resource cae 'Microsoft.App/managedEnvironments@2022-11-01-preview' = {
  name: 'cae-shipping-dronedelivery'
  kind: 'containerenvironment'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: la.properties.customerId
        sharedKey: la.listKeys().primarySharedKey
      }
    }
    customDomainConfiguration: null
    daprAIConnectionString: null
    daprAIInstrumentationKey: null
    daprConfiguration: null
    infrastructureResourceGroup: 'rg-aca-managed-shipping-dronedelivery'
    kedaConfiguration: null
    vnetConfiguration: {
      infrastructureSubnetId: null
      internal: false
      platformReservedCidr: null
      platformReservedDnsIP: null
    }
    zoneRedundant: true
  }
}

@description('Azure diagnostics for Container Apps Environment')
resource d 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
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
