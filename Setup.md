# 🚀 KHABAR (خبر) — Environment Setup & Installation Guide

This guide walks you through setting up the entire development environment for the **KHABAR (Crisis Intelligence & Response Orchestrator)** platform, including the Python FastAPI backend, the Supabase PostgreSQL cloud database, and the Flutter mobile client.

---

## 📋 1. Prerequisites
Ensure you have the following installed on your local machine:
- **Python 3.10+** (Add to system PATH)
- **Flutter SDK v3.16+** & **Dart SDK**
- **Android Studio** (for emulator) or physical Android device with USB debugging enabled
- **Git**

---

## 🔑 2. Get API Keys & Setup Environment Variables

### **Step 2.1: Create Backend Environment File**
Create a new file named `.env` inside the `agents/` folder:
`f:\khabar\agents\.env`

Populate it with the following configuration:
```env
# Google Gemini Model API Key
GEMINI_API_KEY=your_gemini_api_key_here

# Google Maps Platform Geocoding & Distance APIs
GOOGLE_MAPS_API_KEY=your_google_maps_key_here

# Central Supabase PostgreSQL Database URL
DATABASE_URL=postgresql://postgres.your_project_id:your_db_password@aws-0-us-east-1.pooler.supabase.com:6543/postgres?sslmode=require

# TomTom Traffic Flow API Key (Optional)
TOMTOM_API_KEY=your_tomtom_key_here

# Weather API Key (Optional, Open-Meteo runs free without a key)
OPENWEATHER_API_KEY=your_openweather_key_here
```

### **Step 2.2: Add Firebase Credentials**
Ensure your Firebase Admin service account key JSON file is placed at:
`f:\khabar\agents\khabar-46771-firebase-adminsdk-fbsvc-e3117a9fbb.json`

*(This is used for sending real-time FCM bilingual alerts to your mobile devices).*

---

## 🗄️ 3. Supabase Database Schema Setup
Execute the following SQL queries in your Supabase SQL Editor to initialize the central database tables:

```sql
-- 1. Create Incidents Table
CREATE TABLE IF NOT EXISTS incidents (
    incident_id VARCHAR(255) PRIMARY KEY,
    incident_type VARCHAR(100),
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    priority VARCHAR(10),
    status VARCHAR(50),
    confidence DOUBLE PRECISION,
    location JSONB,
    traces JSONB,
    before_state JSONB,
    after_state JSONB,
    state_diff JSONB,
    public_alerts_sent INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Create Resource Inventory Table
CREATE TABLE IF NOT EXISTS resources (
    resource_id VARCHAR(100) PRIMARY KEY,
    resource_type VARCHAR(100),
    status VARCHAR(50),
    current_location VARCHAR(255),
    assigned_incident VARCHAR(255),
    quantity_available INTEGER,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

---

## 💻 4. Python Backend Configuration

1. **Open a terminal in the root directory:**
   ```powershell
   cd f:\khabar
   ```

2. **Create and activate a virtual environment:**
   ```powershell
   python -m venv venv
   # On Windows:
   .\venv\Scripts\activate
   # On macOS/Linux:
   source venv/bin/activate
   ```

3. **Install python packages:**
   ```powershell
   pip install -r requirements.txt
   ```

4. **Seed database resources (Run once):**
   ```powershell
   python seed_resources.py
   ```

5. **Start the API Server:**
   ```powershell
   python api_server.py
   ```
   *The API gateway runs on `http://127.0.0.1:8000`*

6. **Start the Web Dashboard:**
   *Open a new terminal tab, activate the virtual environment, and run:*
   ```powershell
   python dashboard_server.py
   ```
   *Access the web console at `http://127.0.0.1:8001`*

---

## 📱 5. Flutter Client Mobile App Setup

### **Step 5.1: Configure API Base URL**
Open `lib/api_config.dart` and modify the server URL to point to your backend:
- If running on **Android Emulator**, use: `http://10.0.2.2:8000`
- If running on **Physical Device**, use your PC's local network IP (e.g. `http://192.168.1.100:8000`)

### **Step 5.2: Configure Google Maps SDK Keys**
- **Android:** Paste your Google Maps API Key in `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <meta-data 
      android:name="com.google.android.geo.API_KEY"
      android:value="your_google_maps_key_here"/>
  ```

- **iOS:** Paste your Google Maps API Key in `ios/Runner/AppDelegate.swift`:
  ```swift
  GMSServices.provideAPIKey("your_google_maps_key_here")
  ```

### **Step 5.3: Build & Launch App**
1. Fetch Flutter packages:
   ```bash
   flutter pub get
   ```
2. Run the application:
   ```bash
   flutter run
   ```
3. To compile release APK:
   ```bash
   flutter build apk --release
   ```
