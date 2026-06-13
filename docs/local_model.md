# 🤖 Local Gemma Model — Offline AI Inference

KHABAR includes a **fully offline AI inference engine** powered by a quantized Gemma 4 GGUF model running on CPU. No internet connection is required.

---

## Model Details

| Property | Value |
|---|---|
| **Model** | Gemma 4 (Google) |
| **File** | `gemma-4-E2B-it-UD-IQ2_M.gguf` |
| **Location** | `h:\khabar\models\` |
| **Size** | 2.3 GB |
| **Quantization** | IQ2_M (2-bit integer, very compressed) |
| **Engine** | `llama-cpp-python` |
| **Inference** | CPU-only (no GPU required) |
| **Context Window** | 2048 tokens |
| **Threads** | 4 CPU threads |
| **Response Time** | ~5–15 seconds on modern CPU |
| **RAM Usage** | ~3–4 GB |

---

## Architecture (`agents/local_model.py`)

```
First API call with local_model
          ↓
_load_model() called (thread-safe, once only)
          ↓
  ┌───────────────────────────┐
  │ llama_cpp.Llama(          │
  │   model_path = .gguf,     │
  │   n_ctx = 2048,           │
  │   n_threads = 4,          │
  │   n_gpu_layers = 0        │  ← CPU mode
  │ )                         │
  └───────────────────────────┘
          ↓
Model cached as singleton (_llm)
All future calls reuse same instance
```

### Thread Safety
The module uses a `threading.Lock()` to ensure concurrent agent requests don't corrupt the model state.

### Lazy Loading
The model is **NOT loaded on server startup**. It loads on the **first call** that needs it. This keeps the server startup fast even with a 2.3GB model.

---

## Two Public Functions

### `generate_json(system_prompt, user_prompt)` → `str | None`
Used by `LLMClient` as Tier 2 fallback for the 4-agent pipeline.

- Formats prompt in Gemma instruct style (`<start_of_turn>user ... <end_of_turn>`)
- Instructs model to respond in JSON only
- Extracts and validates JSON from model output using brace counting
- Returns `None` if JSON extraction fails (triggers Tier 3 hardcoded fallback)

```python
result = local_model.generate_json(
    system_prompt="You are the Detection Agent...",
    user_prompt="Input: Nullah Lai flooding at Rawalpindi..."
)
# Returns: '{"incident_type": "URBAN_FLOODING", "priority": "P2", ...}'
```

### `generate_chat_response(message, language, sector)` → `str`
Used by the `/local-chat` API endpoint for offline Flutter chat.

- Generates conversational responses in Urdu, Roman Urdu, or English
- Includes sector context (user's location)
- Falls back to `_keyword_fallback()` if model produces empty output

```python
reply = local_model.generate_chat_response(
    message="flood emergency kya karoon?",
    language="en",
    sector="Faizabad (Rawalpindi)"
)
# Returns: "Flood emergency: Call WASA 1334. Turn off electricity..."
```

### `is_available()` → `bool`
Returns `True` if the GGUF file exists AND `llama-cpp-python` is installed.

---

## Fallback Chain

```
agents/llm_client.py:
  ├── Tier 1: AIML API (3 retries)
  │      ↓ all retries exhausted
  ├── Tier 2: local_model.generate_json()
  │      ↓ returns None (model unavailable)
  └── Tier 3: generate_local_fallback()  ← hardcoded JSON, never fails
```

---

## /local-chat Endpoint

The `/local-chat` endpoint in `api_server.py` exposes the local model for Flutter offline chat:

```
POST /local-chat
Body: { "message": "...", "language": "Roman Urdu", "sector": "G-11 (Islamabad)" }

Response:
{
  "success": true,
  "response": "...",
  "mode": "local_gemma",      ← model was used
  "model": "gemma-4-E2B-it-UD-IQ2_M.gguf"
}
```

**Mode values:**
- `local_gemma` — Gemma GGUF generated the response
- `keyword_fallback` — Model not loaded, used keyword matching
- `error_fallback` — Unexpected error

---

## Flutter Integration (`lib/utils/local_llm_service.dart`)

When `ConnectivityService` detects offline status:

```dart
LocalLlmService().getOfflineResponse(query, language, sector)
    ↓
POST http://10.0.2.2:8000/local-chat  (20-second timeout)
    ↓ [timeout or backend unreachable]
_keywordFallback(query, language, sector)
```

The chat bubble shows a **"🤖 Local Gemma Mode"** or **"📋 Offline Guide"** tag to inform users which mode is active.

---

## Performance Tuning

**CPU (default, no GPU):**
```python
# In agents/local_model.py
_llm = Llama(model_path=MODEL_PATH, n_ctx=2048, n_threads=4, n_gpu_layers=0)
```

**GPU acceleration (optional, requires CUDA):**
```python
# Change n_gpu_layers to enable GPU offloading
_llm = Llama(model_path=MODEL_PATH, n_ctx=2048, n_threads=4, n_gpu_layers=35)
```

| Mode | Response Time | RAM | VRAM |
|---|---|---|---|
| CPU (default) | 5–15 sec | ~3–4 GB | 0 |
| GPU (CUDA) | ~1–3 sec | ~1 GB | ~3 GB |

---

## Installation

```powershell
# Standard (CPU, no special requirements)
pip install llama-cpp-python

# If above fails on Windows (compile error):
pip install llama-cpp-python --prefer-binary

# With CUDA GPU support:
pip install llama-cpp-python --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cu121
```
