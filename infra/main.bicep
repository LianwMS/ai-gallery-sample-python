targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name which is used to generate a short unique hash for each resource')
param name string

@minLength(1)
@description('Primary location for all resources')
param location string


@description('Id of the user or app to assign application roles')
param principalId string = ''

param webAppExists bool = false

var resourceToken = toLower(uniqueString(subscription().id, name, location))
var tags = { 'azd-env-name': name }

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${name}-rg'
  location: location
  tags: tags
}

var prefix = '${name}-${resourceToken}'

// Store secrets in a keyvault
module keyVault './core/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: resourceGroup
  params: {
    name: '${replace(take(prefix, 17), '-', '')}-vault'
    location: location
    tags: tags
  }
}

// Give the principal access to KeyVault
module principalKeyVaultAccess './core/security/keyvault-access.bicep' = {
  name: 'keyvault-access-${principalId}'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: principalId
  }
}

module logAnalyticsWorkspace 'core/monitor/loganalytics.bicep' = {
  name: 'loganalytics'
  scope: resourceGroup
  params: {
    name: '${prefix}-loganalytics'
    location: location
    tags: tags
  }
}

// Container apps host (including container registry)
module containerApps 'core/host/container-apps.bicep' = {
  name: 'container-apps'
  scope: resourceGroup
  params: {
    name: 'app'
    location: location
    tags: tags
    containerAppsEnvironmentName: '${prefix}-containerapps-env'
    containerRegistryName: '${replace(prefix, '-', '')}registry'
    logAnalyticsWorkspaceName: logAnalyticsWorkspace.outputs.name
  }
}

// backend app
module backend 'backend.bicep' = {
  name: 'backend'
  scope: resourceGroup
  params: {
    name: replace('${take(prefix,19)}-ca-backend', '--', '-')
    location: location
    tags: tags
    identityName: '${prefix}-id-backend'
    containerAppsEnvironmentName: containerApps.outputs.environmentName
    containerRegistryName: containerApps.outputs.registryName
    exists: webAppExists
  }
}

// Give the backend access to KeyVault
module backendKeyVaultAccess './core/security/keyvault-access.bicep' = {
  name: 'backend-keyvault-access'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: backend.outputs.SERVICE_BACKEND_IDENTITY_PRINCIPAL_ID
  }
}

// frontend app
module frontend 'frontend.bicep' = {
  name: 'frontend'
  scope: resourceGroup
  params: {
    name: replace('${take(prefix,19)}-ca-frontend', '--', '-')
    location: location
    tags: tags
    identityName: '${prefix}-id-frontend'
    containerAppsEnvironmentName: containerApps.outputs.environmentName
    containerRegistryName: containerApps.outputs.registryName
    exists: webAppExists
  }
}



output AZURE_LOCATION string = location
output AZURE_CONTAINER_ENVIRONMENT_NAME string = containerApps.outputs.environmentName
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerApps.outputs.registryLoginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerApps.outputs.registryName
output SERVICE_BACKEND_IDENTITY_PRINCIPAL_ID string = backend.outputs.SERVICE_BACKEND_IDENTITY_PRINCIPAL_ID
output SERVICE_BACKEND_NAME string = backend.outputs.SERVICE_BACKEND_NAME
output SERVICE_BACKEND_URI string = backend.outputs.SERVICE_BACKEND_URI
output SERVICE_BACKEND_IMAGE_NAME string = backend.outputs.SERVICE_BACKEND_IMAGE_NAME
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.endpoint
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
