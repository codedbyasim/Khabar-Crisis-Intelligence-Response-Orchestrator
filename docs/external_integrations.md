# 🔌 External API & System Integrations

KHABAR integrates multiple external services for real-time crisis intelligence. All external calls include SSL verification, timeout protection, and graceful fallbacks.

---

## 1. 🤖 AIML API — Primary LLM (All Agents + Admin Chatbot)

**File:** `agents/llm_client.py`  
**Endpoint:** `https://api.aimlapi.com/v1`  
**Primary Model:** `google/gemini-2.5-flash`  
**Protocol:** OpenAI-compatible `AsyncOpenAI` client  
**Auth:** `AIML_API_KEY` from `agents/.env`  
**SDK Retries:** `max_retries=0` — disabled to prevent double-retries with our manual loop.

**Multi-Model Fallback Retry Loop:**
To prevent timeouts and handle model outages dynamically, `llm_client.py` implements a sequential multi-model fallback chain:
1. **Attempt 1**: `google/gemini-2.5-flash` (Primary, timeout: `20s`)
2. **Attempt 2**: `gpt-4o-mini` (OpenAI model, extremely fast and reliable, timeout: `15s`)
3. **Attempt 3**: `meta-llama/Llama-3-8b-instruct-maas` (Meta Llama model, timeout: `15s`)

If all attempts fail, the client terminates gracefully and generates Pydantic-aligned structured JSON fallbacks directly, without attempting heavy local GGUF loading on the backend server.

---

## 2. 🏠 Local GGUF Models — Offline AI (Client-Side)

**File:** `agents/local_model.py` (Backend, disabled) | `lib/utils/local_llm_service.dart` (Mobile, active)  
**Internet:** ❌ Not required  

To protect server resources, the GGUF model execution (`llama-cpp-python` CPU inference) is **decoupled/disabled on the backend**. Instead, a 100% on-device client-side offline assistant is integrated into the mobile Flutter client:
- **On-Device Matcher**: Formulates responses instantly using keyword matching inside `LocalLlmService` in English, Urdu, and Roman Urdu.
- **Access Gate**: Accessed directly from the login/signup page under the `OfflineChatScreen` without hitting the backend or checking network interfaces.

---

## 3. ☁️ Supabase PostgreSQL — Cloud Database

**File:** `agents/firestore_db.py`  
**Connector:** `psycopg2-binary`  
**Auth:** `DATABASE_URL` from `agents/.env`

Three core tables:
- `users` — stores `user_id`, `email`, `password_hash`, `name`, `region`, and `created_at`.
- `incidents` — all reported disasters, linked to the reporter's `user_id`.
- `resources` — live inventory with `assigned_incident` column (auto-created via self-healing `ALTER TABLE` if missing).

**Self-Healing Fallback:** If Supabase is offline/paused, all reads and writes automatically use thread-safe in-memory Python dictionaries (`_IN_MEMORY_INCIDENTS`, `_IN_MEMORY_RESOURCES`, `_IN_MEMORY_USERS`).

**Automatic Resource Releasing:** When a resource is dispatched via `POST /action/execute` or the admin chatbot, its `assigned_incident` field is updated to link it to the incident. When the incident status transitions to `"RESOLVED"` or `"CLOSED"`, or when `clear_database` is triggered, the system automatically resets all allocated resources back to `'available'` and clears their `assigned_incident` fields to `NULL` / `None` in Postgres and local memory.

---

## 4. 🗺️ Google Maps Platform

**File:** `agents/maps_service.py`  
**Auth:** `GOOGLE_MAPS_API_KEY` from `agents/.env`

APIs used:
- **Geocoding API**: Convert text location → lat/lng coordinates (with fallbacks to local Pakistan dictionary and OpenStreetMap Nominatim).
- **Places API (Nearby Search)**: Find nearest hospitals within 5 km of incident.

**Dynamic Distance & ETA calculations**:
- Calculated dynamically on the mobile client using the **Haversine formula** to get exact distances in kilometers between dispatch coordinates and incident metadata.
- Estimations for travel durations (ETA) are computed dynamically using average speed profiles of dispatched vehicles (Ambulance/Police move faster, WASA pumps/Rescue teams move slower).

---

## 5. 🌦️ Open-Meteo — Weather Ingestion

**File:** `agents/automated_ingestion.py`  
**API:** `https://api.open-meteo.com/v1/forecast`  
**Poll Interval:** Every 15 minutes (background task — disabled by default)

Fetches temperature, precipitation (mm), rain flag for Islamabad. If precipitation > 50mm/hour or temperature > 43°C, a proactive crisis signal is injected into the orchestrator pipeline.

---

## 6. 🚦 TomTom Traffic Flow API

**File:** `agents/automated_ingestion.py`  
**Auth:** `TOMTOM_API_KEY` from `agents/.env`  
**Poll Interval:** Every 10 minutes (background task — disabled by default)

Fetches traffic flow speed ratio. If current speed is < 30% of normal, a road blockage crisis signal is auto-generated.

---

## 7. 📰 Google News RSS — Live News Feed

**File:** `agents/automated_ingestion.py` + `api_server.py`  
**API:** Google News RSS (no API key required)  
**Query:** `Islamabad Rawalpindi (emergency OR floods OR rain OR weather OR crisis OR disaster) when:7d`

Returns up to 12 recent localized crisis news items with English + Urdu titles.

---

## 8. 🔔 Firebase Cloud Messaging (FCM)

**File:** `agents/alert_service.py`  
**SDK:** `firebase-admin` Python package  
**Auth:** `agents/khabar-46771-firebase-adminsdk-fbsvc-e3117a9fbb.json` (gitignored)  
**Topic:** `khabar_public_alerts` (all Flutter users auto-subscribed)

---

## 9. 📊 Integration Status Summary

| Integration | Required | Fallback Available |
|---|---|---|
| AIML API (Multi-model: Gemini, GPT, Llama) | ✅ Required | Hardcoded JSON Fallbacks |
| Local GGUF Model | Bypassed (Backend) | Hardcoded JSON Fallbacks |
| On-Device Offline AI | ✅ Required (Flutter) | Keyword Response Dictionary |
| Supabase PostgreSQL | Recommended | In-Memory StoreFallback |
| Google Maps API | Optional | Local dict + OSM Nominatim |
| Open-Meteo Weather | Optional | Skip weather cross-check |
| TomTom Traffic | Optional | Skip traffic auto-ingestion |
| Google News RSS | Optional | Empty list `[]` |
| Firebase FCM | Optional | Simulated delivery log |
