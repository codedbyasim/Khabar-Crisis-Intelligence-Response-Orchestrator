# 🚨 KHABAR (خبر) — Crisis Intelligence & Response Orchestrator (CIRO)
### **Powered by Google Antigravity & Gemini 2.5 Flash | AISeekho Antigravity Hackathon 2026 (Challenge 3)**

---

## 📸 1. Visual System Diagrams

To help you understand the architectural flow, agent orchestration, and Flutter mobile client layout, please refer to the diagrams below:

### **1.1. Overall System Architecture**
![Overall System Architecture](images/Overall%20System.png)

### **1.2. Multi-Agent Antigravity Orchestration Pipeline**
![Multi-Agent Pipeline](images/Agent.png)

### **1.3. Flutter Mobile Client State Flow**
![Flutter Mobile Client](images/Flutter.png)

---

## 📌 2. Problem Statement
Pakistan's major metropolitan cities—such as Karachi, Lahore, Rawalpindi, and Islamabad—face frequent localized crises, including:
*   **Urban Flooding:** Monsoon rains cause severe water accumulation and blockages in main corridors (e.g., Nullah Lai in Rawalpindi, Underpasses in Lahore).
*   **Infrastructure Failures:** Short-circuits, electric power grid trips (K-Electric, WAPDA), gas leaks, and building collapses.
*   **Traffic & Road Accidents:** Critical collisions blocking transit routes, delaying emergency services.
*   **Heatwaves:** High-temperature weather hazards endangering public health.

**The core challenges in existing emergency responses are:**
1.  **Noisy & Informal Inputs:** Citizens report incidents using mixed languages (English, Urdu, Roman Urdu, Punjabi) containing slang, spelling errors, and emotional text.
2.  **Lack of Authentication:** High volume of fake reports, casual greetings, or general weather observations block the dispatcher queue.
3.  **Fragmented Resource Dispatch:** Rescue units, WASA, Traffic Police, and Power departments operate in silos, causing delays.
4.  **No Before/After Simulation:** Lack of predictive analysis or detour planning to minimize subsequent congestion.

---

## 💡 3. The KHABAR Solution
**KHABAR** (meaning *News* or *Awareness* in Urdu) is an Agentic AI solution that addresses this problem by serving as a unified **Crisis Intelligence & Response Orchestrator (CIRO)**. 

By leveraging **Google Antigravity** as the orchestrator core and **Gemini 2.5 Flash** as the reasoning engine, it transforms noisy, raw citizen signals into automated, verified, and simulated emergency response pipelines.

```
[Citizen Signal (Text/Voice/Photo)] ➔ [Verification Gate] ➔ [Antigravity Pipeline] ➔ [Simulated Dispatches & Alerts]
```

---

## 🤖 4. The Multi-Agent Pipeline (Google Antigravity Core)
The coordination pipeline consists of **four distinct stages** sharing a single `SharedMemoryBlock`:

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│ Detection Agent │ ➔  │ Analysis Agent  │ ➔  │ Planning Agent  │ ➔  │ Execution Agent │
└─────────────────┘      └─────────────────┘      └─────────────────┘      └─────────────────┘
```

### **4.1. Detection Agent (`detection_agent.py`)**
*   **Purpose:** Classify the crisis type, extract GPS coordinates, assign priority (`P1` to `P5`), and estimate parsing confidence.
*   **Verification & Spam Filtering:** Implements the required safety gating. If the input is conversational (e.g. *"hi"*, *"test"*, *"main biryani kha rha hoon"*), or if the weather report contradicts current live Open-Meteo readings (e.g., claiming flooding when live weather shows 0mm precipitation), the agent flags it:
    *   `is_verified = False`
    *   `verification_reason = "Spam or weather anomaly detected."`
*   **Pipeline Halting:** The orchestrator aborts execution instantly on unverified reports, logging `REJECTED` in the database to prevent API billing wastage.

### **4.2. Analysis Agent (`analysis_agent.py`)**
*   **Purpose:** Reason about the real-world impact.
*   **Metrics Estimated:** Stranded vehicles, affected population density, and coordinates of nearby critical infrastructures (e.g., Mayo Hospital, PIMS, K-Electric grid stations).
*   **Outputs:** Bilingual summaries in Romanized Urdu and English.

### **4.3. Planning Agent (`planning_agent.py`)**
*   **Purpose:** Draft a Coordinated Action Plan.
*   **RAG Vector Lookup:** Performs cosine similarity lookup on **NDMA Pakistan SOPs** (stored as vector embeddings in our knowledge base) to fetch standard protocols.
*   **Resource Inventory Check:** Queries the Supabase PostgreSQL database to check available quantities of ambulances, fire trucks, dewatering pumps, and police units before making resource recommendations.

### **4.4. Execution Agent (`execution_agent.py`)**
*   **Purpose:** Trigger registered tools to resolve the incident and log before/after states.
*   **Antigravity SDK Tools Executed:**
    1.  `DispatchRescueTeam`: Reserves database resources and calculates ETAs.
    2.  `UpdateTrafficRoute`: Sets up alternate detour routes (represented as coordinate polyline arrays).
    3.  `BroadcastAlert`: Dispatches real-time, bilingual Firebase Push Notifications (FCM) to all registered citizen mobile apps.
    4.  `UpdateIncidentStatus`: Finalizes status updates from `PROCESSING` to `PIPELINE_COMPLETE`.

---

## 📱 5. Flutter Mobile App (Client Experience)

The mobile client is built using Flutter, offering a dark-themed premium design system:

*   **Real-Time Geolocation Tracking:** Automatically queries device GPS using the `geolocator` plugin on startup to center the map.
*   **Text Signal Entry Screen:** Allows typing in Urdu/English/Roman Urdu, features a draggable Google Map marker, and dynamically updates language confidence.
*   **Multimodal Photo Verification:** Allows capturing photos via the native camera. Includes a **text details input field** to add custom descriptions alongside images before submitting them to Gemini Vision.
*   **Multimodal Voice Report Screen:** Bypasses basic Whisper APIs. Processes voice recordings using the **Gemini Native Audio API** to support Urdu and regional dialects, and allows **attaching photos** directly to the audio report.
*   **Map Interface:** Renders active emergencies, resource coordinates, and visual detour routes (polylines) around the crisis centers.
*   **Interactive Timeline & Outcome Viewer:** Shows the before/after state changes side-by-side alongside real-time trace logs from the active Antigravity agents.

---

## 💻 6. API Reference & Payload Schemas

### **6.1. Submit Text Report (`POST /report/text`)**
*   **Payload (JSON):**
    ```json
    {
      "content": "Nullah Lai is overflowing, water is coming onto Murree Road Rawalpindi!",
      "lat": 33.6375,
      "lng": 73.0784
    }
    ```
*   **Response (JSON):**
    ```json
    {
      "success": true,
      "incident_id": "SIG-1716223400-TXT",
      "status": "PROCESSING",
      "poll_url": "/incident/SIG-1716223400-TXT"
    }
    ```

### **6.2. Submit Photo Verification (`POST /report/image`)**
*   **Payload (Multipart Form-Data):**
    *   `image`: binary (JPEG/PNG)
    *   `description`: "Water logging in G-10 Markaz Islamabad"
    *   `lat`: 33.6844
    *   `lng`: 73.0479
*   **Response (JSON):**
    ```json
    {
      "success": true,
      "incident_id": "SIG-1716223410-IMG",
      "status": "PROCESSING",
      "vision_analysis": {
        "crisis_type": "urban_flooding",
        "severity": "HIGH",
        "priority": "P2",
        "confidence": 0.95,
        "description": "Flooding of roadway with multiple partially submerged passenger cars."
      }
    }
    ```

### **6.3. Submit Voice Report with Photo (`POST /report/voice`)**
*   **Payload (Multipart Form-Data):**
    *   `audio`: binary (M4A/WAV)
    *   `image`: binary (Optional attached JPEG/PNG)
    *   `lat`: 33.6844
    *   `lng`: 73.0479
*   **Response (JSON):**
    ```json
    {
      "success": true,
      "incident_id": "SIG-1716223420-VOI",
      "status": "PROCESSING",
      "speech_analysis": {
        "detected_language": "Urdu",
        "transcription_original": "گاڑیاں ڈوب رہی ہیں اور راستہ بند ہے",
        "transcription_english": "Cars are sinking and the road is blocked."
      }
    }
    ```

---

## 💾 7. Database Tables (Supabase DDL)

To setup the application, create the following core relational schemas in your PostgreSQL database:

```sql
-- Core Incidents Table
CREATE TABLE incidents (
    incident_id VARCHAR(50) PRIMARY KEY,
    title VARCHAR(150),
    description TEXT,
    status VARCHAR(50) DEFAULT 'PROCESSING',
    priority VARCHAR(10) DEFAULT 'P3',
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    source VARCHAR(50),
    before_state JSONB,
    after_state JSONB,
    speech_analysis JSONB,
    vision_analysis JSONB,
    traces TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Resource Inventory Table
CREATE TABLE resources (
    resource_id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    type VARCHAR(50) NOT NULL, -- e.g. ambulance, dewatering_pump, fire_truck, rescue_team
    quantity INTEGER DEFAULT 1,
    status VARCHAR(50) DEFAULT 'available',
    location JSONB -- Contains {"lat": float, "lng": float}
);
```

---

## 🛠️ 8. Technology Stack
KHABAR integrates modern cloud services and robust engineering frameworks:

*   **Core Logic & Orchestration:** Python, Google Antigravity SDK, FastAPI
*   **Mobile Client:** Flutter, Dart, Google Maps SDK, Camera SDK, Audio Recorder
*   **Reasoning LLM APIs:** Gemini 2.5 Flash (Text, Vision, Speech Native APIs)
*   **Cloud Database:** Supabase Cloud PostgreSQL (relational storage for incidents & resource inventories)
*   **Alert Services:** Firebase Cloud Messaging (OAuth2 secure FCM notifications API)
*   **Real-time External APIs:** Open-Meteo Weather API, TomTom Traffic Flow API, OpenStreetMap Geocoding

---

## 📂 9. External Configuration & Auditing References
For details on system setup or compliance status, refer to these workspace documents:

*   **[Environment Setup & DB Schemas (Setup.md)](file:///f:/khabar/Setup.md):** Complete installation guide, database queries, and env configuration variables.
*   **[SRS Compliance Audit Report (ciro_audit_report.md)](file:///C:/Users/HCC/.gemini/antigravity/brain/1b8b626a-eb69-46d4-8557-25cd92d7cdca/ciro_audit_report.md):** Analysis of the implementation coverage against all requirements.
*   **[Hackathon Master Audit Key (challenge_compliance_master_key.md)](file:///C:/Users/HCC/.gemini/antigravity/brain/1b8b626a-eb69-46d4-8557-25cd92d7cdca/challenge_compliance_master_key.md):** Compliance master matrix reviewing each evaluation metric.

---

## 📝 10. Core Platform Assumptions
1.  **Map Corridor Simulations:** Due to API quota limits and routing complexities of rendering live routes via Google Maps, the detour corridor is visually simulated in the Flutter `MapScreen` using coordinate boundaries relative to the incident center.
2.  **Emergency Dispatch Capacity:** The system assumes a baseline resource capacity (WASA, Rescue 1122, K-Electric) in the database. In case of resource exhaustion, the Planning Agent automatically escalates incidents to `STANDBY` until units are released by the dispatcher.
3.  **Human-in-the-Loop Override:** While the pipeline is designed to be fully autonomous, P3-P5 priority events in production would require manual dispatcher confirmation before the Execution Agent triggers actual tool dispatches.
