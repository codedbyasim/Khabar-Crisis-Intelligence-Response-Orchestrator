# 🚨 KHABAR (خبر) — Crisis Intelligence & Response Orchestrator (CIRO)
### **Powered by CrewAI & Gemini 2.5 Flash | AISeekho Hackathon 2026**

---

## 📸 1. Visual System Diagrams

To help you understand the architectural flow, agent orchestration, and Flutter mobile client layout, please refer to the diagrams below:

### **1.1. Overall System Architecture**
![Overall System Architecture](images/Overall%20System.png)

### **1.2. Multi-Agent CrewAI Orchestration Pipeline**
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

By leveraging **CrewAI** as the orchestration framework and **Gemini 2.5 Flash** (via AIML API OpenAI compatibility / native GenAI SDK) as the reasoning engine, it transforms noisy, raw citizen signals into automated, verified, and simulated emergency response pipelines.

```
[Citizen Signal (Text/Voice/Photo)] ➔ [Verification Gate] ➔ [CrewAI Sequence] ➔ [Simulated Dispatches & Alerts]
```

---

## 🤖 4. The Multi-Agent Pipeline (CrewAI Sequential Core)
The coordination pipeline consists of **four distinct agents** running sequentially inside a `Crew` managed by `Process.sequential` with shared task contexts:

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│ Detection Agent │ ➔  │ Analysis Agent  │ ➔  │ Planning Agent  │ ➔  │ Execution Agent │
└─────────────────┘      └─────────────────┘      └─────────────────┘      └─────────────────┘
```

### **4.1. Detection Agent (`crew_agents.py` / `crew_tasks.py`)**
*   **Purpose:** Classify the crisis type, extract GPS coordinates, assign priority (`P1` to `P5`), and estimate parsing confidence.
*   **Verification & Spam Filtering:** Implements the required safety gating. Uses the `WeatherValidationTool` (live Open-Meteo data) to cross-verify weather reports. If the input is conversational (e.g. *"hi"*, *"test"*), or if the weather reports contradict sensors (e.g., claiming flooding when live rain shows 0.0mm), the agent flags it:
    *   `is_verified = False`
    *   `verification_reason = "Spam or weather anomaly detected."`
*   **Pipeline Halting:** The orchestrator aborts execution instantly on unverified reports, logging `REJECTED` in the database to prevent API billing wastage.

### **4.2. Impact Analysis Agent (`crew_agents.py` / `crew_tasks.py`)**
*   **Purpose:** Reason about the real-world impact.
*   **Metrics Estimated:** Stranded vehicles, affected population density, and coordinates of nearby critical infrastructures (e.g., Mayo Hospital, PIMS, power grids) using the custom `MapsContextTool`.
*   **Outputs:** Bilingual summaries in Romanized Urdu and English.

### **4.3. Response Planning Agent (`crew_agents.py` / `crew_tasks.py`)**
*   **Purpose:** Draft a Coordinated Action Plan.
*   **RAG Vector Lookup:** Performs cosine similarity lookup via `QueryKnowledgeBaseTool` using `gemini-embedding-2` on **NDMA Pakistan SOPs** to fetch standard protocols.
*   **Resource Inventory Check:** Queries the database using the `ResourceInventoryTool` to check available quantities of ambulances, fire trucks, dewatering pumps, and police units before making resource recommendations.

### **4.4. Response Execution Agent (`crew_agents.py` / `crew_tasks.py`)**
*   **Purpose:** Trigger registered tools to resolve the incident and log before/after states.
*   **CrewAI Tools Executed:**
    1.  `DispatchRescueTeamTool`: Reserves database resources and calculates ETAs.
    2.  `AllocateSuppliesTool`: Allocates physical rescue resources (e.g. pumps, kits).
    3.  `UpdateTrafficRouteTool`: Sets up alternate detour routes (closed roads/detours).
    4.  `BroadcastAlertTool`: Dispatches real-time, bilingual Firebase Push Notifications (FCM) via the `AlertService` to all registered citizen mobile apps.
    5.  `UpdateIncidentStatusTool`: Finalizes status updates from `PROCESSING` to `PIPELINE_COMPLETE`.

---

## 📱 5. Flutter Mobile App (Client Experience)

The mobile client is built using Flutter, offering a dark-themed premium design system:

*   **Real-Time Geolocation Tracking:** Automatically queries device GPS using the `geolocator` plugin on startup to center the map.
*   **Text Signal Entry Screen:** Allows typing in Urdu/English/Roman Urdu, features a draggable Google Map marker, and dynamically updates language confidence.
*   **Multimodal Photo Verification:** Allows capturing photos via the native camera. Includes a **text details input field** to add custom descriptions alongside images before submitting them to Gemini Vision.
*   **Multimodal Voice Report Screen:** Bypasses basic Whisper APIs. Processes voice recordings using the **Gemini Native Audio API** to support Urdu and regional dialects, and allows **attaching photos** directly to the audio report.
*   **Map Interface:** Renders active emergencies, resource coordinates, and visual detour routes (polylines) around the crisis centers.
*   **Interactive Timeline & Outcome Viewer:** Shows the before/after state changes side-by-side alongside real-time trace logs from the active CrewAI agents.

---

## 💻 6. API Reference & Payload Schemas

### **6.1. Submit Text Report (`POST /report/text`)**
*   **Payload (JSON):**
    ```json
    {
      "text": "Nullah Lai is overflowing, water is coming onto Murree Road Rawalpindi!",
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

-- Resource Inventory Table
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

## 🛠️ 8. Technology Stack
KHABAR integrates modern cloud services and robust engineering frameworks:

*   **Core Logic & Orchestration:** Python, CrewAI framework, LiteLLM, FastAPI
*   **Package Management:** `uv` (ultra-fast Python dependency resolver)
*   **Mobile Client:** Flutter, Dart, Google Maps SDK, Camera SDK, Audio Recorder
*   **Reasoning LLM APIs:** Gemini 2.5 Flash (via AIML API OpenAI interface + Google GenAI SDK)
*   **Cloud Database:** Supabase Cloud PostgreSQL (relational storage for incidents & resources)
*   **Alert Services:** Firebase Cloud Messaging (OAuth2 secure FCM notifications API)
*   **Real-time External APIs:** Open-Meteo Weather API, TomTom Traffic Flow API, OpenStreetMap Geocoding

---

## 📂 9. External Configuration & References
For details on system setup or compliance status, refer to these workspace documents:

*   **[Environment Setup & DB Schemas (Setup.md)](Setup.md):** Complete installation guide, database queries, and env configuration variables.
