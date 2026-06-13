# 🏗️ KHABAR System Architecture

## Overview
KHABAR is a **decentralized, AI-driven emergency response orchestration system** for Pakistan.  
Citizens report crises via a Flutter mobile app. An AI 4-agent pipeline automatically detects, analyses, plans, and executes emergency responses. Coordinators monitor and command via a premium React web dashboard.

---

## System Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                        CITIZEN INTERFACES                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │
│  │  Text Report │  │ Photo Report │  │ Voice Report │               │
│  │ (Urdu/Roman) │  │ (Vision AI)  │  │ (Whisper AI) │               │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘               │
│         └─────────────────┴──────────────────┘                       │
│                       Flutter Mobile App                             │
│                   POST /report/text|image|voice                      │
└───────────────────────────┬──────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│               PYTHON FASTAPI BACKEND  (api_server.py)                │
│                        Port: 8000                                    │
│                                                                      │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐           │
│   │Detection │→ │Analysis  │→ │Planning  │→ │Execution │           │
│   │ Agent    │  │ Agent    │  │ Agent    │  │ Agent    │           │
│   └──────────┘  └──────────┘  └──────────┘  └──────────┘           │
│         │               │           │               │               │
│         └───────────────┴───────────┴───────────────┘               │
│                       SharedMemoryBlock                              │
│                                                                      │
│   LLM Chain:  AIML API (google/gemini-2.5-flash)                    │
│                  → Local Qwen/Gemma GGUF                             │
│                       → Hardcoded JSON (last resort)                │
└───────────┬─────────────────────────────────────────────────────────┘
            │
     ┌──────┴──────────────────────────────┐
     │              SERVICES               │
     │  ┌────────────┐  ┌───────────────┐  │
     │  │  Supabase  │  │  Firebase FCM │  │
     │  │ PostgreSQL │  │ Push Alerts   │  │
     │  └────────────┘  └───────────────┘  │
     │  ┌────────────┐  ┌───────────────┐  │
     │  │Google Maps │  │  Open-Meteo   │  │
     │  │ Geocoding  │  │ Weather API   │  │
     │  └────────────┘  └───────────────┘  │
     └──────────────────┬──────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────────────┐
│            REACT WEB DASHBOARD  (Vite + React)                       │
│                     Port: 8001                                       │
│                                                                      │
│  ┌──────────┐ ┌────────────┐ ┌───────────┐ ┌──────────────────────┐ │
│  │ MapWidget│ │ResourceMgr │ │AgentPanel │ │ AI Command Chatbot   │ │
│  │(Leaflet) │ │(Real-time) │ │(Allocations│ │ POST /admin/chat     │ │
│  └──────────┘ └────────────┘ └───────────┘ └──────────────────────┘ │
│  ┌──────────┐ ┌────────────┐ ┌───────────┐ ┌───────────┐            │
│  │StatsGrid │ │CaseTracker │ │AlertsPanel│ │Situation  │            │
│  │          │ │(Progress   │ │           │ │Summary    │            │
│  │          │ │ Rings)     │ │           │ │           │            │
│  └──────────┘ └────────────┘ └───────────┘ └───────────┘            │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 1. Flutter Mobile Client

**State Management:** Local `StatefulWidget` + `ChangeNotifier` (`LanguageProvider`)  
**Networking:** `http` package — calls FastAPI backend  
**Location & Sensors:** `geolocator` for GPS, `camera` for photo, `record` for audio  

**Key Screens:**

| Screen | File |
|---|---|
| Dashboard + Live Map | `lib/screens/map_screen.dart` |
| Text Crisis Report | `lib/screens/text_signal_screen.dart` |
| Photo Report (Vision) | `lib/screens/photo_verification_screen.dart` |
| Voice Report (Whisper) | `lib/screens/voice_report_screen.dart` |
| Incident Detail + Trace | `lib/screens/incident_tracker_screen.dart` |
| AI Chat (Online + Offline) | `lib/screens/ai_chat_screen.dart` |
| Live Alerts Feed | `lib/screens/alerts_screen.dart` |

**Offline Mode Architecture:**
```
ConnectivityService detects offline
           ↓
LocalLlmService.getOfflineResponse()
           ↓
     POST /local-chat  (Backend Qwen GGUF — no internet needed)
           ↓ [backend unreachable]
     Keyword-based hardcoded fallback
```

---

## 2. Python FastAPI Backend (`api_server.py`)

**Port:** 8000  
**Framework:** FastAPI + Uvicorn  
**Validation:** Pydantic v2 models

**Orchestration Layer:** FastAPI calls `KhabarCrewOrchestrator` (`agents/crew_orchestrator.py`), which orchestrates a hybrid pipeline using a sequential CrewAI Crew. CrewAI agents execute the 4 custom agents as specialized tools using an AIML API-configured `crewai.LLM`.

**Startup:** On server start, `automated_ingestion.py` launches a background polling loop:
- Open-Meteo weather (every 15 min)
- TomTom traffic flow (every 10 min)
- Proactive crisis signal injection if thresholds exceeded

**Note:** Automated background polling is disabled by default to conserve AIML API quota. Enable by setting `ENABLE_AUTO_POLLING=true` in `agents/.env`.

---

## 3. LLM Client Chain (`agents/llm_client.py`)

```
Tier 1: AIML API
  endpoint:    https://api.aimlapi.com/v1
  model:       google/gemini-2.5-flash
  protocol:    OpenAI-compatible AsyncOpenAI client
  max_retries: 0  (SDK retries disabled — manual 3-attempt loop used)

    ↓ [3 manual retries with asyncio.wait_for, 45s timeout each]

Tier 2: Local GGUF Model  (agents/local_model.py)
  primary:   models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf   (380 MB)
  secondary: models/gemma-4-E2B-it-UD-IQ2_M.gguf        (2.3 GB)
  engine:    llama-cpp-python  (CPU inference, no GPU required)
  context:   2048 tokens

    ↓ [model not loaded / unavailable]

Tier 3: Hardcoded JSON
  Deterministic structured fallback per agent type
  Never raises an exception — system always responds
```

**Important:** The OpenAI SDK's built-in auto-retry is explicitly disabled (`max_retries=0`) in all 3 client files (`llm_client.py`, `gemini_vision.py`, `gemini_speech.py`). Our own 3-attempt `asyncio.wait_for` retry loop is the sole retry mechanism.

---

## 4. Database Layer (`agents/firestore_db.py`)

**Primary:** Supabase PostgreSQL via `psycopg2`  
**Fallback:** Thread-safe in-memory Python dictionaries (auto-heals if DB offline)

Tables:
- `incidents` — all reported disasters with full agent traces, before/after states
- `resources` — live inventory (ambulances, rescue teams, fire trucks, dewatering pumps) with `assigned_incident` column (auto-created if missing via self-healing ALTER TABLE)

The `KhabarFirestore` singleton preserves old Firestore method signatures for backward compatibility. Internally routes all calls to Supabase SQL.

---

## 5. Alert System (`agents/alert_service.py`)

- Uses **Firebase Admin SDK** with OAuth2 service account
- Sends **bilingual Urdu + English** push notifications via FCM HTTP v1 API
- Falls back to simulated delivery if `firebase_service_account.json` is missing
- Uses topic `khabar_public_alerts` — all Flutter app users auto-subscribed

---

## 6. Maps & Geocoding (`agents/maps_service.py`)

**Geocoding chain:**
```
1. Google Maps Geocoding API  (if GOOGLE_MAPS_API_KEY set)
2. Local Pakistan city dictionary  (33 pre-loaded locations, instant)
3. OpenStreetMap Nominatim  (free, no key, SSL-verified)
4. Default fallback → Islamabad center (33.6844, 73.0479)
```

**ETA calculation:** Google Distance Matrix API → Haversine formula fallback

---

## 7. React Web Dashboard (`dashboard/`)

**Framework:** Vite + React 18  
**Port:** 8001 (`npm run dev` or `python dashboard_server.py`)  
**Theme:** Premium light-glass command center UI  
**Map:** Leaflet.js with CartoDB Positron light tile layer  

**Components (`dashboard/src/components/`):**

| Component | Description |
|---|---|
| `Chatbot.jsx` | Floating AI Command Assistant — natural language coordinator commands via `POST /admin/chat` |
| `MapWidget.jsx` | Live Leaflet map — incident markers + resource/crew markers with coordinate fallback |
| `ResourceManager.jsx` | Real-time resource table — status, type, quantity, assigned incident |
| `AgentPanel.jsx` | 4-agent pipeline detail view + allocated resource badges per incident |
| `CaseTracker.jsx` | P1–P5 priority distribution progress rings |
| `StatsGrid.jsx` | KPI cards — total incidents, active resources, alerts sent |
| `AlertsPanel.jsx` | Live FCM alert history feed |
| `SituationSummary.jsx` | AI-generated situation overview |
| `Sidebar.jsx` | Navigation sidebar |
