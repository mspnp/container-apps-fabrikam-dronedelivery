targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('Name of the Azure Containers Apps resource.')
@minLength(1)
param containerAppName string

@description('The existing user managed identity resource id to assign this container app.')
@minLength(100)
param containerAppUserAssignedResourceId string

@description('The location of the existing Azure Containers Apps environment.')
@minLength(1)
param location string

@description('The resource ID of the existing Azure Container Apps Environment.')
@minLength(100)
param environmentId string

@description('The resource ID of the existing Azure Container Registry that contain this microservice. The provided managed identity will be granted ACR pull rights.')
@minLength(40)
param containerRegistryResourceId string

@description('The container image in the existing registry, including tag. In the format of \'repository/image:tag\'')
@minLength(5)
param containerImage string

@description('-1 if no ingress is expected, otherwise the container port ingress should be configured on.')
@minValue(-1)
@maxValue(65535)
param containerPort int = -1

@description('true if the ingress be exposed to the Internet, otherwise false.')
param isExternalIngress bool

@description('All custom environment variables required for this app.')
@minLength(0)
param env array = []

@description('All custom secrets required for this app.')
param secrets array

@description('The CPU limit for this app.')
@minLength(1)
param cpu string = '0.5'

@description('The memory limit for this app.')
@minLength(1)
param memory string = '1Gi'

@description('The revision mode for this app.')
@allowed([
  'multiple'
  'single'
])
param revisionMode string

/*** VARIABLES ***/

@description('Was ingress requested for this app?')
var hasIngress = (containerPort == -1) ? false : true

/*** EXISTING RESOURCE ***/

@description('Resource group of the existing container registry')
resource containerRegistryResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  scope: subscription()
  name: split(containerRegistryResourceId, '/')[4]
}

@description('Existing container registry')
resource existingContainerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  scope: containerRegistryResourceGroup
  name: split(containerRegistryResourceId, '/')[8]
}

@description('Resource group of the existing managed identity')
resource managedIdentityResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  scope: subscription()
  name: split(containerAppUserAssignedResourceId, '/')[4]
}

@description('Existing managed identity for this service')
resource existingManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  scope: managedIdentityResourceGroup
  name: split(containerAppUserAssignedResourceId, '/')[8]
}

/*** RESOURCES ***/

@description('Ensure the user managed identity has ACR pull rights to the container registry.')
module acrPull './acrpull-roleassignment.bicep' = {
  name: 'acrpull-${containerAppName}'
  scope: containerRegistryResourceGroup
  params: {
    containerAppUserPrincipalId: existingManagedIdentity.properties.principalId
    containerRegistryName: existingContainerRegistry.name
    containerAppName: containerAppName
  }
}

resource containerApp 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: containerAppName
  location: location
  dependsOn: [
    acrPull
  ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${existingManagedIdentity.id}': {}
    }
  }
  properties: {
    environmentId: environmentId
    workloadProfileName: null
    configuration: {
      activeRevisionsMode: revisionMode
      secrets: secrets
      registries: [
        {
          server: existingContainerRegistry.properties.loginServer
          identity: existingManagedIdentity.id
        }
      ]
      ingress: hasIngress ? {
        external: isExternalIngress
        targetPort: containerPort
        exposedPort: 0
        transport: 'auto'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        customDomains: null
        allowInsecure: false
        ipSecurityRestrictions: null
        corsPolicy: null
        clientCertificateMode: 'ignore'
        stickySessions: {
          affinity: 'none'
        }
      } : null
      dapr: {
        enabled: false
      }
      maxInactiveRevisions: 10
    }
    template: {
      containers: [
        {
          image: '${existingContainerRegistry.properties.loginServer}/${containerImage}'
          name: containerAppName
          env: env
          resources: {
            cpu: json(cpu)
            memory: memory
          }
        }
      ]
      initContainers: null
      revisionSuffix: null
      scale: {
        minReplicas: 1
        maxReplicas: 1
        rules: null
      }
      volumes: null
    }
  }
}

/*** OUTPUT ***/

output fqdn string = hasIngress ? containerApp.properties.configuration.ingress.fqdn : ''
