param containerAppName string
param location string = resourceGroup().location
param environmentId string
param containerImage string
param containerPort int
param isExternalIngress bool
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

var registrySecretRefName = 'containerregistry-password'

resource containerApp 'Microsoft.Web/containerApps@2021-03-01' = {
  name: containerAppName
  kind: 'containerapp'
  location: location
  properties: {
    kubeEnvironmentId: environmentId
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
      ingress: {
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
      }
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

output fqdn string = containerApp.properties.configuration.ingress.fqdn
