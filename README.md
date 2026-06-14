# 🚨 KHABAR (خبر) — Crisis Intelligence & Response Orchestrator (CIRO)
### **AISeekho Antigravity Hackathon 2026 (Challenge 3) | AIML API (google/gemini-2.5-flash) | FastAPI + Flutter + React Dashboard**

---

## 📸 1. Visual System Diagrams

### **1.1. Overall System Architecture**
![Overall System Architecture](images/Overall%20System.png)

### **1.2. Multi-Agent Antigravity Orchestration Pipeline**
![Multi-Agent Pipeline](images/Agent.png)

### **1.3. Flutter Mobile Client State Flow**
![Flutter Mobile Client](images/Flutter.png)

---

## 📌 2. Problem Statement
Pakistan's twin cities — **Rawalpindi** and **Islamabad** — face frequent localized crises:

- 🌊 **Urban Flooding:** Monsoon rains cause severe water accumulation (e.g., Nullah Lai, Rawalpindi underpasses).
- ⚡ **Infrastructure Failures:** Power grid trips, gas leaks, building collapses.
- 🚗 **Traffic & Road Accidents:** Collisions blocking emergency service corridors.
- 🌡️ **Heatwaves:** Temperature-driven public health hazards.

**Core challenges in existing emergency response:**
1. **Noisy & Informal Inputs:** Mixed-language reports (English, Urdu, Roman Urdu, Punjabi) with slang and errors.
2. **No Spam Filtering:** Fake reports, greetings, and weather observations flood the dispatcher queue.
3. **Fragmented Dispatch:** WASA, Rescue 1122, Traffic Police, and NDMA work in silos with no unified view.
4. **No Coordinator Dashboard:** No real-time command center for situational awareness and resource control.

---

## 💡 3. The KHABAR Solution
**KHABAR** (meaning *News / Awareness* in Urdu) is an Agentic AI system that transforms raw citizen signals into automated, verified, and simulated emergency response pipelines — with a full-featured **AI-powered coordinator dashboard**.

```
[Citizen Signal (Text/Voice/Photo)]
         ↓
[Verification Gate — Spam Filter]
         ↓
[4-Agent AI Pipeline (Detection → Analysis → Planning → Execution)]
         ↓
[Simulated Dispatches, FCM Alerts, DB Updates]
         ↓
[React Dashboard — Live Map, Chatbot, Real-time Resource Tracking]
```

---

## 🤖 4. The 4-Agent AI Pipeline

The pipeline consists of **four sequential AI agents** that share a `SharedMemoryBlock`:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Detection Agent │ ➔  │ Analysis Agent  │ ➔  │ Planning Agent  │ ➔  │ Execution Agent │
│ detection_      │    │ analysis_       │    │ planning_       │    │ execution_      │
│ agent.py        │    │ agent.py        │    │ agent.py        │    │ agent.py        │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
```

### **4.1. Detection Agent** (`agents/detection_agent.py`)
- Classifies crisis type (`URBAN_FLOODING`, `FIRE`, `ACCIDENT`, `HEATWAVE`, etc.)
- Extracts GPS coordinates from natural language text
- Assigns priority **P1** (critical) to **P5** (low)
- **Spam / Verification Gate:** Rejects conversational inputs and cross-validates weather claims against live Open-Meteo data
- Pipeline halts immediately on `is_verified = False`

### **4.2. Analysis Agent** (`agents/analysis_agent.py`)
- Estimates affected population, stranded vehicles, arterial road blockage
- Queries `MapsService` for nearby hospitals, WASA depots, and fire stations with real ETAs
- Produces bilingual (Urdu + English) public impact summary

### **4.3. Planning Agent** (`agents/planning_agent.py`)
- Performs **RAG lookup** against Pakistan NDMA SOP knowledge base (cosine similarity)
- Checks Supabase resource inventory (ambulances, fire trucks, dewatering pumps)
- Produces an ordered list of `RecommendedAction` items

### **4.4. Execution Agent** (`agents/execution_agent.py`)
- Maps planning actions to 7 Antigravity tools from `tool_system.py`
- Tracks exact `before_state` → `after_state` system transitions
- Sends **real FCM push notifications** via Firebase Admin SDK (bilingual Urdu + English)
- Writes final incident record to Supabase PostgreSQL
- **Auto-allocates** matching database resources — updates `assigned_incident` field on dispatched units

---

## 🤖 5. AI Backend — LLM Chain

KHABAR uses a **3-tier LLM fallback chain** to ensure 100% uptime:

```
Tier 1: AIML API  (google/gemini-2.5-flash — OpenAI-compatible)
         max_retries=0 (SDK disabled) + 3 manual asyncio.wait_for retries × 45s
         ↓  [all 3 attempts exhausted]
Tier 2: Local Qwen GGUF  (Qwen2.5-0.5B-Instruct-Q4_K_M.gguf — CPU, ~380 MB)
         ↓  [Qwen unavailable]
Tier 2b: Local Gemma GGUF  (gemma-4-E2B-it-UD-IQ2_M.gguf — CPU, 2.3 GB)
         ↓  [model unavailable]
Tier 3: Hardcoded Structured JSON  (last resort, never crashes)
```

| Tier | File | Requires Internet |
|------|------|:-----------------:|
| AIML API (`google/gemini-2.5-flash`) | `agents/llm_client.py` | ✅ Yes |
| Local Qwen GGUF (380 MB) | `agents/local_model.py` | ❌ No |
| Local Gemma GGUF (2.3 GB) | `agents/local_model.py` | ❌ No |
| Hardcoded JSON | `agents/llm_client.py` | ❌ No |

> **Note:** The OpenAI SDK's built-in auto-retry is explicitly disabled (`max_retries=0`) in all client files. Only our manual `asyncio.wait_for` retry loop controls retry behavior, preventing double-retry log spam.

---

## 🖥️ 6. React Admin Dashboard

A **premium light-glass command center** built with Vite + React 18, running on port 8001.

**Key Dashboard Components:**

| Component | Description |
|---|---|
| 🗺️ **MapWidget** | Live Leaflet map (CartoDB Positron tiles) — incident markers + resource/crew markers |
| 📦 **ResourceManager** | Real-time resource table — status, type, assigned incident |
| 🤖 **AgentPanel** | 4-agent pipeline detail + allocated resource badges per incident |
| 💬 **AI Chatbot** | Floating Command Assistant — natural language coordinator commands via `POST /admin/chat` |
| 📊 **CaseTracker** | P1–P5 priority distribution progress rings |
| 📈 **StatsGrid** | KPI cards — total incidents, active resources, alerts sent |
| 🔔 **AlertsPanel** | Live FCM alert history |
| 📋 **SituationSummary** | AI-generated situation narrative |

**Admin Chatbot Commands (natural language → AI parses → executes):**
```
"Dispatch Rescue 1122 to SIG-123"           → [EXECUTE: dispatch, ...]
"Mark SIG-123 as resolved"                  → [EXECUTE: status, ...]
"Send flood alert to Sector G-10"           → [EXECUTE: alert, ...]
"Close Murree Road and reroute via N5"      → [EXECUTE: reroute, ...]
"Add ambulance unit at PIMS"                → [EXECUTE: add_resource, ...]
"Give me a situation summary"               → AI analysis (no command)
```

---

## 📱 7. Flutter Mobile App

Built in Flutter/Dart with a premium dark-themed design system:

| Screen | File | Function |
|---|---|---|
| Dashboard / Map | `map_screen.dart` | Live incidents map with polyline detours |
| Text Report | `text_signal_screen.dart` | Multi-language text crisis submission |
| Photo Report | `photo_verification_screen.dart` | Camera → Vision AI analysis |
| Voice Report | `voice_report_screen.dart` | Audio → Whisper transcription + optional photo |
| Incident Detail | `incident_tracker_screen.dart` | Agent trace timeline, before/after state |
| AI Chat | `ai_chat_screen.dart` | Online chat (AIML API) + Offline (Local GGUF) |
| Live Alerts | `alerts_screen.dart` | Real-time FCM alerts feed |

### **Offline Mode (No Internet)**
When device is offline, `LocalLlmService` calls:
1. `POST /local-chat` → Backend uses **Local Qwen/Gemma GGUF** (no internet needed)
2. If backend is also down → Keyword-based hardcoded responses

### **Platform URL Auto-Detection** (`lib/api_config.dart`)
```dart
Web (Chrome)       → http://127.0.0.1:8000
Android Emulator   → http://10.0.2.2:8000
```

---

## 🌐 8. Complete API Reference

Base URL: `http://127.0.0.1:8000`  
Swagger Docs: `http://127.0.0.1:8000/docs`

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/` | System status & endpoint list |
| `GET` | `/health` | Health check + active incident count |
| `POST` | `/report/text` | Submit text crisis report (Urdu/English/Roman Urdu) |
| `POST` | `/report/image` | Submit photo for Vision damage assessment |
| `POST` | `/report/voice` | Submit audio for Speech transcription |
| `GET` | `/incidents` | All active incidents with P1–P5 priority queue |
| `DELETE` | `/incidents` | Clear all incidents (admin reset) |
| `GET` | `/incident/{id}` | Single incident + full 4-agent trace |
| `GET` | `/resources` | Resource inventory with `assigned_incident` status |
| `POST` | `/resources/add` | Register a new resource unit |
| `POST` | `/action/execute` | Manual tool execution (coordinator mode) |
| `GET` | `/logs/{id}` | Export full agent trace as JSON download |
| `GET` | `/geocode` | Geocode address via Google Maps / OSM Nominatim |
| `POST` | `/chat` | Multi-turn citizen AI chat (online — AIML API) |
| `POST` | `/local-chat` | **Offline citizen AI chat (Local GGUF — no internet)** |
| `POST` | `/admin/chat` | **Dashboard AI Command Assistant** (coordinator commands) |
| `GET` | `/live-news` | Real-time Google News RSS feed |

### **Key Request/Response Examples**

**POST `/report/text`**
```json
Request:  { "text": "Nullah Lai over flow ho rahi hai Rawalpindi!", "lat": 33.6375, "lng": 73.0784 }
Response: { "success": true, "incident_id": "SIG-1716223400-TXT", "status": "PROCESSING", "poll_url": "/incident/SIG-..." }
```

**POST `/admin/chat`** *(Dashboard Chatbot)*
```json
Request:  { "message": "Dispatch Rescue 1122 to SIG-123", "history": [] }
Response: { "success": true, "response": "[EXECUTE: dispatch, ...]\nDispatching 2 units...", "command_executed": {...} }
```

**POST `/local-chat`** *(Offline)*
```json
Request:  { "message": "flood emergency kya karoon?", "language": "Roman Urdu" }
Response: { "success": true, "response": "...", "mode": "local_gguf", "model": "Qwen2.5-0.5B-Instruct-Q4_K_M.gguf" }
```

---

## 💾 9. Database Schema (Supabase PostgreSQL)

```sql
-- Core Incidents Table
CREATE TABLE IF NOT EXISTS incidents (
    incident_id    VARCHAR(255) PRIMARY KEY,
    incident_type  VARCHAR(100),
    lat            DOUBLE PRECISION,
    lng            DOUBLE PRECISION,
    priority       VARCHAR(10),
    status         VARCHAR(50),
    confidence     DOUBLE PRECISION,
    location       JSONB,
    traces         JSONB,
    before_state   JSONB,
    after_state    JSONB,
    state_diff     JSONB,
    public_alerts_sent INTEGER DEFAULT 0,
    created_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Resource Inventory Table
CREATE TABLE IF NOT EXISTS resources (
    resource_id        VARCHAR(100) PRIMARY KEY,
    name               VARCHAR(150) NOT NULL,
    type               VARCHAR(50)  NOT NULL,    -- ambulance | fire_truck | rescue_team | dewatering_pump
    quantity           INTEGER DEFAULT 1,
    status             VARCHAR(50)  DEFAULT 'available',
    location           JSONB,                    -- {"lat": float, "lng": float}
    assigned_incident  VARCHAR(255)              -- auto-created if missing via self-healing ALTER TABLE
);
```

---

## 🛠️ 10. Technology Stack

| Layer | Technology |
|---|---|
| **AI Orchestration** | Python 3.12, FastAPI, Pydantic v2, CrewAI |
| **Primary LLM** | AIML API → `google/gemini-2.5-flash` (OpenAI-compatible AsyncOpenAI) |
| **Offline LLM** | Qwen2.5-0.5B GGUF + Gemma 4-E2B GGUF via `llama-cpp-python` (CPU) |
| **Vision AI** | AIML API Vision (OpenAI-compatible, base64 image encoding) |
| **Speech AI** | OpenAI Whisper API (via AIML API endpoint) |
| **Mobile Client** | Flutter 3.16+, Dart |
| **Web Dashboard** | Vite + React 18 + Leaflet.js (CartoDB Positron tiles) |
| **Maps** | Google Maps Platform (Geocoding + Distance Matrix) + OSM Nominatim |
| **Database** | Supabase Cloud PostgreSQL (psycopg2-binary) + In-Memory fallback |
| **Push Alerts** | Firebase Cloud Messaging v1 (firebase-admin SDK) |
| **Weather** | Open-Meteo API (free, no API key required) |
| **Traffic** | TomTom Traffic Flow API |
| **News Feed** | Google News RSS (free, no API key required) |
| **Geocoding** | Google Maps Geocoding API + Local Pakistan dict + OSM Nominatim fallback |

---

## 📂 11. Project Structure

```
h:\khabar\
├── api_server.py              ← FastAPI backend — all 17 endpoints
├── dashboard_server.py        ← Serves built React dashboard (port 8001)
├── seed_resources.py          ← One-time DB seeder for resource inventory
├── requirements.txt           ← Python dependencies
├── AGENTS.md                  ← Developer & agent configuration rules
│
├── agents/                    ← All backend AI agents & services
│   ├── crew_orchestrator.py   ← KhabarCrewOrchestrator — CrewAI sequential pipeline
│   ├── llm_client.py          ← AIML API client + 3-tier fallback chain (max_retries=0)
│   ├── local_model.py         ← Local Qwen/Gemma GGUF loader (llama-cpp-python)
│   ├── detection_agent.py     ← Stage 1: Classify & verify
│   ├── analysis_agent.py      ← Stage 2: Impact & severity analysis
│   ├── planning_agent.py      ← Stage 3: NDMA RAG + resource planning
│   ├── execution_agent.py     ← Stage 4: Tool execution + state diff
│   ├── tool_system.py         ← 7 Antigravity tools (dispatch, alert, etc.)
│   ├── firestore_db.py        ← Supabase DB adapter + in-memory fallback + self-healing
│   ├── alert_service.py       ← Firebase FCM v1 push notifications
│   ├── maps_service.py        ← Google Maps + OSM geocoding & ETAs
│   ├── gemini_vision.py       ← AIML Vision API (damage assessment, max_retries=0)
│   ├── gemini_speech.py       ← AIML Whisper API (audio transcription, max_retries=0)
│   ├── automated_ingestion.py ← Background weather & traffic polling
│   ├── knowledge_base_data.py ← Pakistan NDMA SOP vector knowledge base
│   └── .env                   ← API keys (gitignored — never commit)
│
├── models/                    ← Local GGUF Models (gitignored — large binaries)
│   ├── Qwen2.5-0.5B-Instruct-Q4_K_M.gguf   (~380 MB — fast, primary fallback)
│   └── gemma-4-E2B-it-UD-IQ2_M.gguf         (2.3 GB — larger context)
│
├── dashboard/                 ← React Web Dashboard (Vite + React 18)
│   ├── src/
│   │   ├── App.jsx            ← Main dashboard layout
│   │   ├── index.css          ← Light-glass premium CSS design system
│   │   └── components/
│   │       ├── Chatbot.jsx        ← AI Command Assistant (POST /admin/chat)
│   │       ├── MapWidget.jsx      ← Leaflet map — incidents + resources
│   │       ├── ResourceManager.jsx ← Real-time resource + assigned_incident table
│   │       ├── AgentPanel.jsx     ← Pipeline detail + allocated resource badges
│   │       ├── CaseTracker.jsx    ← Priority distribution progress rings
│   │       ├── StatsGrid.jsx      ← KPI summary cards
│   │       ├── AlertsPanel.jsx    ← FCM alert history
│   │       ├── SituationSummary.jsx ← AI situation overview
│   │       └── Sidebar.jsx        ← Navigation
│   └── package.json
│
├── lib/                       ← Flutter mobile app
│   ├── main.dart
│   ├── api_config.dart        ← Auto-detects Web vs Android Emulator URL
│   ├── screens/               ← All 7 UI screens
│   └── utils/
│       ├── local_llm_service.dart     ← Calls /local-chat → keyword fallback
│       └── connectivity_service.dart  ← Network connectivity detection
│
├── docs/                      ← Full technical documentation (9 files)
├── skills/                    ← Engineering workflow skills
├── assets/                    ← App images & fonts
└── web/                       ← Flutter web build target assets
```

---

## 🚀 12. Running the System

```powershell
# 1. Start the AI Backend (required)
cd h:\khabar
$env:PYTHONIOENCODING="utf-8"
python api_server.py             # → http://127.0.0.1:8000
                                 # → Swagger: http://127.0.0.1:8000/docs

# 2. Start the React Dashboard (optional)
cd h:\khabar\dashboard
npm run dev                      # → http://127.0.0.1:5173
# OR serve the pre-built static version:
cd h:\khabar
python dashboard_server.py       # → http://127.0.0.1:8001

# 3. Run the Flutter Mobile App
cd h:\khabar
flutter run -d chrome            # Web browser
flutter run                      # Connected Android device / emulator
```

---

## 📝 13. Core Platform Assumptions
1. **Map Corridor Simulations:** Detour corridors are visually simulated using coordinate boundaries relative to the incident center.
2. **Emergency Dispatch Capacity:** Baseline resource capacity seeded via `seed_resources.py`. On exhaustion, Planning Agent auto-escalates to `STANDBY`.
3. **Human-in-the-Loop:** P3–P5 events in production require manual dispatcher confirmation via the admin dashboard chatbot before real dispatches.
4. **Local Model Performance:** Qwen GGUF runs on CPU (~3–8 sec/response). Gemma GGUF (~10–20 sec/response). GPU acceleration can be enabled via `n_gpu_layers` in `agents/local_model.py`.
5. **Auto-Polling:** Background weather/traffic polling is disabled by default to conserve API quota. Incidents can be manually reported through the API or Flutter app at any time.
