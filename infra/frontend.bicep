param name string
param location string = resourceGroup().location
param tags object = {}

param identityName string
param containerAppsEnvironmentName string
param containerRegistryName string
param serviceName string = 'frontend'
param exists bool

resource frontendIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}


module frontend 'core/host/container-app-upsert.bicep' = {
  name: '${serviceName}-container-app-module'
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    identityName: frontendIdentity.name
    exists: exists
    containerAppsEnvironmentName: containerAppsEnvironmentName
    containerRegistryName: containerRegistryName
    env: []
    targetPort: 8000
    secrets: [ ]
  }
}

output SERVICE_FRONT_IDENTITY_PRINCIPAL_ID string = frontendIdentity.properties.principalId
output SERVICE_FRONT_NAME string = frontend.outputs.name
output SERVICE_FRONT_URI string = frontend.outputs.uri
output SERVICE_FRONT_IMAGE_NAME string = frontend.outputs.imageName
