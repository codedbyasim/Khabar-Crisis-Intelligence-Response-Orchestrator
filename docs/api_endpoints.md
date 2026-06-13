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
| `POST` | `/report/text` | Crisis Reporting |
| `POST` | `/report/image` | Crisis Reporting |
| `POST` | `/report/voice` | Crisis Reporting |
| `GET` | `/incidents` | Data Retrieval |
| `GET` | `/incident/{id}` | Data Retrieval |
| `GET` | `/resources` | Resources |
| `POST` | `/resources/add` | Resources |
| `POST` | `/action/execute` | Manual Control |
| `GET` | `/logs/{id}` | Audit & Logs |
| `GET` | `/geocode` | Maps |
| `POST` | `/chat` | AI Chat (Online) |
| `POST` | `/local-chat` | AI Chat (Offline) |
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
  "ai_backend": "AIML API (Gemini 2.5 Flash) + Local Gemma Fallback",
  "version": "2.0.0"
}
```

---

### `GET /health`
Quick health check — returns active incident count.

---

### `POST /report/text`
Submit a crisis text report. Triggers the full 4-agent pipeline asynchronously.

**Request:**
```json
{
  "text": "Nullah Lai over flow ho rahi hai, Murree Road Rawalpindi band ho gayi!",
  "lat": 33.6375,
  "lng": 73.0784
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
Upload an audio recording for Whisper transcription.

**Form Data:**
| Field | Type | Required |
|---|---|---|
| `audio` | File (M4A/WAV) | ✅ |
| `image` | File (JPEG/PNG) | optional |
| `lat` | float | optional |
| `lng` | float | optional |

---

### `GET /incidents`
Returns all incidents with P1–P5 priority queue.

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
      "lng": 73.07
    }
  ]
}
```

---

### `GET /incident/{incident_id}`
Full incident record with complete 4-agent reasoning trace.

**Response includes:**
- `detection` — Stage 1 output (type, priority, confidence)
- `analysis` — Stage 2 output (impact, severity, bilingual summary)
- `planning` — Stage 3 output (action plan, NDMA SOPs)
- `execution` — Stage 4 output (tools executed, before/after state)
- `traces` — Timestamped log of every agent step

---

### `GET /resources`
Current resource inventory from Supabase.

**Response:**
```json
{
  "resources": [...],
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
Manually trigger a tool action (coordinator / dispatcher mode).

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

---

### `GET /logs/{incident_id}`
Export the full Antigravity agent trace log as a downloadable JSON file.

---

### `GET /geocode?query=Faizabad`
Geocode any Pakistan address/landmark.

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

### `POST /chat`  *(Online — AIML API)*
Multi-turn AI chat with context-aware crisis assistant.

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

### `POST /local-chat`  *(Offline — Local Gemma GGUF)* ★ NEW
AI chat powered by local Gemma model. **No internet required.**

**Request:**
```json
{
  "message": "flood emergency mein kya karoon?",
  "language": "Roman Urdu",
  "sector": "Faizabad (Rawalpindi)"
}
```

**Response:**
```json
{
  "success": true,
  "response": "Sailaab emergency: WASA 1334 call karein. Bijli ka main switch off karein...",
  "mode": "local_gemma",
  "model": "gemma-4-E2B-it-UD-IQ2_M.gguf"
}
```

**Mode values:**
| Mode | Meaning |
|---|---|
| `local_gemma` | Gemma GGUF model responded |
| `keyword_fallback` | GGUF not loaded, used keyword matching |
| `error_fallback` | Unexpected error |

---

### `GET /live-news`
Real-time Google News via SerpAPI — localized for Islamabad/Rawalpindi.  
Returns up to 12 recent crisis news items with English + Urdu titles.
