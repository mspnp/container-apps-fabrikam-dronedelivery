@description('ACR region.')
param location string = resourceGroup().location

@description('The resource ID of log analytics sink used by all the resources in the microservices. Will also be used for the app platform resources.')
@minLength(40)
param logAnalyticsResourceId string

@description('For Azure resources that support native geo-redundancy, provide the location the redundant service will have its secondary. Should be different than the location parameter and ideally should be a paired region - https://docs.microsoft.com/en-us/azure/best-practices-availability-paired-regions. This region does not need to support availability zones.')
@allowed([
  'australiasoutheast'
  'canadaeast'
  'eastus2'
  'westus'
  'centralus'
  'westcentralus'
  'francesouth'
  'germanynorth'
  'westeurope'
  'ukwest'
  'northeurope'
  'japanwest'
  'southafricawest'
  'northcentralus'
  'eastasia'
  'eastus'
  'westus2'
  'francecentral'
  'uksouth'
  'japaneast'
  'southeastasia'
])
param geoRedundancyLocation string

@description('Azure Container Registry name.')
param  acrName string

resource acr 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: acrName
  sku: {
    name: 'Premium'
  }
  location: location
  tags: {
    displayName: 'Container Registry'
  }
  properties: {
    adminUserEnabled: false
    networkRuleSet: {
      defaultAction: 'Allow'
      ipRules: []
    }
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 15
        status: 'enabled'
      }
    }
  }
}

resource acrGeoRedundancyLocation 'Microsoft.ContainerRegistry/registries/replications@2025-11-01' = {
  parent: acr
  name: geoRedundancyLocation
  location: geoRedundancyLocation
  properties: {}
}

@description('Azure diagnostics for Container Registry')
resource diagnosticsSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: acr
  properties: {
    workspaceId: logAnalyticsResourceId
    logs: [
      {
        category: 'ContainerRegistryRepositoryEvents'
        enabled: true
      }
      {
        category: 'ContainerRegistryLoginEvents'
        enabled: true
      }
    ]
  }
}

output acrId string = acr.id
