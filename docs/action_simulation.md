# ⚡ Action Simulation Engine

A key requirement of Challenge 3 is simulating the execution of coordinated response actions. KHABAR features a full execution-simulation engine mapped directly to the **Execution Agent**'s tool calls.

---

## 🚧 1. Traffic Rerouting Simulation
When the **Analysis Agent** detects a road blockage (e.g., due to urban flooding or land-slide), it proposes traffic redirection.
*   **Tool Called:** `UpdateTrafficRoute(incident_id, close_road, detour_route)`
*   **Action Logged:** The tool marks the specific arterial road (e.g., *Jinnah Avenue*) as `CLOSED` and computes the alternate route (e.g., *Nazimuddin Road*).
*   **Visual Rendering:** Inside the mobile app (`MapScreen`), the simulation is rendered dynamically centered on the incident's coordinates. 
    - The closed road segment is drawn as a **thick solid Red line**.
    - The proposed detour corridor is mapped as a **teal dashed/dotted corridor**, simulating the active reroute updates in the GPS client.

---

## 🚒 2. Emergency Dispatch Simulation
To coordinate physical responders, the system automates team dispatches.
*   **Tool Called:** `DispatchRescueTeam(agency, units)`
*   **Action Logged:** The tool checks the available resource inventory in the database (e.g., WASA dewatering pumps, Rescue 1122 ambulances). If resources are available, it increments the `active_units` count for the incident and transitions the dispatch status to `EN_ROUTE`.
*   **Visual Rendering:** Inside both the Web Dashboard and Flutter app, the resource inventory counters immediately decrease (e.g., available ambulances count drops) and the incident's active units count goes up.

---

## 📢 3. Localized Alert Simulation
Broadcasting notifications keeps citizens away from danger zones.
*   **Tool Called:** `BroadcastAlert(message, target_audience)`
*   **Action Logged:** The tool increments the incident's `public_alerts_sent` count and logs the generated warning message (e.g., *خطرہ: کلفٹن انڈرپاس میں پانی بھر گیا ہے۔*).
*   **Visual Rendering:** The Web Dashboard updates its **"Public Broadcasts"** widget with the Urdu notification, and the Flutter app immediately prompts a foreground high-priority alert dialog.

---

## 🎫 4. Emergency Ticket Generation
Utility providers and secondary agencies need standardized tasks.
*   **Tool Called:** `CreateEmergencyTicket(target_agency, details, severity)`
*   **Action Logged:** The system generates a structured ticket in the format: `TK-<Incident_ID_Last_4>-<Index_Number>` (e.g., `TK-XQZ9-1`).
*   **State Sync:** The ticket is committed to the PostgreSQL database, dispatching notifications to simulated agency APIs (like WASA or K-Electric power grid control).
