# 📊 Outcome Visualization & Incident Trace

KHABAR provides full transparency into every AI agent decision through the **Incident Detail Screen** in the Flutter app and the **Web Dashboard**.

---

## 1. Flutter Incident Detail Screen

**File:** `lib/screens/incident_detail_screen.dart`

Displays the complete outcome of the 4-agent pipeline for a single incident:

### Sections:

#### 🔍 Detection Summary
- Incident type (e.g., `URBAN_FLOODING`)
- Priority badge: P1 (red) to P5 (grey)
- Confidence percentage
- Verification status (✅ Verified / ❌ Rejected)
- Extracted location (area, sector, city, lat/lng)

#### 📊 Analysis Summary
- Severity score (1–10)
- Estimated affected population
- Stranded vehicles count
- Nearest hospital + ETA
- Bilingual public warning (Urdu + English)

#### 💡 Action Plan
- Response strategy (e.g., "Multi-agency flood response")
- Ordered list of recommended actions with priority badges
- Target agencies

#### ⚡ Execution Results
- Each executed tool with ✅/❌ status
- Generated bilingual alerts (displayed in card format)
- Final outcome string

#### 📋 Before / After State Comparison
Side-by-side card layout showing:

| Before | After |
|---|---|
| ambulance: 0 | ambulance: 2 |
| rescue_team: 0 | rescue_team: 3 |
| closed_roads: [] | closed_roads: ["Murree Road"] |
| alerts_sent: 0 | alerts_sent: 2 |

#### 🕐 Agent Trace Timeline
Chronological timestamped log of every agent step:
```
[2026-06-13T09:15:01Z] [DETECTION]  Signal verified. Type: URBAN_FLOODING, Priority: P2
[2026-06-13T09:15:04Z] [ANALYSIS]   Severity 8/10. ~4,200 affected. ETA Holy Family: 7 min
[2026-06-13T09:15:07Z] [PLANNING]   Plan: dispatch 2 rescue + WASA + FCM alert
[2026-06-13T09:15:11Z] [EXECUTION]  DispatchRescueTeam: 2 units → Rescue 1122 ✅
[2026-06-13T09:15:12Z] [EXECUTION]  BroadcastAlert: 2 FCM alerts sent ✅
[2026-06-13T09:15:12Z] [PIPELINE]   Status → PIPELINE_COMPLETE
```

---

## 2. Map Screen Visualization

**File:** `lib/screens/map_screen.dart`

Shows a live dark-mode Google Maps view with:

- 📍 **Incident Markers** — colored by priority (P1=red, P2=orange, P3=yellow, P4=blue, P5=grey)
- 🚑 **Resource Markers** — rescue hubs, hospitals, WASA depots
- 🔴 **Closed Road Polylines** — roads closed by Execution Agent drawn as thick red lines
- 🟢 **Detour Route Polylines** — alternate routes drawn as dashed green polylines
- **Tap any marker** → opens Incident Detail Screen

---

## 3. Web Dashboard (`dashboard_server.py`)

**Port:** 8001 — `http://127.0.0.1:8001`

The web dashboard provides a desktop-optimized view:

- **Live Incident Feed** — all active incidents sorted by priority
- **Resource Inventory Table** — real-time quantities from Supabase
- **Alert History** — FCM alerts sent with delivery status
- **Agent Trace Viewer** — raw JSON trace viewer per incident
- **System Stats** — total incidents processed, pipeline success rate

---

## 4. Trace Log Export

Every incident's full agent trace can be exported as a JSON file:

```
GET /logs/{incident_id}
→ Downloads: khabar_trace_SIG-1716223400-TXT.json
```

**Export Format:**
```json
{
  "incident_id": "SIG-1716223400-TXT",
  "export_time": "2026-06-13T09:20:00Z",
  "system": "KHABAR Crisis Intelligence & Response Orchestrator",
  "ai_backend": "AIML API (Gemini 2.5 Flash) + Local Gemma Fallback",
  "agent_pipeline": ["Detection Agent", "Analysis Agent", "Planning Agent", "Execution Agent"],
  "trace_count": 12,
  "traces": [
    "[2026-06-13T09:15:01Z] [DETECTION] ...",
    ...
  ]
}
```

---

## 5. Real-time Polling (Flutter)

The Flutter app polls the backend every **5 seconds** while on the Incident Detail Screen:

```dart
// Polls /incident/{id} every 5 seconds
// Status transitions: PROCESSING → IN_PROGRESS → PIPELINE_COMPLETE
// On PIPELINE_COMPLETE → shows full result (no more polling)
```

This creates a live, animated progress experience as each agent completes its stage.
