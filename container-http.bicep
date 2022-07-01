targetScope = 'resourceGroup'

/*** PARAMETERS ***/

param containerAppName string
param containerAppUserAssignedResourceId string
param location string = resourceGroup().location
param environmentId string
param containerImage string
param containerPort int = -1
param isExternalIngress bool = false
param containerRegistry string
param containerRegistryUsername string
param env array = []
param secrets array = [
  {
    name: 'containerregistry-password'
    value: containerRegistryPassword
  }
]
param cpu string = '0.5'
param memory string = '1Gi'

@allowed([
  'multiple'
  'single'
])
param revisionMode string = 'multiple'

@secure()
param containerRegistryPassword string

/*** VARIABLES ***/

var registrySecretRefName = 'containerregistry-password'
var hasIngress = (containerPort == -1) ? false : true

/*** RESOURCES ***/

resource containerApp 'Microsoft.App/containerApps@2022-01-01-preview' = {
  name: containerAppName
  kind: 'containerapp'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${containerAppUserAssignedResourceId}': {}
    }
  }
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      activeRevisionsMode: revisionMode
      secrets: secrets
      registries: [
        {
          server: containerRegistry
          username: containerRegistryUsername
          passwordSecretRef: registrySecretRefName
        }
      ]
      ingress: hasIngress ? {
        external: isExternalIngress
        targetPort: containerPort
        transport: 'auto'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        allowInsecure: false
      } : null
    }
    template: {
      containers: [
        {
          image: containerImage
          name: containerAppName
          env: env
          resources: {
            cpu: cpu
            memory: memory
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


/*** OUTPUT ***/

output fqdn string = hasIngress ? containerApp.properties.configuration.ingress.fqdn : ''
