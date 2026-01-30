# Container Apps Jobs Demo - Deployment Script
# This script deploys the jobs infrastructure using the existing Container Apps environment

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$false)]
    [string]$EnvironmentName = "",
    
    [Parameter(Mandatory=$false)]
    [string]$AcrName = ""
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 Container Apps Jobs Demo - Deployment" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Get environment name if not provided
if ([string]::IsNullOrEmpty($EnvironmentName)) {
    $EnvironmentName = az containerapp env list -g $ResourceGroup --query "[0].name" -o tsv
    if ([string]::IsNullOrEmpty($EnvironmentName)) {
        Write-Error "No Container Apps Environment found in resource group $ResourceGroup"
        exit 1
    }
}

# Get ACR name if not provided
if ([string]::IsNullOrEmpty($AcrName)) {
    $AcrName = az acr list -g $ResourceGroup --query "[0].name" -o tsv
    if ([string]::IsNullOrEmpty($AcrName)) {
        Write-Error "No Container Registry found in resource group $ResourceGroup"
        exit 1
    }
}

$AcrServer = "$AcrName.azurecr.io"

Write-Host "`nConfiguration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $ResourceGroup"
Write-Host "  Environment:    $EnvironmentName"
Write-Host "  ACR:            $AcrServer"

# Step 1: Build and push the job image
Write-Host "`n📦 Step 1: Building and pushing job image..." -ForegroundColor Yellow

az acr login -n $AcrName

docker build -t "$AcrServer/demo-job:latest" .
docker push "$AcrServer/demo-job:latest"

Write-Host "  ✅ Image pushed: $AcrServer/demo-job:latest" -ForegroundColor Green

# Step 2: Deploy the Bicep template
Write-Host "`n🏗️ Step 2: Deploying jobs infrastructure..." -ForegroundColor Yellow

az deployment group create `
    --resource-group $ResourceGroup `
    --template-file "./infra/main.bicep" `
    --parameters containerAppsEnvironmentName=$EnvironmentName `
    --parameters containerRegistryName=$AcrName `
    --output none

Write-Host "  ✅ Jobs deployed successfully" -ForegroundColor Green

# Step 3: Verify deployment
Write-Host "`n📋 Step 3: Verifying deployment..." -ForegroundColor Yellow

$jobs = az containerapp job list -g $ResourceGroup --query "[].{name:name, triggerType:properties.configuration.triggerType}" -o table
Write-Host $jobs

Write-Host "`n✅ Deployment Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "`nCreated Jobs:"
Write-Host "  • data-processor-scheduled (runs every 2 minutes)"
Write-Host "  • data-processor-manual (trigger on-demand)"
Write-Host "  • data-processor-parallel (runs 3 instances in parallel)"
Write-Host "`nNext steps:"
Write-Host "  1. Wait ~2 minutes to see scheduled job run"
Write-Host "  2. View jobs in Azure Portal → Container Apps Jobs"
Write-Host "  3. Follow README.md for demo walkthrough"
Write-Host ""
