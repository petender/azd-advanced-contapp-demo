# CloudBurst Analytics - Complete Demo Runbook

> **Total Demo Duration:** 25-30 minutes  
> **Target Audience:** Developers, Architects, DevOps Engineers  
> **Key Message:** Azure Container Apps delivers enterprise features without Kubernetes complexity

---

## 📋 Pre-Demo Checklist

### Environment Setup (10 minutes before)

- [ ] **Azure Subscription** - Ensure you have Contributor access
- [ ] **Azure CLI** - Logged in (`az login`)
- [ ] **Azure Developer CLI** - Installed and logged in (`azd auth login`)
- [ ] **Docker Desktop** - Running (for local builds)
- [ ] **Browser Tabs Ready:**
  - [ ] Azure Portal (portal.azure.com)
  - [ ] Dashboard URL (after deployment)
  - [ ] Hello API URL (after deployment)

### Initial Deployment

```powershell
# Deploy the complete demo environment (all 3 demos)
azd up

# Note the output URLs for:
# - DASHBOARD_URL (Demo 1)
# - HELLO_API_URL (Demo 2)
# - AZURE_RESOURCE_GROUP (all demos)
```

### Post-Deployment Configuration

```powershell
# Get your resource group name
$rg = (azd env get-values | Select-String "AZURE_RESOURCE_GROUP").ToString().Split("=")[1].Trim('"')

# Demo 1: Set Single revision mode and 3-min cooldown for scaling demo
az containerapp revision set-mode -n ingestion-service -g $rg --mode Single

# Create scale config YAML
@"
properties:
  template:
    scale:
      minReplicas: 1
      maxReplicas: 100
      cooldownPeriod: 180
      rules:
        - name: http-scaler
          http:
            metadata:
              concurrentRequests: "2"
"@ | Out-File -FilePath scale-config.yaml -Encoding UTF8

az containerapp update -n ingestion-service -g $rg --yaml scale-config.yaml
Remove-Item scale-config.yaml
```

### Verify All Services

```powershell
# Get all service URLs
azd env get-values | Select-String "URL"

# List all Container Apps and Jobs
az containerapp list -g $rg --query "[].{name:name,url:properties.configuration.ingress.fqdn}" -o table
az containerapp job list -g $rg --query "[].{name:name,type:properties.triggerType}" -o table
```

---

## 🎯 Demo Overview

| Demo | Duration | Feature | Key Takeaway |
|------|----------|---------|--------------|
| **Demo 1** | 10 min | HTTP Auto-Scaling | Scale 1→10 replicas automatically |
| **Demo 2** | 8 min | Traffic Splitting | Blue-green deployments with percentage routing |
| **Demo 3** | 7 min | Container Jobs | Scheduled & on-demand batch processing |

---

# 🔥 Demo 1: HTTP Auto-Scaling (10 minutes)

**Goal:** Show how Container Apps automatically scales based on HTTP traffic without KEDA configuration.

## Step 1.1: Show Initial State (2 min)

### Check Replica Count

```powershell
$rg = "<your-resource-group>"

# Should show 1 replica
az containerapp revision list -n ingestion-service -g $rg --query "[?properties.active].replicas" -o tsv
```

### In Azure Portal

1. Navigate to **Resource Group** → **ingestion-service**
2. Go to **Application** → **Revisions and replicas**
3. Click **Refresh** → Show **1 replica** running

> **Talking Point:** "The ingestion service starts with just 1 replica. It's ready to handle requests, but not wasting resources when idle."

---

## Step 1.2: Open Dashboard (1 min)

```powershell
# Get Dashboard URL
azd env get-values | Select-String "DASHBOARD_URL"
```

- Open the URL in a browser
- Point out the **🔥 Send 100 Events (Heavy Load)** button

> **Talking Point:** "This dashboard simulates concurrent load against our ingestion service. Let's see what happens when we send 100 requests simultaneously."

---

## Step 1.3: Trigger Scaling (3 min)

### Click the Load Button

1. Click **🔥 Send 100 Events (Heavy Load)**
2. Watch the status update as events are sent

### Check Scaling in Portal (Immediately!)

1. **Azure Portal** → **ingestion-service** → **Revisions and replicas**
2. **Refresh** the page repeatedly
3. Watch replicas increase: **1 → 3 → 5 → 7 → 10+**

### Or Use CLI

```powershell
# Run this while load is happening
az containerapp revision list -n ingestion-service -g $rg --query "[?properties.active].replicas" -o tsv
```

> **Talking Point:** "Container Apps detected the HTTP traffic spike and automatically scaled up. No KEDA installation, no HPA configuration - just set the threshold and it works."

---

## Step 1.4: Wait for Scale-Down (3 min)

### Cooldown Period = 3 Minutes

1. Keep the Portal Replicas view open
2. Refresh every 30-60 seconds
3. Explain cooldown while waiting

```powershell
# Check replica count periodically
az containerapp revision list -n ingestion-service -g $rg --query "[?properties.active].replicas" -o tsv
```

> **Talking Point:** "The cooldown period prevents thrashing - rapid scale up/down cycles. After 3 minutes of reduced traffic, Container Apps scales back down to the minimum."

### Expected Result

- Replicas decrease back to **1**
- Demonstrates consumption-based billing

---

## Step 1.5: Repeat Scaling (1 min)

1. With replicas back at **1**, click the load button again
2. Verify scaling works consistently

> **Talking Point:** "This is repeatable and automatic. Every time load increases, Container Apps responds within seconds."

---

# 🔀 Demo 2: Traffic Splitting (8 minutes)

**Goal:** Show blue-green deployments with percentage-based traffic routing.

## Step 2.1: Show Current Version (1 min)

```powershell
# Get Hello API URL
azd env get-values | Select-String "HELLO_API_URL"
```

1. Open the URL in browser
2. Show the **v1** badge (blue color)

> **Talking Point:** "This is our Hello API running version 1. Let's deploy version 2 and gradually shift traffic."

---

## Step 2.2: Deploy Version 2 (3 min)

### Build and Push v2 Image

```powershell
$acr = (azd env get-values | Select-String "CONTAINER_REGISTRY_LOGIN_SERVER").ToString().Split("=")[1].Trim('"')
$rg = (azd env get-values | Select-String "AZURE_RESOURCE_GROUP").ToString().Split("=")[1].Trim('"')

cd demos/traffic-splitting

# Build v2 with green styling
docker build -t "$acr/hello-api:v2" --build-arg APP_VERSION=v2 .
docker push "$acr/hello-api:v2"
```

### Enable Multiple Revision Mode

```powershell
az containerapp revision set-mode -n hello-api -g $rg --mode Multiple
```

### Deploy v2 as New Revision

```powershell
az containerapp update -n hello-api -g $rg `
  --image "$acr/hello-api:v2" `
  --revision-suffix v2 `
  --set-env-vars "APP_VERSION=v2"
```

### Verify in Portal

1. Navigate to **hello-api** → **Revisions and replicas**
2. Show **2 revisions** now exist
3. Show traffic is 100% on the old revision

---

## Step 2.3: Split Traffic 50/50 (2 min)

### Get Revision Names

```powershell
az containerapp revision list -n hello-api -g $rg --query "[].name" -o tsv
# Note: v1 revision name (e.g., hello-api--xxxxx) and hello-api--v2
```

### Apply Traffic Split

```powershell
$v1Revision = "<v1-revision-name>"  # e.g., hello-api--5xbnfr1

az containerapp ingress traffic set -n hello-api -g $rg `
  --revision-weight "$v1Revision=50" "hello-api--v2=50"
```

### Demonstrate Traffic Split

1. Open the Hello API URL
2. **Refresh multiple times** (F5)
3. Show alternating between:
   - **Blue "v1"** badge
   - **Green "v2"** badge

> **Talking Point:** "50% of users see v1, 50% see v2. Perfect for A/B testing or canary deployments."

### Verify in Portal

1. Navigate to **hello-api** → **Revisions and replicas**
2. Show **Traffic %** column: 50% / 50%

---

## Step 2.4: Complete Migration (1 min)

### Shift 100% to v2

```powershell
az containerapp ingress traffic set -n hello-api -g $rg `
  --revision-weight "hello-api--v2=100"
```

### Verify

- Refresh browser - always shows **v2** (green)
- Old revision can be deactivated

> **Talking Point:** "With traffic splitting, you can gradually migrate users. If v2 has issues, instantly roll back by shifting traffic to v1."

---

# ⚡ Demo 3: Container Apps Jobs (7 minutes)

**Goal:** Show batch processing without Kubernetes CronJobs complexity.

## Step 3.1: List Deployed Jobs (1 min)

```powershell
# Show all 3 jobs deployed by azd
az containerapp job list -g $rg --query "[].{Name:name, Type:properties.triggerType, Schedule:properties.scheduleTriggerConfig.cronExpression}" -o table
```

**Expected Output:**

| Name | Type | Schedule |
|------|------|----------|
| data-processor-scheduled | Schedule | */2 * * * * |
| data-processor-manual | Manual | null |
| data-processor-parallel | Manual | null |

### Verify in Portal

1. Navigate to **Resource Group** → Filter by **Container Apps Job**
2. Show the 3 jobs

> **Talking Point:** "We have 3 types of jobs: a scheduled job running every 2 minutes, and two manual jobs - one single-instance and one that runs 3 parallel workers."

---

## Step 3.2: View Scheduled Job Executions (2 min)

### Check Execution History

```powershell
az containerapp job execution list -n data-processor-scheduled -g $rg `
  --query "[].{Name:name, Status:properties.status, Started:properties.startTime}" -o table
```

### View in Portal

1. Navigate to **data-processor-scheduled** → **Execution history**
2. Show executions running every 2 minutes
3. Click on an execution to see details

> **Talking Point:** "No CronJobs, no Kubernetes scheduler - just set the cron expression in Bicep and Container Apps handles the rest."

---

## Step 3.3: Trigger Manual Job (2 min)

### Start Manual Job

```powershell
az containerapp job start -n data-processor-manual -g $rg --query "name" -o tsv
```

### Wait and Check Status

```powershell
# Wait 15 seconds for job to complete
Start-Sleep -Seconds 15

az containerapp job execution list -n data-processor-manual -g $rg `
  --query "[0].{Name:name, Status:properties.status, Duration:properties.endTime}" -o table
```

### View Logs (Portal)

1. Navigate to **data-processor-manual** → **Execution history**
2. Click on the latest execution
3. Click **Console logs** to see output

> **Talking Point:** "Manual jobs are perfect for on-demand tasks - data migrations, report generation, cleanup tasks."

---

## Step 3.4: Run Parallel Job (2 min)

### Start Parallel Job (3 workers)

```powershell
az containerapp job start -n data-processor-parallel -g $rg --query "name" -o tsv
```

### Check Execution

```powershell
Start-Sleep -Seconds 20

az containerapp job execution list -n data-processor-parallel -g $rg `
  --query "[0].{Name:name, Status:properties.status, Replicas:properties.template.containers[0].name}" -o table
```

### View in Portal

1. Navigate to **data-processor-parallel** → **Execution history**
2. Show 3 parallel replicas ran simultaneously

> **Talking Point:** "Parallel jobs split work across multiple instances. Great for processing large datasets quickly - each worker handles a portion."

---

# 📊 Demo Summary (2 minutes)

## Key Takeaways

| Feature | Container Apps | Kubernetes |
|---------|---------------|------------|
| **HTTP Scaling** | Built-in, just set threshold | Install KEDA + HPA |
| **Traffic Splitting** | Portal or CLI toggle | Ingress controller + annotations |
| **Batch Jobs** | Bicep/ARM definition | CronJob YAML + kubectl |
| **Infrastructure** | Fully managed | Cluster management required |

## When to Use Container Apps

✅ **Good fit:**
- HTTP APIs and microservices
- Event-driven processing
- Scheduled batch jobs
- Blue-green deployments
- Teams without Kubernetes expertise

❌ **Consider AKS instead:**
- Complex service mesh requirements
- Custom operators needed
- Existing Kubernetes investments
- Fine-grained cluster control

> **Closing Statement:** "Azure Container Apps gives you 80% of Kubernetes capabilities with 20% of the complexity. Perfect for teams that want to focus on code, not infrastructure."

---

# 🔧 Quick Reference

## All Demo Commands

```powershell
# Set resource group variable
$rg = "<your-resource-group>"
$acr = "<your-acr>.azurecr.io"

# Demo 1: Check replicas
az containerapp revision list -n ingestion-service -g $rg --query "[?properties.active].replicas" -o tsv

# Demo 2: Traffic split commands
az containerapp revision set-mode -n hello-api -g $rg --mode Multiple
az containerapp revision list -n hello-api -g $rg --query "[].name" -o tsv
az containerapp ingress traffic set -n hello-api -g $rg --revision-weight "<v1>=50" "<v2>=50"

# Demo 3: Job commands
az containerapp job list -g $rg -o table
az containerapp job start -n data-processor-manual -g $rg
az containerapp job execution list -n data-processor-scheduled -g $rg -o table
```

## Portal Navigation

| Demo | Path |
|------|------|
| Scaling | Resource Group → ingestion-service → Revisions and replicas |
| Traffic Split | Resource Group → hello-api → Revisions and replicas |
| Jobs | Resource Group → Container Apps Jobs → Execution history |

---

# ⚠️ Troubleshooting

## Demo 1: Replicas Not Scaling

```powershell
# Ensure Single revision mode
az containerapp revision set-mode -n ingestion-service -g $rg --mode Single

# Verify scaling rules
az containerapp show -n ingestion-service -g $rg --query "properties.template.scale" -o json
```

## Demo 2: Traffic Split Not Working

```powershell
# Ensure Multiple revision mode
az containerapp revision set-mode -n hello-api -g $rg --mode Multiple

# List active revisions
az containerapp revision list -n hello-api -g $rg --query "[?properties.active].name" -o tsv
```

## Demo 3: Job Image Not Found

```powershell
# Rebuild and push job image
cd demos/container-jobs
docker build -t "$acr/demo-job:latest" .
docker push "$acr/demo-job:latest"

# Update job with new image
az containerapp job update -n data-processor-manual -g $rg --image "$acr/demo-job:latest"
```

---

# 🧹 Cleanup

```powershell
# Delete all demo resources
azd down --force --purge

# Or delete just specific jobs (keep main demo)
az containerapp job delete -n data-processor-scheduled -g $rg --yes
az containerapp job delete -n data-processor-manual -g $rg --yes
az containerapp job delete -n data-processor-parallel -g $rg --yes
```

---

## 📚 Resources

- [Azure Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [Container Apps Scaling](https://learn.microsoft.com/azure/container-apps/scale-app)
- [Traffic Splitting](https://learn.microsoft.com/azure/container-apps/revisions-manage)
- [Container Apps Jobs](https://learn.microsoft.com/azure/container-apps/jobs)
- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/)

---

*Last Updated: January 29, 2026*
