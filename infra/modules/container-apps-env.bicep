// Azure Container Apps Environment
// Serverless container platform with built-in Dapr, KEDA scaling, and observability
// KEY DIFFERENTIATOR: No cluster management, no node pools, no Kubernetes complexity

@description('Name of the Container Apps Environment')
param name string

@description('Location for all resources')
param location string

@description('Tags to apply to all resources')
param tags object = {}

@description('Log Analytics Workspace Customer ID')
param logAnalyticsWorkspaceCustomerId string

@description('Log Analytics Workspace Shared Key')
@secure()
param logAnalyticsWorkspaceSharedKey string

@description('Event Hub connection string for Dapr pub/sub')
@secure()
param eventHubConnectionString string = ''

@description('Event Hub namespace host for managed identity auth (e.g., namespace.servicebus.windows.net)')
param eventHubNamespaceHost string = ''

@description('Event Hub name')
param eventHubName string = 'telemetry'

@description('Consumer group for Event Hub')
param eventHubConsumerGroup string = '$Default'

@description('Storage account name for Event Hub checkpointing')
param storageAccountName string = ''

@description('Storage container name for Event Hub checkpointing')
param storageContainerName string = 'eventhub-checkpoints'

@description('Cosmos DB endpoint URL for Dapr state store')
param cosmosDbUrl string = ''

@description('Cosmos DB primary key for Dapr state store')
@secure()
param cosmosDbKey string = ''

@description('Enable Dapr components (requires connection strings)')
param enableDaprComponents bool = false

@description('Use managed identity for Event Hub authentication')
param useEventHubManagedIdentity bool = false

@description('Use managed identity for Cosmos DB authentication')
param useCosmosDbManagedIdentity bool = false

@description('Client ID of the managed identity for Dapr components')
param managedIdentityClientId string = ''

@description('Cosmos DB database name')
param cosmosDbDatabase string = 'telemetry'

@description('Cosmos DB container name for state store')
param cosmosDbContainer string = 'state'

// ============================================================================
// Container Apps Environment
// This is the serverless equivalent of an AKS cluster - but fully managed!
// ============================================================================

resource containerAppsEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    // Consumption workload profile enables scale-to-zero and pay-per-use
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
    // Integrated logging - no additional configuration needed!
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspaceCustomerId
        sharedKey: logAnalyticsWorkspaceSharedKey
      }
    }
    // Enable peer-to-peer encryption for security
    peerTrafficConfiguration: {
      encryption: {
        enabled: true
      }
    }
  }
}

// ============================================================================
// Dapr Component: Pub/Sub (using Azure Event Hubs)
// KEY DIFFERENTIATOR: Dapr is native to Container Apps, no Helm installation needed
// Supports both connection string and managed identity authentication
// ============================================================================

// Pub/Sub with managed identity (for Event Hubs with SAS disabled)
resource daprPubSubManagedIdentity 'Microsoft.App/managedEnvironments/daprComponents@2024-03-01' = if (enableDaprComponents && useEventHubManagedIdentity && !empty(eventHubNamespaceHost)) {
  name: 'pubsub'
  parent: containerAppsEnv
  properties: {
    componentType: 'pubsub.azure.eventhubs'
    version: 'v1'
    metadata: [
      {
        // Use eventHubNamespace (not namespaceName) for managed identity auth
        // Value should be just the namespace name, not the full hostname
        name: 'eventHubNamespace'
        value: split(eventHubNamespaceHost, '.')[0]
      }
      {
        name: 'hubName'
        value: eventHubName
      }
      {
        name: 'consumerID'
        value: eventHubConsumerGroup
      }
      {
        name: 'storageAccountName'
        value: storageAccountName
      }
      {
        name: 'storageContainerName'
        value: storageContainerName
      }
      {
        name: 'enableEntityManagement'
        value: 'false'
      }
      {
        name: 'azureClientId'
        value: managedIdentityClientId
      }
    ]
    scopes: [
      'ingestion-service'
      'processor-service'
    ]
  }
}

// Pub/Sub with connection string (legacy)
resource daprPubSub 'Microsoft.App/managedEnvironments/daprComponents@2024-03-01' = if (enableDaprComponents && !useEventHubManagedIdentity && !empty(eventHubConnectionString)) {
  name: 'pubsub'
  parent: containerAppsEnv
  properties: {
    componentType: 'pubsub.azure.eventhubs'
    version: 'v1'
    metadata: [
      {
        name: 'connectionString'
        secretRef: 'eventhub-connection'
      }
    ]
    scopes: [
      'ingestion-service'
      'processor-service'
    ]
    secrets: [
      {
        name: 'eventhub-connection'
        value: eventHubConnectionString
      }
    ]
  }
}

// ============================================================================
// Dapr Component: State Store (using Cosmos DB)
// Enables stateful microservices without managing database connections
// Supports both key-based and managed identity authentication
// ============================================================================

// State store with managed identity (for Cosmos DB with local auth disabled)
resource daprStateStoreManagedIdentity 'Microsoft.App/managedEnvironments/daprComponents@2024-03-01' = if (enableDaprComponents && useCosmosDbManagedIdentity && !empty(cosmosDbUrl)) {
  name: 'statestore'
  parent: containerAppsEnv
  properties: {
    componentType: 'state.azure.cosmosdb'
    version: 'v1'
    metadata: [
      {
        name: 'url'
        value: cosmosDbUrl
      }
      {
        name: 'database'
        value: cosmosDbDatabase
      }
      {
        name: 'collection'
        value: cosmosDbContainer
      }
      {
        name: 'azureClientId'
        value: managedIdentityClientId
      }
    ]
    scopes: [
      'ingestion-service'
      'processor-service'
      'api-gateway'
    ]
  }
}

// State store with key (legacy)
resource daprStateStore 'Microsoft.App/managedEnvironments/daprComponents@2024-03-01' = if (enableDaprComponents && !useCosmosDbManagedIdentity && !empty(cosmosDbUrl) && !empty(cosmosDbKey)) {
  name: 'statestore'
  parent: containerAppsEnv
  properties: {
    componentType: 'state.azure.cosmosdb'
    version: 'v1'
    metadata: [
      {
        name: 'url'
        value: cosmosDbUrl
      }
      {
        name: 'masterKey'
        secretRef: 'cosmos-key'
      }
      {
        name: 'database'
        value: cosmosDbDatabase
      }
      {
        name: 'collection'
        value: cosmosDbContainer
      }
    ]
    scopes: [
      'ingestion-service'
      'processor-service'
      'api-gateway'
    ]
    secrets: [
      {
        name: 'cosmos-key'
        value: cosmosDbKey
      }
    ]
  }
}

// ============================================================================
// Outputs
// ============================================================================

output id string = containerAppsEnv.id
output name string = containerAppsEnv.name
output defaultDomain string = containerAppsEnv.properties.defaultDomain
