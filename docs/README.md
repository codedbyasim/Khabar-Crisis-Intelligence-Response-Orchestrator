# 📚 KHABAR Documentation Index

Complete technical documentation for the KHABAR Crisis Intelligence & Response Orchestrator.

---

## Documents

| File | Description |
|---|---|
| [architecture.md](architecture.md) | Full system architecture — components, LLM chain, DB layer, maps |
| [api_endpoints.md](api_endpoints.md) | All 15 API endpoints with request/response schemas |
| [multi_agent_pipeline.md](multi_agent_pipeline.md) | 4-agent pipeline — per-stage input/output schemas, tools |
| [multi_source_input.md](multi_source_input.md) | Text, image, voice input modalities + automated ingestion |
| [action_simulation.md](action_simulation.md) | 7 Antigravity tools — before/after state tracking |
| [outcome_visualization.md](outcome_visualization.md) | Flutter UI, map visualization, trace log export |
| [fcm_notifications.md](fcm_notifications.md) | Firebase FCM push notifications — setup & bilingual templates |
| [external_integrations.md](external_integrations.md) | All external APIs — AIML, Gemma, Supabase, Maps, Weather, News |
| [local_model.md](local_model.md) | ★ Local Gemma GGUF model — offline inference documentation |

---

## Quick Reference

### Run the system
```powershell
cd h:\khabar
.\venv\Scripts\activate
$env:PYTHONIOENCODING="utf-8"
python api_server.py          # → http://127.0.0.1:8000
```

### AI Backend
- **Online:** AIML API (Gemini 2.5 Flash) via `agents/llm_client.py`
- **Offline:** Local Gemma GGUF via `agents/local_model.py`
- **Model:** `models/gemma-4-E2B-it-UD-IQ2_M.gguf` (2.3 GB)

### Key Endpoints
| Endpoint | Use |
|---|---|
| `POST /report/text` | Submit text crisis report |
| `POST /chat` | Online AI chat |
| `POST /local-chat` | **Offline AI chat (Gemma GGUF)** |
| `GET /incidents` | All active incidents |
| `GET /docs` | Swagger interactive API docs |

---

## Architecture at a Glance

```
[Citizen] → Text/Image/Voice
                 ↓
         FastAPI Backend
                 ↓
    Detection → Analysis → Planning → Execution
                 ↓
         AIML API / Local Gemma
                 ↓
    Supabase DB + Firebase FCM + Flutter App
```
