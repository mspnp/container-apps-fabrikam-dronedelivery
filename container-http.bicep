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

@description('The full URI of the container image, including tag. In the format of yourAcr.azurecr.io/registry/image:tag')
@minLength(15)
param containerImage string

@description('-1 if no ingress is expected, otherwise the container port ingress should be configured on.')
@minValue(-1)
@maxValue(65535)
param containerPort int = -1

@description('true if the ingress be exposed to the Internet, otherwise false.')
param isExternalIngress bool

@description('The FQDN of the ACR instance containing all the microservice containers. Needs to match the containerImage URI.')
@minLength(12)
param containerRegistry string

@description('The admin user name of the acrServer provided.')
@minLength(5)
param containerRegistryUsername string

@description('The admin user password of the acrServer provided.')
@secure()
@minLength(5)
param containerRegistryPassword string

@description('All custom environment variables required for this app.')
@minLength(0)
param env array = []

@description('All custom secrets required for this app.  This must at least include \'containerregistry-password\'.')
@minLength(1)
param secrets array = [
  {
    name:  'containerregistry-password'
    value: containerRegistryPassword
  }
]

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
param revisionMode string = 'multiple'

/*** VARIABLES ***/

@description('Was ingress requested for this app?')
var hasIngress = (containerPort == -1) ? false : true

/*** RESOURCES ***/

resource containerApp 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: containerAppName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${containerAppUserAssignedResourceId}': {}
    }
  }
  properties: {
    environmentId: environmentId
    workloadProfileName: null
    configuration: {
      activeRevisionsMode: revisionMode
      dapr: {
        enabled: false
      }
      ingress: hasIngress ? {
        allowInsecure: false
        clientCertificateMode: 'ignore'
        corsPolicy: null
        customDomains: []
        exposedPort: null
        external: isExternalIngress
        ipSecurityRestrictions: []
        stickySessions: {
          affinity: 'none'
        }
        targetPort: containerPort
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
        transport: 'auto'
      } : null
      maxInactiveRevisions: 10
      registries: [
        {
          passwordSecretRef: 'containerregistry-password'
          server: containerRegistry
          username: containerRegistryUsername
        }
      ]
      secrets: secrets
    }
    template: {
      containers: [
        {
          image: containerImage
          name: containerAppName
          env: env
          args: []
          command: []
          probes: []
          resources: {
            cpu: cpu
            memory: memory
          }
          volumeMounts: []
        }
      ]
      initContainers: []
      revisionSuffix: null
      scale: {
        maxReplicas: 1
        minReplicas: 1
        rules: []
      }
      volumes: []
    }
  }
}


/*** OUTPUT ***/

output fqdn string = hasIngress ? containerApp.properties.configuration.ingress.fqdn : ''
