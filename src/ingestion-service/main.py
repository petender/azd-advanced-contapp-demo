# Ingestion Service
# Python + FastAPI microservice that consumes events from Azure Event Hubs
# Demonstrates: Event-driven scaling, Dapr integration, scale-to-zero

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from azure.eventhub.aio import EventHubConsumerClient
from azure.identity.aio import DefaultAzureCredential, ManagedIdentityCredential
import asyncio
import os
import logging
import json
from datetime import datetime
from contextlib import asynccontextmanager
import httpx

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Environment configuration
# Using Managed Identity authentication (Azure Entra ID)
EVENTHUB_NAMESPACE = os.getenv("EVENTHUB_NAMESPACE", "")  # e.g., evhns-xxx.servicebus.windows.net
EVENTHUB_NAME = os.getenv("EVENTHUB_NAME", "telemetry")
CONSUMER_GROUP = os.getenv("CONSUMER_GROUP", "ingestion")
MANAGED_IDENTITY_CLIENT_ID = os.getenv("AZURE_CLIENT_ID", "")  # User-assigned managed identity
DAPR_HTTP_PORT = os.getenv("DAPR_HTTP_PORT", "3500")

# Global state
event_count = 0
last_event_time = None
consumer_task = None

# Lifespan context manager for startup/shutdown
@asynccontextmanager
async def lifespan(app: FastAPI):
    global consumer_task
    logger.info("Starting Ingestion Service...")
    # Start event consumer in background
    consumer_task = asyncio.create_task(consume_events())
    yield
    # Cleanup
    if consumer_task:
        consumer_task.cancel()
    logger.info("Ingestion Service stopped")

app = FastAPI(
    title="Ingestion Service",
    description="Event Hub consumer for CloudBurst Analytics",
    version="1.0.0",
    lifespan=lifespan
)

# ============================================================================
# Event Processing
# ============================================================================

async def process_event(event_data: dict):
    """
    Process incoming telemetry events and forward to processor service via Dapr.
    Demonstrates Dapr service invocation and pub/sub patterns.
    """
    global event_count, last_event_time
    
    event_count += 1
    last_event_time = datetime.utcnow().isoformat()
    
    # Enrich event with metadata
    enriched_event = {
        "id": event_data.get("id", str(event_count)),
        "deviceId": event_data.get("deviceId", "unknown"),
        "timestamp": event_data.get("timestamp", last_event_time),
        "eventType": event_data.get("eventType", "telemetry"),
        "payload": event_data.get("payload", {}),
        "processingMetadata": {
            "ingestedAt": last_event_time,
            "ingestedBy": "ingestion-service",
            "sequenceNumber": event_count
        }
    }
    
    # Forward to processor service via Dapr pub/sub
    await publish_to_dapr(enriched_event)
    
    return enriched_event

async def publish_to_dapr(event: dict):
    """
    Publish event to Dapr pub/sub component.
    KEY DIFFERENTIATOR: Dapr provides reliable messaging without infrastructure code.
    """
    dapr_url = f"http://localhost:{DAPR_HTTP_PORT}/v1.0/publish/pubsub/telemetry-events"
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                dapr_url,
                json=event,
                headers={"Content-Type": "application/json"}
            )
            if response.status_code == 204:
                logger.debug(f"Published event {event['id']} to Dapr pub/sub")
            else:
                logger.warning(f"Dapr publish returned {response.status_code}")
    except Exception as e:
        logger.error(f"Failed to publish to Dapr: {e}")
        # In production, implement retry logic or dead-letter queue

async def consume_events():
    """
    Consume events from Azure Event Hubs using Managed Identity.
    Container Apps will scale this based on Event Hub message lag.
    """
    if not EVENTHUB_NAMESPACE:
        logger.warning("No Event Hub namespace configured (EVENTHUB_NAMESPACE)")
        return
    
    logger.info(f"Starting Event Hub consumer for {EVENTHUB_NAME} on {EVENTHUB_NAMESPACE}")
    
    async def on_event(partition_context, event):
        try:
            event_data = json.loads(event.body_as_str())
            await process_event(event_data)
            await partition_context.update_checkpoint(event)
        except Exception as e:
            logger.error(f"Error processing event: {e}")
    
    # Use managed identity credential for authentication
    credential = None
    try:
        if MANAGED_IDENTITY_CLIENT_ID:
            # Use specific user-assigned managed identity
            credential = ManagedIdentityCredential(client_id=MANAGED_IDENTITY_CLIENT_ID)
            logger.info(f"Using user-assigned managed identity: {MANAGED_IDENTITY_CLIENT_ID}")
        else:
            # Fall back to default credential chain
            credential = DefaultAzureCredential()
            logger.info("Using default Azure credential")
        
        # Create consumer using managed identity
        fully_qualified_namespace = EVENTHUB_NAMESPACE if ".servicebus.windows.net" in EVENTHUB_NAMESPACE else f"{EVENTHUB_NAMESPACE}.servicebus.windows.net"
        
        consumer = EventHubConsumerClient(
            fully_qualified_namespace=fully_qualified_namespace,
            eventhub_name=EVENTHUB_NAME,
            consumer_group=CONSUMER_GROUP,
            credential=credential
        )
        
        async with consumer:
            await consumer.receive(
                on_event=on_event,
                starting_position="-1"  # Start from latest
            )
    except Exception as e:
        logger.error(f"Event Hub consumer error: {e}")
    finally:
        if credential:
            await credential.close()

# ============================================================================
# API Endpoints
# ============================================================================

@app.get("/")
async def root():
    """Service information endpoint."""
    return {
        "service": "ingestion-service",
        "version": "1.0.0",
        "description": "Event Hub consumer for CloudBurst Analytics",
        "differentiators": [
            "Scale-to-zero when no events",
            "Event-driven autoscaling via KEDA",
            "Dapr pub/sub for reliable messaging"
        ]
    }

@app.get("/health")
async def health():
    """Liveness probe for Container Apps."""
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}

@app.get("/ready")
async def ready():
    """Readiness probe for Container Apps."""
    return {"status": "ready", "timestamp": datetime.utcnow().isoformat()}

@app.get("/stats")
async def stats():
    """Return processing statistics."""
    return {
        "eventsProcessed": event_count,
        "lastEventTime": last_event_time,
        "consumerGroup": CONSUMER_GROUP,
        "eventHubName": EVENTHUB_NAME
    }

@app.post("/simulate")
async def simulate_event(request: Request):
    """
    Simulate an incoming event for testing.
    Useful for demos when Event Hub is not configured.
    Includes artificial delay to demonstrate scaling under load.
    """
    # Artificial delay to simulate processing time and create visible concurrency for scaling demos
    await asyncio.sleep(0.5)  # 500ms delay per request
    
    try:
        event_data = await request.json()
    except:
        event_data = {
            "id": f"sim-{event_count + 1}",
            "deviceId": "simulator-001",
            "eventType": "temperature",
            "payload": {
                "temperature": 72.5,
                "humidity": 45.2,
                "pressure": 1013.25
            }
        }
    
    processed = await process_event(event_data)
    return {"message": "Event simulated", "event": processed}

# ============================================================================
# Dapr Subscription Endpoint (for pub/sub)
# ============================================================================

@app.get("/dapr/subscribe")
async def subscribe():
    """
    Dapr subscription configuration.
    Tells Dapr which topics this service subscribes to.
    """
    return []  # Ingestion service publishes only, doesn't subscribe

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
