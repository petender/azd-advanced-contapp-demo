// Azure Event Hubs for high-throughput event ingestion
// Handles millions of events per second from IoT sensors

@description('Name of the Event Hub Namespace')
param namespaceName string

@description('Location for all resources')
param location string

@description('Tags to apply to all resources')
param tags object = {}

@description('SKU for the Event Hub Namespace')
@allowed(['Basic', 'Standard', 'Premium'])
param sku string = 'Standard'

@description('Throughput units for Standard SKU')
@minValue(1)
@maxValue(20)
param capacity int = 1

@description('Principal ID of the managed identity for Event Hubs Data Receiver role')
param managedIdentityPrincipalId string = ''

// ============================================================================
// Event Hub Namespace
// ============================================================================

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' = {
  name: namespaceName
  location: location
  tags: tags
  sku: {
    name: sku
    tier: sku
    capacity: capacity
  }
  properties: {
    isAutoInflateEnabled: true
    maximumThroughputUnits: 10
    kafkaEnabled: true // Kafka protocol support
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false // Using managed identity is recommended for production
  }
}

// ============================================================================
// Event Hub for Telemetry
// ============================================================================

resource telemetryHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = {
  name: 'telemetry'
  parent: eventHubNamespace
  properties: {
    messageRetentionInDays: 1
    partitionCount: 8 // Enables parallel processing
    status: 'Active'
  }
}

// Consumer group for ingestion service
resource ingestionConsumerGroup 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2024-01-01' = {
  name: 'ingestion'
  parent: telemetryHub
  properties: {
    userMetadata: 'Consumer group for ingestion service'
  }
}

// Consumer group for processor service
resource processorConsumerGroup 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2024-01-01' = {
  name: 'processor'
  parent: telemetryHub
  properties: {
    userMetadata: 'Consumer group for processor service'
  }
}

// ============================================================================
// Authorization Rules
// ============================================================================

resource sendListenRule 'Microsoft.EventHub/namespaces/authorizationRules@2024-01-01' = {
  name: 'SendListenPolicy'
  parent: eventHubNamespace
  properties: {
    rights: [
      'Listen'
      'Send'
    ]
  }
}

// ============================================================================
// RBAC: Event Hubs Data Receiver Role for Managed Identity
// Required for Azure Entra ID authentication
// ============================================================================

// Azure Event Hubs Data Receiver role
var eventHubsDataReceiverRoleId = 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde'

resource eventHubsDataReceiverRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(managedIdentityPrincipalId)) {
  name: guid(eventHubNamespace.id, managedIdentityPrincipalId, eventHubsDataReceiverRoleId)
  scope: eventHubNamespace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', eventHubsDataReceiverRoleId)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Azure Event Hubs Data Sender role (for sending events)
var eventHubsDataSenderRoleId = '2b629674-e913-4c01-ae53-ef4638d8f975'

resource eventHubsDataSenderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(managedIdentityPrincipalId)) {
  name: guid(eventHubNamespace.id, managedIdentityPrincipalId, eventHubsDataSenderRoleId)
  scope: eventHubNamespace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', eventHubsDataSenderRoleId)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// Outputs
// ============================================================================

output namespaceId string = eventHubNamespace.id
output namespaceName string = eventHubNamespace.name
output namespaceHost string = '${eventHubNamespace.name}.servicebus.windows.net'
output telemetryHubName string = telemetryHub.name

#disable-next-line outputs-should-not-contain-secrets // Used internally for Container Apps secrets
output connectionString string = sendListenRule.listKeys().primaryConnectionString
