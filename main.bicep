targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The Application Insights key used for all of the logging done by the microservices.')
@minLength(20)
param applicationInsightsInstrumentationKey string

@description('The resource ID of the existing Azure Container Registry that contains all the microservices.')
@minLength(40)
param containerRegistryResourceId string

@description('The Cosmos DB database name used by the Delivery service.')
@minLength(1)
param deliveryCosmosdbDatabaseName string

@description('The Cosmos DB collection name used by the Delivery service.')
@minLength(1)
param deliveryCosmosdbCollectionName string

@description('The Cosmos DB HTTP endpoint used by the Delivery service. Should be in the form of https://databaseName.documents.azure.com:443/')
@minLength(24)
param deliveryCosmosdbEndpoint string

@description('The FQDN of the Redis instance used by the Delivery service. Should be in the form of instanceName.redis.cache.windows.net')
@minLength(23)
param deliveryRedisEndpoint string

@description('The Key Vault HTTP endpoint used by the Delivery service. Should be in the form of https://instanceName.vault.azure.net/')
@minLength(24)
param deliveryKeyVaultUri string

@description('The Cosmos DB HTTP endpoint used by the Scheduler service. Should be in the form of https://databaseName.documents.azure.com:443/')
@minLength(24)
param droneSchedulerCosmosdbEndpoint string

@description('The Key Vault HTTP endpoint used by the Scheduler service. Should be in the form of https://instanceName.vault.azure.net/')
@minLength(24)
param droneSchedulerKeyVaultUri string

@description('The Service Bus HTTP endpoint used by the Workflow service. Should be in the form of https://namespaceName.servicebus.windows.net:443/')
@minLength(24)
param wokflowNamespaceEndpoint string

@description('The Service Bus Queue Access Policy Name for the Workflow service.')
@minLength(1)
param workflowNamespaceSASName string

@description('The Service Bus Queue Access Policy SaS key for the Workflow service.')
@secure()
@minLength(5)
param workflowNamespaceSASKey string

@description('The Service Bus Queue Name for the Workflow service.')
@minLength(1)
param workflowQueueName string

@description('The Mongo DB connection string for the Package service. Should be in the form of mongodb://user:secret@instanceName.mongo.cosmos.azure.com:10255/?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@appName@')
@secure()
@minLength(60)
param packageMongodbConnectionString string

@description('The Service Bus namespace for the Ingestion service.')
@minLength(1)
param ingestionNamespaceName string

@description('The Service Bus Queue Access Policy Name for the Ingestion service.')
@minLength(1)
param ingestionNamespaceSASName string

@description('The Service Bus Queue Access Policy SaS key for the Ingestion service.')
@minLength(5)
param ingestionNamespaceSASKey string

@description('The Service Bus Queue Name for the Ingestion service.')
@minLength(1)
param ingestionQueueName string

@description('The location to deploy all new resources.')
@minLength(5)
param location string = resourceGroup().location

/*** EXISTING RESOURCE GROUP RESOURCES ***/

@description('The existing managed identity for the Delivery service.')
resource miDelivery 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: 'uid-delivery'
  scope: resourceGroup()
}

@description('The existing managed identity for the Scheduler service.')
resource miDroneScheduler 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: 'uid-dronescheduler'
  scope: resourceGroup()
}

@description('The existing managed identity for the Workflow service.')
resource miWorkflow 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: 'uid-workflow'
  scope: resourceGroup()
}

@description('The existing managed identity for the Package service.')
resource miPackage 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: 'uid-package'
  scope: resourceGroup()
}

@description('The existing managed identity for the Ingestion service.')
resource miIngestion 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: 'uid-ingestion'
  scope: resourceGroup()
}

/*** RESOURCES ***/

// Drone Delivery App Environment
module env_shipping_dronedelivery 'environment.bicep' = {
  name: 'env-shipping-dronedelivery'
  params: {
    location: location
  }
}

// Delivery App
module ca_delivery 'container-http.bicep' = {
  name: 'ca-delivery'
  params: {
    location: location
    containerAppName: 'delivery-app'
    containerAppUserAssignedResourceId: miDelivery.id
    environmentId: env_shipping_dronedelivery.outputs.id
    containerRegistryResourceId: containerRegistryResourceId
    containerImage: 'shipping/delivery:0.1.0'
    containerPort: 8080
    isExternalIngress: false
    revisionMode: 'multiple'
    secrets: [
        {
          name: 'applicationinsights-instrumentationkey'
          value: applicationInsightsInstrumentationKey
        }
    ]
    env: [
      {
        name: 'ApplicationInsights__InstrumentationKey'
        secretref: 'applicationinsights-instrumentationkey'
      }
      {
        name: 'CosmosDB-Endpoint'
        value: deliveryCosmosdbEndpoint
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
        name: 'KEY_VAULT_URI'
        value: deliveryKeyVaultUri
      }
      {
        name: 'AZURE_CLIENT_ID'
        value: miDelivery.properties.clientId
      }
    ]
  }
}

// DroneScheduler App
module ca_dronescheduler 'container-http.bicep' = {
  name: 'ca-dronescheduler'
  params: {
    location: location
    containerAppName: 'dronescheduler-app'
    containerAppUserAssignedResourceId: miDroneScheduler.id
    environmentId: env_shipping_dronedelivery.outputs.id
    containerRegistryResourceId: containerRegistryResourceId
    containerImage: 'shipping/dronescheduler:0.1.0'
    containerPort: 8080
    isExternalIngress: false
    revisionMode: 'multiple'
    secrets: [
      {
        name: 'applicationinsights-instrumentationkey'
        value: applicationInsightsInstrumentationKey
      }
    ]
    env: [
      {
        name: 'ApplicationInsights__InstrumentationKey'
        secretref: 'applicationinsights-instrumentationkey'
      }
      {
        name: 'CosmosDBEndpoint'
        value: droneSchedulerCosmosdbEndpoint
      }
      {
        name: 'CosmosDBConnectionMode'
        value: 'Gateway'
      }
      {
        name: 'CosmosDBConnectionProtocol'
        value: 'Https'
      }
      {
        name: 'CosmosDBMaxConnectionsLimit'
        value: '50'
      }
      {
        name: 'CosmosDBMaxParallelism'
        value: '-1'
      }
      {
        name: 'CosmosDBMaxBufferedItemCount'
        value: '0'
      }
      {
        name: 'FeatureManagement__UsePartitionKey'
        value: 'false'
      }
      {
        name: 'COSMOSDB_DATABASEID'
        value: 'invoicing'
      }
      {
        name: 'COSMOSDB_COLLECTIONID'
        value: 'utilization'
      }
      {
        name: 'LOGGING__ApplicationInsights__LOGLEVEL__DEFAULT'
        value: 'Error'
      }
      {
        name: 'KEY_VAULT_URI'
        value: droneSchedulerKeyVaultUri
      }
      {
        name: 'AZURE_CLIENT_ID'
        value: miDroneScheduler.properties.clientId
      }
    ]
  }
}

// Workflow App
module ca_workflow 'container-http.bicep' = {
  name: 'ca-workflow'
  params: {
    location: location
    containerAppName: 'workflow-app'
    containerAppUserAssignedResourceId: miWorkflow.id
    environmentId: env_shipping_dronedelivery.outputs.id
    containerRegistryResourceId: containerRegistryResourceId
    containerImage: 'shipping/workflow:0.1.0'
    revisionMode: 'single'
    isExternalIngress: false
    secrets: [
      {
        name: 'applicationinsights-instrumentationkey'
        value: applicationInsightsInstrumentationKey
      }
      {
        name: 'namespace-sas-key'
        value: workflowNamespaceSASKey
      }
    ]
    env: [
      {
        name: 'ApplicationInsights__InstrumentationKey'
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
        value: 'https://${ca_package.outputs.fqdn}/api/packages/'
      }
      {
        name: 'SERVICE_URI_DRONE'
        value: 'https://${ca_dronescheduler.outputs.fqdn}/api/DroneDeliveries/'
      }
      {
        name: 'SERVICE_URI_DELIVERY'
        value: 'https://${ca_delivery.outputs.fqdn}/api/Deliveries/'
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
  }
}

// Package App
module ca_package 'container-http.bicep' = {
  name: 'ca-package'
  params: {
    location: location
    containerAppName: 'package-app'
    containerAppUserAssignedResourceId: miPackage.id
    environmentId: env_shipping_dronedelivery.outputs.id
    containerRegistryResourceId: containerRegistryResourceId
    containerImage: 'shipping/package:0.1.0'
    containerPort: 80
    isExternalIngress: false
    revisionMode: 'multiple'
    secrets: [
      {
        name: 'applicationinsights-instrumentationkey'
        value: applicationInsightsInstrumentationKey
      }
      {
        name: 'mongodb-connectrionstring'
        value: packageMongodbConnectionString
      }
    ]
    env: [
      {
        name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
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
  }
}

// Ingestion App
module ca_ingestion 'container-http.bicep' = {
  name: 'ca-ingestion'
  params: {
    location: location
    containerAppName: 'ingestion-app'
    containerAppUserAssignedResourceId: miIngestion.id
    environmentId: env_shipping_dronedelivery.outputs.id
    containerRegistryResourceId: containerRegistryResourceId
    containerImage: 'shipping/ingestion:0.1.0'
    containerPort: 80
    cpu: '1'
    memory: '2.0Gi'
    isExternalIngress: true
    revisionMode: 'multiple'
    secrets: [
      {
        name: 'applicationinsights-instrumentationkey'
        value: applicationInsightsInstrumentationKey
      }
      {
        name: 'namespace-sas-key'
        value: ingestionNamespaceSASKey
      }
    ]
    env: [
      {
        name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
        secretref: 'applicationinsights-instrumentationkey'
      }
      {
        name: 'APPINSIGHTS_LOGGERLEVEL'
        value: 'error'
      }
      {
        name: 'CONTAINER_NAME'
        value: 'fabrikam-ingestion'
      }
      {
        name: 'QUEUE_NAMESPACE'
        value: ingestionNamespaceName
      }
      {
        name: 'QUEUE_NAME'
        value: ingestionQueueName
      }
      {
        name: 'QUEUE_KEYNAME'
        value: ingestionNamespaceSASName
      }
      {
        name: 'QUEUE_KEYVALUE'
        secretref: 'namespace-sas-key'
      }
    ]
  }
}

/*** OUTPUTS ***/

output ingestionFqdn string = ca_ingestion.outputs.fqdn
