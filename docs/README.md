# 📚 KHABAR Documentation Index

Complete technical documentation for the KHABAR Crisis Intelligence & Response Orchestrator.

---

## Documents

| File | Description |
|---|---|
| [architecture.md](architecture.md) | Full system architecture — Flutter app, FastAPI backend, React dashboard, LLM chain, DB layer |
| [api_endpoints.md](api_endpoints.md) | All 17 API endpoints with request/response schemas |
| [multi_agent_pipeline.md](multi_agent_pipeline.md) | 4-agent pipeline — per-stage schemas, CrewAI orchestration, tools |
| [multi_source_input.md](multi_source_input.md) | Text, image, voice input modalities + automated ingestion |
| [action_simulation.md](action_simulation.md) | 7 Antigravity tools — before/after state tracking |
| [outcome_visualization.md](outcome_visualization.md) | Flutter UI, React dashboard, Chatbot, map visualization, trace export |
| [fcm_notifications.md](fcm_notifications.md) | Firebase FCM push notifications — setup & bilingual templates |
| [external_integrations.md](external_integrations.md) | All external APIs — AIML, GGUF models, Supabase, Maps, Weather, News |
| [local_model.md](local_model.md) | ★ Local GGUF models (Qwen + Gemma) — offline inference documentation |

---

## Quick Start

### 1. Start the AI Backend
```powershell
cd h:\khabar
$env:PYTHONIOENCODING="utf-8"
python api_server.py          # → http://127.0.0.1:8000
```

### 2. Start the React Dashboard
```powershell
cd h:\khabar\dashboard
npm run dev                   # → http://127.0.0.1:5173
# OR serve the built version:
cd h:\khabar
python dashboard_server.py    # → http://127.0.0.1:8001
```

### 3. Run the Flutter Mobile App
```powershell
cd h:\khabar
flutter run -d chrome         # Web
flutter run                   # Android emulator/device
```

---

## Tech Stack at a Glance

| Layer | Technology |
|---|---|
| Primary LLM | AIML API → `google/gemini-2.5-flash` (OpenAI-compatible) |
| Offline LLM | Qwen2.5-0.5B-Instruct GGUF + Gemma 4-E2B GGUF via `llama-cpp-python` |
| Backend | Python FastAPI (`api_server.py`) + Uvicorn on port 8000 |
| Web Dashboard | Vite + React 18 + Leaflet.js on port 8001 |
| Mobile App | Flutter 3.16+ / Dart |
| Database | Supabase PostgreSQL + In-Memory fallback |
| Alerts | Firebase Cloud Messaging v1 (FCM) |
| Maps | Google Maps Platform + OSM Nominatim fallback |

---

## Key Endpoints Quick Reference

| Endpoint | Use |
|---|---|
| `POST /report/text` | Submit text crisis report → triggers 4-agent pipeline |
| `POST /report/image` | Upload photo → Vision AI analysis |
| `POST /report/voice` | Upload audio → Whisper transcription |
| `GET /incidents` | All active incidents |
| `GET /resources` | Resource inventory with allocation status |
| `POST /action/execute` | Manually dispatch resources or execute actions |
| `POST /admin/chat` | **AI Command Assistant** — natural language coordinator commands |
| `POST /chat` | Online citizen AI chat (AIML API) |
| `POST /local-chat` | **Offline citizen AI chat** (Local GGUF) |
| `GET /logs/{id}` | Export agent trace log as JSON |
| `GET /docs` | Swagger interactive API documentation |

---

## Architecture at a Glance

```
[Citizen] → Text / Image / Voice
                 ↓
         FastAPI Backend (port 8000)
                 ↓
    Detection → Analysis → Planning → Execution
                 ↓                        ↓
         AIML API                  7 Antigravity Tools
    (google/gemini-2.5-flash)      (Dispatch, Alert, Reroute...)
         ↓ [fallback]                     ↓
    Local GGUF Model           Supabase DB + Firebase FCM
         ↓ [fallback]
    Hardcoded JSON
                 ↓
    React Dashboard (port 8001) — Live Map, Chatbot, Resource Manager
    Flutter Mobile App          — Citizen reporting, Incident tracking
```

---

## LLM Fallback Chain (DO NOT BREAK)

```
AIML API (3 manual retries, 45s timeout each)
     ↓
Local Qwen GGUF  (agents/local_model.py — Qwen2.5-0.5B)
     ↓
Local Gemma GGUF (agents/local_model.py — Gemma 4-E2B, if available)
     ↓
Hardcoded JSON    (generate_local_fallback in llm_client.py)
```

**Note:** OpenAI SDK built-in retries are disabled (`max_retries=0`) across all client instances. Only our manual retry loop controls retry behavior.
