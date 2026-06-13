# ⚡ Action Simulation & Tool Execution System

The **Execution Agent** uses a set of **7 Antigravity Tools** from `tool_system.py` to simulate real-world emergency response actions with precise before/after state tracking.

---

## SystemState — The Global State Model

Every tool reads the current `SystemState` and produces an updated `SystemState`:

```python
class SystemState(BaseModel):
    status: str                          # PROCESSING | IN_PROGRESS | PIPELINE_COMPLETE
    active_units: Dict[str, int]         # {"ambulance": 2, "rescue_team": 1, "fire_truck": 0}
    closed_roads: List[str]              # ["Murree Road", "Nullah Lai Bridge"]
    detour_routes: List[str]             # ["Via Expressway", "9th Avenue Detour"]
    allocated_supplies: Dict[str, int]   # {"medical_kit": 5, "food_pack": 20}
    tickets: List[str]                   # ["TKT-001: NDMA alerted"]
    public_alerts_sent: int              # count of FCM notifications sent
    resource_notes: List[str]            # free-text log entries
```

---

## The 7 Antigravity Tools

### 1. `DispatchRescueTeam`
Deploys emergency units from Supabase resource inventory.

```python
tool = DispatchRescueTeam(db_client)
response = tool.run(state, agency="Rescue 1122", units=2)
```

**State Change:**
- `active_units["rescue_team"]` += 2
- Updates Supabase `resources` table (status → "en_route")
- Logs: `"2 units dispatched from Rescue 1122"`

---

### 2. `AllocateSupplies`
Reserves medical, food, or equipment supplies.

```python
tool = AllocateSupplies(db_client)
response = tool.run(state, item_type="medical_kit", quantity=10)
```

**State Change:**
- `allocated_supplies["medical_kit"]` += 10

---

### 3. `BroadcastAlert`
Sends bilingual FCM push notification to all app users via `AlertService`.

```python
tool = BroadcastAlert(alert_service)
response = tool.run(state, message="Flood alert...", target_audience="PUBLIC")
```

**State Change:**
- `public_alerts_sent` += 1
- Triggers real FCM v1 push if Firebase configured

---

### 4. `UpdateTrafficRoute`
Marks a road as closed and sets a detour route.

```python
tool = UpdateTrafficRoute(db_client)
response = tool.run(state, close_road="Murree Road", detour_route="Via Expressway")
```

**State Change:**
- `closed_roads` += ["Murree Road"]
- `detour_routes` += ["Via Expressway"]

---

### 5. `CreateEmergencyTicket`
Creates an inter-agency emergency ticket.

```python
tool = CreateEmergencyTicket(db_client)
response = tool.run(state, target_agency="NDMA", details="Flooding P2", severity="HIGH")
```

**State Change:**
- `tickets` += ["TKT-{id}: NDMA — Flooding P2"]

---

### 6. `QueryKnowledgeBase`
Performs cosine similarity lookup on NDMA SOP knowledge base.

```python
tool = QueryKnowledgeBase()
response = tool.run(state, query="urban flood response protocol")
```

Returns relevant SOP text. **State: unchanged** (read-only lookup).

---

### 7. `UpdateIncidentStatus`
Transitions the incident status (e.g., PROCESSING → PIPELINE_COMPLETE).

```python
tool = UpdateIncidentStatus(db_client)
response = tool.run(state, new_status="PIPELINE_COMPLETE", reason="All actions executed")
```

**State Change:**
- `status` = "PIPELINE_COMPLETE"

---

## Before / After State Diff

Every execution produces a `StateDiff` showing exact changes:

```json
{
  "before_state": {
    "status": "IN_PROGRESS",
    "active_units": {"ambulance": 0, "rescue_team": 0},
    "closed_roads": [],
    "public_alerts_sent": 0
  },
  "after_state": {
    "status": "PIPELINE_COMPLETE",
    "active_units": {"ambulance": 2, "rescue_team": 3},
    "closed_roads": ["Nullah Lai Bridge"],
    "public_alerts_sent": 2
  },
  "system_state_diff": {
    "changed_keys": ["status", "active_units", "closed_roads", "public_alerts_sent"],
    "descriptions": [
      "Status changed to PIPELINE_COMPLETE",
      "2 ambulances + 3 rescue teams deployed",
      "Nullah Lai Bridge closed, Via Expressway detour set",
      "2 bilingual FCM alerts sent to ~1,200 users"
    ]
  }
}
```

---

## Manual Tool Execution (Coordinator Mode)

Dispatchers can manually trigger any tool via:

```
POST /action/execute
```

```json
{
  "incident_id": "SIG-1716223400-TXT",
  "action_type": "dispatch",
  "agency": "Rescue 1122",
  "units": 3
}
```

**Available `action_type` values:**
| Value | Tool Triggered |
|---|---|
| `dispatch` | `DispatchRescueTeam` |
| `alert` | `BroadcastAlert` |
| `reroute` | `UpdateTrafficRoute` |
| `ticket` | `CreateEmergencyTicket` |
| `status` | `UpdateIncidentStatus` |
