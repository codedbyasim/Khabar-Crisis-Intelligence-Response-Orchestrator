# 🚨 KHABAR (خبر) — Crisis Intelligence & Response Orchestrator (CIRO)
### AIML API (Gemini, GPT, Llama) | FastAPI + Flutter + React Dashboard

---

## 📸 1. Visual System Diagrams

### **1.1. Overall System Architecture**
![Overall System Architecture](images/Overall%20System.png)

### **1.2. Flutter Mobile Client State Flow**
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
[Citizen Signal (Text/Photo)]
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
- Writes final incident record to Supabase PostgreSQL, linked to the reporter's `user_id`
- **Auto-allocates** matching database resources — updates `assigned_incident` field on dispatched units

---

## 🤖 5. AI Backend — LLM Chain

KHABAR uses a **2-tier LLM fallback chain** with multi-model resilience on the backend to ensure 100% uptime:

```
Tier 1: AIML API (Multi-model resilience retry loop)
  1. Primary Model:   google/gemini-2.5-flash  (timeout: 20 seconds)
          ↓ [times out or errors]
  2. Backup Model 1:  gpt-4o-mini               (timeout: 15 seconds)
          ↓ [times out or errors]
  3. Backup Model 2:  meta-llama/Llama-3-8b-instruct-maas (timeout: 15 seconds)

    ↓ [all attempts exhausted]

Tier 2: Hardcoded Structured JSON Fallback
  Pydantic schema-aligned mock models. Never fails to respond.
```

*Note on Local Model Decoupling:* To protect server resources, local model loading on the backend has been bypassed (`local_model.py`'s GGUF inference features are disabled at runtime). If the primary API fails, it jumps directly to the hardcoded JSON layer.

---

## 🖥️ 6. React Admin Dashboard

A **premium light-glass command center** built with Vite + React 18, running on port 8001.

**Key Dashboard Components:**

| Component | Description |
|---|---|
| 🗺️ **MapWidget** | Live Leaflet map (CartoDB Positron tiles) — incident markers + resource/crew markers |
| 📦 **ResourceManager** | Real-time resource table — status, type, quantity, assigned incident |
| 🤖 **AgentPanel** | 4-agent pipeline detail + allocated resource badges + Case Analysis & Summary (English & Urdu summaries) |
| 💬 **AI Chatbot** | Floating Command Assistant — natural language coordinator commands via `POST /admin/chat` (supports markdown) |
| 📊 **CaseTracker** | P1–P5 priority distribution progress rings (active & complete statuses) |
| 📈 **StatsGrid** | KPI cards — total incidents, active resources, alerts sent |
| 📋 **SituationSummary** | AI-generated situation narrative |

**Admin Chatbot Commands (natural language → AI parses → executes):**
```
"Dispatch Rescue 1122 to SIG-123"           → [EXECUTE: dispatch, ...]
"Mark SIG-123 as resolved"                  → [EXECUTE: status, ...] (Automatically releases resources back to available)
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
| Dashboard / Map | `map_screen.dart` | Live incidents map with polyline detours and zoom buttons |
| Login / Signup | `auth_screen.dart` | Glassmorphic login gate with on-device AI launcher |
| Offline Chatbot | `offline_chat_screen.dart` | 100% offline emergency AI chat assistant (Qwen2.5 local model) |
| Text Report | `text_signal_screen.dart` | Multi-language text crisis submission (stamps User ID) |
| Photo Report | `photo_verification_screen.dart` | Camera → Vision AI analysis (stamps User ID) |
| Incident Detail | `incident_tracker_screen.dart` | Agent trace timeline, dynamically calculated resource distance and ETA (Help Delivery confirmed releases resources) |
| AI Chat | `ai_chat_screen.dart` | Online citizen AI chat (raises connection error when offline, supports rich markdown) |
| Live Alerts | `alerts_screen.dart` | Real-time FCM alerts feed |

### **Offline Mode (No Internet)**
When a citizen has no internet connection, they can launch the **Offline AI Assistant** directly from the Login/Signup page.
- Runs 100% on the device without checking backend server or network sockets.
- Runs local quantized **Qwen2.5-0.5B-Instruct** GGUF model via `llama_cpp_dart` on background isolates (streams response tokens).
- Falls back to a regex-based keyword parser inside `LocalLlmService` to return localized safety guidelines and rescue hotline phone numbers if model is not yet downloaded.
- Supports English, Urdu script, and Roman Urdu with auto-detection and custom markdown rendering.

---

## 🌐 8. Complete API Reference

Base URL: `http://127.0.0.1:8000`  
Swagger Docs: `http://127.0.0.1:8000/docs`

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/` | System status & endpoint list |
| `GET` | `/health` | Health check |
| `POST` | `/auth/signup` | Register new user profile |
| `POST` | `/auth/login` | Authenticate user and return profile |
| `POST` | `/report/text` | Submit text crisis report (stamps User ID) |
| `POST` | `/report/image` | Submit photo for Vision damage assessment |
| `GET` | `/incidents` | All active incidents (accepts `user_id` query to return user's 10 latest cases) |
| `DELETE` | `/incidents` | Clear all incidents & reset resources (admin reset) |
| `GET` | `/incident/{id}` | Single incident + full 4-agent trace |
| `GET` | `/resources` | Resource inventory with `assigned_incident` status |
| `POST` | `/resources/add` | Register a new resource unit |
| `POST` | `/action/execute` | Manual tool execution (resolving or closing releases resources) |
| `GET` | `/logs/{id}` | Export full agent trace as JSON download |
| `GET` | `/geocode` | Geocode address via Google Maps / OSM Nominatim |
| `POST` | `/chat` | Multi-turn citizen AI chat (online — AIML API with fallbacks) |
| `POST` | `/admin/chat` | **Dashboard AI Command Assistant** (coordinator commands) |
| `GET` | `/live-news` | Real-time Google News RSS feed |

---

## 💾 9. Database Schema (Supabase PostgreSQL)

```sql
-- User Accounts Table
CREATE TABLE IF NOT EXISTS users (
    user_id        VARCHAR(255) PRIMARY KEY,
    email          VARCHAR(255) UNIQUE NOT NULL,
    password_hash  VARCHAR(255) NOT NULL,
    name           VARCHAR(255) NOT NULL,
    region         VARCHAR(255) NOT NULL,
    created_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

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
    user_id        VARCHAR(255),  -- Links to users table
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
    assigned_incident  VARCHAR(255)              -- links to active incident ID
);
```

---

## 🛠️ 10. Technology Stack

| Layer | Technology |
|---|---|
| **AI Orchestration** | Python 3.12, FastAPI, Pydantic v2, CrewAI |
| **Primary LLM** | AIML API → `google/gemini-2.5-flash` with `gpt-4o-mini` and Llama 3 fallbacks |
| **Offline AI** | On-Device local Qwen2.5-0.5B GGUF model via llama_cpp_dart (with regex fallback) |
| **Vision AI** | AIML API Vision (OpenAI-compatible) |
| **Mobile Client** | Flutter 3.16+, Dart |
| **Web Dashboard** | Vite + React 18 + Leaflet.js (CartoDB tiles) |
| **Database** | Supabase Cloud PostgreSQL + In-Memory fallback |
| **Push Alerts** | Firebase Cloud Messaging v1 (firebase-admin SDK) |
| **Weather** | Open-Meteo API |
| **Traffic** | TomTom Traffic Flow API |
| **News Feed** | Google News RSS |

---

## 📂 11. Project Structure

```
h:\khabar\
├── api_server.py              ← FastAPI backend — all endpoints
├── dashboard_server.py        ← Serves built React dashboard (port 8001)
├── seed_resources.py          ← One-time DB seeder for resource inventory
├── requirements.txt           ← Python dependencies
├── AGENTS.md                  ← Developer & agent configuration rules
│
├── agents/                    ← All backend AI agents & services
│   ├── crew_orchestrator.py   ← KhabarCrewOrchestrator — CrewAI sequential pipeline
│   ├── llm_client.py          ← AIML API client + multi-model fallback retry loop
│   ├── local_model.py         ← Local GGUF loader (preserved for rules, disabled at runtime)
│   ├── detection_agent.py     ← Stage 1: Classify & verify
│   ├── analysis_agent.py      ← Stage 2: Impact & severity analysis
│   ├── planning_agent.py      ← Stage 3: NDMA SOPs RAG & resource planning
│   ├── execution_agent.py     ← Stage 4: Tool execution + state diff
│   ├── tool_system.py         ← 7 Antigravity tools (dispatch, alert, etc.)
│   ├── firestore_db.py        ← Supabase DB adapter + in-memory fallback
│   ├── alert_service.py       ← Firebase FCM v1 push notifications
│   ├── maps_service.py        ← Google Maps geocoding & hospital search
│   ├── gemini_vision.py       ← AIML Vision API (damage assessment)
│   └── automated_ingestion.py ← Background weather & traffic polling
│
├── dashboard/                 ← React Web Dashboard (Vite + React 18)
│   ├── src/
│   │   ├── App.jsx            ← Main dashboard layout (simulator/alerts tabs removed)
│   │   ├── index.css          ← Light-glass premium CSS design system
│   │   └── components/
│   │       ├── Chatbot.jsx        ← AI Command Assistant (POST /admin/chat, markdown support)
│   │       ├── ResourceManager.jsx ← Real-time resource + assigned_incident table
│   │       └── MapWidget.jsx      ← Live map
│   └── package.json
│
├── lib/                       ← Flutter mobile app
│   ├── main.dart
│   ├── api_config.dart        ← Base URL configurations
│   ├── screens/               
│   │   ├── auth_screen.dart           ← Login/Signup view with offline AI entry
│   │   └── offline_chat_screen.dart   ← 100% offline chat assistant screen (download & stream Qwen2.5 GGUF)
│   └── utils/
│       ├── local_llm_service.dart     ← Local LLM service (isolate manager for Qwen2.5, regex fallback)
│       └── connectivity_service.dart  ← Network connectivity checks (debounced check)
│
├── docs/                      ← Technical documentation
├── skills/                    ← Engineering workflows
└── web/                       ← Web build configurations
```

---

## 🚀 12. Running the System

```powershell
# 1. Start the AI Backend (required)
cd h:\khabar
$env:PYTHONIOENCODING="utf-8"
python api_server.py             # → http://127.0.0.1:8000

# 2. Start the React Dashboard (optional)
cd h:\khabar\dashboard
npm run dev                      # → http://127.0.0.1:5173
# OR serve the pre-built static version:
cd h:\khabar
python dashboard_server.py       # → http://127.0.0.1:8001

# 3. Run the Flutter Mobile App
cd h:\khabar
flutter run                      # Run on connected device or emulator
```
