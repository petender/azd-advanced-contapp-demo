# CloudBurst Analytics: Event-Driven Microservices with Azure Container Apps

> **Demo Scenario**: Showcasing the power of Azure Container Apps for serverless, event-driven microservices — without the complexity of managing Kubernetes.

## 🎯 Scenario Overview

A manufacturing company needs to monitor equipment health across 50 factories worldwide. This demo showcases how Azure Container Apps can:

- **Ingest thousands of sensor events per second** from IoT devices
- **Auto-scale from zero to peak demand** (and back to zero during off-hours)
- **Pay only for actual compute usage** with consumption-based billing
- **Deploy in days, not weeks** — no Kubernetes expertise required

## 💡 Container Apps vs AKS: Key Differentiators

| Capability | AKS | Container Apps |
|------------|-----|----------------|
| Kubernetes expertise needed | ✅ Yes | ❌ No |
| Scale to zero | ❌ Manual config | ✅ Built-in |
| Event-driven autoscaling (KEDA) | ⚙️ Install & configure | ✅ Native |
| Cluster management overhead | ✅ Node pools, upgrades | ❌ Serverless |
| Pay-per-use billing | ❌ Always-on nodes | ✅ Consumption plan |
| Dapr integration | ⚙️ Install via Helm | ✅ One-click enable |
| Traffic splitting | ⚙️ Ingress controller | ✅ Built-in revisions |
| Time to production | Weeks | Days |

## 🏗️ Architecture

```
┌─────────────────┐     ┌──────────────────────────────────────────────────┐
│   IoT Sensors   │────▶│              Azure Event Hubs                    │
└─────────────────┘     └──────────────────────────────────────────────────┘
                                           │
                                           ▼
                        ┌──────────────────────────────────────────────────┐
                        │         Azure Container Apps Environment          │
                        │  ┌─────────────┐  ┌─────────────┐  ┌───────────┐ │
                        │  │  Ingestion  │─▶│  Processor  │─▶│  API      │ │
                        │  │  Service    │  │  Service    │  │  Gateway  │ │
                        │  │ (scale 0-N) │  │ (scale 0-N) │  │           │ │
                        │  └─────────────┘  └─────────────┘  └───────────┘ │
                        │         │              │     ▲          │        │
                        │         └──────┬───────┘     │          │        │
                        │                ▼             │          ▼        │
                        │         ┌─────────────┐      │   ┌───────────┐   │
                        │         │    Dapr     │      │   │  Dashboard│   │
                        │         │  Sidecar    │──────┘   │  (React)  │   │
                        │         └─────────────┘          └───────────┘   │
                        └──────────────────────────────────────────────────┘
                                           │
                        ┌──────────────────┴───────────────────┐
                        ▼                                      ▼
               ┌─────────────────┐                   ┌─────────────────┐
               │  Azure Cosmos   │                   │ Azure Managed   │
               │       DB        │                   │    Grafana      │
               └─────────────────┘                   └─────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)

### Deploy in One Command

```bash
# Clone and navigate to the project
cd azd-contapp-demo

# Login to Azure
azd auth login

# Deploy everything (infrastructure + services)
azd up
```

This single command will:
1. ✅ Provision all Azure infrastructure (Container Apps Environment, Event Hubs, Cosmos DB, etc.)
2. ✅ Create Key Vault and User-Assigned Managed Identity for secure secret management
3. ✅ Build and push container images to Azure Container Registry
4. ✅ Deploy all microservices to Container Apps with Key Vault secret references
5. ✅ Configure Dapr components for pub/sub and state management
6. ✅ Set up auto-scaling rules based on HTTP requests
7. ✅ Deploy Traffic Splitting demo app (hello-api)
8. ✅ Deploy Container Apps Jobs (scheduled, manual, parallel)

### Demo Flow (25-30 minutes)

| Step | Demo | What to Highlight |
|------|------|-------------------|
| 1 | `azd up` | One-command deployment of entire solution |
| 2 | **Auto-Scaling** | Click load button, watch 1→10 replicas |
| 3 | Scale-down | 3-minute cooldown, back to 1 replica |
| 4 | **Traffic Split** | Deploy v2, split 50/50, refresh to see blue/green |
| 5 | **Container Jobs** | View scheduled jobs, trigger manual/parallel jobs |
| 6 | Summary | Compare Container Apps vs AKS complexity |

See [DEMO-RUNBOOK.md](docs/DEMO-RUNBOOK.md) for complete step-by-step instructions.

## 📁 Project Structure

```
/azd-contapp-demo
├── azure.yaml                 # Azure Developer CLI manifest (all services)
├── infra/
│   ├── main.bicep            # Main deployment (all demos)
│   ├── main.parameters.json  # Environment parameters
│   └── modules/
│       ├── container-apps-env.bicep
│       ├── container-app.bicep
│       ├── container-job.bicep   # Container Apps Job module
│       ├── event-hub.bicep
│       ├── cosmos-db.bicep
│       ├── container-registry.bicep
│       ├── key-vault.bicep
│       ├── managed-identity.bicep
│       └── log-analytics.bicep
├── src/
│   ├── ingestion-service/    # Python + FastAPI (Demo 1: scaling)
│   └── dashboard/            # React + Vite (Demo 1: load test UI)
├── demos/
│   ├── traffic-splitting/    # Node.js app (Demo 2: v1/v2 versions)
│   │   ├── app.js
│   │   ├── Dockerfile
│   │   └── README.md
│   └── container-jobs/       # Python job (Demo 3: batch processing)
│       ├── job.py
│       ├── Dockerfile
│       └── README.md
├── docs/
│   └── DEMO-RUNBOOK.md       # Complete demo guide (all 3 demos)
└── README.md
```

## 🎭 Additional Demo Scenarios

All demos are deployed together with `azd up`. See [DEMO-RUNBOOK.md](docs/DEMO-RUNBOOK.md) for complete instructions.

### Demo 1: HTTP Auto-Scaling (Main Demo)
**Services:** `dashboard`, `ingestion-service`

Click the load button on the dashboard and watch replicas scale from 1→10 automatically, then back down after the 3-minute cooldown.

### Demo 2: Traffic Splitting
**Service:** `hello-api` (in `demos/traffic-splitting/`)

Shows blue-green deployments and canary releases. Deploy v2, split traffic 50/50, watch browser alternate between blue (v1) and green (v2).

### Demo 3: Container Apps Jobs
**Jobs:** `data-processor-scheduled`, `data-processor-manual`, `data-processor-parallel`

Shows scheduled and manual batch jobs without Kubernetes CronJob complexity. Scheduled job runs every 2 minutes, manual jobs can be triggered on-demand.

## 🔐 Security Architecture

This demo follows Azure security best practices:

- **Managed Identity**: User-assigned identity for passwordless authentication
- **Key Vault Integration**: All secrets stored in Key Vault, referenced by Container Apps
- **RBAC**: Role-based access control for Key Vault secrets
- **No Hardcoded Secrets**: Connection strings never exposed in code or Bicep outputs

```
┌─────────────────────┐     ┌─────────────────────┐
│   Container Apps    │────▶│     Key Vault       │
│  (Managed Identity) │     │   (Secret Store)    │
└─────────────────────┘     └─────────────────────┘
         │                           │
         │ Passwordless Auth         │ Stores
         ▼                           ▼
┌─────────────────────┐     ┌─────────────────────┐
│   Event Hub         │     │   Cosmos DB         │
│   (Connection)      │     │   (Connection)      │
└─────────────────────┘     └─────────────────────┘
```

## ⭐ Key Demo Highlights

### 1. Scale-to-Zero Magic

Container Apps automatically scales based on Event Hub message lag:

```yaml
scale:
  minReplicas: 0
  maxReplicas: 100
  rules:
    - name: eventhub-scaling
      custom:
        type: azure-eventhub
        metadata:
          consumerGroup: processor
          unprocessedEventThreshold: "64"
```

### 2. Dapr Integration (Zero Config)

Enable service-to-service communication, pub/sub, and state management:

```yaml
dapr:
  enabled: true
  appId: processor-service
  appPort: 8080
```

### 3. Built-in Traffic Splitting

Blue-green deployments with one command:

```bash
az containerapp ingress traffic set \
  --name api-gateway \
  --revision-weight latest=20 previous=80
```

### 4. Cost Comparison

- **AKS**: 3-node cluster running 24/7 ≈ $300/month minimum
- **Container Apps**: Pay per vCPU-second ≈ $15/month for bursty workloads

## 🔧 Configuration

### Environment Variables

Create a `.env` file or set these in Azure:

| Variable | Description |
|----------|-------------|
| `AZURE_LOCATION` | Azure region (default: eastus) |
| `AZURE_ENV_NAME` | Environment name (dev/staging/prod) |
| `EVENTHUB_CONNECTION_STRING` | Auto-configured by azd |
| `COSMOS_CONNECTION_STRING` | Auto-configured by azd |

## 📚 Learn More

- [Azure Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [Dapr on Container Apps](https://learn.microsoft.com/azure/container-apps/dapr-overview)
- [KEDA Scaling in Container Apps](https://learn.microsoft.com/azure/container-apps/scale-app)
- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/)

## 📄 License

This project is licensed under the MIT License.
