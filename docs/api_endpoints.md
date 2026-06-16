# 🌐 KHABAR API Endpoints Reference

Base URL: `http://127.0.0.1:8000`  
Swagger UI: `http://127.0.0.1:8000/docs`  
Android Emulator: `http://10.0.2.2:8000`

---

## Complete Endpoint List

| Method | Endpoint | Category |
|--------|----------|----------|
| `GET` | `/` | System Info |
| `GET` | `/health` | Health Check |
| `POST` | `/auth/signup` | Authentication |
| `POST` | `/auth/login` | Authentication |
| `POST` | `/report/text` | Crisis Reporting |
| `POST` | `/report/image` | Crisis Reporting |
| `POST` | `/report/voice` | Crisis Reporting |
| `GET` | `/incidents` | Data Retrieval |
| `DELETE` | `/incidents` | Data Management |
| `GET` | `/incident/{id}` | Data Retrieval |
| `GET` | `/resources` | Resources |
| `POST` | `/resources/add` | Resources |
| `POST` | `/action/execute` | Manual Control |
| `GET` | `/logs/{id}` | Audit & Logs |
| `GET` | `/geocode` | Maps |
| `POST` | `/chat` | AI Chat (Online — Citizen) |
| `POST` | `/admin/chat` | AI Command Assistant (Dashboard) |
| `GET` | `/live-news` | News Feed |

---

## Endpoint Details

### `GET /`
System status, AI backend info, and all endpoint descriptions.

**Response:**
```json
{
  "status": "online",
  "system": "KHABAR Crisis Intelligence & Response Orchestrator",
  "ai_backend": "AIML API (google/gemini-2.5-flash)",
  "version": "2.0.0"
}
```

---

### `GET /health`
Quick health check — returns active incident count and server status.

---

### `POST /auth/signup`
Creates a new user profile with hashed passwords using PBKDF2.

**Request:**
```json
{
  "email": "citizen@example.com",
  "password": "securepassword123",
  "name": "Arsalan Khan",
  "region": "Islamabad, Capital Territory"
}
```
**Response:**
```json
{
  "success": true,
  "user": {
    "user_id": "USR-A8F2BC43",
    "email": "citizen@example.com",
    "name": "Arsalan Khan",
    "region": "Islamabad, Capital Territory"
  }
}
```

---

### `POST /auth/login`
Authenticates user and returns profile metadata.

**Request:**
```json
{
  "email": "citizen@example.com",
  "password": "securepassword123"
}
```
**Response:**
```json
{
  "success": true,
  "user": {
    "user_id": "USR-A8F2BC43",
    "email": "citizen@example.com",
    "name": "Arsalan Khan",
    "region": "Islamabad, Capital Territory"
  }
}
```

---

### `POST /report/text`
Submit a crisis text report. Triggers the full 4-agent pipeline asynchronously.

**Request:**
```json
{
  "text": "Nullah Lai over flow ho rahi hai, Murree Road Rawalpindi band ho gayi!",
  "lat": 33.6375,
  "lng": 73.0784,
  "user_id": "USR-A8F2BC43"
}
```
**Response:**
```json
{
  "success": true,
  "incident_id": "SIG-1716223400-TXT",
  "status": "PROCESSING",
  "poll_url": "/incident/SIG-1716223400-TXT"
}
```

---

### `POST /report/image`
Upload a photo for Vision AI damage assessment.

**Form Data:**
| Field | Type | Required |
|---|---|---|
| `image` | File (JPEG/PNG) | ✅ |
| `lat` | float | optional (default: 33.6844) |
| `lng` | float | optional (default: 73.0479) |
| `description` | string | optional |
| `user_id` | string | optional (links report to reporter profile) |

**Response:**
```json
{
  "success": true,
  "incident_id": "SIG-1716223410-IMG",
  "vision_analysis": {
    "crisis_type": "urban_flooding",
    "severity": "HIGH",
    "priority": "P2",
    "confidence": 0.95
  }
}
```

---

### `POST /report/voice`
Upload an audio recording for Whisper transcription + crisis analysis.

**Form Data:**
| Field | Type | Required |
|---|---|---|
| `audio` | File (M4A/WAV/OGG) | ✅ |
| `image` | File (JPEG/PNG) | optional — dual-modal analysis |
| `lat` | float | optional |
| `lng` | float | optional |
| `user_id` | string | optional |

---

### `GET /incidents`
Returns all incidents or limits incidents to a user. Supports filtering.

**Query Parameters:**
- `user_id` (string, optional) - If provided, filters cases by creator and returns the **10 most recent cases** sorted chronologically.

**Response:**
```json
{
  "total": 3,
  "incidents": [
    {
      "incident_id": "SIG-...",
      "incident_type": "urban_flooding",
      "priority": "P2",
      "status": "PIPELINE_COMPLETE",
      "lat": 33.63,
      "lng": 73.07,
      "user_id": "USR-A8F2BC43"
    }
  ]
}
```

---

### `DELETE /incidents`
Clear all incidents from database (both Supabase and in-memory store) and reset resources status to available.

**Response:**
```json
{ "success": true, "message": "All incidents cleared." }
```

---

### `GET /incident/{incident_id}`
Full incident record with complete 4-agent reasoning trace.

**Response includes:**
- `detection` — Stage 1 output (type, priority, confidence, location)
- `analysis` — Stage 2 output (impact, severity, bilingual summary)
- `planning` — Stage 3 output (action plan, NDMA SOPs)
- `execution` — Stage 4 output (tools executed, before/after state)
- `traces` — Timestamped log of every agent step

---

### `GET /resources`
Current resource inventory from Supabase (with in-memory fallback).

**Response:**
```json
{
  "resources": [
    {
      "resource_id": "RES-AMB-01",
      "name": "PIMS Ambulance",
      "resource_type": "ambulance",
      "status": "available",
      "quantity_available": 3,
      "assigned_incident": null
    }
  ],
  "summary": {
    "ambulances": {"available": 11, "en_route": 0},
    "rescue_teams": {"available": 4, "en_route": 0},
    "dewatering_pumps": {"available": 7}
  }
}
```

---

### `POST /resources/add`
Register a new resource unit dynamically.

**Request:**
```json
{
  "resource_id": "RES-RWP-06",
  "name": "Rawalpindi Rescue Team Unit",
  "resource_type": "rescue_team",
  "quantity_available": 3,
  "status": "available",
  "location": {"lat": 33.5651, "lng": 73.0169}
}
```

---

### `POST /action/execute`
Manually trigger a tool action (coordinator / dispatcher mode). Auto-allocates matching available resources in the database.

**Request:**
```json
{
  "incident_id": "SIG-1716223400-TXT",
  "action_type": "dispatch",
  "agency": "Rescue 1122",
  "units": 2
}
```
**action_type options:** `dispatch` | `alert` | `reroute` | `ticket` | `status`

**Effect:** 
- When dispatching, the backend sets status to `deployed` and links them to the incident.
- When resolving or closing (`status` with `RESOLVED` or `CLOSED`), the backend automatically frees all allocated resources back to `available` with `assigned_incident = null`.

---

### `GET /logs/{incident_id}`
Export the full Antigravity agent trace log as a downloadable JSON file.

```
→ Downloads: khabar_trace_{incident_id}.json
```

---

### `GET /geocode?query=Faizabad`
Geocode any Pakistan address/landmark using the 4-tier geocoding chain.

**Response:**
```json
{
  "success": true,
  "lat": 33.6375,
  "lng": 73.0784,
  "display_name": "Faizabad, Rawalpindi",
  "city": "Rawalpindi"
}
```

---

### `POST /chat`  *(Online — Citizen AI Chat)*
Multi-turn AI chat with context-aware crisis assistant. Uses AIML API `google/gemini-2.5-flash` with fallback models like `gpt-4o-mini` and Llama 3 for extreme resilience.

**Request:**
```json
{
  "message": "WASA kab tak aayega G-11 mein?",
  "history": [],
  "language": "Roman Urdu",
  "user_location": "Sector G-11 (Islamabad)"
}
```

**Response:**
```json
{
  "success": true,
  "response": "Aap ke sector G-11 ke qareeb G-11 Fire Station & Rescue Unit hai. Calculated travel time: 5 to 8 minutes (2.8 km)..."
}
```

---

### `POST /admin/chat`  *(Dashboard — AI Command Assistant)*
Intelligent chatbot for emergency coordinators in the admin dashboard. Reads live system state (incidents + resources) and can execute real coordinator commands.

**Request:**
```json
{
  "message": "Dispatch Rescue 1122 to SIG-123 immediately",
  "history": [
    {"role": "user", "content": "..."},
    {"role": "assistant", "content": "..."}
  ]
}
```

**Response:**
```json
{
  "success": true,
  "response": "[EXECUTE: dispatch, incident_id=\"SIG-123\", agency=\"Rescue 1122\", units=2]\nDispatching 2 Rescue 1122 units to the incident...",
  "command_executed": {
    "type": "dispatch",
    "incident_id": "SIG-123",
    "agency": "Rescue 1122",
    "units": 2
  }
}
```

**Supported inline commands (parsed from AI response):**
| Tag | Action |
|---|---|
| `[EXECUTE: dispatch, ...]` | Dispatch resource units to an incident |
| `[EXECUTE: alert, ...]` | Broadcast public warning via FCM |
| `[EXECUTE: reroute, ...]` | Close road / set traffic detour |
| `[EXECUTE: ticket, ...]` | Create inter-agency support ticket |
| `[EXECUTE: status, ...]` | Update status (Resolving/closing automatically releases resources) |
| `[EXECUTE: add_resource, ...]` | Register new resource unit |
| `[EXECUTE: clear_database]` | Clear all incidents and reset resources from system |

---

### `GET /live-news`
Real-time news feed from Google News RSS — localized for Islamabad/Rawalpindi.  
Returns up to 12 recent crisis news items with English + Urdu titles.
