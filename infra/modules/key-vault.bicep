// Azure Key Vault for secure secret management
// Stores connection strings and keys accessed by Container Apps via managed identity

@description('Name of the Key Vault')
param name string

@description('Location for all resources')
param location string

@description('Tags to apply to all resources')
param tags object = {}

@description('Principal ID of the managed identity that needs access')
param managedIdentityPrincipalId string

@description('Principal ID of the deploying user for Key Vault management')
param deployingUserPrincipalId string = ''

@description('Event Hub connection string to store')
@secure()
param eventHubConnectionString string

@description('Cosmos DB connection string to store')
@secure()
param cosmosDbConnectionString string

@description('Log Analytics shared key to store')
@secure()
param logAnalyticsSharedKey string

// ============================================================================
// Key Vault
// ============================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true // Cannot be disabled once enabled
    publicNetworkAccess: 'Enabled'
  }
}

// ============================================================================
// RBAC: Grant Managed Identity access to read secrets
// ============================================================================

// Key Vault Secrets User role
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, managedIdentityPrincipalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Key Vault Secrets Officer role for deploying user (manage secrets)
var keyVaultSecretsOfficerRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'

resource keyVaultSecretsOfficerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(deployingUserPrincipalId)) {
  name: guid(keyVault.id, deployingUserPrincipalId, keyVaultSecretsOfficerRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsOfficerRoleId)
    principalId: deployingUserPrincipalId
    principalType: 'User'
  }
}

// ============================================================================
// Secrets
// ============================================================================

resource eventHubSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'eventhub-connection-string'
  parent: keyVault
  properties: {
    value: eventHubConnectionString
    contentType: 'text/plain'
  }
}

resource cosmosDbSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'cosmosdb-connection-string'
  parent: keyVault
  properties: {
    value: cosmosDbConnectionString
    contentType: 'text/plain'
  }
}

resource logAnalyticsSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'log-analytics-shared-key'
  parent: keyVault
  properties: {
    value: logAnalyticsSharedKey
    contentType: 'text/plain'
  }
}

// ============================================================================
// Outputs
// ============================================================================

output id string = keyVault.id
output name string = keyVault.name
output uri string = keyVault.properties.vaultUri

// Secret URIs for Container Apps Key Vault references
output eventHubSecretUri string = eventHubSecret.properties.secretUri
output cosmosDbSecretUri string = cosmosDbSecret.properties.secretUri
output logAnalyticsSecretUri string = logAnalyticsSecret.properties.secretUri
