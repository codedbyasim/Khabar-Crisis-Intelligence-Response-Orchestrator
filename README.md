# 🚨 KHABAR (خبر) — Crisis Intelligence & Response Orchestrator (CIRO)
### **AISeekho Antigravity Hackathon 2026 (Challenge 3) | AIML API + Local Gemma 4 | FastAPI + Flutter**

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
3. **Fragmented Dispatch:** WASA, Rescue 1122, Traffic Police, and Power departments work in silos.
4. **No Simulation:** No before/after state tracking or detour planning.

---

## 💡 3. The KHABAR Solution
**KHABAR** (meaning *News / Awareness* in Urdu) is an Agentic AI system that transforms raw citizen signals into automated, verified, and simulated emergency response pipelines.

```
[Citizen Signal (Text/Voice/Photo)]
         ↓
[Verification Gate — Spam Filter]
         ↓
[4-Agent AI Pipeline (Detection → Analysis → Planning → Execution)]
         ↓
[Simulated Dispatches, FCM Alerts, DB Updates]
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
- **Spam / Verification Gate:** Rejects conversational inputs (e.g. "hi", "test") and cross-validates weather claims against live Open-Meteo data
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
- Maps planning actions to tools from `tool_system.py`
- Tracks exact `before_state` → `after_state` system transitions
- Sends **real FCM push notifications** via Firebase Admin SDK (bilingual Urdu + English)
- Writes final incident record to Supabase PostgreSQL

---

## 🤖 5. AI Backend — LLM Chain

KHABAR uses a **3-tier LLM fallback chain** to ensure 100% uptime:

```
Tier 1: AIML API  (Gemini 2.5 Flash via OpenAI-compatible API)
         ↓  [3 retries exhausted]
Tier 2: Local Gemma GGUF  (gemma-4-E2B-it-UD-IQ2_M.gguf — CPU inference)
         ↓  [model unavailable]
Tier 3: Hardcoded Structured JSON  (last resort, never crashes)
```

| Tier | File | Requires Internet |
|------|------|:-----------------:|
| AIML API | `agents/llm_client.py` | ✅ Yes |
| Local Gemma | `agents/local_model.py` | ❌ No |
| Hardcoded JSON | `agents/llm_client.py` | ❌ No |

---

## 📱 6. Flutter Mobile App

Built in Flutter/Dart with a premium dark-themed design system:

| Screen | File | Function |
|---|---|---|
| Dashboard / Map | `map_screen.dart` | Live incidents map with polyline detours |
| Text Report | `report_text_screen.dart` | Multi-language text crisis submission |
| Photo Report | `report_image_screen.dart` | Camera → Gemini Vision analysis |
| Voice Report | `report_voice_screen.dart` | Audio → Whisper transcription |
| Incident Detail | `incident_detail_screen.dart` | Agent trace timeline, before/after state |
| AI Chat | `ai_chat_screen.dart` | Online chat (AIML API) + Offline (Local Gemma) |
| Live News | (in Dashboard) | Real-time SerpAPI Google News feed |

### **Offline Mode (No Internet)**
When device is offline, `LocalLlmService` calls:
1. `POST /local-chat` → Backend uses **Local Gemma GGUF** (no internet needed on backend either)
2. If backend is also down → Keyword-based hardcoded responses

### **Platform URL Auto-Detection** (`lib/api_config.dart`)
```dart
Web (Chrome)       → http://127.0.0.1:8000
Android Emulator   → http://10.0.2.2:8000
```

---

## 🌐 7. Complete API Reference

Base URL: `http://127.0.0.1:8000`
Swagger Docs: `http://127.0.0.1:8000/docs`

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/` | System status & endpoint list |
| `GET` | `/health` | Health check + active incident count |
| `POST` | `/report/text` | Submit text crisis report (Urdu/English/Roman Urdu) |
| `POST` | `/report/image` | Submit photo for Vision damage assessment |
| `POST` | `/report/voice` | Submit audio for Speech transcription |
| `GET` | `/incidents` | All active incidents with P1–P5 queue |
| `GET` | `/incident/{id}` | Single incident + full agent trace |
| `GET` | `/resources` | Resource inventory & rescue team status |
| `POST` | `/resources/add` | Register a new resource unit |
| `POST` | `/action/execute` | Manual tool execution (coordinator mode) |
| `GET` | `/logs/{id}` | Export full agent trace as JSON |
| `GET` | `/geocode` | Geocode address via Google Maps / OSM |
| `POST` | `/chat` | Multi-turn AI chat (online — AIML API) |
| `POST` | `/local-chat` | **Offline AI chat (Local Gemma GGUF — no internet)** |
| `GET` | `/live-news` | Real-time SerpAPI Google News feed |

### **7.1. POST `/report/text`**
```json
Request:  { "text": "Nullah Lai over flow ho rahi hai Rawalpindi!", "lat": 33.6375, "lng": 73.0784 }
Response: { "success": true, "incident_id": "SIG-1716223400-TXT", "status": "PROCESSING", "poll_url": "/incident/SIG-..." }
```

### **7.2. POST `/local-chat`** *(NEW)*
```json
Request:  { "message": "flood emergency kya karoon?", "language": "Roman Urdu", "sector": "Faizabad (Rawalpindi)" }
Response: { "success": true, "response": "...", "mode": "local_gemma", "model": "gemma-4-E2B-it-UD-IQ2_M.gguf" }
```

### **7.3. POST `/chat`** (Online AI)
```json
Request:  { "message": "WASA kab tak aayega?", "history": [], "language": "Roman Urdu", "user_location": "G-11 (Islamabad)" }
Response: { "success": true, "response": "Aap ke sector G-11 ke qareeb G-11 Fire Station hai, estimated time: 5–8 minutes..." }
```

---

## 💾 8. Database Schema (Supabase PostgreSQL)

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
    location           JSONB                     -- {"lat": float, "lng": float}
);
```

---

## 🛠️ 9. Technology Stack

| Layer | Technology |
|---|---|
| **AI Orchestration** | Python, FastAPI, Pydantic v2 |
| **Primary LLM** | AIML API → Gemini 2.5 Flash (OpenAI-compatible) |
| **Offline LLM** | Local Gemma 4 GGUF via `llama-cpp-python` (CPU) |
| **Vision AI** | AIML API Vision (OpenAI-compatible base64 image) |
| **Speech AI** | OpenAI Whisper API (via AIML) |
| **Mobile Client** | Flutter 3.16+, Dart |
| **Maps** | Google Maps Flutter SDK + OpenStreetMap Nominatim |
| **Database** | Supabase Cloud PostgreSQL (psycopg2) + In-Memory fallback |
| **Push Alerts** | Firebase Cloud Messaging v1 (Firebase Admin SDK) |
| **Weather** | Open-Meteo API (free, no key) |
| **Traffic** | TomTom Traffic Flow API |
| **News Feed** | SerpAPI Google News engine |
| **Geocoding** | Google Maps Geocoding API + OSM Nominatim fallback |

---

## 📂 10. Project Structure

```
h:\khabar\
├── api_server.py              ← FastAPI backend — all 15 endpoints
├── dashboard_server.py        ← Web dashboard (port 8001)
├── seed_resources.py          ← One-time DB seeder
├── requirements.txt           ← Python dependencies
│
├── agents/                    ← All backend AI agents
│   ├── orchestrator.py        ← KhabarOrchestrator — main pipeline runner
│   ├── llm_client.py          ← AIML API client + 3-tier fallback chain
│   ├── local_model.py         ← ★ NEW: Local Gemma GGUF loader (llama-cpp-python)
│   ├── detection_agent.py     ← Stage 1: Classify & verify
│   ├── analysis_agent.py      ← Stage 2: Impact & severity analysis
│   ├── planning_agent.py      ← Stage 3: NDMA RAG + resource planning
│   ├── execution_agent.py     ← Stage 4: Tool execution + state diff
│   ├── tool_system.py         ← 7 Antigravity tools (dispatch, alert, etc.)
│   ├── firestore_db.py        ← Supabase DB adapter + in-memory fallback
│   ├── alert_service.py       ← Firebase FCM v1 push notifications
│   ├── maps_service.py        ← Google Maps + OSM geocoding & ETAs
│   ├── gemini_vision.py       ← AIML Vision API (damage assessment)
│   ├── gemini_speech.py       ← AIML Whisper API (audio transcription)
│   ├── automated_ingestion.py ← Background weather & traffic polling
│   └── .env                   ← API keys (not in git)
│
├── models/                    ← ★ Local AI Models
│   └── gemma-4-E2B-it-UD-IQ2_M.gguf   (2.3 GB — Gemma 4 quantized)
│
├── lib/                       ← Flutter mobile app
│   ├── main.dart
│   ├── api_config.dart        ← Auto-detects Web vs Emulator URL
│   ├── screens/               ← All UI screens
│   ├── theme/                 ← Color system, fonts, language provider
│   └── utils/
│       ├── local_llm_service.dart  ← ★ Calls /local-chat → keyword fallback
│       └── connectivity_service.dart
│
├── docs/                      ← Full technical documentation
├── dashboard/                 ← Web dashboard HTML/JS
└── assets/                    ← App images & fonts
```

---

## 📝 11. Core Platform Assumptions
1. **Map Corridor Simulations:** Detour corridors are visually simulated using coordinate boundaries relative to the incident center (due to API routing complexity).
2. **Emergency Dispatch Capacity:** Baseline resource capacity seeded via `seed_resources.py`. On exhaustion, Planning Agent auto-escalates to `STANDBY`.
3. **Human-in-the-Loop:** P3–P5 events in production require manual dispatcher confirmation before the Execution Agent triggers real dispatches.
4. **Local Model Performance:** Gemma GGUF runs on CPU (~5–15 sec/response). For production, GPU acceleration can be enabled via `n_gpu_layers` in `agents/local_model.py`.
