import json
import logging
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional
from pydantic import BaseModel, Field

# ==========================================
# CORE SCHEMAS & STATE TRACKING
# ==========================================
class SystemState(BaseModel):
    incident_id: str
    status: str = "OPEN"
    active_units: Dict[str, int] = Field(default_factory=dict)
    allocated_supplies: Dict[str, int] = Field(default_factory=dict)
    closed_roads: List[str] = Field(default_factory=list)
    public_alerts_sent: int = 0
    tickets: List[str] = Field(default_factory=list)
    knowledge_queries: int = 0
    last_update: str = ""

class ToolResponse(BaseModel):
    tool_name: str
    success: bool
    output_message: str
    execution_time: str
    logs: List[str]
    before_state: SystemState
    after_state: SystemState
    firestore_update_payload: Dict[str, Any]

# Use real KhabarFirestore singleton as database backend
from firestore_db import db as _default_db, KhabarFirestore

# Backward-compatible alias so old code using MockFirestore() still works
class MockFirestore:
    """Thin wrapper — delegates all calls to the KhabarFirestore singleton."""
    def update_document(self, collection: str, doc_id: str, data: dict):
        _default_db.update_document(collection, doc_id, data)


# ==========================================
# BASE TOOL CLASS
# ==========================================
class AntigravityTool:
    def __init__(self, db_client: MockFirestore):
        self.db = db_client
        self.logs: List[str] = []

    def log(self, message: str):
        timestamp = datetime.now(timezone.utc).isoformat()
        log_entry = f"[{timestamp}] [TRACE-{self.__class__.__name__}] {message}"
        self.logs.append(log_entry)
        logging.info(log_entry)

    def _execute(self, state: SystemState, **kwargs) -> ToolResponse:
        raise NotImplementedError

    def run(self, state: SystemState, **kwargs) -> ToolResponse:
        self.logs = []
        self.log(f"Starting execution with params: {kwargs}")
        
        before_state = state.model_copy(deep=True)
        
        try:
            # Subclasses implement actual state mutation logic here
            after_state, output_message, firestore_payload = self._execute(state, **kwargs)
            after_state.last_update = datetime.now(timezone.utc).isoformat()
            
            # Simulated DB commit
            self.db.update_document("incidents", after_state.incident_id, firestore_payload)
            self.log("Firestore commit successful.")
            
            return ToolResponse(
                tool_name=self.__class__.__name__,
                success=True,
                output_message=output_message,
                execution_time=datetime.now(timezone.utc).isoformat(),
                logs=self.logs,
                before_state=before_state,
                after_state=after_state,
                firestore_update_payload=firestore_payload
            )
        except Exception as e:
            self.log(f"Execution FAILED: {str(e)}")
            return ToolResponse(
                tool_name=self.__class__.__name__,
                success=False,
                output_message=f"Error: {str(e)}",
                execution_time=datetime.now(timezone.utc).isoformat(),
                logs=self.logs,
                before_state=before_state,
                after_state=before_state,
                firestore_update_payload={}
            )

# ==========================================
# 1. DISPATCH RESCUE TEAM
# ==========================================
class DispatchRescueTeam(AntigravityTool):
    """
    PURPOSE: Deploys specific units from an agency to the incident zone.
    PARAMETERS: agency (str), units (int)
    """
    def _execute(self, state: SystemState, agency: str, units: int):
        self.log(f"Allocating {units} units from {agency}.")
        state.active_units[agency] = state.active_units.get(agency, 0) + units
        
        payload = {"active_units": state.active_units}
        msg = f"Successfully dispatched {units} units from {agency}."
        return state, msg, payload

# ==========================================
# 2. ALLOCATE SUPPLIES
# ==========================================
class AllocateSupplies(AntigravityTool):
    """
    PURPOSE: Allocates physical resources (water, pumps, blankets) to the scene.
    PARAMETERS: item_type (str), quantity (int)
    """
    def _execute(self, state: SystemState, item_type: str, quantity: int):
        self.log(f"Provisioning {quantity}x {item_type}.")
        state.allocated_supplies[item_type] = state.allocated_supplies.get(item_type, 0) + quantity
        
        payload = {"allocated_supplies": state.allocated_supplies}
        msg = f"Allocated {quantity} of {item_type}."
        return state, msg, payload

# ==========================================
# 3. BROADCAST ALERT
# ==========================================
class BroadcastAlert(AntigravityTool):
    """
    PURPOSE: Sends SMS/push notifications to citizens in affected geo-fences.
    PARAMETERS: message (str), target_audience (str)
    """
    def _execute(self, state: SystemState, message: str, target_audience: str):
        self.log(f"Broadcasting to {target_audience}: '{message}'")
        state.public_alerts_sent += 1
        
        payload = {"public_alerts_sent": state.public_alerts_sent, "last_alert_msg": message}
        msg = f"Alert sent to {target_audience}."
        return state, msg, payload

# ==========================================
# 4. UPDATE TRAFFIC ROUTE
# ==========================================
class UpdateTrafficRoute(AntigravityTool):
    """
    PURPOSE: Closes arterial roads and updates maps APIs for detours.
    PARAMETERS: close_road (str), detour_route (str)
    """
    def _execute(self, state: SystemState, close_road: str, detour_route: str):
        self.log(f"Closing road: {close_road}. Setting detour: {detour_route}")
        if close_road not in state.closed_roads:
            state.closed_roads.append(close_road)
            
        payload = {"closed_roads": state.closed_roads, "active_detour": detour_route}
        msg = f"Traffic updated. {close_road} closed."
        return state, msg, payload

# ==========================================
# 5. CREATE EMERGENCY TICKET
# ==========================================
class CreateEmergencyTicket(AntigravityTool):
    """
    PURPOSE: Generates standardized tickets for IESCO, WASA, Rescue 1122, CDA, and other Islamabad/Rawalpindi agencies.
    PARAMETERS: target_agency (str), details (str), severity (str)
    """
    def _execute(self, state: SystemState, target_agency: str, details: str, severity: str):
        ticket_id = f"TK-{state.incident_id[-4:]}-{len(state.tickets)+1}"
        self.log(f"Generating {severity} ticket {ticket_id} for {target_agency}. Details: {details}")
        
        state.tickets.append(ticket_id)
        
        payload = {"tickets": state.tickets, "latest_ticket": ticket_id}
        msg = f"Ticket {ticket_id} dispatched to {target_agency}."
        return state, msg, payload

# ==========================================
# 6. QUERY KNOWLEDGE BASE
# ==========================================
from knowledge_base_data import search_ndma_protocols

class QueryKnowledgeBase(AntigravityTool):
    """
    PURPOSE: Retrieves SOPs or historical mitigation strategies from the vector database.
    PARAMETERS: query (str)
    """
    def _execute(self, state: SystemState, query: str):
        self.log(f"Querying NDMA Vector DB: '{query}'")
        state.knowledge_queries += 1
        
        # Real retrieval from Pakistan NDMA Knowledge Base
        retrieved_sop = search_ndma_protocols(query)
        self.log(f"Retrieved: {retrieved_sop}")
        
        payload = {"knowledge_queries": state.knowledge_queries}
        msg = f"Knowledge base returned: {retrieved_sop}"
        return state, msg, payload

# ==========================================
# 7. UPDATE INCIDENT STATUS
# ==========================================
class UpdateIncidentStatus(AntigravityTool):
    """
    PURPOSE: Changes the global escalation state of the incident.
    PARAMETERS: new_status (str), reason (str)
    """
    def _execute(self, state: SystemState, new_status: str, reason: str):
        self.log(f"State transition: {state.status} -> {new_status}. Reason: {reason}")
        state.status = new_status
        
        payload = {"status": state.status, "status_reason": reason}
        msg = f"Incident status escalated to {new_status}."
        return state, msg, payload


# ==========================================
# EXAMPLE EXECUTION & ORCHESTRATION
# ==========================================
if __name__ == "__main__":
    import sys
    if sys.stdout.encoding != 'utf-8':
        sys.stdout.reconfigure(encoding='utf-8')
    logging.basicConfig(level=logging.INFO, format='%(message)s')
    
    db = MockFirestore()
    
    # Initialize the tools
    dispatch_tool = DispatchRescueTeam(db)
    alert_tool = BroadcastAlert(db)
    traffic_tool = UpdateTrafficRoute(db)
    ticket_tool = CreateEmergencyTicket(db)
    status_tool = UpdateIncidentStatus(db)
    
    # Starting State
    current_state = SystemState(incident_id="INC-2026-XQZ9")
    
    print("\n" + "="*50)
    print("KHABAR ANTIGRAVITY TOOL SYSTEM INITIALIZED")
    print("="*50 + "\n")
    
    # Execute Pipeline
    responses = []
    
    responses.append(ticket_tool.run(current_state, target_agency="IESCO", details="Power cut required at flooded Nullah Lai Bridge section", severity="CRITICAL"))
    responses.append(dispatch_tool.run(current_state, agency="Rescue 1122", units=3))
    responses.append(traffic_tool.run(current_state, close_road="Murree Road Rawalpindi", detour_route="Peshawar Road Alternative"))
    responses.append(alert_tool.run(current_state, message="خطرہ: مری روڈ راولپنڈی میں سیلاب۔ محفوظ مقام پر جائیں۔", target_audience="Rawalpindi/Islamabad Citizens"))
    responses.append(status_tool.run(current_state, new_status="RESPONDING", reason="Initial response pipeline deployed for Rawalpindi flood incident."))
    
    # Output Results
    for idx, resp in enumerate(responses):
        print(f"\n--- TOOL {idx+1}: {resp.tool_name} ---")
        print(resp.model_dump_json(indent=2))
        
    print("\n--- FINAL GLOBAL SYSTEM STATE ---")
    print(current_state.model_dump_json(indent=2))
