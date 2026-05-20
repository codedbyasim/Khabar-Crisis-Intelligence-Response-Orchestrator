# 📊 Outcome Visualization

To ensure auditability and transparency, KHABAR visualizes the exact operational impact of the AI's decisions through "Before vs After" comparisons and system reasoning logs.

---

## 🔄 1. "Before vs After" Impact Panel
When the orchestrator processes an incident, it takes a snapshot of the global variables *before* any tools are executed, runs the tools, and takes another snapshot *after* completion.

The difference (`state_diff`) shows the direct impact of the system's decisions:
*   **Flutter App (`lib/screens/incident_tracker_screen.dart`):**
    A slide-up panel displays a side-by-side table comparing the pre-response state vs. the post-response state:
    - Status changes (`OPEN` ➔ `PIPELINE_COMPLETE`).
    - Active Units deployed (e.g., WASA: 2).
    - Roads closed (e.g., Jinnah Avenue closed).
    - Tickets created.
*   **Web Dashboard (`dashboard_server.py`):**
    Shows a clean dark-mode widget outlining the state transition with highlighted green text for changed variables.

---

## 📋 2. Real-Time System Reasoning Logs (Traces)
Every reasoning step, database call, and tool execution is recorded in a chronological trace log array.

### Visual Representation:
*   **Flutter App:**
    Rendered as a dynamic vertical timeline. Each step in the multi-agent pipeline glows and turns green once its phase is completed, with corresponding timestamps.
*   **Web Dashboard:**
    Features a dedicated monospaced console widget. The logs are color-coded by the active agent phase using CSS classes:
    - `trace-detection` (Blue): Highlights signal classification and priority tagging.
    - `trace-analysis` (Purple): Highlights severity calculations.
    - `trace-planning` (Green): Highlights SOP protocols and RAG matching.
    - `trace-execution` (Teal): Highlights specific tool executions.

---

## 🚑 3. Live Resource Inventory
The system tracks public resources across raw agencies to model capacity limits during multiple concurrent disasters.
*   **Monitored Assets:**
    - Dewatering Pumps (WASA)
    - Rescue Teams (Rescue 1122)
    - Ambulances (Edhi/Red Crescent)
    - Medical Kits (Hospitals)
*   **State Updates:**
    When the Execution Agent dispatches units, the database resources decrease in real-time, preventing the planning agent from double-allocating depleted resources.
