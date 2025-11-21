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

@description('Optional: HTTP GET path for liveness probe.')
param livenessPath string = ''

@description('Optional: HTTP GET path for readiness probe.')
param readinessPath string = ''

@description('Optional: HTTP GET path for startup probe.')
param startupPath string = ''

@description('The minimum number of replicas for this app.')
@minValue(1)
param minReplicas int = 3

@description('The maximum number of replicas for this app.')
@minValue(1)
param maxReplicas int = 3

/*** VARIABLES ***/

@description('Was ingress requested for this app?')
var hasIngress = (containerPort == -1) ? false : true

/*** EXISTING RESOURCE ***/

@description('Resource group of the existing container registry')
resource containerRegistryResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  scope: subscription()
  name: split(containerRegistryResourceId, '/')[4]
}

@description('Existing container registry')
resource existingContainerRegistry 'Microsoft.ContainerRegistry/registries@2025-05-01-preview' existing = {
  scope: containerRegistryResourceGroup
  name: split(containerRegistryResourceId, '/')[8]
}

@description('Resource group of the existing managed identity')
resource managedIdentityResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  scope: subscription()
  name: split(containerAppUserAssignedResourceId, '/')[4]
}

@description('Existing managed identity for this service')
resource existingManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = {
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

resource containerApp 'Microsoft.App/containerApps@2025-02-02-preview' = {
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
        targetPortHttpScheme: 'http'
        exposedPort: 0
        additionalPortMappings: []
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
      // Production readiness change: For internet-facing workloads, disable built-in public ingress and front the app with Azure Front Door or Application Gateway with WAF & DDoS protection. This provides centralized routing, TLS, WAF rules, and advanced threat mitigation. Trade-off: gateway health probes keep at least one replica warm, reducing scale-to-zero benefits. See https://learn.microsoft.com/azure/container-apps/ingress-overview and https://learn.microsoft.com/azure/web-application-firewall/overview
      // Production readiness change: Enable built-in authentication (Easy Auth) to offload identity & auth concerns from application code. Configure auth providers rather than custom middleware in code. See https://learn.microsoft.com/azure/container-apps/authentication for guidance.
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
          probes: union(
            livenessPath != ''
              ? [
                  {
                    type: 'Liveness'
                    httpGet: {
                      path: livenessPath
                      port: containerPort
                      scheme: 'HTTP'
                    }
                    initialDelaySeconds: 10
                    periodSeconds: 10
                    timeoutSeconds: 5
                    failureThreshold: 3
                  }
                ]
              : [],
            readinessPath != ''
              ? [
                  {
                    type: 'Readiness'
                    httpGet: {
                      path: readinessPath
                      port: containerPort
                      scheme: 'HTTP'
                    }
                    initialDelaySeconds: 5
                    periodSeconds: 10
                    timeoutSeconds: 3
                    failureThreshold: 3
                    successThreshold: 1
                  }
                ]
              : [],
            startupPath != ''
              ? [
                  {
                    type: 'Startup'
                    httpGet: {
                      path: startupPath
                      port: containerPort
                      scheme: 'HTTP'
                    }
                    initialDelaySeconds: 0
                    periodSeconds: 10
                    timeoutSeconds: 3
                    failureThreshold: 3
                  }
                ]
              : []
          )
        }
      ]
      initContainers: []
      revisionSuffix: null
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas // Production readiness change: Adjust maxReplicas based on your workload's scaling needs and enable autoscaling rules for dynamic scaling
        rules: [] // Production readiness change: Add HTTP-based autoscaling rules for services with variable load (e.g., ingestion service). See https://learn.microsoft.com/azure/container-apps/scale-app
      }
      volumes: []
      serviceBinds: []
      terminationGracePeriodSeconds: 30
    }
  }
}

/*** OUTPUT ***/

output fqdn string = hasIngress ? containerApp.properties.configuration.ingress.fqdn : ''
