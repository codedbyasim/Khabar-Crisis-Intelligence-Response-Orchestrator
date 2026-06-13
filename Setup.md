# 🚀 KHABAR (خبر) — Setup & Installation Guide

Complete setup guide for the **KHABAR Crisis Intelligence & Response Orchestrator** platform.  
Covers: Python FastAPI backend, Local Gemma GGUF model, Supabase database, and Flutter mobile client.

---

## 📋 1. Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| Python | 3.10+ | Add to system PATH |
| Flutter SDK | 3.16+ | With Dart SDK |
| Android Studio | Latest | For Android Emulator |
| Git | Any | |
| RAM | 8 GB+ | Local Gemma model needs ~3–4 GB |

---

## 🔑 2. API Keys & Environment Setup

### **Step 2.1 — Create Backend `.env` File**
Create `h:\khabar\agents\.env` with the following content:

```env
# ── PRIMARY AI API ──
# AIML API key (get from: https://aimlapi.com)
AIML_API_KEY=your_aiml_api_key_here

# ── MAPS ──
# Google Maps Platform — Geocoding, Distance Matrix, Places APIs
GOOGLE_MAPS_API_KEY=your_google_maps_key_here

# ── DATABASE ──
# Supabase PostgreSQL connection string
DATABASE_URL=postgresql://postgres.your_project_id:your_password@aws-0-us-east-1.pooler.supabase.com:6543/postgres?sslmode=require

# ── EXTERNAL FEEDS (Optional) ──
TOMTOM_API_KEY=your_tomtom_key_here         # Traffic flow data
OPENWEATHER_API_KEY=your_openweather_key_here  # Weather alerts
SERPAPI_KEY=your_serpapi_key_here            # Google News live feed
```

> **Note:** `GEMINI_API_KEY` is NO LONGER used. Project now uses `AIML_API_KEY`.

### **Step 2.2 — Add Firebase Credentials**
Place your Firebase Admin service account JSON at:
```
h:\khabar\agents\khabar-46771-firebase-adminsdk-fbsvc-e3117a9fbb.json
```
*(Firebase Console → Project Settings → Service Accounts → Generate new private key)*

---

## 🗄️ 3. Supabase Database Setup

Run these SQL queries in your **Supabase SQL Editor**:

```sql
-- 1. Incidents Table
CREATE TABLE IF NOT EXISTS incidents (
    incident_id        VARCHAR(255) PRIMARY KEY,
    incident_type      VARCHAR(100),
    lat                DOUBLE PRECISION,
    lng                DOUBLE PRECISION,
    priority           VARCHAR(10),
    status             VARCHAR(50),
    confidence         DOUBLE PRECISION,
    location           JSONB,
    traces             JSONB,
    before_state       JSONB,
    after_state        JSONB,
    state_diff         JSONB,
    public_alerts_sent INTEGER DEFAULT 0,
    created_at         TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Resource Inventory Table
CREATE TABLE IF NOT EXISTS resources (
    resource_id        VARCHAR(100) PRIMARY KEY,
    name               VARCHAR(150) NOT NULL,
    type               VARCHAR(50)  NOT NULL,
    quantity           INTEGER DEFAULT 1,
    status             VARCHAR(50)  DEFAULT 'available',
    location           JSONB
);
```

---

## 💻 4. Python Backend Setup

```powershell
# Step 1 — Go to project root
cd h:\khabar

# Step 2 — Create virtual environment
python -m venv venv
.\venv\Scripts\activate   # Windows

# Step 3 — Install all dependencies
pip install -r requirements.txt

# Step 4 — Install Local Gemma model support (first time only)
# Note: This may take 5–10 mins to compile on Windows
pip install llama-cpp-python

# Step 5 — Seed database resources (run ONCE)
python seed_resources.py

# Step 6 — Start the API Server
$env:PYTHONIOENCODING="utf-8"
python api_server.py
```

✅ Backend will start at: `http://127.0.0.1:8000`  
📖 Swagger Docs at: `http://127.0.0.1:8000/docs`

### **Optional: Start Web Dashboard**
```powershell
# New terminal (venv activated)
python dashboard_server.py
```
📊 Dashboard at: `http://127.0.0.1:8001`

---

## 🤖 5. Local Gemma Model Setup

The local model provides **offline AI fallback** when AIML API is unavailable.

**Model location:**
```
h:\khabar\models\gemma-4-E2B-it-UD-IQ2_M.gguf   (2.3 GB)
```

The model **loads automatically** on first use (lazy loading). No extra setup needed — just keep the `.gguf` file in the `models/` folder.

**Verify the model is working:**
```powershell
# With backend running, test the offline chat endpoint:
Invoke-RestMethod `
  -Uri "http://127.0.0.1:8000/local-chat" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"message":"flood emergency", "language":"English", "sector":"G-10 Islamabad"}'
```

Expected response:
```json
{
  "success": true,
  "response": "...",
  "mode": "local_gemma",
  "model": "gemma-4-E2B-it-UD-IQ2_M.gguf"
}
```

---

## 📱 6. Flutter Mobile App Setup

### **Step 6.1 — Install Dependencies**
```bash
cd h:\khabar
flutter pub get
```

### **Step 6.2 — Configure API URL**
Open [`lib/api_config.dart`](lib/api_config.dart). The URL is now **automatically detected**:
- **Web (Chrome):** `http://127.0.0.1:8000` ← auto
- **Android Emulator:** `http://10.0.2.2:8000` ← auto
- **Physical Device:** Edit the file manually to your PC's local IP (e.g. `http://192.168.1.100:8000`)

### **Step 6.3 — Configure Google Maps Key**

**Android** — Edit `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="your_google_maps_key_here"/>
```

**iOS** — Edit `ios/Runner/AppDelegate.swift`:
```swift
GMSServices.provideAPIKey("your_google_maps_key_here")
```

### **Step 6.4 — Run the App**
```bash
flutter run -d chrome     # Web browser (recommended for quick test)
flutter run               # Android Emulator or connected device
flutter build apk --release  # Build release APK
```

---

## 🔄 7. Full System Startup (Quick Reference)

```powershell
# Terminal 1 — Backend
cd h:\khabar
.\venv\Scripts\activate
$env:PYTHONIOENCODING="utf-8"
python api_server.py

# Terminal 2 — Flutter App
cd h:\khabar
flutter run -d chrome

# Terminal 3 — Web Dashboard (optional)
cd h:\khabar
.\venv\Scripts\activate
python dashboard_server.py
```

---

## 🧩 8. Requirements Reference (`requirements.txt`)

| Package | Purpose |
|---|---|
| `fastapi` | REST API framework |
| `uvicorn` | ASGI server |
| `pydantic` | Data validation (v2) |
| `openai` | AIML API client (OpenAI-compatible) |
| `llama-cpp-python` | Local Gemma GGUF inference (CPU) |
| `psycopg2-binary` | Supabase PostgreSQL connector |
| `firebase-admin` | FCM push notifications |
| `httpx` | Async HTTP client |
| `python-dotenv` | `.env` file loading |
| `python-multipart` | File upload support |
| `google-search-results` | SerpAPI news feed |

---

## 🐛 9. Common Issues & Fixes

| Problem | Solution |
|---|---|
| `UnicodeEncodeError` on Windows | Run `$env:PYTHONIOENCODING="utf-8"` before `python api_server.py` |
| `llama-cpp-python` compile error | Use: `pip install llama-cpp-python --prefer-binary` |
| Flutter web CORS error | Ensure `allow_origins=["*"]` is set in `api_server.py` (already done) |
| Android Emulator can't connect | Backend must be on `10.0.2.2:8000` — `api_config.dart` handles this automatically |
| Local model slow (~10–15 sec) | Normal for CPU mode. GPU: set `n_gpu_layers=35` in `agents/local_model.py` |
| `DATABASE_URL` not set | Create `agents/.env` file with your Supabase connection string |
