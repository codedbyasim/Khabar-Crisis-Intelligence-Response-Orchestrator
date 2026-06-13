# 📊 Outcome Visualization & Incident Trace

KHABAR provides full transparency into every AI agent decision through the **Incident Detail Screen** in the Flutter app and the **React Web Dashboard**.

---

## 1. Flutter Incident Detail Screen

**File:** `lib/screens/incident_tracker_screen.dart`

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
- Target agencies (Rescue 1122, WASA, NDMA, Traffic Police, Edhi Foundation)

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

Shows a live Flutter map view with:

- 📍 **Incident Markers** — colored by priority (P1=red, P2=orange, P3=yellow, P4=blue, P5=grey)
- 🚑 **Resource Markers** — rescue hubs, hospitals, WASA depots
- 🔴 **Closed Road Polylines** — roads closed by Execution Agent drawn as thick red lines
- 🟢 **Detour Route Polylines** — alternate routes drawn as dashed green polylines
- **Tap any marker** → opens Incident Detail Screen

---

## 3. React Web Dashboard (`dashboard/`)

**Framework:** Vite + React 18  
**Port:** 8001 — `http://127.0.0.1:8001`  
**Theme:** Premium light-glass command center  
**Map:** Leaflet.js + CartoDB Positron light tile layer

### Dashboard Components

#### 🗺️ `MapWidget.jsx` — Live Incident & Resource Map
- Leaflet map with CartoDB Positron light tiles
- **Incident markers** — color-coded by priority with popup details
- **Resource/crew markers** — ambulances, rescue teams, depots
- Safe coordinate resolver handles nested location formats (`location.latitude`, `lat`, etc.)
- Auto-refreshes every 10 seconds

#### 📦 `ResourceManager.jsx` — Real-time Resource Inventory
- Full resource table: ID, Name, Type, Status, Quantity
- **Assigned Case** column — shows which incident each unit is deployed to (`assigned_incident`)
- Status badges: `available` (green), `deployed` (orange), `en_route` (blue)
- Refreshes every 10 seconds from `/resources`

#### 🤖 `AgentPanel.jsx` — Incident Detail & Agent Pipeline View
- 4-agent pipeline accordion with per-stage outputs
- **Allocated Incident Resources** badge list — specific units currently assigned to selected incident
- Agent trace timeline viewer
- Manual action execution panel

#### 🤖 `Chatbot.jsx` — AI Command Assistant
- Floating chatbot in bottom-right corner
- Connects to `POST /admin/chat` — AIML API `google/gemini-2.5-flash`
- **Context-aware:** Reads all active incidents + resource inventory
- **Command execution:** Type natural language commands → AI parses and executes:
  - `"Dispatch Rescue 1122 to SIG-123"` → `[EXECUTE: dispatch, ...]`
  - `"Mark SIG-123 as resolved"` → `[EXECUTE: status, ...]`
  - `"Send flood alert to sector G-10"` → `[EXECUTE: alert, ...]`
- Language support: English, Urdu, Roman Urdu
- Fallback: Local Qwen GGUF if AIML API is unavailable

#### 📊 `CaseTracker.jsx` — Priority Distribution
- SVG progress rings for P1–P5 incident counts
- Percentage and count labels centered inside each ring

#### 📈 `StatsGrid.jsx` — KPI Cards
- Total Incidents, Active Resources, Alerts Sent, Pipeline Success Rate

#### 🔔 `AlertsPanel.jsx` — Live Alert Feed
- Real-time list of FCM alerts sent with timestamps and bilingual content

#### 📋 `SituationSummary.jsx` — AI Situation Overview
- Narrative summary of current emergency landscape

#### 🧭 `Sidebar.jsx` — Navigation
- View switcher between Dashboard, Incidents, Resources, Alerts

---

## 4. Trace Log Export

Every incident's full agent trace can be exported as a JSON file:

```
GET /logs/{incident_id}
→ Downloads: khabar_trace_{incident_id}.json
```

**Export Format:**
```json
{
  "incident_id": "SIG-1716223400-TXT",
  "export_time": "2026-06-13T09:20:00Z",
  "system": "KHABAR Crisis Intelligence & Response Orchestrator",
  "ai_backend": "AIML API (google/gemini-2.5-flash) + Local GGUF Fallback",
  "agent_pipeline": ["Detection Agent", "Analysis Agent", "Planning Agent", "Execution Agent"],
  "trace_count": 12,
  "traces": [
    "[2026-06-13T09:15:01Z] [DETECTION] ...",
    "..."
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

---

## 6. Real-time Polling (React Dashboard)

The React dashboard auto-refreshes all data panels:

| Panel | Endpoint | Interval |
|---|---|---|
| Incidents list | `GET /incidents` | 10 seconds |
| Resources table | `GET /resources` | 10 seconds |
| Root status | `GET /` | 10 seconds |
| News feed | `GET /live-news` | On demand |
