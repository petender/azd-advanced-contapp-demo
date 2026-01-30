// Azure Cosmos DB for storing processed telemetry data
// Provides global distribution and low-latency access

@description('Name of the Cosmos DB account')
param accountName string

@description('Location for all resources')
param location string

@description('Tags to apply to all resources')
param tags object = {}

@description('Principal ID of the managed identity to grant access')
param managedIdentityPrincipalId string = ''

// Cosmos DB Built-in Data Contributor role (read/write data)
var cosmosDbDataContributorRoleId = '00000000-0000-0000-0000-000000000002'

// ============================================================================
// Cosmos DB Account
// ============================================================================

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: accountName
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session' // Good balance for IoT workloads
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless' // Cost-effective for bursty workloads
      }
    ]
    // Security best practices
    disableKeyBasedMetadataWriteAccess: false
    disableLocalAuth: false // Using managed identity is recommended for production
    publicNetworkAccess: 'Enabled'
    enableFreeTier: false
    minimalTlsVersion: 'Tls12'
  }
}

// ============================================================================
// Database for Telemetry
// ============================================================================

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  name: 'telemetry'
  parent: cosmosAccount
  properties: {
    resource: {
      id: 'telemetry'
    }
  }
}

// ============================================================================
// Container for Raw Events
// ============================================================================

resource eventsContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  name: 'events'
  parent: database
  properties: {
    resource: {
      id: 'events'
      partitionKey: {
        paths: ['/deviceId']
        kind: 'Hash'
        version: 2
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/payload/*' // Exclude raw payload for performance
          }
        ]
      }
      defaultTtl: 86400 // 24 hours TTL for raw events
    }
  }
}

// ============================================================================
// Container for Aggregated Metrics
// ============================================================================

resource metricsContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  name: 'metrics'
  parent: database
  properties: {
    resource: {
      id: 'metrics'
      partitionKey: {
        paths: ['/deviceId', '/timestamp']
        kind: 'MultiHash'
        version: 2
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
      }
    }
  }
}

// ============================================================================
// Container for Dapr State Store
// ============================================================================

resource stateContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  name: 'state'
  parent: database
  properties: {
    resource: {
      id: 'state'
      partitionKey: {
        paths: ['/partitionKey']
        kind: 'Hash'
        version: 2
      }
    }
  }
}

// ============================================================================
// RBAC Role Assignment for Managed Identity
// Grants Cosmos DB Built-in Data Contributor role (read/write data)
// ============================================================================

resource cosmosRbacRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = if (!empty(managedIdentityPrincipalId)) {
  name: guid(cosmosAccount.id, managedIdentityPrincipalId, cosmosDbDataContributorRoleId)
  parent: cosmosAccount
  properties: {
    roleDefinitionId: '${cosmosAccount.id}/sqlRoleDefinitions/${cosmosDbDataContributorRoleId}'
    principalId: managedIdentityPrincipalId
    scope: cosmosAccount.id
  }
}

// ============================================================================
// Outputs
// ============================================================================

output accountId string = cosmosAccount.id
output accountName string = cosmosAccount.name
output endpoint string = cosmosAccount.properties.documentEndpoint

#disable-next-line outputs-should-not-contain-secrets // Used internally for Container Apps secrets
output connectionString string = cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString

#disable-next-line outputs-should-not-contain-secrets // Used internally for Dapr state store
output primaryKey string = cosmosAccount.listKeys().primaryMasterKey
