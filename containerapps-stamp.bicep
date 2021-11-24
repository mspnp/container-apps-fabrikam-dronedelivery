param logAnalitycsCustomerId string

@secure()
param logAnalitycsSharedKey string

param acrSever string

resource cae 'Microsoft.Web/kubeenvironments@2021-02-01' = {
  name: 'cae-shipping-dronedelivery'
  kind: 'containerenvironment'
  location: resourceGroup().location
  properties: {
    type: 'managed'
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalitycsCustomerId
        sharedKey: logAnalitycsSharedKey
      }
    }
  }
}

resource my_container_app 'Microsoft.Web/containerApps@2021-03-01' = {
  name: 'my-container-app'
  kind: 'containerapp'
  location: resourceGroup().location
  properties: {
    kubeEnvironmentId: cae.id
    configuration: {
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
          image: '${acrSever}/azuredocs/containerapps-helloworld:latest'
          name: 'my-container-app'
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
