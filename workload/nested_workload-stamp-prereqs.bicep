@description('Azure Container Registry resource group location.')
param location string = resourceGroup().location

resource workflowManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'uid-workflow'
  location: location
  tags: {
    displayName: 'workflow managed identity'
    what: 'rbac'
    reason: 'aad-workload-identity'
    app: 'fabrikam-workflow'
  }
}

resource deliveryManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'uid-delivery'
  location: location
  tags: {
    displayName: 'delivery managed identity'
    what: 'rbac'
    reason: 'aad-workload-identity'
    app: 'fabrikam-delivery'
  }
}

resource droneschedulerManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'uid-dronescheduler'
  location: location
  tags: {
    displayName: 'dronescheduler managed identity'
    what: 'rbac'
    reason: 'aad-workload-identity'
    app: 'fabrikam-dronescheduler'
  }
}

resource ingestionManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'uid-ingestion'
  location: location
  tags: {
    displayName: 'ingestion managed identity'
    what: 'rbac'
    reason: 'aad-workload-identity'
    app: 'fabrikam-ingestion'
  }
}

resource packageManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'uid-package'
  location: location
  tags: {
    displayName: 'package managed identity'
    what: 'rbac'
    reason: 'aad-workload-identity'
    app: 'fabrikam-package'
  }
}
