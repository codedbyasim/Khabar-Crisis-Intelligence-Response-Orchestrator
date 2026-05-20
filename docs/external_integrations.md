# 🔌 External API & System Integrations

KHABAR binds core local services, open mapping APIs, and database structures to create a robust and reliable environment.

---

## ☁️ 1. Supabase PostgreSQL Database
Unlike static mock systems, KHABAR relies on a secure cloud-hosted PostgreSQL database on AWS through the Supabase interface.
*   **Purpose:** Persistently syncs incidents, active dispatches, resource inventory, and alert logs.
*   **Integration File:** `agents/firestore_db.py` contains the CRUD connectors. It maps SQL rows to unstructured JSON dictionaries matching the Pydantic state schemas.
*   **Tables Sync:**
    - `incidents`: Main list of reported disasters, traces, before/after states, and location coordinates.
    - `resources`: Live counts of available ambulances, rescue teams, and utility crews.
    - `alerts`: Public warnings sent via the system.

---

## 🗺️ 2. Google Maps API
Visualizing coordinates is necessary for emergency logistics.
*   **Geocoding:** Handles landmark name extraction and places pins on the precise coordinates of the reported incident.
*   **Mobile Map Render (`lib/screens/map_screen.dart`):**
    - Uses the standard `google_maps_flutter` package.
    - Features customized dark-mode map styles.
    - Programmatically draws closed-road segments and alternate detours using Polylines calculated by the planning agent.

---

## 🌦️ 3. Open-Meteo Weather Ingestion
*   **Purpose:** Periodically queries the public Open-Meteo API to fetch local temperature, windspeed, and precipitation forecasts.
*   **Trigger:** If precipitation exceeds 50mm/hour or temperature hits a heatwave threshold (>43°C), it fires a proactive warning state into the background queue to alert the planning agent.

---

## 📰 4. SerpApi (Google News Reader)
*   **Purpose:** Automatically parses Pakistani news media alerts.
*   **Use-Case:** Dynamically injects crisis updates (e.g., land-slides on Murree Expressway, strikes, localized road blocks) directly onto the mobile app's main feed dashboard.
