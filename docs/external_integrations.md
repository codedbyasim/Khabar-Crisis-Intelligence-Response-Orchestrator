# 🔌 External API & System Integrations

KHABAR integrates multiple external services for real-time crisis intelligence. All external calls include SSL verification, timeout protection, and graceful fallbacks.

---

## 1. 🤖 AIML API — Primary LLM (All Agents + Admin Chatbot)

**File:** `agents/llm_client.py`  
**Endpoint:** `https://api.aimlapi.com/v1`  
**Model:** `google/gemini-2.5-flash`  ✅ (verified working — returns HTTP 200)  
**Protocol:** OpenAI-compatible `AsyncOpenAI` client  
**Auth:** `AIML_API_KEY` from `agents/.env`  
**SDK Retries:** `max_retries=0` — disabled to prevent double-retry with our manual loop

Used by:
- All 4 pipeline agents (`llm_client.py`) for JSON-structured reasoning
- Vision analysis (`gemini_vision.py`) for image crisis detection
- Audio transcription (`gemini_speech.py`) for Whisper + analysis
- Admin dashboard chatbot (`/admin/chat`) for coordinator AI commands

**Retry Strategy:**
```
SDK auto-retry: DISABLED (max_retries=0)
Manual retry:   3 attempts × asyncio.wait_for(timeout=45s)
On exhaustion:  Falls back to Local GGUF → Hardcoded JSON
```

**Fallback:** Local GGUF model → Hardcoded JSON (see [local_model.md](local_model.md))

---

## 2. 🏠 Local GGUF Models — Offline LLM

**File:** `agents/local_model.py`  
**Engine:** `llama-cpp-python` (CPU inference, no GPU required)  
**Internet:** ❌ Not required

| Model | File | Size | Used For |
|---|---|---|---|
| Qwen2.5-0.5B-Instruct | `models/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf` | ~380 MB | Primary local fallback — fast, lightweight |
| Gemma 4-E2B | `models/gemma-4-E2B-it-UD-IQ2_M.gguf` | ~2.3 GB | Secondary local fallback — larger context |

Used when AIML API is unreachable. Also powers:
- `/local-chat` endpoint for offline Flutter citizen chat
- `/admin/chat` local fallback when online AI unavailable

See [local_model.md](local_model.md) for full configuration details.

---

## 3. ☁️ Supabase PostgreSQL — Cloud Database

**File:** `agents/firestore_db.py`  
**Connector:** `psycopg2-binary`  
**Auth:** `DATABASE_URL` from `agents/.env`

Two core tables:
- `incidents` — all reported disasters with full agent traces, before/after states
- `resources` — live inventory with `assigned_incident` column (auto-created via self-healing `ALTER TABLE` if missing)

**Self-Healing Fallback:** If Supabase is offline/paused, all reads and writes automatically use thread-safe in-memory Python dictionaries (`_IN_MEMORY_INCIDENTS`, `_IN_MEMORY_RESOURCES`). The system never crashes due to a database outage.

**Resource Allocation Tracking:** When a resource is dispatched via `POST /action/execute` or the admin chatbot, its `assigned_incident` field is automatically updated to link it to the incident ID.

---

## 4. 🗺️ Google Maps Platform

**File:** `agents/maps_service.py`  
**Auth:** `GOOGLE_MAPS_API_KEY` from `agents/.env`

Three APIs used:

| API | Purpose |
|---|---|
| Geocoding API | Convert text location → lat/lng coordinates |
| Distance Matrix API | Calculate real driving distances & ETAs between resources and incident |
| Places API (Nearby Search) | Find nearest hospitals within 5 km of incident |

**Geocoding Fallback Chain:**
```
Google Maps Geocoding API
        ↓ (API key missing or request failed)
Local Pakistan City Dictionary  (33 pre-loaded locations, instant, no API key)
        ↓ (location not in dictionary)
OpenStreetMap Nominatim  (free, no key, SSL-verified)
        ↓ (all failed)
Default: Islamabad center (33.6844, 73.0479)
```

---

## 5. 🌦️ Open-Meteo — Weather Ingestion

**File:** `agents/automated_ingestion.py`  
**API:** `https://api.open-meteo.com/v1/forecast`  
**Auth:** No API key required (free public API)  
**Poll Interval:** Every 15 minutes (background task — disabled by default)

Fetches: temperature, precipitation (mm), rain flag for Islamabad (33.6844°N, 73.0479°E).

**Auto-trigger:** If precipitation > 50mm/hour OR temperature > 43°C, a proactive crisis signal is injected into the orchestrator pipeline.

**Detection Agent Integration:** Weather data is cross-validated against citizen reports:
- Flood claim + 0mm precipitation → report rejected as unverified
- Heatwave claim + temperature < 35°C → report flagged as suspicious

---

## 6. 🚦 TomTom Traffic Flow API

**File:** `agents/automated_ingestion.py`  
**Auth:** `TOMTOM_API_KEY` from `agents/.env`  
**Poll Interval:** Every 10 minutes (background task — disabled by default)

Fetches current traffic flow speed vs free-flow speed ratio. If current speed is significantly below free-flow (< 30% of normal), a road blockage crisis signal is auto-generated.

---

## 7. 📰 Google News RSS — Live News Feed

**File:** `agents/automated_ingestion.py` + `api_server.py`  
**API:** Google News RSS (no API key required)  
**Query:** `Islamabad Rawalpindi (emergency OR floods OR rain OR weather OR crisis OR disaster) when:7d`

Returns up to 12 recent crisis news items with:
- English title (cleaned from RSS)
- Source name and publication date
- Article link

**Fallback:** Returns empty list `[]` if Google News RSS is unreachable. Flutter app handles this gracefully.

> **Note:** SerpAPI was previously used for news. The system now uses the free Google News RSS endpoint directly (no API key required, no quota limits).

---

## 8. 🔔 Firebase Cloud Messaging (FCM)

**File:** `agents/alert_service.py`  
**SDK:** `firebase-admin` Python package  
**Auth:** `agents/khabar-46771-firebase-adminsdk-fbsvc-e3117a9fbb.json` (gitignored)  
**Topic:** `khabar_public_alerts` (all Flutter users auto-subscribed)

See [fcm_notifications.md](fcm_notifications.md) for full FCM setup details.

---

## 9. 📊 Integration Status Summary

| Integration | Required | Fallback Available |
|---|---|---|
| AIML API (`google/gemini-2.5-flash`) | ✅ Required | Local GGUF models |
| Local Qwen GGUF (380MB) | Recommended | Hardcoded JSON |
| Local Gemma GGUF (2.3GB) | Optional | Qwen GGUF or JSON |
| Supabase PostgreSQL | Recommended | In-Memory Store |
| Google Maps API | Optional | Local dict + OSM Nominatim |
| Open-Meteo Weather | Optional | Skip weather cross-check |
| TomTom Traffic | Optional | Skip traffic auto-ingestion |
| Google News RSS | Optional | Empty list `[]` |
| Firebase FCM | Optional | Simulated delivery log |
