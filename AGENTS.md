# Developer & Agent Configuration

## Project Structure

- **Custom Agent Logic:** All 4-agent pipeline code lives in `./agents/`
- **Engineering Workflows:** Operational quality gates and frameworks live in `./skills/`
- **Agent Design Specs:** Custom designs and feature specs live in `./agent/`
- **Documentation:** Full technical docs live in `./docs/`

## Tech Stack (Current)

| Layer | Technology |
|---|---|
| Primary LLM | AIML API → `gemini/gemini-2.5-flash` (OpenAI-compatible) |
| Offline LLM | Local Gemma GGUF via `llama-cpp-python` |
| Backend | Python FastAPI (`api_server.py`) |
| Database | Supabase PostgreSQL + In-Memory fallback |
| Mobile | Flutter 3.16+ / Dart |
| Alerts | Firebase Cloud Messaging v1 |

## Key Files for AI Development

| File | Purpose |
|---|---|
| `agents/llm_client.py` | AIML API client + 3-tier fallback chain |
| `agents/local_model.py` | Local Gemma GGUF loader (offline inference) |
| `agents/orchestrator.py` | Main pipeline runner (KhabarOrchestrator) |
| `agents/detection_agent.py` | Stage 1: Classify & spam-filter |
| `agents/analysis_agent.py` | Stage 2: Impact & severity analysis |
| `agents/planning_agent.py` | Stage 3: NDMA RAG + resource planning |
| `agents/execution_agent.py` | Stage 4: Tool execution + state tracking |
| `agents/tool_system.py` | 7 Antigravity tools |

## Core Instruction

Before executing any development phase, you must dynamically read and strictly follow the corresponding process workflow inside the `./skills/` directory:

- For clarifying requirements → Use `skills/interview-me/` or `skills/spec-driven-development/`
- For breaking down tasks → Use `skills/planning-and-task-breakdown/`
- For implementation & logic → Use `skills/test-driven-development/` and `skills/incremental-implementation/`
- For code reviews → Use `skills/code-review-and-quality/` or `skills/code-simplification/`

## Development Rules

1. **Never use `GEMINI_API_KEY`** — project uses `AIML_API_KEY` (AIML API, OpenAI-compatible)
2. **Never remove local model fallback** — `agents/local_model.py` is a required component
3. **Always run `py_compile`** after editing any Python file
4. **Always run `flutter analyze`** after editing any Dart file
5. **Set `PYTHONIOENCODING=utf-8`** before running backend on Windows
6. **Never hardcode API keys** — all secrets go in `agents/.env`
7. **Never skip verification gates** — excuses like "I will add tests later" are forbidden

## LLM Fallback Chain (DO NOT BREAK)

```
AIML API (3 retries)
     ↓
Local Gemma GGUF  (agents/local_model.py)
     ↓
Hardcoded JSON    (generate_local_fallback in llm_client.py)
```

This chain must remain intact. Never remove any tier.
