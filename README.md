# 🚨 KHABAR — Crisis Intelligence & Response Orchestrator (CIRO)
### **Powered by Google Antigravity  |  AISeekho Antigravity Hackathon 2026 (Challenge 3)**

KHABAR (Urdu for *News* or *Awareness*) is a state-of-the-art Agentic AI Crisis Management platform built using the Google Antigravity orchestrator. It automates the detection, analysis, planning, and execution of responses to metropolitan disasters (such as urban flooding, heatwaves, road accidents, and building collapses) in Pakistan.

---

## 🏗️ 1. System Architecture (4-Tier Overview)

```mermaid
graph TD
    subgraph Tier 1: Input (Frontend)
        A[Flutter Mobile App] -->|Report Text/Photo/Voice| B[FastAPI Gateway]
        C[Google News RSS Feed] -->|Pakistan Alerts| A
    end
    
    subgraph Tier 2: API Gateway
        B -->|Orchestrate Pipeline| D[Google Antigravity Core]
        B -->|Background Polling| E[Weather & Traffic Ingestor]
    end

    subgraph Tier 3: AI Core (Antigravity Pipeline)
        D -->|Stage 1| F[Detection Agent]
        F -->|Stage 2| G[Analysis Agent]
        G -->|Stage 3| H[Planning Agent]
        H -->|Stage 4| I[Execution Agent]
        
        H -->|RAG Query| J[(Vector Database - NDMA SOPs)]
    end

    subgraph Tier 4: Execution & Data
        I -->|Tools| K[Google Maps API]
        I -->|Tools| L[Action Simulations]
        I -->|Logs & Tickets| M[(Supabase PostgreSQL - AWS)]
        E -->|Ingest Alerts| B
    end
```

---

## 🤖 2. Google Antigravity 4-Agent Workflow

Our platform orchestrates four specialized agents in a linear workflow, passing structured JSON payloads down the pipeline.

### **Stage 1: Detection Agent**
*   **Role:** Analyzes noisy, informal text (in English, Urdu, Roman Urdu, or Punjabi), transcribed voice audio, or disaster photos to classify the crisis type, GPS coordinates, and assigns confidence score.
*   **Model:** `gemini-3.1-pro-preview-customtools` (Zero-shot text parser) and `gemini-3-pro-image-preview` (Vision-based damage estimator).

### **Stage 2: Analysis Agent**
*   **Role:** Evaluates the severity and determines the impact of the crisis. It calculates stranded vehicles, estimates affected populace, looks up nearby critical infrastructure (via Google Maps), and produces bilingual impact summaries.
*   **Model:** `gemini-3.1-pro-preview-customtools`

### **Stage 3: Planning Agent**
*   **Role:** Formulates a highly prioritized response action plan. It queries the Vector Database for the official **NDMA (National Disaster Management Authority) Pakistan protocols** and checks local resource inventories before proposing dispatches.
*   **Model:** `gemini-3.1-pro-preview-customtools`

### **Stage 4: Execution Agent**
*   **Role:** Directly invokes the corresponding tool integrations to simulate the actions in real-time. It records the complete "Before vs After" system state differences.
*   **Model:** `gemini-3.1-pro-preview-customtools`

---

## 📸 3. Multi-Source Input Pipelines (Voice & Photo)
*   **Voice Reporting:** Citizens can submit raw audio via the mobile app. The audio is sent directly to the `gemini-3.1-flash` native audio API, which accurately transcribes regional languages like Urdu and Punjabi into actionable text.
*   **Photo Verification:** Citizens can snap photos of an emerging crisis. The image is analyzed by `gemini-3.1-pro-vision` to verify the severity (e.g., measuring water levels, structural damage) before being ingested into the pipeline.
*   **Text Processing:** Fully capable of understanding "Roman Urdu" (e.g., *G-10 mein pani bhar gaya hai*) natively through Gemini.

---

## 🛠️ 3. Real-world Agentic Tool Functions

The **Execution Agent** uses Google Antigravity's tool-calling interface to execute these functions:
1.  `query_knowledge_base(question)`: Performs Cosine Similarity Vector Search against NDMA Pakistan SOPs using the **Gemini `text-embedding-004` model**.
2.  `update_traffic_route(incident_id, alt_route)`: Computes alternate routing using Google Maps API and logs original vs. new routes.
3.  `dispatch_rescue_team(team_id, incident_id)`: Generates formal dispatch tickets for Rescue 1122 and WASA teams.
4.  `broadcast_alert(message, location, language)`: Generates and logs delivery counts of simulated localized SMS alerts in Urdu.
5.  `allocate_supplies(type, qty, location)`: Dynamically handles local emergency depots' resource inventory.
6.  `create_emergency_ticket(incident_id, agency)`: Submits NDMA and Traffic Police emergency tickets.
7.  `update_incident_status(incident_id, status)`: Transitions database status logs.

---

## 📊 5. Outcome Visualization & Simulations

To fully satisfy the simulation requirements of the challenge, KHABAR implements deep real-time UI simulations:
*   **Before vs After Impact Panel:** Inside the `IncidentTrackerScreen`, users can see the exact numerical difference in deployed units, rerouted roads, and emergency tickets before and after the Execution Agent completes its plan.
*   **Dynamic Map Route Simulation:** When an incident triggers a traffic reroute, the `MapScreen` actively generates and visualizes mock map routes (a red line for the closed arterial road, and a green dotted corridor for the generated detour) dynamically centered around the incident's GPS coordinates.
*   **System Reasoning Logs:** The complete end-to-end trace logs of all four agents (including their tool calls) are beautifully rendered in the Flutter timeline.

---

## 🔔 6. Real-time Live Notifications (FCM)

KHABAR integrates Firebase Cloud Messaging (FCM) to satisfy the alerting requirement:
*   **In-App Alerts:** When an automated alert tool is executed by the agent, a foreground red warning dialog pops up containing a bilingual summary.
*   **Deep Linking:** Tapping on a background notification instantly routes the user to the `AlertsScreen` to view the comprehensive crisis report.

---

## 📊 7. Real-time Live Web Dashboard

Built with FastAPI and a modern HTML/CSS interface, the **Web Dashboard** (`dashboard_server.py`) features:
*   **Before vs After Comparisons:** Live dynamic state tables showing exact route changes and dispatch confirmations.
*   **Agent Reasonings:** The full Antigravity reasoning logs showing exactly what the agents planned.
*   **Priority Queue:** Real-time visual monitoring of all P1 (Critical) to P5 incidents.
*   **Resource Monitor:** Live counters showing remaining dewatering pumps, rescue units, and medical kits.

---

## 🚀 5. Setup & Run Instructions

Ensure your environment is set up with Python 3.10+ and Flutter.

### **1. Environment Configuration**
Create a `.env` file in the `agents/` directory:
```env
GEMINI_API_KEY=YOUR_GEMINI_API_KEY
GOOGLE_MAPS_API_KEY=YOUR_GOOGLE_MAPS_API_KEY
```

### **2. Install Dependencies**
```bash
pip install -r requirements.txt
```

### **3. Start Python API Gateway Server**
```bash
python api_server.py
```
*Runs on `http://127.0.0.1:8000`*
*(This automatically boots the background weather Open-Meteo & Google Maps traffic ingestion loops).*

### **4. Start Web Dashboard**
```bash
python dashboard_server.py
```
*Open `http://127.0.0.1:8001` in your browser.*

### **5. Run Flutter Mobile App**
Ensure your emulator is running, then run:
```bash
flutter pub get
flutter run
```

---

## 🏆 9. Key Innovations & Highlights
*   **Dual Language Audio Pipeline:** Speech inputs are transcribed directly via **Gemini 2.5 Flash Native Audio** supporting raw voice.
*   **Live Weather Ingestor:** Uses actual, real-time geocoded Open-Meteo forecasts to trigger proactive flood/heatwave emergencies without human input.
*   **Zero-dependency Neural RAG:** The knowledge base uses a lightweight, highly efficient local Vector DB using cosine similarity over real Gemini Embeddings.
*   **Production-grade Supabase Integration:** Dropped all database mocks to establish a real-time, persistent PostgreSQL database hosted on Supabase (AWS Tokyo), fully syncing incidents and resources across client sessions.

---

## 📝 10. Assumptions
1.  **Map Route Simulation:** As LLMs cannot reliably output exact 50+ coordinate polylines for real-world detours, the "mock route generation" visually simulates the detour via an algorithm in the Flutter MapScreen relative to the incident center.
2.  **Resource API:** It is assumed that the global resource API provides near-real-time data; in absence, the system gracefully falls back to a padded baseline to prevent planning failure.
3.  **Human-in-the-Loop:** For demonstration, the system auto-proceeds from P5 to P1. In a production environment, P3-P5 events would require human dispatcher confirmation before proceeding to Execution.
