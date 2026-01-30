# Traffic Splitting Demo - Azure Container Apps

> **Demo Duration:** 8-10 minutes  
> **Key Message:** Blue-green deployments and canary releases without an ingress controller

---

## 🎯 What This Demo Shows

| Capability | AKS Approach | Container Apps |
|------------|--------------|----------------|
| Traffic splitting | Install Nginx/Traefik + annotations | Built-in, one command |
| Blue-green deploy | Complex ingress config | Native revision support |
| Canary releases | Service mesh (Istio/Linkerd) | Simple percentage-based |
| Rollback | kubectl rollout undo | One command |

---

## 📋 Prerequisites

- Azure CLI logged in (`az login`)
- Existing Container Apps Environment (from main demo)
- Docker running (for building images)

**Get environment info from main demo:**
```powershell
$RG = "rg-pdt1010pm"  # Your resource group
$ENV_NAME = (az containerapp env list -g $RG --query "[0].name" -o tsv)
$ACR_NAME = (az acr list -g $RG --query "[0].name" -o tsv)
```

---

## 🎬 Demo Script

### Step 1: Build and Push Version 1 (2 minutes)

```powershell
# Navigate to demo folder
cd c:\azd-contapp-demo\demos\traffic-splitting

# Login to ACR
az acr login -n $ACR_NAME

# Build and push v1
docker build -t "$ACR_NAME.azurecr.io/hello-api:v1" --build-arg APP_VERSION=v1 .
docker push "$ACR_NAME.azurecr.io/hello-api:v1"
```

### Step 2: Deploy Version 1 (1 minute)

```powershell
# Create the hello-api container app with v1
az containerapp create `
  --name hello-api `
  --resource-group $RG `
  --environment $ENV_NAME `
  --image "$ACR_NAME.azurecr.io/hello-api:v1" `
  --target-port 3000 `
  --ingress external `
  --min-replicas 1 `
  --max-replicas 5 `
  --env-vars APP_VERSION=v1 `
  --registry-server "$ACR_NAME.azurecr.io" `
  --query "properties.configuration.ingress.fqdn" -o tsv
```

**Open the URL in browser** - You should see the **blue "v1"** badge.

> **Talking Point:** "We've deployed version 1 of our API. It's showing the blue badge. Now let's deploy version 2 without any downtime."

---

### Step 3: Enable Multiple Revisions Mode (30 seconds)

```powershell
# Switch to multiple revision mode for traffic splitting
az containerapp revision set-mode -n hello-api -g $RG --mode Multiple
```

> **Talking Point:** "To split traffic between versions, we need Multiple revision mode. This allows both versions to run simultaneously."

---

### Step 4: Build and Push Version 2 (1 minute)

```powershell
# Build and push v2 (green version)
docker build -t "$ACR_NAME.azurecr.io/hello-api:v2" .
docker push "$ACR_NAME.azurecr.io/hello-api:v2"
```

---

### Step 5: Deploy Version 2 (1 minute)

```powershell
# Update the app with v2 - this creates a new revision
az containerapp update `
  --name hello-api `
  --resource-group $RG `
  --image "$ACR_NAME.azurecr.io/hello-api:v2" `
  --set-env-vars APP_VERSION=v2 `
  --revision-suffix v2
```

**Check revisions:**
```powershell
az containerapp revision list -n hello-api -g $RG `
  --query "[].{name:name, active:properties.active, traffic:properties.trafficWeight}" -o table
```

> **Talking Point:** "Now we have two revisions running. By default, all traffic goes to the latest revision."

---

### Step 6: Split Traffic 50/50 (1 minute)

```powershell
# Get revision names
$REV_V1 = (az containerapp revision list -n hello-api -g $RG --query "[?contains(name, 'v1') || !contains(name, 'v2')].name" -o tsv | Select-Object -First 1)
$REV_V2 = (az containerapp revision list -n hello-api -g $RG --query "[?contains(name, 'v2')].name" -o tsv)

# Split traffic 50/50
az containerapp ingress traffic set `
  --name hello-api `
  --resource-group $RG `
  --revision-weight "$REV_V1=50" "$REV_V2=50"
```

**Demonstrate by refreshing the browser multiple times** - You'll see it alternate between blue (v1) and green (v2)!

> **Talking Point:** "With one command, we're now routing 50% of traffic to each version. Refresh the page - you'll randomly get v1 or v2. This is perfect for A/B testing or canary releases."

---

### Step 7: Gradual Rollout to v2 (1 minute)

```powershell
# Shift to 80% v2, 20% v1
az containerapp ingress traffic set `
  --name hello-api `
  --resource-group $RG `
  --revision-weight "$REV_V1=20" "$REV_V2=80"

# Check the traffic distribution
az containerapp ingress traffic show -n hello-api -g $RG -o table
```

> **Talking Point:** "We're now sending 80% of traffic to v2. If we see errors or issues, we can instantly roll back."

---

### Step 8: Complete Rollout or Rollback (1 minute)

#### Option A: Complete the rollout to v2
```powershell
# 100% to v2
az containerapp ingress traffic set `
  --name hello-api `
  --resource-group $RG `
  --revision-weight "$REV_V2=100"
```

#### Option B: Rollback to v1
```powershell
# 100% back to v1
az containerapp ingress traffic set `
  --name hello-api `
  --resource-group $RG `
  --revision-weight "$REV_V1=100"
```

> **Talking Point:** "Rolling back is just as easy as rolling forward. One command, instant traffic shift, zero downtime."

---

### Step 9: Cleanup (Optional)

```powershell
# Deactivate old revision to save resources
az containerapp revision deactivate -n hello-api -g $RG --revision $REV_V1

# Or delete the demo app entirely
az containerapp delete -n hello-api -g $RG --yes
```

---

## 📊 Quick Reference Commands

### Show Current Traffic Distribution
```powershell
az containerapp ingress traffic show -n hello-api -g $RG -o table
```

### List All Revisions
```powershell
az containerapp revision list -n hello-api -g $RG -o table
```

### Instant Rollback
```powershell
az containerapp ingress traffic set -n hello-api -g $RG --revision-weight "<old-revision>=100"
```

---

## 🎯 Key Talking Points

1. **No Ingress Controller** - Traffic splitting is built into Container Apps
2. **Instant Rollback** - One command to shift all traffic
3. **Percentage-Based** - Fine-grained control (1% canary is possible)
4. **Zero Downtime** - Both versions run simultaneously
5. **Works with Any Image** - No code changes required

---

## 🆚 Comparison Summary

| Task | AKS | Container Apps |
|------|-----|----------------|
| Initial setup | Install ingress controller, configure TLS | None |
| Create canary | Write annotations, update ingress | One CLI command |
| Shift traffic | Edit ingress YAML, kubectl apply | One CLI command |
| Rollback | kubectl rollout undo OR edit ingress | One CLI command |
| Time to implement | Hours | Minutes |

---

*Last Updated: January 30, 2026*
