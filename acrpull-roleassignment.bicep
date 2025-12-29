targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The name of the Azure Container Registry to perform the role assignment on.')
@minLength(5)
param containerRegistryName string

@description('The existing user managed identity pricipal id to grant the ACR pull role to. This is a GUID.')
@minLength(36)
@maxLength(36)
param containerAppUserPrincipalId string

@description('Name of the Azure Containers Apps resource.')
@minLength(1)
param containerAppName string

/*** EXISTING RESOURCE ***/

@description('Existing container registry')
resource existingContainerRegistry 'Microsoft.ContainerRegistry/registries@2025-11-01' existing = {
  name: containerRegistryName
}

@description('Built-in ACR Pull role')
resource builtInAcrPullRole 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  scope: subscription()
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
}

/*** RESOURCES ***/

@description('The ACR Pull role assignment between the managed identity and the ACR instance.')
resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerAppUserPrincipalId, builtInAcrPullRole.id, existingContainerRegistry.id)
  scope: existingContainerRegistry
  properties: {
    principalId: containerAppUserPrincipalId
    roleDefinitionId: builtInAcrPullRole.id
    description: 'Allows the ${containerAppName} to pull images from this container registry.'
    principalType: 'ServicePrincipal'
  }
}
