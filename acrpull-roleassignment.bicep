targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The name of the Azure Container Registry to perform the role assignment on.')
@minLength(1)
param containerRegistryName string

@description('The existing user managed identity resource id to grant the ACR pull role to.')
@minLength(100)
param containerAppUserAssignedResourceId string

@description('Name of the Azure Containers Apps resource.')
@minLength(1)
param containerAppName string

/*** EXISTING RESOURCE ***/

@description('Existing container registry')
resource existingContainerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: containerRegistryName
}

@description('Built-in ACR Pull role')
resource builtInAcrPullRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
}

/*** RESOURCES ***/

@description('The ACR Pull role assignment between the managed identity and the ACR instance.')
resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerAppUserAssignedResourceId, builtInAcrPullRole.id, existingContainerRegistry.id)
  scope: existingContainerRegistry
  properties: {
    principalId: containerAppUserAssignedResourceId
    roleDefinitionId: builtInAcrPullRole.id
    description: 'Allows the ${containerAppName} to pull images from this container registry.'
    principalType: 'ServicePrincipal'
  }
}
