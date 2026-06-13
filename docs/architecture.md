# 🏗️ KHABAR System Architecture

## Overview
KHABAR is a **decentralized, AI-driven emergency response orchestration system**.  
The Flutter mobile app is the citizen-facing client. The Python FastAPI backend is the AI orchestration core.

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
│                           │  Flutter App                             │
│                           │  POST /report/text|image|voice           │
└───────────────────────────┼──────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│                   PYTHON FASTAPI BACKEND (api_server.py)             │
│                                                                      │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐           │
│   │Detection │→ │Analysis  │→ │Planning  │→ │Execution │           │
│   │ Agent    │  │ Agent    │  │ Agent    │  │ Agent    │           │
│   └──────────┘  └──────────┘  └──────────┘  └──────────┘           │
│         │               │           │               │               │
│         └───────────────┴───────────┴───────────────┘               │
│                         SharedMemoryBlock                            │
│                                                                      │
│   LLM Chain:  AIML API  →  Local Gemma GGUF  →  Hardcoded JSON      │
└───────────┬─────────────────────────────────────────────────────────┘
            │
     ┌──────┴──────────────────────────────┐
     │              SERVICES               │
     │  ┌────────────┐  ┌───────────────┐  │
     │  │  Supabase  │  │  Firebase FCM │  │
     │  │ PostgreSQL │  │ Push Alerts   │  │
     │  └────────────┘  └───────────────┘  │
     │  ┌────────────┐  ┌───────────────┐  │
     │  │Google Maps │  │ Open-Meteo   │  │
     │  │ Geocoding  │  │ Weather API  │  │
     │  └────────────┘  └───────────────┘  │
     └─────────────────────────────────────┘
```

---

## 1. Flutter Mobile Client

**State Management:** Local `StatefulWidget` + `ChangeNotifier` (`LanguageProvider`)  
**Networking:** `http` package — calls FastAPI backend  
**Location & Sensors:** `geolocator` for GPS, `camera` for photo, `record` for audio  

**Key Screens:**

| Screen | File |
|---|---|
| Dashboard + Live Map | `screens/map_screen.dart` |
| Text Crisis Report | `screens/text_signal_screen.dart` |
| Photo Report (Vision) | `screens/photo_verification_screen.dart` |
| Voice Report (Whisper) | `screens/voice_report_screen.dart` |
| Incident Detail + Trace | `screens/incident_tracker_screen.dart` |
| AI Chat (Online + Offline) | `screens/ai_chat_screen.dart` |

**Offline Mode Architecture:**
```
ConnectivityService detects offline
           ↓
LocalLlmService.getOfflineResponse()
           ↓
    POST /local-chat  (Backend Gemma GGUF — no internet)
           ↓ [backend unreachable]
    Keyword-based hardcoded fallback
```

---

## 2. Python FastAPI Backend (`api_server.py`)

**Port:** 8000  
**Framework:** FastAPI + Uvicorn  
**Validation:** Pydantic v2 models

**Orchestration Layer:** FastAPI calls `KhabarCrewOrchestrator` (`agents/crew_orchestrator.py`), which orchestrates a hybrid pipeline using a sequential CrewAI Crew (`crewai.Crew`). CrewAI agents execute our 4 custom agents as specialized tools using an AIML API-configured `crewai.LLM`.

**Startup:** On server start, `automated_ingestion.py` begins a background polling loop:
- Open-Meteo weather (every 15 min)
- TomTom traffic flow (every 10 min)
- Proactive crisis signal injection if thresholds exceeded


---

## 3. LLM Client Chain (`agents/llm_client.py`)

```python
Tier 1: AIML API
  endpoint: https://api.aimlapi.com/v1
  model:    gemini/gemini-2.5-flash
  protocol: OpenAI-compatible AsyncOpenAI

    ↓ [3 retries with exponential backoff]

Tier 2: Local Gemma GGUF  (agents/local_model.py)
  file:    models/gemma-4-E2B-it-UD-IQ2_M.gguf
  engine:  llama-cpp-python (CPU, n_threads=4)
  context: 2048 tokens

    ↓ [model not loaded / unavailable]

Tier 3: Hardcoded JSON
  Deterministic structured fallback per agent type
  Never raises an exception — system always responds
```

---

## 4. Database Layer (`agents/firestore_db.py`)

**Primary:** Supabase PostgreSQL via `psycopg2`  
**Fallback:** Thread-safe in-memory Python dictionaries (auto-heals if DB offline)

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
1. Google Maps Geocoding API (if GOOGLE_MAPS_API_KEY set)
2. Local Pakistan city dictionary (instant, no API key)
3. OpenStreetMap Nominatim (free, no key, SSL-verified)
4. Default fallback → Islamabad center coordinates
```

**ETA calculation:** Google Distance Matrix API → Haversine formula fallback
