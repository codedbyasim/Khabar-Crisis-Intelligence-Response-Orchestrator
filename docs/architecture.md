# 🏗️ KHABAR System Architecture

## Overview
KHABAR is a **decentralized, AI-driven emergency response orchestration system** for Pakistan.  
Citizens register/login and report crises via a Flutter mobile app. All reports are dynamically linked to their user profiles. An AI 4-agent pipeline automatically detects, analyses, plans, and executes emergency responses. If internet connectivity drops, citizens can access a 100% offline, on-device AI emergency assistant from the login screen. Coordinators monitor and command via a premium React web dashboard.

---

## System Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                        CITIZEN INTERFACES (MOBILE)                   │
│                                                                      │
│  ┌──────────────────────────────┐    ┌────────────────────────────┐  │
│  │   ONLINE REPORTING GATEWAYS  │    │  100% OFFLINE ASSISTANT    │  │
│  │  ┌──────────┐  ┌──────────┐  │    │  ┌──────────────────────┐  │  │
│  │  │   Text   │  │  Photo   │  │    │  │ OfflineChatScreen    │  │  │
│  │  │  Signal  │  │ (Vision) │  │    │  │ (No Backend/Network) │  │  │
│  │  └────┬─────┘  └────┬─────┘  │    │  └──────────┬───────────┘  │  │
│  │       └──────┬──────┘        │    │             ▼              │  │
│  │              ▼               │    │       LocalLlmService      │  │
│  │      Flutter Mobile App      │    │  (On-Device Matcher: EN/   │  │
│  │   (Profile ID linked via     │    │      UR/ROM Urdu)          │  │
│  │       profile.json)          │    └────────────────────────────┘  │
│  └──────────────┬───────────────┘                                    │
└─────────────────┼────────────────────────────────────────────────────┘
                  │
                  │ POST /report/... or /auth/...
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
│                  → Fallback: gpt-4o-mini                             │
│                  → Fallback: Llama 3 8B                              │
│                  → Hardcoded JSON (last resort)                      │
│                                                                      │
│   *Note: Backend GGUF model is decoupled to eliminate CPU load.      │
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
│  │          │ │  Status)   │ │  Timelines│ │                      │ │
│  │└─────────┘ └────────────┘ └───────────┘ └──────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 1. Flutter Mobile Client

**State Management:** Local `StatefulWidget` + `ChangeNotifier` (`LanguageProvider`)  
**Networking:** `http` package — calls FastAPI backend  
**Location & Sensors:** `geolocator` for GPS, `camera` for photo, `record` for audio  
**Session Management:** Profile local persistence via `profile.json` saved inside device directories on login/signup.

**Key Screens:**

| Screen | File | Description |
|---|---|---|
| Dashboard + Live Map | `lib/screens/map_screen.dart` | Incident and resource display |
| Login / Signup | `lib/screens/auth_screen.dart` | User entrance card with offline assistant access |
| Offline AI Assistant | `lib/screens/offline_chat_screen.dart` | 100% offline chat simulator |
| Text Crisis Report | `lib/screens/text_signal_screen.dart` | Submit text with location and user ID |
| Photo Report (Vision) | `lib/screens/photo_verification_screen.dart` | Photo damage analysis |
| Voice Report (Whisper) | `lib/screens/voice_report_screen.dart` | Speech signal transcription |
| Incident Detail + Trace | `lib/screens/incident_tracker_screen.dart` | Step-by-step progress tracking and live distance/ETA |
| AI Chat (Online) | `lib/screens/ai_chat_screen.dart` | Online assistant (raises error if connection drops) |
| Live Alerts Feed | `lib/screens/alerts_screen.dart` | Broadcast warning history |

**Offline Mode Architecture:**
```
[Auth Screen Page] -> Clicking "Offline AI Assistant"
                             ↓
              [OfflineChatScreen launched]
                             ↓
                User enters query message
                             ↓
               [LocalLlmService is invoked]
                             ↓
On-device keyword matching (Urdu script, Roman Urdu, and English)
                             ↓
     Returns rich safety instructions and helplines instantly
```

---

## 2. Python FastAPI Backend (`api_server.py`)

**Port:** 8000  
**Framework:** FastAPI + Uvicorn  
**Validation:** Pydantic v2 models  
**Authorization**: self-contained authentication with PBKDF2 credential hashing.

**Orchestration Layer:** FastAPI calls `KhabarCrewOrchestrator` (`agents/crew_orchestrator.py`), which orchestrates a hybrid pipeline using a sequential CrewAI Crew. CrewAI agents execute the 4 custom agents as specialized tools using an AIML API-configured `crewai.LLM`.

**Startup:** On server start, `automated_ingestion.py` launches a background polling loop:
- Open-Meteo weather (every 15 min)
- TomTom traffic flow (every 10 min)
- Proactive crisis signal injection if thresholds exceeded

---

## 3. LLM Client Chain (`agents/llm_client.py`)

```
Tier 1: AIML API (Multi-model resilience retry loop)
  1. Primary Model:   google/gemini-2.5-flash  (timeout: 20 seconds)
          ↓ [times out or errors]
  2. Backup Model 1:  gpt-4o-mini               (timeout: 15 seconds)
          ↓ [times out or errors]
  3. Backup Model 2:  meta-llama/Llama-3-8b-instruct-maas (timeout: 15 seconds)

    ↓ [all attempts exhausted]

Tier 2: Hardcoded JSON Fallback
  Pydantic schema-aligned mock models. Never fails to respond.
```

**Note on Local Model Decoupling:** To save CPU, memory, and startup latency on the server, `local_model.py`'s GGUF inference features have been bypassed. If Tier 1 fails, the system bypasses Gemma GGUF loading and falls back directly to the hardcoded JSON layer.

---

## 4. Database Layer (`agents/firestore_db.py`)

**Primary:** Supabase PostgreSQL via `psycopg2`  
**Fallback:** Thread-safe in-memory Python dictionaries (auto-heals if DB offline)

Tables:
- `users` — stores `user_id` (primary key), `email`, `password_hash`, `name`, `region`, and `created_at`.
- `incidents` — all reported disasters, linked to the reporter's `user_id`.
- `resources` — live inventory with `assigned_incident` column (auto-created if missing via self-healing ALTER TABLE).

**Automatic Resource Releasing**:
When an incident is updated to `"RESOLVED"` or `"CLOSED"` (via admin dashboard status commands), or when `clear_database` is triggered, the system automatically marks all allocated resource records as `'available'` and clears their `assigned_incident` fields to `NULL` / `None` in Postgres and local memory.

---

## 5. Alert System (`agents/alert_service.py`)

- Uses **Firebase Admin SDK** with OAuth2 service account
- Sends **bilingual Urdu + English** push notifications via FCM HTTP v1 API
- Topic: `khabar_public_alerts` — all mobile users auto-subscribed

---

## 6. Maps & Geocoding (`agents/maps_service.py`)

**Geocoding chain:**
1. Google Maps Geocoding API  (if GOOGLE_MAPS_API_KEY set)
2. Local Pakistan city dictionary  (33 pre-loaded locations, instant)
3. OpenStreetMap Nominatim  (free, no key, SSL-verified)
4. Default fallback → Islamabad center (33.6844, 73.0479)

**Distance & ETA calculation:**
- Calculates geographic distance between resources and incidents dynamically using the **Haversine formula**.
- Computes travel durations (ETA) using average speed profiles of dispatched vehicles (Ambulance/Police move faster, WASA pumps/Rescue teams move slower).

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
