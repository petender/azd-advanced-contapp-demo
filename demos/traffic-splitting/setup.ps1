# Traffic Splitting Demo - Quick Setup Script
# Run this before the demo to set up the hello-api service

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$false)]
    [string]$EnvironmentName = ""
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 Traffic Splitting Demo Setup" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Get environment name if not provided
if ([string]::IsNullOrEmpty($EnvironmentName)) {
    $EnvironmentName = az containerapp env list -g $ResourceGroup --query "[0].name" -o tsv
}

# Get ACR name
$AcrName = az acr list -g $ResourceGroup --query "[0].name" -o tsv
$AcrServer = "$AcrName.azurecr.io"

Write-Host "`nConfiguration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $ResourceGroup"
Write-Host "  Environment: $EnvironmentName"
Write-Host "  ACR: $AcrServer"

# Login to ACR
Write-Host "`n📦 Logging into ACR..." -ForegroundColor Yellow
az acr login -n $AcrName

# Build v1
Write-Host "`n🔨 Building v1 (blue)..." -ForegroundColor Yellow
docker build -t "$AcrServer/hello-api:v1" .
docker push "$AcrServer/hello-api:v1"

# Build v2
Write-Host "`n🔨 Building v2 (green)..." -ForegroundColor Yellow
# Update the Dockerfile or use build arg for v2
docker build -t "$AcrServer/hello-api:v2" --build-arg APP_VERSION=v2 .
docker push "$AcrServer/hello-api:v2"

# Deploy v1
Write-Host "`n🚀 Deploying v1..." -ForegroundColor Yellow
$Fqdn = az containerapp create `
    --name hello-api `
    --resource-group $ResourceGroup `
    --environment $EnvironmentName `
    --image "$AcrServer/hello-api:v1" `
    --target-port 3000 `
    --ingress external `
    --min-replicas 1 `
    --max-replicas 5 `
    --env-vars "APP_VERSION=v1" `
    --registry-server $AcrServer `
    --query "properties.configuration.ingress.fqdn" -o tsv

# Enable multiple revision mode
Write-Host "`n⚙️ Enabling multiple revision mode..." -ForegroundColor Yellow
az containerapp revision set-mode -n hello-api -g $ResourceGroup --mode Multiple

Write-Host "`n✅ Setup Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host "Hello API URL: https://$Fqdn" -ForegroundColor Cyan
Write-Host "`nNext steps:"
Write-Host "  1. Open the URL in browser - should show blue 'v1'"
Write-Host "  2. Run demo commands from README.md"
Write-Host ""
