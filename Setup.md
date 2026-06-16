# 🚀 KHABAR (خبر) — Setup & Installation Guide

Complete step-by-step setup guide for the **KHABAR Crisis Intelligence & Response Orchestrator** platform.  
Covers: Python FastAPI backend, database migrations, React web dashboard, and Flutter mobile client on a new device.

---

## 📋 1. Prerequisites

Aap ke naye PC ya device par neeche di gayi requirements aur tool installations honi chahiye:

| Tool / Requirement | Version | Link / Notes |
|---|---|---|
| **Python** | 3.10+ | [python.org/downloads](https://www.python.org/downloads/) (Tick "Add Python to PATH" during install) |
| **Flutter SDK** | 3.16+ | [flutter.dev](https://docs.flutter.dev/get-started/install) (Must run `flutter doctor` to verify) |
| **Node.js & NPM** | LTS version | [nodejs.org](https://nodejs.org/) (Needed for React Web Dashboard packages) |
| **Android Studio** | Latest | [developer.android.com/studio](https://developer.android.com/studio) (Set up Android SDK & Emulator) |
| **Git** | Any | [git-scm.com](https://git-scm.com/) |
| **RAM** | 4 GB+ | Bypassed server-side GGUF limits keep backend memory overhead minimal |

---

## 🔑 2. API Keys & Environment Setup

### **Step 2.1 — Create Backend `.env` File**
Create a new file at `h:\khabar\agents\.env` containing the following environment configuration:

```env
# ── PRIMARY AI API ──
# AIML API key (get from: https://aimlapi.com)
AIML_API_KEY=your_aiml_api_key_here

# ── MAPS ──
# Google Maps Platform — Geocoding, Distance Matrix, Places APIs
GOOGLE_MAPS_API_KEY=your_google_maps_key_here

# ── DATABASE ──
# Supabase PostgreSQL connection URI string
DATABASE_URL=postgresql://postgres.your_project_id:your_password@aws-0-us-east-1.pooler.supabase.com:6543/postgres?sslmode=require
```

> **Note:** `GEMINI_API_KEY` is no longer used by the system. All backend models (Gemini 2.5 Flash, GPT-4o-Mini, Llama 3 8B) use `AIML_API_KEY` through the multi-model resilience client.

### **Step 2.2 — Add Firebase Credentials (Push Alerts)**
1. Go to [Firebase Console](https://console.firebase.google.com).
2. Open project `khabar-46771` (or your custom project).
3. Navigate to **Project Settings → Service Accounts → Generate new private key**.
4. Download the generated JSON credential file, rename it to exactly `khabar-46771-firebase-adminsdk-fbsvc-e3117a9fbb.json`, and place it at:
   ```
   h:\khabar\agents\khabar-46771-firebase-adminsdk-fbsvc-e3117a9fbb.json
   ```

---

## 🗄️ 3. Supabase Database Setup

Navigate to your **Supabase Project → SQL Editor** and execute the following SQL script to create the required tables:

```sql
-- 1. Users Accounts Table
CREATE TABLE IF NOT EXISTS users (
    user_id        VARCHAR(255) PRIMARY KEY,
    email          VARCHAR(255) UNIQUE NOT NULL,
    password_hash  VARCHAR(255) NOT NULL,
    name           VARCHAR(255) NOT NULL,
    region         VARCHAR(255) NOT NULL,
    created_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Core Incidents Table
CREATE TABLE IF NOT EXISTS incidents (
    incident_id    VARCHAR(255) PRIMARY KEY,
    incident_type  VARCHAR(100),
    lat            DOUBLE PRECISION,
    lng            DOUBLE PRECISION,
    priority       VARCHAR(10),
    status         VARCHAR(50),
    confidence     DOUBLE PRECISION,
    location       JSONB,
    traces         JSONB,
    before_state   JSONB,
    after_state    JSONB,
    state_diff     JSONB,
    public_alerts_sent INTEGER DEFAULT 0,
    user_id        VARCHAR(255),  -- Links to users table
    created_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Resource Inventory Table
CREATE TABLE IF NOT EXISTS resources (
    resource_id        VARCHAR(100) PRIMARY KEY,
    name               VARCHAR(150) NOT NULL,
    type               VARCHAR(50)  NOT NULL,    -- ambulance | fire_truck | rescue_team | dewatering_pump
    quantity           INTEGER DEFAULT 1,
    status             VARCHAR(50)  DEFAULT 'available',
    location           JSONB,                    -- {"lat": float, "lng": float}
    assigned_incident  VARCHAR(255)              -- links to active incident ID
);
```

---

## 💻 4. Python Backend Setup

Run the following commands in your terminal to initialize the backend system:

```powershell
# Step 1 — Navigate to project root
cd h:\khabar

# Step 2 — Create python virtual environment
python -m venv venv

# Step 3 — Activate the virtual environment
.\venv\Scripts\activate

# Step 4 — Install dependencies
pip install -r requirements.txt

# Step 5 — Seed the database resources (Run ONCE to populate inventory)
python seed_resources.py

# Step 6 — Set Python Console Encodings for Windows (avoids Urdu print crashes)
$env:PYTHONIOENCODING="utf-8"

# Step 7 — Run the FastAPI server
python api_server.py
```

✅ **API Backend Server running at:** `http://127.0.0.1:8000`  
📖 **Swagger Interactive Docs at:** `http://127.0.0.1:8000/docs`

---

## 🤖 5. Client-Side Offline AI Assistant

For 100% offline capability when network connection or backend services are unavailable, the mobile client includes a dedicated **Offline AI Assistant** accessible directly from the Login/Signup screen.

- **Zero Server Overhead**: The backend GGUF model (`llama-cpp-python` inference) is decoupled/bypassed at runtime on the server to prevent RAM/CPU saturation.
- **On-Device Execution**: The offline assistant runs 100% locally in Dart code within the mobile client, requiring zero server connection.
- **Language & Regex Processing**: Utilizes regex-based keyword parsing to handle English, Urdu script, and Roman Urdu inputs, returning tailored emergency hotline details and Pakistan NDMA standard safety guidelines.

---

## 🖥️ 6. React Web Dashboard Setup

The React command center dashboard runs on Port `8001` or `5173` and can be launched in two ways:

### **Method A: React Vite Development Mode (Recommended)**
Use this mode when you want to run or test UI modifications:
```powershell
# Open a new terminal
cd h:\khabar\dashboard

# Install React dependencies
npm install

# Run the dev server
npm run dev
```
📊 **Vite Dev Server running at:** `http://127.0.0.1:5173`

### **Method B: Served Pre-built Static Version (Simpler & faster)**
Serve the pre-built files instantly without dev packages:
```powershell
# In a terminal with active python venv
cd h:\khabar
python dashboard_server.py
```
📊 **Static Server running at:** `http://127.0.0.1:8001`

---

## 📱 7. Flutter Mobile App Setup

### **Step 7.1 — Fetch Dependencies**
```powershell
cd h:\khabar
flutter pub get
```

### **Step 7.2 — API Address Configuration (`api_config.dart`)**
Open `lib/api_config.dart`. Connection URLs are automatically resolved:
- **Chrome Web:** `http://127.0.0.1:8000`
- **Android Emulator:** `http://10.0.2.2:8000`
- **Physical Device:** Change the URL manually to match your computer's local network IP address (e.g., `http://192.168.1.100:8000`) and ensure both devices share the same Wi-Fi connection.

### **Step 7.3 — Google Maps Key Binding**

**Android:** Open [android/app/src/main/AndroidManifest.xml](file:///h:/khabar/android/app/src/main/AndroidManifest.xml) and add/verify the API key metadata tag inside the `<application>` node:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="your_google_maps_key_here"/>
```

**iOS:** Open [ios/Runner/AppDelegate.swift](file:///h:/khabar/ios/Runner/AppDelegate.swift) and set the API key:
```swift
GMSServices.provideAPIKey("your_google_maps_key_here")
```

### **Step 7.4 — Run/Build Mobile App**
```powershell
# Run in Chrome web browser (fastest check):
flutter run -d chrome

# Run on connected emulator or physical phone:
flutter run

# Build release APK file:
flutter build apk --release
```

---

## 🔄 8. Full Startup Checklist (Quick Reference)

Run these three services in separate terminals to launch the entire environment:

```powershell
# Terminal 1 — FastAPI Server (Backend)
cd h:\khabar
.\venv\Scripts\activate
$env:PYTHONIOENCODING="utf-8"
python api_server.py

# Terminal 2 — React Dashboard (Web Command Center)
cd h:\khabar\dashboard
npm run dev

# Terminal 3 — Flutter Mobile App (Citizen Client)
cd h:\khabar
flutter run -d chrome
```

---

## 🧩 9. Package Dependencies Reference

| Package | Category | Purpose |
|---|---|---|
| `fastapi` | Backend | API server framework |
| `uvicorn` | Backend | ASGI server execution |
| `pydantic` | Backend | Schema structure & validation (v2) |
| `openai` | Backend | AIML API client calls |
| `psycopg2-binary`| Backend | Supabase PostgreSQL client connection |
| `firebase-admin` | Backend | FCM push alert dispatch |
| `httpx` | Backend | Async HTTP call requests |
| `llama-cpp-python` | Backend | Kept for rule compliance (Execution decoupled) |

---

## 🐛 10. Common Troubleshooting & Fixes

| Issue / Error | Cause | Solution / Fix |
|---|---|---|
| `UnicodeEncodeError` on Windows | Default Windows console is not UTF-8 | Run `$env:PYTHONIOENCODING="utf-8"` in PowerShell prior to starting `api_server.py` |
| `llama-cpp-python` compile failure | Missing C++ compilers on Windows | Install using binary flags: `pip install llama-cpp-python --prefer-binary` (Note: bypassed at server runtime) |
| Flutter CORS Block | Browser blocking headers on localhost | FastAPI has `allow_origins=["*"]` configured to automatically permit local cross-origin connections |
| Database connection error | `DATABASE_URL` settings incorrect | Double-check that your Supabase connection string is correctly defined in `agents/.env` |
| Emulator connection refused | Hardcoded `127.0.0.1` used on phone | Emulator requires `10.0.2.2` instead of `localhost`. The `api_config.dart` file resolves this automatically |
