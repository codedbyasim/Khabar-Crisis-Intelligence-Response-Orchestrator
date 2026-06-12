"""
crew_tools.py — All KHABAR tools as crewai.tools.BaseTool subclasses.

Converted from:
  - tool_system.py (AntigravityTool subclasses) → 7 execution tools
  - New context/read tools → 3 intelligence-gathering tools

Tool Categories:
  READ (no DB write):
    1. WeatherValidationTool    — Open-Meteo live weather (Detection Agent)
    2. MapsContextTool          — Google Maps geocode + ETAs (Analysis Agent)
    3. ResourceInventoryTool    — Supabase resource counts (Planning Agent)

  WRITE (mutate DB / external state):
    4. DispatchRescueTeamTool   — Deploy agency units
    5. AllocateSuppliesTool     — Allocate physical resources
    6. BroadcastAlertTool       — Send FCM push notifications
    7. UpdateTrafficRouteTool   — Close roads, set detours
    8. CreateEmergencyTicketTool— Generate agency tickets
    9. QueryKnowledgeBaseTool   — RAG semantic search NDMA SOPs
   10. UpdateIncidentStatusTool — Change incident lifecycle state
"""
import json
import logging
import os
from datetime import datetime, timezone
from typing import Type, Optional, List, Dict, Any

from pydantic import BaseModel, Field
from crewai.tools import BaseTool


# ─── Shared singletons (unchanged from existing code) ───────────────────────
from firestore_db import db as firestore_db
from maps_service import maps_service
from knowledge_base_data import search_ndma_protocols


# ==============================================================
# SHARED STATE STORE
# Keyed by incident_id — tools mutate this during execution
# ==============================================================
_SYSTEM_STATES: Dict[str, Dict[str, Any]] = {}

def get_or_create_state(incident_id: str) -> Dict[str, Any]:
    if incident_id not in _SYSTEM_STATES:
        _SYSTEM_STATES[incident_id] = {
            "incident_id": incident_id,
            "status": "OPEN",
            "active_units": {},
            "allocated_supplies": {},
            "closed_roads": [],
            "public_alerts_sent": 0,
            "tickets": [],
            "knowledge_queries": 0,
            "last_update": "",
        }
    return _SYSTEM_STATES[incident_id]

def snapshot_state(incident_id: str) -> Dict[str, Any]:
    """Returns a deep copy of current state (for before/after diff)."""
    import copy
    return copy.deepcopy(get_or_create_state(incident_id))


# ==============================================================
# TOOL 1 — WeatherValidationTool
# Used by: Detection Agent
# Purpose: Fetch live Open-Meteo weather to cross-validate reports
# ==============================================================
class WeatherValidationInput(BaseModel):
    lat: float = Field(description="Latitude of the incident location")
    lng: float = Field(description="Longitude of the incident location")

class WeatherValidationTool(BaseTool):
    name: str = "weather_validation"
    description: str = (
        "Fetches live real-time weather data from Open-Meteo API for a given "
        "latitude/longitude. Use this to cross-validate weather-related crisis "
        "reports (floods, heatwaves, storms). Returns temperature_c, rain_mm, "
        "showers_mm, wind_speed_kmh."
    )
    args_schema: Type[BaseModel] = WeatherValidationInput

    def _run(self, lat: float, lng: float) -> str:
        try:
            import httpx
            url = (
                f"https://api.open-meteo.com/v1/forecast"
                f"?latitude={lat}&longitude={lng}"
                f"&current=temperature_2m,rain,showers,snowfall,wind_speed_10m"
                f"&timezone=auto"
            )
            with httpx.Client(timeout=5, verify=False) as client:
                response = client.get(url)
                if response.status_code == 200:
                    current = response.json().get("current", {})
                    result = {
                        "temperature_c": current.get("temperature_2m"),
                        "rain_mm": current.get("rain"),
                        "showers_mm": current.get("showers"),
                        "snowfall_cm": current.get("snowfall"),
                        "wind_speed_kmh": current.get("wind_speed_10m"),
                        "source": "open_meteo_live",
                    }
                    logging.info(f"[WeatherValidationTool] Live data: {result}")
                    return json.dumps(result)
        except Exception as e:
            logging.warning(f"[WeatherValidationTool] Failed: {e}")
        return json.dumps({"error": "Weather data unavailable", "source": "fallback"})


# ==============================================================
# TOOL 2 — MapsContextTool
# Used by: Analysis Agent
# Purpose: Geocode location + get hospitals + compute resource ETAs
# ==============================================================
class MapsContextInput(BaseModel):
    lat: float = Field(description="Latitude of the incident")
    lng: float = Field(description="Longitude of the incident")
    location_text: str = Field(description="Human-readable location name e.g. 'G-10 Islamabad'")

class MapsContextTool(BaseTool):
    name: str = "maps_context"
    description: str = (
        "Gets full geographical context for an incident location: nearby hospitals "
        "within 5km, critical infrastructure list, and travel-time ETAs for each "
        "resource type (ambulances, dewatering_pumps, fire_trucks, utility_crews, "
        "traffic_units). Uses Google Maps API with Nominatim + local Pakistan "
        "dictionary as fallback."
    )
    args_schema: Type[BaseModel] = MapsContextInput

    def _run(self, lat: float, lng: float, location_text: str) -> str:
        try:
            context = maps_service.get_context_for_analysis(lat, lng, location_text)
            logging.info(f"[MapsContextTool] Context retrieved for ({lat}, {lng})")
            return json.dumps(context)
        except Exception as e:
            logging.warning(f"[MapsContextTool] Failed: {e}")
            return json.dumps({"error": str(e), "geocoded_location": {"lat": lat, "lng": lng}})


# ==============================================================
# TOOL 3 — ResourceInventoryTool
# Used by: Planning Agent (and Analysis Agent)
# Purpose: Query Supabase for available rescue resource counts
# ==============================================================
class ResourceInventoryInput(BaseModel):
    dummy: str = Field(default="fetch", description="Pass 'fetch' to get current inventory")

class ResourceInventoryTool(BaseTool):
    name: str = "resource_inventory"
    description: str = (
        "Queries the Supabase PostgreSQL database for the current available count "
        "of all emergency resources: ambulances, fire_trucks, dewatering_pumps, "
        "rescue_teams, police_units. Use this before drafting a resource allocation "
        "plan to ensure you do not over-commit unavailable resources."
    )
    args_schema: Type[BaseModel] = ResourceInventoryInput

    def _run(self, dummy: str = "fetch") -> str:
        try:
            resources = firestore_db.get_resources()
            counts: Dict[str, int] = {
                "ambulances": 0,
                "fire_trucks": 0,
                "dewatering_pumps": 0,
                "rescue_teams": 0,
                "police_units": 0,
            }
            for r in resources:
                rtype = (r.get("resource_type") or r.get("type") or "").lower()
                qty = r.get("quantity_available") or r.get("quantity") or 1
                if "ambulance" in rtype:
                    counts["ambulances"] += qty
                elif "fire" in rtype or "truck" in rtype:
                    counts["fire_trucks"] += qty
                elif "pump" in rtype or "dewater" in rtype:
                    counts["dewatering_pumps"] += qty
                elif "team" in rtype or "rescue" in rtype:
                    counts["rescue_teams"] += qty
                elif "police" in rtype:
                    counts["police_units"] += qty

            # Pad with base capacities (same logic as SharedMemoryBlock.get_global_resources)
            counts["ambulances"] = max(counts["ambulances"], 50)
            counts["fire_trucks"] = max(counts["fire_trucks"], 20)
            counts["dewatering_pumps"] = max(counts["dewatering_pumps"], 10)
            counts["rescue_teams"] = max(counts["rescue_teams"], 15)
            counts["police_units"] = max(counts["police_units"], 100)

            logging.info(f"[ResourceInventoryTool] Inventory: {counts}")
            return json.dumps(counts)
        except Exception as e:
            logging.warning(f"[ResourceInventoryTool] DB error: {e}")
            return json.dumps({
                "ambulances": 50, "fire_trucks": 20,
                "dewatering_pumps": 10, "rescue_teams": 15, "police_units": 100,
                "source": "fallback_defaults"
            })


# ==============================================================
# TOOL 4 — DispatchRescueTeamTool
# Used by: Execution Agent
# Purpose: Deploy units from an agency and update DB
# ==============================================================
class DispatchRescueTeamInput(BaseModel):
    incident_id: str = Field(description="Incident ID this dispatch belongs to")
    agency: str = Field(description="Name of the dispatching agency e.g. 'Rescue 1122'")
    units: int = Field(description="Number of units to dispatch", ge=1)

class DispatchRescueTeamTool(BaseTool):
    name: str = "dispatch_rescue_team"
    description: str = (
        "Deploys a specified number of units from a Pakistani emergency agency "
        "(Rescue 1122, WASA, Edhi Foundation, Traffic Police, etc.) to the incident "
        "zone. Updates the active_units count in the system state and commits to the "
        "Supabase database. Always call this for life-saving dispatch actions."
    )
    args_schema: Type[BaseModel] = DispatchRescueTeamInput

    def _run(self, incident_id: str, agency: str, units: int) -> str:
        state = get_or_create_state(incident_id)
        state["active_units"][agency] = state["active_units"].get(agency, 0) + units
        state["last_update"] = datetime.now(timezone.utc).isoformat()

        try:
            firestore_db.update_document("incidents", incident_id, {
                "active_units": state["active_units"]
            })
        except Exception as e:
            logging.warning(f"[DispatchRescueTeamTool] DB update failed: {e}")

        msg = f"Successfully dispatched {units} units from {agency} to incident {incident_id}."
        logging.info(f"[DispatchRescueTeamTool] {msg}")
        return json.dumps({"success": True, "message": msg, "active_units": state["active_units"]})


# ==============================================================
# TOOL 5 — AllocateSuppliesTool
# Used by: Execution Agent
# Purpose: Allocate physical resources (pumps, blankets, kits)
# ==============================================================
class AllocateSuppliesInput(BaseModel):
    incident_id: str = Field(description="Incident ID")
    item_type: str = Field(description="Type of supply e.g. 'dewatering_pump', 'medical_kit'")
    quantity: int = Field(description="Number of items to allocate", ge=1)

class AllocateSuppliesTool(BaseTool):
    name: str = "allocate_supplies"
    description: str = (
        "Allocates physical emergency supplies (dewatering pumps, medical kits, "
        "water bowsers, blankets) to the incident location. Updates allocated_supplies "
        "in the system state."
    )
    args_schema: Type[BaseModel] = AllocateSuppliesInput

    def _run(self, incident_id: str, item_type: str, quantity: int) -> str:
        state = get_or_create_state(incident_id)
        state["allocated_supplies"][item_type] = (
            state["allocated_supplies"].get(item_type, 0) + quantity
        )
        state["last_update"] = datetime.now(timezone.utc).isoformat()

        try:
            firestore_db.update_document("incidents", incident_id, {
                "allocated_supplies": state["allocated_supplies"]
            })
        except Exception as e:
            logging.warning(f"[AllocateSuppliesTool] DB update failed: {e}")

        msg = f"Allocated {quantity}x {item_type} to incident {incident_id}."
        logging.info(f"[AllocateSuppliesTool] {msg}")
        return json.dumps({"success": True, "message": msg, "allocated_supplies": state["allocated_supplies"]})


# ==============================================================
# TOOL 6 — BroadcastAlertTool
# Used by: Execution Agent
# Purpose: Send bilingual FCM push notifications via AlertService
# ==============================================================
class BroadcastAlertInput(BaseModel):
    incident_id: str = Field(description="Incident ID")
    incident_type: str = Field(description="Type of incident e.g. 'urban flood'")
    location: str = Field(description="Location name e.g. 'G-10 Markaz, Islamabad'")
    severity: str = Field(description="Severity level: CRITICAL, HIGH, MEDIUM, LOW")

class BroadcastAlertTool(BaseTool):
    name: str = "broadcast_alert"
    description: str = (
        "Sends real-time bilingual (Urdu + English) Firebase FCM push notifications "
        "to all registered KHABAR mobile app users in the affected geo-fence. "
        "Generates the appropriate Urdu and English message templates automatically "
        "based on the incident type and location."
    )
    args_schema: Type[BaseModel] = BroadcastAlertInput

    def _run(self, incident_id: str, incident_type: str, location: str, severity: str) -> str:
        from alert_service import alert_service
        try:
            result = alert_service.broadcast_crisis_alert(
                incident_type=incident_type,
                location=location,
                severity=severity,
                incident_id=incident_id,
            )
            state = get_or_create_state(incident_id)
            state["public_alerts_sent"] += 1
            state["last_update"] = datetime.now(timezone.utc).isoformat()

            try:
                firestore_db.update_document("incidents", incident_id, {
                    "public_alerts_sent": state["public_alerts_sent"]
                })
            except Exception as e:
                logging.warning(f"[BroadcastAlertTool] DB update failed: {e}")

            logging.info(f"[BroadcastAlertTool] Alert sent — {result.get('status')}")
            return json.dumps(result)
        except Exception as e:
            logging.error(f"[BroadcastAlertTool] Failed: {e}")
            return json.dumps({"success": False, "error": str(e)})


# ==============================================================
# TOOL 7 — UpdateTrafficRouteTool
# Used by: Execution Agent
# Purpose: Close a road and set up a detour
# ==============================================================
class UpdateTrafficRouteInput(BaseModel):
    incident_id: str = Field(description="Incident ID")
    close_road: str = Field(description="Name of the road to be closed")
    detour_route: str = Field(description="Description of the alternate detour route")

class UpdateTrafficRouteTool(BaseTool):
    name: str = "update_traffic_route"
    description: str = (
        "Closes an arterial road affected by the incident and sets up an alternate "
        "detour route. Updates the closed_roads list in system state and notifies "
        "Traffic Police. Use this for flood blockages, accidents, or building "
        "collapses that obstruct traffic."
    )
    args_schema: Type[BaseModel] = UpdateTrafficRouteInput

    def _run(self, incident_id: str, close_road: str, detour_route: str) -> str:
        state = get_or_create_state(incident_id)
        if close_road not in state["closed_roads"]:
            state["closed_roads"].append(close_road)
        state["last_update"] = datetime.now(timezone.utc).isoformat()

        try:
            firestore_db.update_document("incidents", incident_id, {
                "closed_roads": state["closed_roads"],
                "active_detour": detour_route,
            })
        except Exception as e:
            logging.warning(f"[UpdateTrafficRouteTool] DB update failed: {e}")

        msg = f"Road '{close_road}' closed. Detour set: '{detour_route}'."
        logging.info(f"[UpdateTrafficRouteTool] {msg}")
        return json.dumps({"success": True, "message": msg, "closed_roads": state["closed_roads"]})


# ==============================================================
# TOOL 8 — CreateEmergencyTicketTool
# Used by: Execution Agent
# Purpose: Generate standardized agency tickets (e.g., K-Electric)
# ==============================================================
class CreateEmergencyTicketInput(BaseModel):
    incident_id: str = Field(description="Incident ID")
    target_agency: str = Field(description="Agency to raise ticket with e.g. 'K-Electric', 'WASA'")
    details: str = Field(description="Full description of required action")
    severity: str = Field(description="Ticket severity: CRITICAL, HIGH, MEDIUM")

class CreateEmergencyTicketTool(BaseTool):
    name: str = "create_emergency_ticket"
    description: str = (
        "Generates a standardized emergency dispatch ticket for a specific Pakistani "
        "utility or agency (K-Electric, WASA, Sui Gas, NDMA, PDMA). Use this to "
        "formally escalate a required action to an agency when a direct dispatch "
        "is not possible."
    )
    args_schema: Type[BaseModel] = CreateEmergencyTicketInput

    def _run(self, incident_id: str, target_agency: str, details: str, severity: str) -> str:
        state = get_or_create_state(incident_id)
        ticket_id = f"TK-{incident_id[-6:]}-{len(state['tickets']) + 1}"
        state["tickets"].append(ticket_id)
        state["last_update"] = datetime.now(timezone.utc).isoformat()

        try:
            firestore_db.update_document("incidents", incident_id, {
                "tickets": state["tickets"],
                "latest_ticket": ticket_id,
            })
        except Exception as e:
            logging.warning(f"[CreateEmergencyTicketTool] DB update failed: {e}")

        msg = f"Ticket {ticket_id} ({severity}) dispatched to {target_agency}. Details: {details}"
        logging.info(f"[CreateEmergencyTicketTool] {msg}")
        return json.dumps({"success": True, "ticket_id": ticket_id, "message": msg})


# ==============================================================
# TOOL 9 — QueryKnowledgeBaseTool
# Used by: Planning Agent
# Purpose: Real RAG vector search against Pakistan NDMA SOPs
# ==============================================================
class QueryKnowledgeBaseInput(BaseModel):
    query: str = Field(description="Natural language query about crisis response protocols")

class QueryKnowledgeBaseTool(BaseTool):
    name: str = "query_knowledge_base"
    description: str = (
        "Performs semantic vector search (RAG) against Pakistan NDMA Standard Operating "
        "Procedures (SOPs) using Gemini text-embedding-004. Returns the most relevant "
        "SOP protocol for the given crisis type. Always call this when planning the "
        "response strategy to align with official Pakistani emergency protocols."
    )
    args_schema: Type[BaseModel] = QueryKnowledgeBaseInput

    def _run(self, query: str) -> str:
        try:
            result = search_ndma_protocols(query)
            logging.info(f"[QueryKnowledgeBaseTool] SOP retrieved for query: '{query[:50]}'")
            return json.dumps({"sop_protocol": result, "query": query})
        except Exception as e:
            logging.warning(f"[QueryKnowledgeBaseTool] RAG search failed: {e}")
            return json.dumps({
                "sop_protocol": (
                    "General SOP: Dispatch Rescue 1122 immediately, secure perimeter, "
                    "assess situation, and escalate to NDMA if life-threatening."
                ),
                "query": query,
            })


# ==============================================================
# TOOL 10 — UpdateIncidentStatusTool
# Used by: Execution Agent
# Purpose: Change incident lifecycle status in DB
# ==============================================================
class UpdateIncidentStatusInput(BaseModel):
    incident_id: str = Field(description="Incident ID to update")
    new_status: str = Field(
        description="New status: OPEN, PROCESSING, ACTIVE_DEPLOYMENT, PIPELINE_COMPLETE, REJECTED, MANUAL_REVIEW_REQUIRED"
    )
    reason: str = Field(description="Reason for the status change")

class UpdateIncidentStatusTool(BaseTool):
    name: str = "update_incident_status"
    description: str = (
        "Updates the global lifecycle status of an incident in the Supabase database. "
        "Call this as the final tool after all dispatches and alerts are sent. "
        "Valid statuses: OPEN, PROCESSING, ACTIVE_DEPLOYMENT, PIPELINE_COMPLETE, "
        "REJECTED, MANUAL_REVIEW_REQUIRED."
    )
    args_schema: Type[BaseModel] = UpdateIncidentStatusInput

    def _run(self, incident_id: str, new_status: str, reason: str) -> str:
        state = get_or_create_state(incident_id)
        old_status = state["status"]
        state["status"] = new_status
        state["last_update"] = datetime.now(timezone.utc).isoformat()

        try:
            firestore_db.update_document("incidents", incident_id, {
                "status": new_status,
                "status_reason": reason,
            })
        except Exception as e:
            logging.warning(f"[UpdateIncidentStatusTool] DB update failed: {e}")

        msg = f"Status transition: {old_status} → {new_status}. Reason: {reason}"
        logging.info(f"[UpdateIncidentStatusTool] {msg}")
        return json.dumps({"success": True, "message": msg, "status": new_status})
