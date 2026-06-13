# 🔌 External API & System Integrations

KHABAR integrates multiple external services for real-time crisis intelligence. All external calls include SSL verification, timeout protection, and graceful fallbacks.

---

## 1. 🤖 AIML API — Primary LLM (All Agents)

**File:** `agents/llm_client.py`  
**Endpoint:** `https://api.aimlapi.com/v1`  
**Model:** `gemini/gemini-2.5-flash`  
**Protocol:** OpenAI-compatible `AsyncOpenAI` client  
**Auth:** `AIML_API_KEY` from `agents/.env`

Used by all 4 agents for JSON-structured reasoning. Supports:
- Text generation (JSON mode enforced)
- Vision analysis (base64 image encoding)
- Audio transcription (Whisper API)

**Fallback:** Local Gemma GGUF → Hardcoded JSON (see [local_model.md](local_model.md))

---

## 2. 🏠 Local Gemma GGUF — Offline LLM

**File:** `agents/local_model.py`  
**Model:** `models/gemma-4-E2B-it-UD-IQ2_M.gguf` (2.3 GB)  
**Engine:** `llama-cpp-python` (CPU inference, no GPU required)  
**Internet:** ❌ Not required

Used when AIML API is unreachable. Also powers the `/local-chat` endpoint for offline Flutter chat. See [local_model.md](local_model.md) for full details.

---

## 3. ☁️ Supabase PostgreSQL — Cloud Database

**File:** `agents/firestore_db.py`  
**Connector:** `psycopg2-binary`  
**Auth:** `DATABASE_URL` from `agents/.env`

Two core tables:
- `incidents` — all reported disasters with full agent traces, before/after states
- `resources` — live inventory of ambulances, rescue teams, fire trucks, dewatering pumps

**Self-Healing Fallback:** If Supabase is offline/paused, all reads and writes automatically use thread-safe in-memory Python dictionaries (`_IN_MEMORY_INCIDENTS`, `_IN_MEMORY_RESOURCES`). The system never crashes due to a database outage.

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
        ↓ (API key missing or failed)
Local Pakistan City Dictionary  (33 pre-loaded locations, instant)
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
**Poll Interval:** Every 15 minutes (background task)

Fetches: temperature, precipitation (mm), rain flag for Islamabad (33.6844°N, 73.0479°E).

**Auto-trigger:** If precipitation > 50mm/hour OR temperature > 43°C, a proactive crisis signal is injected into the orchestrator pipeline.

**Detection Agent Integration:** Weather data is cross-validated against citizen reports:
- Flood claim + 0mm precipitation → report rejected as unverified
- Heatwave claim + temperature < 35°C → report flagged as suspicious

---

## 6. 🚦 TomTom Traffic Flow API

**File:** `agents/automated_ingestion.py`  
**Auth:** `TOMTOM_API_KEY` from `agents/.env`  
**Poll Interval:** Every 10 minutes (background task)

Fetches current traffic flow speed vs free-flow speed. If current speed is significantly below free-flow, a road blockage signal is auto-generated.

---

## 7. 📰 SerpAPI — Google News Feed

**File:** `agents/alert_service.py` (invoked via `/live-news` endpoint)  
**Auth:** `SERPAPI_KEY` from `agents/.env`

Query: `"Islamabad Rawalpindi rain flood WASA OR Rescue 1122 OR alert when:7d"`  
Returns up to 12 recent crisis news items with:
- English title (cleaned)
- Urdu translated title (template-mapped by keyword)
- Source name
- Publication date
- Article link

**Fallback:** Returns empty list `[]` if SerpAPI is unavailable. Flutter app handles this gracefully.

---

## 8. 🔔 Firebase Cloud Messaging (FCM)

**File:** `agents/alert_service.py`  
**SDK:** `firebase-admin` Python package  
**Auth:** `agents/khabar-46771-firebase-adminsdk-fbsvc-e3117a9fbb.json`  
**Topic:** `khabar_public_alerts` (all Flutter users auto-subscribed)

See [fcm_notifications.md](fcm_notifications.md) for full FCM setup details.

---

## 9. 📊 Integration Status Summary

| Integration | Required | Fallback Available |
|---|---|---|
| AIML API | ✅ Required | Local Gemma GGUF |
| Local Gemma GGUF | Optional | Hardcoded JSON |
| Supabase PostgreSQL | Recommended | In-Memory Store |
| Google Maps API | Optional | Local dict + OSM |
| Open-Meteo | Optional | Skip weather check |
| TomTom Traffic | Optional | Skip traffic check |
| SerpAPI News | Optional | Empty list [] |
| Firebase FCM | Optional | Simulated delivery |
