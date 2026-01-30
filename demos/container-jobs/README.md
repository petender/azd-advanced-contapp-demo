# Container Apps Jobs Demo

> **Demo Duration:** 6-8 minutes  
> **Key Message:** Run scheduled and event-driven jobs without Kubernetes CronJob complexity

---

## 🎯 What This Demo Shows

| Capability | AKS Approach | Container Apps Jobs |
|------------|--------------|---------------------|
| Scheduled tasks | CronJob YAML (20+ lines) | One Bicep resource |
| Manual triggers | kubectl create job | One CLI command |
| Parallel execution | Configure parallelism manually | Built-in parameter |
| Execution history | kubectl get jobs + cleanup | Automatic in Portal |
| Logs access | kubectl logs + pod selection | Built-in log viewer |
| Cleanup | Manual or TTL controller | Automatic retention |

---

## 📋 Pre-Deployment (Before Demo)

### Deploy the Jobs Infrastructure

```powershell
cd c:\azd-contapp-demo\demos\container-jobs

# Deploy using the script (uses existing Container Apps environment)
.\deploy.ps1 -ResourceGroup "rg-pdt1010pm"
```

This creates 3 jobs:
| Job Name | Trigger Type | Description |
|----------|--------------|-------------|
| `data-processor-scheduled` | Schedule | Runs every 2 minutes |
| `data-processor-manual` | Manual | Trigger on-demand |
| `data-processor-parallel` | Manual | Runs 3 replicas in parallel |

---

## 🎬 Demo Script

### Step 1: Show the Jobs in Azure Portal (2 minutes)

1. Navigate to **Azure Portal** → **Resource Group** → **Container Apps Jobs**
2. Show the three jobs created:
   - Point out **Trigger type** column (Schedule vs Manual)
   - Click on `data-processor-scheduled`

> **Talking Point:** "We've deployed three Container Apps Jobs. Unlike regular Container Apps that run continuously, Jobs run to completion and stop. No wasted resources when there's no work to do."

---

### Step 2: View Scheduled Job Execution (2 minutes)

1. In the Portal, go to **data-processor-scheduled** → **Execution history**
2. If a job has run, click on it to see details
3. Click **Console logs** to see the job output

```powershell
# Or view from CLI
az containerapp job execution list -n data-processor-scheduled -g rg-pdt1010pm -o table
```

**Expected output:**
```
Name                                  Status     StartTime
------------------------------------  ---------  -------------------------
data-processor-scheduled-xxxxx        Succeeded  2026-01-30T07:02:00+00:00
```

> **Talking Point:** "The scheduled job runs automatically every 2 minutes. Container Apps handles the scheduling, execution tracking, and cleanup. No CronJob YAML, no manual pod cleanup."

---

### Step 3: Trigger Manual Job (1 minute)

```powershell
# Trigger the manual job
az containerapp job start -n data-processor-manual -g rg-pdt1010pm

# Watch it run
az containerapp job execution list -n data-processor-manual -g rg-pdt1010pm -o table
```

> **Talking Point:** "We can also trigger jobs on-demand. This is perfect for one-off tasks like data migrations, report generation, or manual maintenance."

---

### Step 4: Demonstrate Parallel Execution (2 minutes)

```powershell
# Trigger the parallel job (runs 3 instances simultaneously)
az containerapp job start -n data-processor-parallel -g rg-pdt1010pm

# Watch all 3 replicas
az containerapp job execution list -n data-processor-parallel -g rg-pdt1010pm -o table
```

1. In Portal, go to **data-processor-parallel** → **Execution history**
2. Click on the latest execution
3. Show **3 replicas** running in parallel

> **Talking Point:** "Need to process a large batch faster? Just set parallelism to 3, and Container Apps runs 3 instances simultaneously. Each gets its own replica index so they can partition the work."

---

### Step 5: View Job Logs (1 minute)

```powershell
# Get the execution name
$EXEC = az containerapp job execution list -n data-processor-manual -g rg-pdt1010pm --query "[0].name" -o tsv

# View logs
az containerapp job logs show -n data-processor-manual -g rg-pdt1010pm --execution $EXEC
```

Or in Portal: **Job** → **Execution history** → **Click execution** → **Console logs**

> **Talking Point:** "All logs are captured and retained. You can view them in the Portal or CLI without having to find and query specific pods."

---

## 📊 Key Talking Points

### 1. No CronJob YAML

**AKS CronJob:**
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: data-processor
spec:
  schedule: "*/2 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: processor
            image: myregistry/job:latest
          restartPolicy: Never
      backoffLimit: 3
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
```

**Container Apps (Bicep):**
```bicep
resource job 'Microsoft.App/jobs@2024-03-01' = {
  name: 'data-processor'
  properties: {
    configuration: {
      triggerType: 'Schedule'
      scheduleTriggerConfig: {
        cronExpression: '*/2 * * * *'
      }
    }
    template: {
      containers: [{ name: 'processor', image: 'myregistry/job:latest' }]
    }
  }
}
```

### 2. Built-in Execution Tracking

- Every execution is recorded with status, start/end time, duration
- No need to configure TTL controllers for cleanup
- Logs are retained and queryable

### 3. Easy Parallelism

- Set `parallelism: 10` to run 10 instances
- Each gets `CONTAINER_APP_REPLICA_INDEX` environment variable
- Automatic coordination and completion tracking

---

## 🔧 Quick Reference Commands

### List All Jobs
```powershell
az containerapp job list -g rg-pdt1010pm -o table
```

### View Execution History
```powershell
az containerapp job execution list -n <job-name> -g rg-pdt1010pm -o table
```

### Trigger Manual Job
```powershell
az containerapp job start -n <job-name> -g rg-pdt1010pm
```

### View Job Logs
```powershell
$EXEC = az containerapp job execution list -n <job-name> -g rg-pdt1010pm --query "[0].name" -o tsv
az containerapp job logs show -n <job-name> -g rg-pdt1010pm --execution $EXEC
```

### Stop a Running Job
```powershell
az containerapp job execution stop -n <job-name> -g rg-pdt1010pm --execution <execution-name>
```

---

## 🧹 Cleanup

```powershell
# Delete all demo jobs
az containerapp job delete -n data-processor-scheduled -g rg-pdt1010pm --yes
az containerapp job delete -n data-processor-manual -g rg-pdt1010pm --yes
az containerapp job delete -n data-processor-parallel -g rg-pdt1010pm --yes
```

---

## 🆚 Comparison Summary

| Task | AKS | Container Apps Jobs |
|------|-----|---------------------|
| Create scheduled job | Write CronJob YAML | Bicep or CLI |
| View execution history | kubectl get jobs + grep | Portal or CLI |
| View logs | Find pod name, kubectl logs | Click in Portal |
| Cleanup old jobs | Configure TTL or manual | Automatic |
| Parallel execution | Configure parallelism | Set one parameter |
| Trigger on-demand | kubectl create job --from | az containerapp job start |

---

*Last Updated: January 30, 2026*
