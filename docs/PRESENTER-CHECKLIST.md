# CloudBurst Analytics - Presenter Quick Checklist

## ⏰ 30 Minutes Before Demo

| # | Task | Status |
|---|------|--------|
| 1 | Run `az account show` - verify correct subscription | ☐ |
| 2 | Run `azd env list` - verify environment exists | ☐ |
| 3 | Docker Desktop running | ☐ |
| 4 | VS Code open with project | ☐ |
| 5 | Azure Portal open, logged in | ☐ |
| 6 | Browser tabs ready (Portal, Dashboard, API) | ☐ |

## 🚀 Quick Deploy Command

```bash
cd c:\azd-contapp-demo
azd up
```

## 🔗 Get Deployed URLs

```bash
azd env get-values | Select-String "URL"
```

## 📍 Key Portal Navigation Paths

| Resource | Path |
|----------|------|
| Container Apps Environment | Resource Group → cae-* |
| Ingestion Service | Resource Group → ingestion-service |
| Key Vault | Resource Group → kv-* |
| Event Hub | Resource Group → evhns-* |
| Cosmos DB | Resource Group → cosmos-* |

## 🎯 5 Key Points to Make

1. **"One command deployment"** → `azd up`
2. **"Scale to zero"** → Show 0 replicas, then trigger scaling
3. **"Native Dapr"** → One toggle, no Helm
4. **"Built-in traffic splitting"** → Revisions tab
5. **"Secure by default"** → Key Vault + Managed Identity

## 🔥 Show-Stopper Moments

| Moment | What to Do | Expected Reaction |
|--------|------------|-------------------|
| Scale 0→N | Send burst of events | "Wow, it just works!" |
| Scale N→0 | Stop events, wait | "That saves money!" |
| Key Vault | Show no passwords | "That's secure!" |
| Comparison table | AKS vs Container Apps | "Why didn't I know this?" |

## 🆘 If Things Go Wrong

| Problem | Quick Fix |
|---------|-----------|
| `azd up` fails | `azd down --purge` then retry |
| Dashboard blank | Check browser console, refresh |
| Scaling not working | Verify Event Hub connection in Portal |
| Portal slow | Use pre-captured screenshots |

## 📊 Commands for Live Metrics

```bash
# Show container app details
az containerapp show --name ingestion-service --resource-group rg-<env>

# Stream logs live
az containerapp logs show --name ingestion-service --resource-group rg-<env> --follow

# Check replica count
az containerapp replica list --name ingestion-service --resource-group rg-<env>
```

## 🎤 Closing Lines

> "Container Apps: All the power of containers, none of the Kubernetes complexity."

> "Try it yourself - `azd init` and `azd up` - you'll be deployed in minutes."

---

**Remember:** The goal is to make them want to try Container Apps for their next project!
