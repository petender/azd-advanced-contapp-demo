# CloudBurst Analytics - Hands-On Lab Guide

> **Estimated Duration:** 90-120 minutes  
> **Skill Level:** Intermediate  
> **Prerequisites:** Azure subscription with Contributor access, Azure CLI, Docker Desktop

---

## 🎯 Lab Objectives

By the end of this lab, you will be able to:

1. Deploy Azure Container Apps infrastructure using Bicep templates via Azure CLI
2. Build and push container images to Azure Container Registry
3. Deploy and update Container Apps with your custom images
4. Validate HTTP auto-scaling behavior under load
5. Implement traffic splitting for blue-green deployments
6. Work with Container Apps Jobs for batch processing

---

## 📋 Lab Overview

This lab guides you through deploying and operating the **CloudBurst Analytics** platform, an event-driven microservices application built on Azure Container Apps. You will work with:

| Component | Description | Demo Scenario |
|-----------|-------------|---------------|
| `ingestion-service` | Python FastAPI service that processes events | Auto-Scaling |
| `dashboard` | React frontend for load testing | Auto-Scaling |
| `hello-api` | Node.js API with version badges | Traffic Splitting |
| `demo-job` | Python batch processing job | Container Jobs |

---

## 🔧 Part 1: Environment Setup

### Exercise 1.1: Verify Prerequisites

Ensure you have the following tools installed and configured:

```powershell
# Check Azure CLI version (requires 2.50+)
az version

# Check Docker is running
docker --version

# Login to Azure
az login

# Set your subscription (replace with your subscription ID or name)
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"

# Verify current subscription
az account show --query "{Name:name, SubscriptionId:id}" -o table
```

### Exercise 1.2: Clone the Repository

```powershell
# Clone the repository
git clone https://github.com/petender/azd-advanced-contapp-demo.git

# Navigate to the project directory
cd azd-advanced-contapp-demo
```

### Exercise 1.3: Set Environment Variables

Define the environment variables that will be used throughout the lab:

```powershell
# Set your environment name (use lowercase, no special characters)
$ENV_NAME = "yourname-lab"  # Example: "john-lab"

# Set the Azure region
$LOCATION = "eastus2"

# Get your user principal ID (for Key Vault access)
$PRINCIPAL_ID = (az ad signed-in-user show --query id -o tsv)

# Verify the principal ID was retrieved
Write-Host "Principal ID: $PRINCIPAL_ID"
```

> ⚠️ **Important:** Replace `yourname-lab` with a unique name. This will be used to create globally unique resource names.

---

## 🏗️ Part 2: Deploy Infrastructure with Bicep

### Exercise 2.1: Review the Bicep Template

Before deploying, examine the main Bicep template to understand what resources will be created:

```powershell
# Open the main Bicep file to review
Get-Content .\infra\main.bicep | Select-Object -First 80
```

**Resources created by the template:**
- Resource Group
- Log Analytics Workspace
- User-Assigned Managed Identity
- Azure Container Registry
- Container Apps Environment
- Azure Event Hubs Namespace
- Azure Cosmos DB (serverless)
- Azure Key Vault
- Container Apps (with placeholder images)
- Container Apps Jobs (with placeholder images)

### Exercise 2.2: Deploy the Infrastructure

Deploy the Bicep template using Azure CLI:

```powershell
# Deploy infrastructure at subscription scope
az deployment sub create `
    --name "cloudburst-$ENV_NAME" `
    --location $LOCATION `
    --template-file .\infra\main.bicep `
    --parameters environmentName=$ENV_NAME `
    --parameters location=$LOCATION `
    --parameters principalId=$PRINCIPAL_ID `
    --query "properties.outputs" -o json
```

> ⏱️ **Expected Duration:** 5-8 minutes

### Exercise 2.3: Capture Deployment Outputs

After deployment completes, capture the output values for later use:

```powershell
# Get deployment outputs
$OUTPUTS = az deployment sub show `
    --name "cloudburst-$ENV_NAME" `
    --query "properties.outputs" -o json | ConvertFrom-Json

# Extract key values
$RG = $OUTPUTS.AZURE_RESOURCE_GROUP.value
$ACR = $OUTPUTS.CONTAINER_REGISTRY_LOGIN_SERVER.value
$ACR_NAME = $OUTPUTS.CONTAINER_REGISTRY_NAME.value
$CAE_NAME = $OUTPUTS.CONTAINER_APPS_ENVIRONMENT_NAME.value
$DASHBOARD_URL = $OUTPUTS.DASHBOARD_URL.value
$INGESTION_URL = $OUTPUTS.INGESTION_SERVICE_URL.value
$HELLO_API_URL = $OUTPUTS.HELLO_API_URL.value

# Display captured values
Write-Host "========================================="
Write-Host "Resource Group:        $RG"
Write-Host "Container Registry:    $ACR"
Write-Host "Environment:           $CAE_NAME"
Write-Host "Dashboard URL:         $DASHBOARD_URL"
Write-Host "Ingestion Service URL: $INGESTION_URL"
Write-Host "Hello API URL:         $HELLO_API_URL"
Write-Host "========================================="
```

### Exercise 2.4: Verify Initial Deployment

Check that all resources were created:

```powershell
# List all resources in the resource group
az resource list -g $RG --query "[].{Name:name, Type:type}" -o table

# List Container Apps
az containerapp list -g $RG --query "[].{Name:name, URL:properties.configuration.ingress.fqdn}" -o table

# List Container Apps Jobs
az containerapp job list -g $RG --query "[].{Name:name, TriggerType:properties.configuration.triggerType}" -o table
```

> 📝 **Note:** At this point, the Container Apps are running with placeholder images (`containerapps-helloworld`). In the next section, you will build and deploy the actual application images.

---

## 📦 Part 3: Build and Deploy Container Images

### Exercise 3.1: Login to Azure Container Registry

```powershell
# Login to ACR
az acr login --name $ACR_NAME
```

### Exercise 3.2: Build and Push the Ingestion Service

```powershell
# Navigate to the ingestion-service directory
cd src/ingestion-service

# Build the container image
docker build -t "$ACR/ingestion-service:v1" .

# Push to Azure Container Registry
docker push "$ACR/ingestion-service:v1"

# Return to project root
cd ../..
```

### Exercise 3.3: Build and Push the Dashboard

```powershell
# Navigate to the dashboard directory
cd src/dashboard

# Build the container image
docker build -t "$ACR/dashboard:v1" .

# Push to Azure Container Registry
docker push "$ACR/dashboard:v1"

# Return to project root
cd ../..
```

### Exercise 3.4: Build and Push the Hello API

```powershell
# Navigate to the hello-api directory
cd src/hello-api

# Build v1 of the Hello API (blue version)
docker build -t "$ACR/hello-api:v1" --build-arg APP_VERSION=v1 .

# Push to Azure Container Registry
docker push "$ACR/hello-api:v1"

# Return to project root
cd ../..
```

### Exercise 3.5: Build and Push the Demo Job

```powershell
# Navigate to the demo-job directory
cd src/demo-job

# Build the job image
docker build -t "$ACR/demo-job:v1" .

# Push to Azure Container Registry
docker push "$ACR/demo-job:v1"

# Return to project root
cd ../..
```

### Exercise 3.6: Verify Images in ACR

```powershell
# List all repositories in ACR
az acr repository list --name $ACR_NAME -o table

# List tags for each repository
az acr repository show-tags --name $ACR_NAME --repository ingestion-service -o table
az acr repository show-tags --name $ACR_NAME --repository dashboard -o table
az acr repository show-tags --name $ACR_NAME --repository hello-api -o table
az acr repository show-tags --name $ACR_NAME --repository demo-job -o table
```

---

## 🚀 Part 4: Update Container Apps with Custom Images

### Exercise 4.1: Update the Ingestion Service

```powershell
# Update the ingestion-service with the custom image
az containerapp update `
    --name ingestion-service `
    --resource-group $RG `
    --image "$ACR/ingestion-service:v1"

# Verify the update
az containerapp show -n ingestion-service -g $RG `
    --query "{Name:name, Image:properties.template.containers[0].image, Status:properties.runningStatus}" -o table
```

### Exercise 4.2: Update the Dashboard

```powershell
# Update the dashboard with the custom image
az containerapp update `
    --name dashboard `
    --resource-group $RG `
    --image "$ACR/dashboard:v1"

# Verify the update
az containerapp show -n dashboard -g $RG `
    --query "{Name:name, Image:properties.template.containers[0].image, Status:properties.runningStatus}" -o table
```

### Exercise 4.3: Update the Hello API

```powershell
# Update the hello-api with the custom image
az containerapp update `
    --name hello-api `
    --resource-group $RG `
    --image "$ACR/hello-api:v1"

# Verify the update
az containerapp show -n hello-api -g $RG `
    --query "{Name:name, Image:properties.template.containers[0].image, Status:properties.runningStatus}" -o table
```

### Exercise 4.4: Update the Container Apps Jobs

```powershell
# Update all three jobs with the demo-job image
az containerapp job update -n data-processor-scheduled -g $RG --image "$ACR/demo-job:v1"
az containerapp job update -n data-processor-manual -g $RG --image "$ACR/demo-job:v1"
az containerapp job update -n data-processor-parallel -g $RG --image "$ACR/demo-job:v1"

# Verify the updates
az containerapp job list -g $RG `
    --query "[].{Name:name, Image:properties.template.containers[0].image}" -o table
```

### Exercise 4.5: Validate All Services Are Running

```powershell
# Check all Container Apps are running
az containerapp list -g $RG `
    --query "[].{Name:name, Status:properties.runningStatus, Replicas:properties.template.scale.minReplicas}" -o table

# Test the endpoints
Write-Host "`nTesting Dashboard..."
Invoke-RestMethod -Uri "$DASHBOARD_URL/health" -TimeoutSec 30

Write-Host "`nTesting Ingestion Service..."
Invoke-RestMethod -Uri "$INGESTION_URL/health" -TimeoutSec 30

Write-Host "`nTesting Hello API..."
Invoke-RestMethod -Uri "$HELLO_API_URL/api/version" -TimeoutSec 30
```

---

## 📈 Part 5: Scenario 1 - HTTP Auto-Scaling

In this scenario, you will observe how Azure Container Apps automatically scales the ingestion-service based on HTTP traffic.

### Exercise 5.1: Check Initial Replica Count

```powershell
# Check the current number of replicas
az containerapp replica list -n ingestion-service -g $RG -o table

# Note: Should show 1 replica (minReplicas is set to 1)
```

### Exercise 5.2: Review Scaling Configuration

```powershell
# View the scaling rules configured for the ingestion-service
az containerapp show -n ingestion-service -g $RG `
    --query "properties.template.scale" -o json
```

> 📝 **Note:** The `concurrentRequests` is set to `2`, meaning the service will scale up when there are more than 2 concurrent requests per replica.

### Exercise 5.3: Open the Dashboard

Open the dashboard URL in your browser:

```powershell
# Display the dashboard URL
Write-Host "Open this URL in your browser: $DASHBOARD_URL"

# Or open directly (Windows)
Start-Process $DASHBOARD_URL
```

### Exercise 5.4: Trigger Load and Observe Scaling

1. In the dashboard, click the **🔥 Send 100 Events (Heavy Load)** button
2. Watch the status message showing events being sent

While the load test is running, monitor the replica count:

```powershell
# Run this command multiple times during the load test to see scaling
az containerapp replica list -n ingestion-service -g $RG -o table

# Or watch continuously (run in a separate terminal)
while ($true) {
    $count = (az containerapp replica list -n ingestion-service -g $RG -o json | ConvertFrom-Json).Count
    Write-Host "$(Get-Date -Format 'HH:mm:ss') - Replica count: $count"
    Start-Sleep -Seconds 5
}
```

### Exercise 5.5: Observe Scale-Down

After the load test completes, wait for the cooldown period (default 5 minutes) and observe the replicas scaling back down:

```powershell
# Check replica count after load subsides
az containerapp replica list -n ingestion-service -g $RG -o table
```

### Exercise 5.6: View Scaling Metrics in Azure Portal

1. Navigate to the **Azure Portal** → **Resource Group** → **ingestion-service**
2. Go to **Metrics**
3. Add the metric **Replica Count**
4. Observe the scaling behavior over time

> ✅ **Checkpoint:** You should have observed the ingestion-service scaling from 1 replica up to multiple replicas during load, then back down after the cooldown period.

---

## 🔀 Part 6: Scenario 2 - Traffic Splitting

In this scenario, you will deploy a second version of the Hello API and implement traffic splitting for a blue-green deployment.

### Exercise 6.1: Verify Version 1 is Running

```powershell
# Open Hello API in browser
Start-Process $HELLO_API_URL

# Or test via CLI
Invoke-RestMethod -Uri "$HELLO_API_URL/api/version"
```

You should see a **blue "v1"** badge on the page.

### Exercise 6.2: Enable Multiple Revision Mode

To split traffic between multiple versions, enable multiple revision mode:

```powershell
# Enable multiple revision mode
az containerapp revision set-mode `
    --name hello-api `
    --resource-group $RG `
    --mode Multiple

# Verify the mode change
az containerapp show -n hello-api -g $RG `
    --query "properties.configuration.activeRevisionsMode" -o tsv
```

### Exercise 6.3: Build and Push Version 2

```powershell
# Navigate to the hello-api directory
cd src/hello-api

# Build v2 (green version)
docker build -t "$ACR/hello-api:v2" --build-arg APP_VERSION=v2 .

# Push to ACR
docker push "$ACR/hello-api:v2"

# Return to project root
cd ../..
```

### Exercise 6.4: Deploy Version 2 as a New Revision

```powershell
# Deploy v2 as a new revision with a custom suffix
az containerapp update `
    --name hello-api `
    --resource-group $RG `
    --image "$ACR/hello-api:v2" `
    --revision-suffix v2 `
    --set-env-vars "APP_VERSION=v2"
```

### Exercise 6.5: List All Revisions

```powershell
# List all revisions of hello-api
az containerapp revision list -n hello-api -g $RG `
    --query "[].{Name:name, Active:properties.active, TrafficWeight:properties.trafficWeight, Created:properties.createdTime}" -o table
```

> 📝 **Note:** At this point, 100% of traffic goes to the latest revision (v2).

### Exercise 6.6: Split Traffic 50/50

```powershell
# Get the revision names
$REVISIONS = az containerapp revision list -n hello-api -g $RG --query "[].name" -o tsv
Write-Host "Available revisions:`n$REVISIONS"

# Get the v1 revision name (the one without 'v2' suffix)
$REV_V1 = az containerapp revision list -n hello-api -g $RG `
    --query "[?!contains(name, 'v2')].name" -o tsv | Select-Object -First 1

# Split traffic 50/50
az containerapp ingress traffic set `
    --name hello-api `
    --resource-group $RG `
    --revision-weight "$REV_V1=50" "hello-api--v2=50"
```

### Exercise 6.7: Verify Traffic Splitting

```powershell
# Check the traffic distribution
az containerapp ingress traffic show -n hello-api -g $RG -o table
```

### Exercise 6.8: Test Traffic Splitting

Refresh the Hello API page multiple times in your browser. You should see it alternate between:
- **Blue "v1"** badge
- **Green "v2"** badge

Or test via CLI:

```powershell
# Make multiple requests and observe the version
1..10 | ForEach-Object {
    $response = Invoke-RestMethod -Uri "$HELLO_API_URL/api/version"
    Write-Host "Request $_`: Version = $($response.version)"
    Start-Sleep -Milliseconds 500
}
```

### Exercise 6.9: Complete the Migration

Shift 100% of traffic to v2:

```powershell
# Route all traffic to v2
az containerapp ingress traffic set `
    --name hello-api `
    --resource-group $RG `
    --revision-weight "hello-api--v2=100"

# Verify
az containerapp ingress traffic show -n hello-api -g $RG -o table
```

### Exercise 6.10: (Optional) Rollback to v1

If needed, you can instantly roll back:

```powershell
# Rollback to v1
az containerapp ingress traffic set `
    --name hello-api `
    --resource-group $RG `
    --revision-weight "$REV_V1=100"
```

> ✅ **Checkpoint:** You have successfully implemented blue-green deployment with traffic splitting, allowing you to gradually migrate users between versions.

---

## ⚡ Part 7: Scenario 3 - Container Apps Jobs

In this scenario, you will work with Container Apps Jobs for batch processing tasks.

### Exercise 7.1: List All Jobs

```powershell
# List all Container Apps Jobs
az containerapp job list -g $RG `
    --query "[].{Name:name, TriggerType:properties.configuration.triggerType, Schedule:properties.configuration.scheduleTriggerConfig.cronExpression}" -o table
```

You should see three jobs:
| Name | Trigger Type | Schedule |
|------|--------------|----------|
| data-processor-scheduled | Schedule | */2 * * * * |
| data-processor-manual | Manual | - |
| data-processor-parallel | Manual | - |

### Exercise 7.2: View Scheduled Job Executions

The scheduled job runs every 2 minutes. Check its execution history:

```powershell
# List executions for the scheduled job
az containerapp job execution list `
    --name data-processor-scheduled `
    --resource-group $RG `
    --query "[].{Name:name, Status:properties.status, StartTime:properties.startTime}" -o table
```

> 📝 **Note:** If no executions appear, wait 2 minutes for the first scheduled run.

### Exercise 7.3: View Job Logs

```powershell
# Get the latest execution name
$EXECUTION = az containerapp job execution list `
    --name data-processor-scheduled `
    --resource-group $RG `
    --query "[0].name" -o tsv

Write-Host "Latest execution: $EXECUTION"

# View logs for the execution (via Azure Portal is recommended)
Write-Host "View logs in Azure Portal:"
Write-Host "Portal → Resource Group → data-processor-scheduled → Execution history → $EXECUTION → Console logs"
```

### Exercise 7.4: Trigger a Manual Job

```powershell
# Start the manual job
$JOB_EXECUTION = az containerapp job start `
    --name data-processor-manual `
    --resource-group $RG `
    --query "name" -o tsv

Write-Host "Started job execution: $JOB_EXECUTION"

# Wait for completion
Write-Host "Waiting for job to complete..."
Start-Sleep -Seconds 20

# Check execution status
az containerapp job execution list `
    --name data-processor-manual `
    --resource-group $RG `
    --query "[0].{Name:name, Status:properties.status, StartTime:properties.startTime, EndTime:properties.endTime}" -o table
```

### Exercise 7.5: Trigger a Parallel Job

The parallel job runs 3 instances simultaneously:

```powershell
# Start the parallel job
az containerapp job start `
    --name data-processor-parallel `
    --resource-group $RG

Write-Host "Started parallel job with 3 replicas"

# Wait and check status
Start-Sleep -Seconds 25

# View execution details
az containerapp job execution list `
    --name data-processor-parallel `
    --resource-group $RG `
    --query "[0].{Name:name, Status:properties.status}" -o table
```

### Exercise 7.6: View Parallel Execution in Portal

1. Navigate to **Azure Portal** → **Resource Group** → **data-processor-parallel**
2. Go to **Execution history**
3. Click on the latest execution
4. Observe that 3 replicas ran simultaneously

> ✅ **Checkpoint:** You have successfully worked with Container Apps Jobs, including scheduled jobs, manual triggers, and parallel execution.

---

## 🧹 Part 8: Cleanup

When you're finished with the lab, clean up the resources to avoid ongoing charges:

### Exercise 8.1: Delete All Resources

```powershell
# Delete the resource group and all resources within it
az group delete --name $RG --yes --no-wait

Write-Host "Resource group deletion initiated. This may take a few minutes."
```

### Exercise 8.2: Verify Deletion

```powershell
# Check if resource group still exists
az group exists --name $RG
```

---

## 📚 Summary

In this lab, you have learned how to:

| Skill | What You Did |
|-------|--------------|
| **Infrastructure Deployment** | Deployed Azure Container Apps infrastructure using Bicep templates via Azure CLI |
| **Container Management** | Built, pushed, and deployed container images to Azure Container Registry |
| **Auto-Scaling** | Observed HTTP-based auto-scaling under load with no additional configuration |
| **Traffic Splitting** | Implemented blue-green deployments with percentage-based traffic routing |
| **Container Jobs** | Worked with scheduled, manual, and parallel batch processing jobs |
| **Security** | Used Managed Identity and Key Vault for secure secret management |

### Key Takeaways

1. **Azure Container Apps** provides a serverless container platform without Kubernetes complexity
2. **Auto-scaling** is built-in and requires only simple threshold configuration
3. **Traffic splitting** enables zero-downtime deployments and A/B testing
4. **Container Jobs** replace Kubernetes CronJobs with simpler configuration
5. **Managed Identity** provides secure, passwordless authentication to Azure services

---

## 🔗 Additional Resources

- [Azure Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [Container Apps Scaling](https://learn.microsoft.com/azure/container-apps/scale-app)
- [Traffic Splitting](https://learn.microsoft.com/azure/container-apps/revisions-manage)
- [Container Apps Jobs](https://learn.microsoft.com/azure/container-apps/jobs)
- [Managed Identity](https://learn.microsoft.com/azure/container-apps/managed-identity)

---

*Lab Guide Version: 1.0 | Last Updated: January 30, 2026*
