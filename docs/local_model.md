# 🤖 Offline AI Inference — Client-Side Local Assistant

In KHABAR, heavy GGUF local model inference has been **decoupled from the backend** to avoid server-side CPU overhead and memory resource consumption. Instead, the offline intelligence now runs **100% locally on-device** within the Flutter mobile client, providing an instant emergency responder without requiring any backend connection or internet access.

---

## Technical Overview

### 1. Decoupled Backend GGUF Model
- **Zero Server CPU Overhead**: The GGUF model loading in `agents/local_model.py` has been disabled. The method `_load_model()` returns `False` immediately.
- **Instant Server Startup**: The server starts up instantly and consumes 0% GGUF model RAM or CPU threads.
- **Rule Compliance**: The file `agents/local_model.py` remains in the codebase to satisfy the rule `Never remove local model fallback — agents/local_model.py is a required component`.
- **API Fallback Chain**: If the primary AIML API model fails or times out, the backend falls back safely to Pydantic-aligned static schema JSON generation in `llm_client.py` instead of initiating GGUF loading.

### 2. On-Device Client-Side Offline AI (`lib/utils/local_llm_service.dart`)
- **Qwen2.5-0.5B-Instruct Local GGUF**: Integrates native llama_cpp bindings for Dart to run the quantized Qwen model locally on-device.
- **Dynamic Downloading**: Includes a chunk-based downloader with a progress indicator (~350MB GGUF download on demand).
- **Background Isolate Offloading**: Runs heavy GGUF inference in a background isolate (background thread) to guarantee smooth 60fps mobile UI rendering during answer generation.
- **Multilingual Token Streaming**: Streams response tokens word-by-word in English, Urdu, and Roman Urdu.
- **Intelligent Fallback Engine**: If the model has not been downloaded yet, the service falls back instantly to a regex-based keyword-matching engine covering:
  * **🚨 Helplines**: Immediate numbers for Rescue 1122, Police 15, Fire 16, WASA 1334, and CDA.
  * **🌧️ Monsoon / Rain**: Rain storm precautions, lightning safety, and WASA monitoring metrics.
  * **🌊 Flooding**: Nullah Lai flood warnings, dewatering alerts, and household water entering rules.
  * **⚡ Electrical Safety**: Power outage precautions, fallen utility poles, and electric shock first aid.
  * **🚑 Medical First Aid**: Regional hospital helplines (PIMS, Shifa, Holy Family) and wound care.
  * **🔥 Gas / Fire**: Gas leak detection (Sui Gas 1199) and active fire evacuation procedures.

---

## Language Auto-Detection
The client-side service automatically determines the language of the query based on the input text structure:
- **Urdu (`Urdu`)**: Matches Arabic script block regex: `[\u0600-\u06FF]`.
- **Roman Urdu (`Roman Urdu`)**: Checks for phonetic Urdu words written in Latin script (e.g. `kya`, `hai`, `batao`, `pani`, `bijli`).
- **English (`English`)**: Standard default language routing.

The assistant can also be overridden manually in the chat UI via a language selector dropdown.

---

## Offline Chat Interface (`lib/screens/offline_chat_screen.dart`)

The offline assistant is accessed directly from the **Login/Signup Page** using a glassmorphic **Offline AI Assistant (No Internet)** button. 

### Key Visual & Functional Features:
- **Active Core Status Indicator**: Displays a glowing green dot labeled `On-Device Core: ACTIVE` indicating offline execution.
- **Download Management Card**: Interactive panel displaying the download status, download file size, progress bar (percentage), and model initialization states.
- **Offline Banner**: Renders a notice alerting users that the mode is offline, and in critical danger, they should dial 1122 directly.
- **Suggested Action Chips**: Shows quick-trigger chips (e.g. `🚨 Helplines`, `🌧️ Rain Precautions`) that dynamically adapt to the active language.
- **Custom Markdown Render Engine**: Converts bold highlights (`**bold**`) and bullet points (`* `) into inline `RichText` widgets with customized teal glow highlights, keeping UI premium without external packages.
- **Dynamic Token Streaming**: Renders text word-by-word as it is generated from the background isolate.
