// Container Apps Jobs Demo - Main Bicep Template
// Deploys both scheduled and manual jobs to demonstrate Container Apps Jobs

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Location for all resources')
param location string = resourceGroup().location

@description('Container Apps Environment name (from main deployment)')
param containerAppsEnvironmentName string

@description('Container Registry name (from main deployment)')
param containerRegistryName string

@description('Tags to apply to resources')
param tags object = {
  'demo-scenario': 'container-jobs'
}

// ============================================================================
// Existing Resources
// ============================================================================

resource containerAppsEnv 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: containerAppsEnvironmentName
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: containerRegistryName
}

// ============================================================================
// Container Apps Jobs
// ============================================================================

// Scheduled Job - Runs every 2 minutes
module scheduledJob './job.bicep' = {
  name: 'scheduled-job'
  params: {
    name: 'data-processor-scheduled'
    location: location
    tags: union(tags, { 'job-type': 'scheduled' })
    containerAppsEnvironmentId: containerAppsEnv.id
    containerRegistryName: containerRegistry.name
    containerImage: '${containerRegistry.properties.loginServer}/demo-job:latest'
    triggerType: 'Schedule'
    cronExpression: '*/2 * * * *'  // Every 2 minutes
    parallelism: 1
    replicaTimeout: 120
  }
}

// Manual Job - Triggered on-demand
module manualJob './job.bicep' = {
  name: 'manual-job'
  params: {
    name: 'data-processor-manual'
    location: location
    tags: union(tags, { 'job-type': 'manual' })
    containerAppsEnvironmentId: containerAppsEnv.id
    containerRegistryName: containerRegistry.name
    containerImage: '${containerRegistry.properties.loginServer}/demo-job:latest'
    triggerType: 'Manual'
    parallelism: 1
    replicaTimeout: 120
  }
}

// Parallel Job - Runs 3 replicas in parallel (for demonstrating parallelism)
module parallelJob './job.bicep' = {
  name: 'parallel-job'
  params: {
    name: 'data-processor-parallel'
    location: location
    tags: union(tags, { 'job-type': 'parallel' })
    containerAppsEnvironmentId: containerAppsEnv.id
    containerRegistryName: containerRegistry.name
    containerImage: '${containerRegistry.properties.loginServer}/demo-job:latest'
    triggerType: 'Manual'
    parallelism: 3  // Run 3 instances in parallel
    replicaTimeout: 120
  }
}

// ============================================================================
// Outputs
// ============================================================================

output scheduledJobName string = scheduledJob.outputs.name
output manualJobName string = manualJob.outputs.name
output parallelJobName string = parallelJob.outputs.name
