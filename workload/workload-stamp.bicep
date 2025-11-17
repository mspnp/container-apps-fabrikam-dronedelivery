@description('The location to deploy the workload stamp to.')
param location string = resourceGroup().location

@description('For Azure resources that support native geo-redundancy, provide the location the redundant service will have its secondary. Should be different than the location parameter and ideally should be a paired region - https://learn.microsoft.com/azure/best-practices-availability-paired-regions. This region does not need to support availability zones.')
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
param geoRedundancyLocation string = 'centralus'


var prefix = substring(uniqueString(subscription().subscriptionId, resourceGroup().id), 0, 10)
var acrName = 'acr${prefix}'
var appInsightsName = 'ai-${prefix}'
var logAnalyticsWorkspaceName = 'law-${prefix}'
var nestedACRDeploymentName = '${resourceGroup().name}-deployment'
var deliveryRedisCacheSKU = 'Basic'
var deliveryRedisCacheFamily = 'C'
var deliveryRedisCacheCapacity = 0
var deliveryCosmosDbName = 'cosmos-delivery-${prefix}'
var deliveryRedisName = 'redis-delivery-${prefix}'
var deliveryKeyVaultName = 'kv-delivery-${prefix}'
var droneSchedulerCosmosDbName = 'cosmos-scheduler-${prefix}'
var droneSchedulerKeyVaultName = 'kv-schedule-${prefix}'
var packageKeyVaultName = 'kv-package-${prefix}'
var packageMongoDbName = 'cosmos-package-${prefix}'
var ingestionSBNamespaceName = 'sbns-ingest-${prefix}'
var ingestionSBNamespaceSKU = 'Premium'
var ingestionSBNamespaceTier = 'Premium'
var ingestionSBName = 'sb-ingest-${prefix}'
var ingestionServiceAccessKeyName = 'IngestionServiceAccessKey'
var ingestionKeyVaultName = 'kv-ingest-${prefix}'
var workflowKeyVaultName = 'kv-workflow-${prefix}'
var workflowServiceAccessKeyName = 'WorkflowServiceAccessKey'
var keyVaultSecretsUserRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')

@description('Built-in Role: Reader - https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#reader')
resource builtInReaderRole 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  scope: subscription()
}

resource workflowManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: 'uid-workflow'
  location: location
  tags: {
    displayName: 'workflow managed identity'
    what: 'rbac'
    reason: 'aad-workload-identity'
    app: 'fabrikam-workflow'
  }
}

resource deliveryManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: 'uid-delivery'
  location: location
  tags: {
    displayName: 'delivery managed identity'
    what: 'rbac'
    reason: 'aad-workload-identity'
    app: 'fabrikam-delivery'
  }
}

resource droneSchedulerManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: 'uid-dronescheduler'
  location: location
  tags: {
    displayName: 'dronescheduler managed identity'
    what: 'rbac'
    reason: 'aad-workload-identity'
    app: 'fabrikam-dronescheduler'
  }
}

resource ingestionManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: 'uid-ingestion'
  location: location
  tags: {
    displayName: 'ingestion managed identity'
    what: 'rbac'
    reason: 'aad-workload-identity'
    app: 'fabrikam-ingestion'
  }
}

resource packageManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: 'uid-package'
  location: location
  tags: {
    displayName: 'package managed identity'
    what: 'rbac'
    reason: 'aad-workload-identity'
    app: 'fabrikam-package'
  }
}

module containerRegistry './nested_workload-stamp.bicep' = {
  name: nestedACRDeploymentName
  params: {
    location: location
    acrName: acrName
    geoRedundancyLocation: geoRedundancyLocation
  }
  dependsOn: []
}

resource deliveryRedis 'Microsoft.Cache/Redis@2020-06-01' = {
  name: deliveryRedisName
  location: location
  tags: {
    displayName: 'Redis Cache for inflight deliveries'
    app: 'fabrikam-delivery'
    TODO: 'add log analytics resource'
  }
  properties: {
    sku: {
      capacity: deliveryRedisCacheCapacity
      family: deliveryRedisCacheFamily
      name: deliveryRedisCacheSKU
    }
  }
  dependsOn: []
}

resource deliveryCosmosDb 'Microsoft.DocumentDB/databaseAccounts@2025-05-01-preview' = {
  name: deliveryCosmosDbName
  location: location
  tags: {
    displayName: 'Delivery Azure Cosmos DB for NoSQL'
    app: 'fabrikam-delivery'
  }
  properties: {
    databaseAccountOfferType: 'Standard'
    isVirtualNetworkFilterEnabled: false
    virtualNetworkRules: []
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
  }
  dependsOn: []
}

resource packageMongoDb 'Microsoft.DocumentDB/databaseAccounts@2025-05-01-preview' = {
  name: packageMongoDbName
  kind: 'MongoDB'
  location: location
  tags: {
    displayName: 'Package Azure Cosmos DB for MongoDB'
    app: 'fabrikam-package'
  }
  properties: {
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
    databaseAccountOfferType: 'Standard'
    isVirtualNetworkFilterEnabled: false
    apiProperties: {
       serverVersion: '7.0'
    }
    virtualNetworkRules: []
  }
  dependsOn: []
}

resource packageKeyVault 'Microsoft.KeyVault/vaults@2025-05-01' = {
  name: packageKeyVaultName
  location: location
  tags: {
    displayName: 'Package Key Vault'
    app: 'fabrikam-package'
  }
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'Enabled' // Production readiness change: Disable public network access and use private endpoints to secure Key Vault access. See https://learn.microsoft.com/azure/key-vault/general/private-link-service
    enableRbacAuthorization: true
    accessPolicies: []
  }
  resource secretApplicationInsightsKey 'secrets' = {
    name: 'ApplicationInsights--InstrumentationKey'
    properties: {
      value: appInsights.properties.InstrumentationKey
    }
  }
  resource secretApplicationInsightsConnectionString 'secrets' = {
    name: 'ApplicationInsights--ConnectionString'
    properties: {
      value: appInsights.properties.ConnectionString
    }
  }
  resource secretCosmosDBConnectionString 'secrets' = {
    name: 'CosmosDb--ConnectionString'
    properties: {
      value: packageMongoDb.listConnectionStrings().connectionStrings[0].connectionString
    }
  }

}

resource packagePrincipalKeyVaultSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: packageKeyVault
  name: guid(packageManagedIdentity.id, packageKeyVault.name, keyVaultSecretsUserRole)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole
    principalId: packageManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource droneSchedulerCosmosDb 'Microsoft.DocumentDB/databaseAccounts@2025-05-01-preview' = {
  name: droneSchedulerCosmosDbName
  location: location
  tags: {
    displayName: 'Drone Scheduler Azure Cosmos DB for NoSQL'
    app: 'fabrikam-dronescheduler'
  }
  properties: {
    databaseAccountOfferType: 'Standard'
    isVirtualNetworkFilterEnabled: false
    virtualNetworkRules: []
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
  }
  dependsOn: []
}

resource ingestionSBNamespace 'Microsoft.ServiceBus/namespaces@2025-05-01-preview' = {
  name: ingestionSBNamespaceName
  location: location
  sku: {
    name: ingestionSBNamespaceSKU
    tier: ingestionSBNamespaceTier
  }
  properties: {
    zoneRedundant: true
  }
  tags: {
    displayName: 'Ingestion and Workflow Service Bus'
    app: 'fabrikam-ingestion and fabrikam-workflow'
    'app-producer': 'fabrikam-ingestion'
    'app-consumer': 'fabrikam-workflow'
  }
}

resource ingestionSBNamespaceIngestionSB 'Microsoft.ServiceBus/namespaces/queues@2025-05-01-preview' = {
  parent: ingestionSBNamespace
  name: ingestionSBName
  properties: {
    lockDuration: 'PT5M'
    maxSizeInMegabytes: 1024
  }
}

resource ingestionSBNamespaceIngestionServiceAccessKey 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2025-05-01-preview' = {
  parent: ingestionSBNamespace
  name: ingestionServiceAccessKeyName
  properties: {
    rights: [
      'Send'
    ]
  }
}

resource ingestionSBNamespaceWorkflowServiceAccessKey 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2025-05-01-preview' = {
  parent: ingestionSBNamespace
  name: workflowServiceAccessKeyName
  properties: {
    rights: [
      'Listen'
    ]
  }
}

resource deliveryKeyVault 'Microsoft.KeyVault/vaults@2025-05-01' = {
  name: deliveryKeyVaultName
  location: location
  tags: {
    displayName: 'Delivery Key Vault'
    app: 'fabrikam-delivery'
  }
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'Enabled' // Production readiness change: Disable public network access and use private endpoints to secure Key Vault access. See https://learn.microsoft.com/azure/key-vault/general/private-link-service
    enableRbacAuthorization: true
    accessPolicies: []
  }
  resource secretCosmosDbEndpoint 'secrets' = {
    name: 'CosmosDB-Endpoint'
    properties: {
      value: deliveryCosmosDb.properties.documentEndpoint
    }
  }

  resource secretCosmosDbKey 'secrets' = {
    name: 'CosmosDB-Key'
    properties: {
      value: deliveryCosmosDb.listKeys().primaryMasterKey
    }
  }

  resource secretRedisEndpoint 'secrets' = {
    name: 'Redis-Endpoint'
    properties: {
      value: deliveryRedis.properties.hostName
    }
  }

  resource secretRedisAccessKey 'secrets' = {
    name: 'Redis-AccessKey'
    properties: {
      value: deliveryRedis.listKeys().primaryKey
    }
  }

  resource secretApplicationInsightsKey 'secrets' = {
    name: 'ApplicationInsights--InstrumentationKey'
    properties: {
      value: appInsights.properties.InstrumentationKey
    }
  }
}

resource deliveryPrincipalKeyVaultSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: deliveryKeyVault
  name: guid(deliveryManagedIdentity.id, deliveryKeyVault.name, keyVaultSecretsUserRole)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole
    principalId: deliveryManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource ingestionKeyVault 'Microsoft.KeyVault/vaults@2025-05-01' = {
  name: ingestionKeyVaultName
  location: location
  tags: {
    displayName: 'Ingestion Key Vault'
    app: 'fabrikam-ingestion'
  }
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'Enabled' // Production readiness change: Disable public network access and use private endpoints to secure Key Vault access. See https://learn.microsoft.com/azure/key-vault/general/private-link-service
    enableRbacAuthorization: true
    accessPolicies: []
  }
   resource secretQueueKey 'secrets' = {
    name: 'Queue--Key'
    properties: {
      value: ingestionSBNamespaceIngestionServiceAccessKey.listKeys().primaryKey
    }
  }

  resource secretApplicationInsightsKey 'secrets' = {
    name: 'ApplicationInsights--InstrumentationKey'
    properties: {
      value: appInsights.properties.InstrumentationKey
    }
  }
}

resource ingestionPrincipalVaultSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: ingestionKeyVault
  name: guid(ingestionManagedIdentity.id, ingestionKeyVault.name, keyVaultSecretsUserRole)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole
    principalId: ingestionManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource droneSchedulerKeyVault 'Microsoft.KeyVault/vaults@2025-05-01' = {
  name: droneSchedulerKeyVaultName
  location: location
  tags: {
    displayName: 'DroneScheduler Key Vault'
    app: 'fabrikam-dronescheduler'
  }
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'Enabled' // Production readiness change: Disable public network access and use private endpoints to secure Key Vault access. See https://learn.microsoft.com/azure/key-vault/general/private-link-service
    enableRbacAuthorization: true
    accessPolicies: []
  }

  resource secretApplicationInsights 'secrets' = {
    name: 'ApplicationInsights--InstrumentationKey'
    properties: {
      value: appInsights.properties.InstrumentationKey
    }
  }
    
  resource secretCosmosDBKey 'secrets' = {
    name: 'CosmosDBKey'
    properties: {
      value: droneSchedulerCosmosDb.listKeys().primaryMasterKey
    }
  }
}

resource droneSchedulerPrincipalKeyVaultSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: droneSchedulerKeyVault
  name: guid(droneSchedulerManagedIdentity.id, droneSchedulerKeyVault.name, keyVaultSecretsUserRole)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole
    principalId: droneSchedulerManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource workflowKeyVault 'Microsoft.KeyVault/vaults@2025-05-01' = {
  name: workflowKeyVaultName
  location: location
  tags: {
    displayName: 'Workflow Key Vault'
    app: 'fabrikam-workflow'
  }
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'Enabled' // Production readiness change: Disable public network access and use private endpoints to secure Key Vault access. See https://learn.microsoft.com/azure/key-vault/general/private-link-service
    enableRbacAuthorization: true
    accessPolicies: []
  }

  resource secretQueueAccessPolicyKey 'secrets' = {
    name: 'QueueAccessPolicyKey'
    properties: {
      value: ingestionSBNamespaceWorkflowServiceAccessKey.listKeys().primaryKey
    }
  }

  resource secretApplicationInsights 'secrets' = {
    name: 'ApplicationInsights--InstrumentationKey'
    properties: {
      value: appInsights.properties.InstrumentationKey
    }
  }
}

resource workflowPrincipalKeyVaultSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: workflowKeyVault
  name: guid(workflowManagedIdentity.id, workflowKeyVault.name, keyVaultSecretsUserRole)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole
    principalId: workflowManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'pergb2018'
    }
    publicNetworkAccessForIngestion:'Enabled'
    publicNetworkAccessForQuery:'Enabled'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  kind: 'other'
  location: location
  tags: {
    displayName: 'App Insights instance - Distributed Tracing'
  }
  properties: {
    Application_Type: 'other'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode:'LogAnalytics'
    publicNetworkAccessForIngestion:'Enabled'
    publicNetworkAccessForQuery:'Enabled'
  }
}

resource deliveryKeyVaultMicrosoftAuthorizationDeliveryIdNameIdReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name:  guid('${deliveryKeyVaultName}${resourceGroup().id}', builtInReaderRole.id)
  scope: deliveryKeyVault
  properties: {
    roleDefinitionId: builtInReaderRole.id
    principalId: deliveryManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource workflowKeyVaultNameMicrosoftAuthorizationWorkflowIdNameIdReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01'= {
  name: guid('${workflowKeyVaultName}${resourceGroup().id}', builtInReaderRole.id)
  scope: workflowKeyVault
  properties: {
    roleDefinitionId: builtInReaderRole.id
    principalId: workflowManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource droneSchedulerKeyVaultNameMicrosoftAuthorizationDroneSchedulerIdNameIdReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${droneSchedulerKeyVaultName}${resourceGroup().id}', builtInReaderRole.id)
  scope: droneSchedulerKeyVault
  properties: {
    roleDefinitionId: builtInReaderRole.id
    principalId: droneSchedulerManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource ingestionKeyVaultNameMicrosoftAuthorizationIngestionIdNameIdReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${ingestionKeyVaultName}${resourceGroup().id}', builtInReaderRole.id)
  scope: ingestionKeyVault
  properties: {
    roleDefinitionId: builtInReaderRole.id
    principalId: ingestionManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource packageKeyVaultNameMicrosoftAuthorizationPackageIdNameIdReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${packageKeyVaultName}${resourceGroup().id}', builtInReaderRole.id)
  scope: packageKeyVault
  properties: {
    roleDefinitionId: builtInReaderRole.id
    principalId: packageManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output acrId string = containerRegistry.outputs.acrId
output acrName string = acrName
output deliveryKeyVaultUri string = deliveryKeyVault.properties.vaultUri
output droneSchedulerKeyVaultUri string = droneSchedulerKeyVault.properties.vaultUri
output deliveryCosmosDbName string = deliveryCosmosDbName
output droneSchedulerCosmosDbName string = droneSchedulerCosmosDbName
output packageMongoDbName string = packageMongoDbName
output ingestionQueueNamespace string = ingestionSBNamespaceName
output ingestionQueueName string = ingestionSBName
output ingestionServiceAccessKeyName string = ingestionServiceAccessKeyName
output workflowKeyVaultName string = workflowKeyVaultName
output deliveryKeyVaultName string = deliveryKeyVaultName
output droneSchedulerKeyVaultName string = droneSchedulerKeyVaultName
output ingestionKeyVaultName string = ingestionKeyVaultName
output packageKeyVaultName string = packageKeyVaultName
output appInsightsName string = appInsightsName
output laWorkspace string = logAnalyticsWorkspace.id
output deliveryRedisName string = deliveryRedis.name
output workflowServiceAccessKeyName string = workflowServiceAccessKeyName
