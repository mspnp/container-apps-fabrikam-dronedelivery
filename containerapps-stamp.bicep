param acrSever string
param containerRegistryUser string
param containerRegistryPassword string
param applicationInsightsInstrumentationKey string
param deliveryCosmosdbDatabaseName string
param deliveryCosmosdbCollectionName string
param deliveryCosmosdbEndpoint string
param deliveryCosmosdbKey string
param deliveryRedisEndpoint string
param deliveryRedisKey string

resource la 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'la-shipping-dronedelivery'
  location: resourceGroup().location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      legacy: 0
      searchVersion: 1
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource cae 'Microsoft.Web/kubeenvironments@2021-03-01' = {
  name: 'cae-shipping-dronedelivery'
  kind: 'containerenvironment'
  location: resourceGroup().location
  properties: {
    type: 'managed'
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: la.properties.customerId
        sharedKey: listKeys(la.id, '2021-06-01').primarySharedKey
      }
    }
  }
}

resource ca_delivery 'Microsoft.Web/containerApps@2021-03-01' = {
  name: 'ca-delivery'
  kind: 'containerapp'
  location: resourceGroup().location
  properties: {
    kubeEnvironmentId: cae.id
    configuration: {
      secrets: [
        {
          name: 'applicationinsights-instrumentationkey'
          value: applicationInsightsInstrumentationKey
        }
        {
          name: 'delivery-cosmosdb-key'
          value: deliveryCosmosdbKey
        }
        {
          name: 'delivery-redis-key'
          value: deliveryRedisKey
        }
        {
          name: 'containerregistry-password'
          value: containerRegistryPassword
        }
      ]
      registries: [
        {
          server: acrSever
          username: containerRegistryUser
          passwordSecretRef: 'containerregistry-password'
        }
      ]
      ingress: {
        external: true
        targetPort: 8080
        transport: 'Auto'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        allowInsecure: false
      }
    }
    template: {
      containers: [
        {
          image: '${acrSever}/shipping/delivery:0.1.0'
          name: 'delivery-app'
          env: [
            {
              name: 'ApplicationInsights--InstrumentationKey'
              secretref: 'applicationinsights-instrumentationkey'
            }
            {
              name: 'CosmosDB-Endpoint'
              value: deliveryCosmosdbEndpoint
            }
            {
              name: 'CosmosDB-Key'
              secretref: 'delivery-cosmosdb-key'
            }
            {
              name: 'DOCDB_DATABASEID'
              value: deliveryCosmosdbDatabaseName
            }
            {
              name: 'DOCDB_COLLECTIONID'
              value: deliveryCosmosdbCollectionName
            }
            {
              name: 'Redis-Endpoint'
              value: deliveryRedisEndpoint
            }
            {
              name: 'Redis-AccessKey'
              secretref: 'delivery-redis-key'
            }
          ]
          resources: {
            cpu: '0.5'
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}
