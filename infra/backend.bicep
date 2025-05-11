param name string
param location string = resourceGroup().location
param tags object = {}

param identityName string
param containerAppsEnvironmentName string
param containerRegistryName string
param serviceName string = 'backend'
param exists bool

resource backendIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}


module backend 'core/host/container-app-upsert.bicep' = {
  name: '${serviceName}-container-app-module'
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    identityName: backendIdentity.name
    exists: exists
    containerAppsEnvironmentName: containerAppsEnvironmentName
    containerRegistryName: containerRegistryName
    env: []
    targetPort: 8000
    secrets: [ ]
  }
}

output SERVICE_BACKEND_IDENTITY_PRINCIPAL_ID string = backendIdentity.properties.principalId
output SERVICE_BACKEND_NAME string = backend.outputs.name
output SERVICE_BACKEND_URI string = backend.outputs.uri
output SERVICE_BACKEND_IMAGE_NAME string = backend.outputs.imageName
