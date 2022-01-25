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
param wokflowNamespaceEndpoint string
param workflowNamespaceSASName string
param workflowNamespaceSASKey string
param workflowQueueName string
param packageMongodbConnectionString string

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

resource ca_dronescheduler 'Microsoft.Web/containerApps@2021-03-01' = {
  name: 'ca-dronescheduler'
  kind: 'containerapp'
  location: resourceGroup().location
  properties: {
    kubeEnvironmentId: cae_shipping_dronedelivery.id
    configuration: {
      secrets: [
        {
          name: 'applicationinsights-instrumentationkey'
          value: applicationInsightsInstrumentationKey
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
          image: '${acrSever}/shipping/dronescheduler:0.1.0'
          name: 'dronescheduler-app'
          env: [
            {
              name: 'ApplicationInsights--InstrumentationKey'
              secretref: 'applicationinsights-instrumentationkey'
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

resource ca_workflow 'Microsoft.Web/containerApps@2021-03-01' = {
  name: 'ca-workflow'
  kind: 'containerapp'
  location: resourceGroup().location
  properties: {
    kubeEnvironmentId: cae_shipping_dronedelivery.id
    configuration: {
      secrets: [
        {
          name: 'applicationinsights-instrumentationkey'
          value: applicationInsightsInstrumentationKey
        }
        {
          name: 'containerregistry-password'
          value: containerRegistryPassword
        }
        {
          name: 'namespace-sas-key'
          value: workflowNamespaceSASKey
        }
      ]
      registries: [
        {
          server: acrSever
          username: containerRegistryUser
          passwordSecretRef: 'containerregistry-password'
        }
      ]
    }
    template: {
      containers: [
        {
          image: '${acrSever}/shipping/workflow:0.1.0'
          name: 'workflow-app'
          env: [
            {
              name: 'ApplicationInsights--InstrumentationKey'
              secretref: 'applicationinsights-instrumentationkey'
            }
            {
              name: 'QueueName'
              value: workflowQueueName
            }
            {
              name: 'QueueEndpoint'
              value: wokflowNamespaceEndpoint
            }
            {
              name: 'QueueAccessPolicyName'
              value: workflowNamespaceSASName
            }
            {
              name: 'QueueAccessPolicyKey'
              secretref: 'namespace-sas-key'
            }
            {
              name: 'HEALTHCHECK_INITIAL_DELAY'
              value: '30000'
            }
            {
              name: 'SERVICE_URI_PACKAGE'
              value: 'http://package/api/packages/'
            }
            {
              name: 'SERVICE_URI_DRONE'
              value: 'http://dronescheduler/api/DroneDeliveries/'
            }
            {
              name: 'SERVICE_URI_DELIVERY'
              value: 'http://delivery/api/Deliveries/'
            }
            {
              name: 'LOGGING__ApplicationInsights__LOGLEVEL__DEFAULT'
              value: 'Error'
            }
            {
              name: 'SERVICEREQUEST__MAXRETRIES'
              value: '3'
            }
            {
              name: 'SERVICEREQUEST__CIRCUITBREAKERTHRESHOLD'
              value: '0.5'
            }
            {
              name: 'SERVICEREQUEST__CIRCUITBREAKERSAMPLINGPERIODSECONDS'
              value: '5'
            }
            {
              name: 'SERVICEREQUEST__CIRCUITBREAKERMINIMUMTHROUGHPUT'
              value: '20'
            }
            {
              name: 'SERVICEREQUEST__CIRCUITBREAKERBREAKDURATION'
              value: '30'
            }
            {
              name: 'SERVICEREQUEST__MAXBULKHEADSIZE'
              value: '100'
            }
            {
              name: 'SERVICEREQUEST__MAXBULKHEADQUEUESIZE'
              value: '25'
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

resource ca_package 'Microsoft.Web/containerApps@2021-03-01' = {
  name: 'ca-package'
  kind: 'containerapp'
  location: resourceGroup().location
  properties: {
    kubeEnvironmentId: cae_shipping_dronedelivery.id
    configuration: {
      secrets: [
        {
          name: 'applicationinsights-instrumentationkey'
          value: applicationInsightsInstrumentationKey
        }
        {
          name: 'containerregistry-password'
          value: containerRegistryPassword
        }
        {
          name: 'mongodb-connectrionstring'
          value: packageMongodbConnectionString
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
        targetPort: 80
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
          image: '${acrSever}/shipping/package:0.1.0'
          name: 'package-app'
          env: [
            {
              name: 'ApplicationInsights--InstrumentationKey'
              secretref: 'applicationinsights-instrumentationkey'
            }
            {
              name: 'CONNECTION_STRING'
              secretref: 'mongodb-connectrionstring'
            }
            {
              name: 'COLLECTION_NAME'
              value: 'packages'
            }
            {
              name: 'LOG_LEVEL'
              value: 'error'
            }
            {
              name: 'CONTAINER_NAME'
              value: 'fabrikam-package'
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