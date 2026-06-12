"""
dashboard_server.py — KHABAR Dashboard REST API
Provides REST endpoints for React frontend dashboard
Runs on: http://127.0.0.1:8001
"""
import sys, os
sys.path.append(os.path.join(os.path.dirname(__file__), "agents"))

import logging
# pyrefly: ignore [missing-import]
import httpx
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
# pyrefly: ignore [missing-import]
from pydantic import BaseModel
# pyrefly: ignore [missing-import]
from fastapi import FastAPI, HTTPException, BackgroundTasks
# pyrefly: ignore [missing-import]
from fastapi.middleware.cors import CORSMiddleware
# pyrefly: ignore [missing-import]
import uvicorn

# ════════════════════════════════════════════
# SETUP
# ════════════════════════════════════════════
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="KHABAR Dashboard API",
    description="REST API for Admin Dashboard",
    version="1.0.0"
)

# CORS for React frontend (port 5173)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://127.0.0.1:5173", "*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ════════════════════════════════════════════
# CONFIGURATION
# ════════════════════════════════════════════
API_SERVER_URL = "http://127.0.0.1:8000"
REQUEST_TIMEOUT = 30.0

# ════════════════════════════════════════════
# DATA MODELS
# ════════════════════════════════════════════
class ResourceCreateRequest(BaseModel):
    name: str
    resource_type: str  # ambulance|rescue|pump|medical_kit
    quantity_available: int = 1
    status: str = "available"  # available|en_route|deployed
    lat: float
    lng: float

class ResourceUpdateRequest(BaseModel):
    status: str  # available|en_route|deployed
    incident_id: Optional[str] = None

# ════════════════════════════════════════════
# UTILITY FUNCTIONS
# ════════════════════════════════════════════
async def call_api_server(endpoint: str, method: str = "GET", data: dict = None) -> dict:
    """Proxy call to api_server"""
    try:
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
            url = f"{API_SERVER_URL}{endpoint}"
            if method == "GET":
                resp = await client.get(url)
            elif method == "POST":
                resp = await client.post(url, json=data)
            elif method == "PUT":
                resp = await client.put(url, json=data)
            elif method == "DELETE":
                resp = await client.delete(url)
            
            if resp.status_code == 200:
                return resp.json()
            else:
                logger.warning(f"API server returned {resp.status_code}: {resp.text}")
                return {}
    except httpx.ConnectError:
        logger.warning(f"Cannot connect to api_server at {API_SERVER_URL}{endpoint} — is api_server.py running on port 8000?")
        return {}
    except Exception as e:
        logger.error(f"Error calling api_server: {type(e).__name__}: {repr(e)}")
        return {}

def aggregate_hotspots(incidents: List[dict]) -> Dict[str, int]:
    """
    Aggregate incidents by sector/location.
    Returns: {sector: incident_count}
    """
    hotspots = {}
    for inc in incidents:
        sector = "Unknown"
        if inc.get("location"):
            sector = inc["location"].get("area") or inc["location"].get("city") or "Unknown"
        elif inc.get("lat") and inc.get("lng"):
            # Simple sector mapping based on coordinates (Islamabad/Rawalpindi)
            lat, lng = inc["lat"], inc["lng"]
            if 33.7 <= lat <= 33.8 and 73.1 <= lng <= 73.2:
                sector = "G-10 Markaz"
            elif 33.6 <= lat <= 33.7 and 73.0 <= lng <= 73.1:
                sector = "Faizabad"
            elif lat <= 33.6 and 73.0 <= lng <= 73.2:
                sector = "Saddar"
            elif lat >= 33.85 and 73.1 <= lng <= 73.3:
                sector = "Chungi"
            else:
                sector = f"Zone-{int(lat)},{int(lng)}"
        
        hotspots[sector] = hotspots.get(sector, 0) + 1
    
    return hotspots

# ════════════════════════════════════════════
# HEALTH CHECK
# ════════════════════════════════════════════
@app.get("/health")
async def health():
    """Health check endpoint"""
    return {
        "status": "online",
        "service": "KHABAR Dashboard API",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

# ════════════════════════════════════════════
# INCIDENTS
# ════════════════════════════════════════════
@app.get("/incidents")
async def get_incidents():
    """
    Get all active incidents in P1-P5 priority order.
    Proxies to api_server /incidents endpoint.
    """
    data = await call_api_server("/incidents")
    
    if not data.get("incidents"):
        return {
            "total": 0,
            "incidents": [],
            "resource_summary": data.get("resource_summary", {})
        }
    
    return data

@app.get("/incident/{incident_id}")
async def get_incident_detail(incident_id: str):
    """
    Get full detail for a single incident.
    Proxies to api_server /incident/{id} endpoint.
    """
    data = await call_api_server(f"/incident/{incident_id}")
    
    if not data:
        raise HTTPException(status_code=404, detail=f"Incident {incident_id} not found")
    
    return data

# ════════════════════════════════════════════
# RESOURCES
# ════════════════════════════════════════════
@app.get("/resources")
async def get_resources():
    """
    Get current resource inventory.
    Proxies to api_server /resources endpoint.
    """
    data = await call_api_server("/resources")
    
    return {
        "resources": data.get("resources", []),
        "summary": data.get("summary", {}),
        "last_updated": data.get("last_updated", datetime.now(timezone.utc).isoformat())
    }

@app.post("/resource/create")
async def create_resource(req: ResourceCreateRequest):
    """
    Register a new resource with location.
    """
    payload = {
        "name": req.name,
        "resource_type": req.resource_type,
        "quantity_available": req.quantity_available,
        "status": req.status,
        "location": {
            "lat": req.lat,
            "lng": req.lng
        },
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    
    # TODO: Call firestore_db.save_resource(payload)
    # For now, return mock response
    resource_id = f"RES-{int(datetime.now().timestamp())}"
    payload["id"] = resource_id
    payload["resource_id"] = resource_id
    
    logger.info(f"Created resource: {resource_id}")
    
    return {
        "success": True,
        "resource_id": resource_id,
        "resource": payload
    }

@app.delete("/resource/{resource_id}")
async def delete_resource(resource_id: str):
    """
    Remove a resource from inventory.
    """
    # TODO: Call firestore_db.delete_resource(resource_id)
    logger.info(f"Deleted resource: {resource_id}")
    
    return {
        "success": True,
        "message": f"Resource {resource_id} deleted",
        "resource_id": resource_id
    }

@app.put("/resource/{resource_id}/status")
async def update_resource_status(resource_id: str, req: ResourceUpdateRequest):
    """
    Update resource status (available|en_route|deployed).
    """
    # TODO: Call firestore_db.update_resource_status(resource_id, req.status)
    logger.info(f"Updated resource {resource_id} status to {req.status}")
    
    return {
        "success": True,
        "resource_id": resource_id,
        "status": req.status,
        "linked_incident": req.incident_id
    }

# ════════════════════════════════════════════
# DEPLOYMENTS
# ════════════════════════════════════════════
@app.get("/deployments")
async def get_deployments():
    """
    Get active deployment tracking (resource → incident mapping).
    Returns list of active dispatches with ETA.
    """
    incidents_data = await call_api_server("/incidents")
    incidents = incidents_data.get("incidents", [])
    
    deployments = []
    for inc in incidents:
        if inc.get("status") in ["PROCESSING", "PIPELINE_COMPLETE"]:
            # For now, create mock deployment from incident
            # In production, query from deployment/dispatch table
            deployment = {
                "resource_id": f"AMB-{inc.get('incident_id', 'unknown')[-4:]}",
                "resource_name": "Ambulance",
                "incident_id": inc.get("incident_id"),
                "incident_type": inc.get("incident_type", "Unknown"),
                "status": inc.get("status"),
                "deployed_location": {
                    "lat": inc.get("lat", 33.6844),
                    "lng": inc.get("lng", 73.0479),
                },
                "target_location": inc.get("location", {}),
                "eta_minutes": 5,  # Mock ETA
                "dispatched_at": datetime.now(timezone.utc).isoformat()
            }
            deployments.append(deployment)
    
    return {
        "total": len(deployments),
        "deployments": deployments,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }

# ════════════════════════════════════════════
# SPATIAL ANALYSIS - HOTSPOTS
# ════════════════════════════════════════════
@app.get("/hotspots")
async def get_hotspots():
    """
    Get incident count aggregated by sector/area.
    Used for spatial analysis visualization.
    """
    incidents_data = await call_api_server("/incidents")
    incidents = incidents_data.get("incidents", [])
    
    hotspots = aggregate_hotspots(incidents)
    
    # Format for chart consumption
    hotspot_list = [
        {"sector": sector, "count": count}
        for sector, count in sorted(hotspots.items(), key=lambda x: x[1], reverse=True)
    ]
    
    return {
        "total_incidents": len(incidents),
        "sectors": len(hotspots),
        "hotspots": hotspot_list,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }

# ════════════════════════════════════════════
# MANUAL ACTIONS
# ════════════════════════════════════════════
class ManualActionRequest(BaseModel):
    incident_id: str
    action_type: str  # dispatch|alert|reroute|ticket|status
    agency: Optional[str] = None
    units: Optional[int] = 1
    message: Optional[str] = None
    location: Optional[str] = None
    new_status: Optional[str] = None

@app.post("/action/execute")
async def execute_manual_action(req: ManualActionRequest):
    """
    Execute manual action via coordinator (dispatch, alert, etc).
    Proxies to api_server /action/execute endpoint.
    """
    payload = req.dict()
    result = await call_api_server("/action/execute", method="POST", data=payload)
    
    if not result:
        raise HTTPException(status_code=500, detail="Failed to execute action")
    
    return result

# ════════════════════════════════════════════
# DASHBOARD SUMMARY
# ════════════════════════════════════════════
@app.get("/dashboard/summary")
async def get_dashboard_summary():
    """
    Get comprehensive dashboard summary:
    - Incident counts by priority
    - Resource status
    - Active deployments
    - Hotspots
    """
    incidents_data = await call_api_server("/incidents")
    resources_data = await call_api_server("/resources")
    
    incidents = incidents_data.get("incidents", [])
    
    # Count by priority
    priority_counts = {
        "P1": len([i for i in incidents if i.get("priority") == "P1"]),
        "P2": len([i for i in incidents if i.get("priority") == "P2"]),
        "P3": len([i for i in incidents if i.get("priority") == "P3"]),
        "P4": len([i for i in incidents if i.get("priority") == "P4"]),
        "P5": len([i for i in incidents if i.get("priority") == "P5"]),
    }
    
    # Hotspots
    hotspots = aggregate_hotspots(incidents)
    
    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "incidents": {
            "total": len(incidents),
            "by_priority": priority_counts,
            "processing": len([i for i in incidents if i.get("status") == "PROCESSING"]),
            "completed": len([i for i in incidents if i.get("status") == "PIPELINE_COMPLETE"])
        },
        "resources": resources_data.get("summary", {}),
        "hotspots": hotspots,
        "active_alerts": incidents_data.get("resource_summary", {})
    }

if __name__ == "__main__":
    print("\n" + "="*60)
    print("  KHABAR Dashboard API (REST)")
    print("  API Server: http://127.0.0.1:8001")
    print("  React Frontend: http://localhost:5173")
    print("  API Docs: http://127.0.0.1:8001/docs")
    print("="*60 + "\n")
    uvicorn.run(app, host="0.0.0.0", port=8001)
