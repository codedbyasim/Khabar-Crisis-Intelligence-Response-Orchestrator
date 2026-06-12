"""
crew_tasks.py — KHABAR 4 CrewAI Task definitions.

Each task corresponds to one agent in the sequential pipeline:
  Task 1: detection_task   → detection_agent
  Task 2: analysis_task    → analysis_agent   (context: detection_task)
  Task 3: planning_task    → planning_agent   (context: detection_task, analysis_task)
  Task 4: execution_task   → execution_agent  (context: all prior tasks)

output_pydantic is used so CrewAI auto-parses the agent output into the
Pydantic model — no manual JSON parsing needed.

System prompts are the EXACT same logic as the old SYSTEM_PROMPT strings
from detection_agent.py, analysis_agent.py, planning_agent.py, execution_agent.py.
"""
from crewai import Task

from crew_agents import (
    detection_agent,
    analysis_agent,
    planning_agent,
    execution_agent,
)
from crew_tools import (
    WeatherValidationTool,
    MapsContextTool,
    ResourceInventoryTool,
    DispatchRescueTeamTool,
    AllocateSuppliesTool,
    BroadcastAlertTool,
    UpdateTrafficRouteTool,
    CreateEmergencyTicketTool,
    QueryKnowledgeBaseTool,
    UpdateIncidentStatusTool,
)
from schemas import (
    DetectionOutput,
    AnalysisOutput,
    PlanningOutput,
    ExecutionOutput,
)


# ==============================================================
# TASK 1 — Detection Task
# ==============================================================
detection_task = Task(
    description=(
        """You are the KHABAR Crisis Detection Agent processing the following raw signal:

SIGNAL DATA:
{raw_signal_json}

COORDINATES:
Latitude: {lat}
Longitude: {lng}

STEP-BY-STEP INSTRUCTIONS:
1. NORMALIZE INPUT: Translate Urdu, Punjabi, or Roman Urdu into clear English. Correct typos and informal grammar.

2. WEATHER VALIDATION: 
   - FIRST, call the weather_validation tool with lat={lat} and lng={lng} to get live weather data.
   - If the signal reports weather-related issues (flooding, heavy rain, storm, extreme heatwave):
     * Cross-reference with live weather_validation tool result.
     * If live rain_mm = 0.0 but signal claims flooding → set is_verified=False, set verification_reason to "Reported flooding but live sensors show 0mm precipitation."
     * If live temperature < 30°C but signal claims extreme heatwave → set is_verified=False with appropriate reason.
     * If weather data unavailable or correlates with the claim → set is_verified=True.
   - For non-weather events (accidents, fires, building collapses, medical emergencies) → set is_verified=True (cannot be validated by weather sensors).

3. SPAM/CASUAL DETECTION:
   - If the message is a greeting ("hi", "hello", "test"), casual talk ("main theek hoon", "sab thik hai"), or clearly has no emergency → set incident_type="unknown" and is_verified=False with reason "Casual conversation or test message detected. No active emergency."

4. IDENTIFY INCIDENT TYPE: Map to exactly ONE of:
   urban flood | road accident | building collapse | fire | heatwave | road blockage | infrastructure failure | medical emergency | unknown

5. EXTRACT LOCATION: City and local area/road/landmark.

6. ASSIGN PRIORITY:
   - P1: Life-threatening (building collapse with trapped people, massive fire, catastrophic flood)
   - P2: High risk (severe accident, major infrastructure failure)
   - P3: Moderate (localized flooding, non-fatal accident)
   - P4: Low (road blockage, minor fire)
   - P5: Non-emergency, informational, test, greeting

7. IDENTIFY URGENCY FLAGS: Exact phrases like "log phans gaye", "bhot aag", "paani bhar gaya", "help fast".

8. GENERATE REASONING: Concise step-by-step explanation of your classification and verification decision.

CRITICAL RULES:
- If life is in immediate danger → Priority MUST be P1, Severity MUST be CRITICAL.
- Handle noisy mixed-language text robustly.
- P1 incidents auto-trigger the full response pipeline — be sensitive to life-threat indicators.

Return a JSON object conforming EXACTLY to the DetectionOutput schema."""
    ),
    expected_output=(
        "A JSON object with fields: incident_type, severity (CRITICAL/HIGH/MEDIUM/LOW), "
        "priority (P1-P5), confidence_score (0.0-1.0), detected_location (city, area, "
        "raw_location_mentions), normalized_input, reasoning_trace, urgency_flags list, "
        "is_verified (bool), verification_reason (str)."
    ),
    output_pydantic=DetectionOutput,
    agent=detection_agent,
    tools=[WeatherValidationTool()],
)


# ==============================================================
# TASK 2 — Analysis Task
# ==============================================================
analysis_task = Task(
    description=(
        """You are the KHABAR Impact Analysis Agent. The Detection Agent has verified a crisis.

INCIDENT COORDINATES:
Latitude: {lat}
Longitude: {lng}

DETECTION RESULT (from previous task, passed as context):

STEP-BY-STEP INSTRUCTIONS:
1. CALL maps_context tool with lat={lat}, lng={lng} and the detected location to get:
   - Nearby hospitals within 5km
   - Critical infrastructure list
   - Resource ETAs for all resource types from nearest stations

2. CALL resource_inventory tool to get current available resource counts.

3. ESTIMATE AFFECTED POPULATION:
   - Use location density data (G-10 Markaz → dense commercial, 300+ people; residential sectors → 100-200; highways → vehicles focused)
   - Factor in time of day if discernible from signal
   - Estimate both affected_people and affected_vehicles realistically

4. IDENTIFY SECONDARY RISKS:
   - Urban flood near utility poles → electrocution risk
   - Fire near gas lines → explosion risk
   - Building collapse → aftershock / structural cascade risk
   - Road blockage → ambulance access blockage

5. DETERMINE RESPONSE DIFFICULTY:
   - EASY: Isolated, clear access, low risk
   - MODERATE: Some access issues or secondary risks
   - HARD: High traffic, poor access, significant secondary risks
   - EXTREME: Multiple life threats, blocked access, extreme weather

6. CALCULATE IMPACT SCORE (0-100):
   - 90+: Mass casualties or critical infrastructure failure
   - 70-90: Major incident, multiple agencies needed
   - 50-70: Significant impact, one primary agency
   - Below 50: Minor, localized

7. GENERATE BILINGUAL SUMMARIES:
   - english_summary: Clear, actionable 2-3 sentence summary
   - urdu_summary: Standard professional Urdu script (not Roman Urdu)

Return a JSON object conforming EXACTLY to the AnalysisOutput schema."""
    ),
    expected_output=(
        "A JSON object with: impact_score (0-100), affected_people (int), "
        "affected_vehicles (int), nearby_hospitals (list of Facility objects), "
        "nearby_infrastructure (list of str), secondary_risks (list of str), "
        "response_difficulty (EASY/MODERATE/HARD/EXTREME), "
        "congestion_level (NONE/MODERATE/HEAVY/GRIDLOCK), "
        "analysis_reasoning (str), english_summary (str), urdu_summary (str in Urdu script)."
    ),
    output_pydantic=AnalysisOutput,
    agent=analysis_agent,
    tools=[MapsContextTool(), ResourceInventoryTool()],
    context=[detection_task],
)


# ==============================================================
# TASK 3 — Planning Task
# ==============================================================
planning_task = Task(
    description=(
        """You are the KHABAR Response Planning Agent. The Analysis Agent has completed impact assessment.

DETECTION RESULT (from Task 1, passed as context):

ANALYSIS RESULT (from Task 2, passed as context):

STEP-BY-STEP INSTRUCTIONS:
1. QUERY NDMA KNOWLEDGE BASE:
   - Call query_knowledge_base tool with the crisis type as query to get the official NDMA SOP.
   - Use this SOP to guide your action plan.

2. CHECK RESOURCE INVENTORY:
   - Call resource_inventory tool to verify current available counts.
   - Do NOT allocate more than available.

3. FORMULATE RECOMMENDED ACTIONS:
   - Order actions by priority: P1_IMMEDIATE first, then P2_URGENT, then P3_STANDARD.
   - Assign the correct Pakistani agency for each action:
     * Flooding → WASA (dewatering), Rescue 1122 (rescue)
     * Fire → Fire Brigade via Rescue 1122, Sui Gas (gas disconnect)
     * Road Accident → Traffic Police (traffic), Rescue 1122 (medical)
     * Power failure → K-Electric or WAPDA
     * Mass casualty → Edhi Foundation (body management), NDMA (coordination)
   - For each action, include the ETA information from maps_context in the description.

4. COMPUTE RESOURCE REQUIREMENTS:
   - Use ONLY these keys: ambulances, fire_trucks, dewatering_pumps, traffic_units, utility_crews
   - Base on analysis: affected_people, severity, response_difficulty

5. PROVIDE SAFETY GUIDANCE (MANDATORY):
   - In response_strategy field, include actionable Do's and Don'ts in Roman Urdu + English for victims waiting for help.
   - Example: "DO: Bijli ke switch band karein. DO NOT: Paani mein khare hokar wire ko hath lagayen."

6. ASSESS ESCALATION RISK:
   - LOW: Contained, resources sufficient
   - MEDIUM: Situation could worsen
   - HIGH: Multiple threats, resources strained
   - CRITICAL: Situation escalating rapidly

7. PROVIDE FALLBACK ACTIONS:
   - What to do if primary resources are unavailable or primary route is blocked.

CRITICAL RULES:
- resource_requirements keys MUST be ONLY: ambulances, fire_trucks, dewatering_pumps, traffic_units, utility_crews. NO other keys.
- Actions must be realistically ordered by priority.
- estimated_resolution_time must be specific (e.g., "45-90 minutes", not "unknown").

Return a JSON object conforming EXACTLY to the PlanningOutput schema."""
    ),
    expected_output=(
        "A JSON object with: recommended_actions (list of RecommendedAction objects with "
        "action_type, priority, target_agency, description, required_units), "
        "action_priority (str), resource_requirements (dict with ONLY these keys: "
        "ambulances/fire_trucks/dewatering_pumps/traffic_units/utility_crews), "
        "response_strategy (str with Do's & Don'ts in Roman Urdu + English), "
        "estimated_resolution_time (str), escalation_risk (LOW/MEDIUM/HIGH/CRITICAL), "
        "planning_reasoning (str), fallback_actions (list)."
    ),
    output_pydantic=PlanningOutput,
    agent=planning_agent,
    tools=[QueryKnowledgeBaseTool(), ResourceInventoryTool()],
    context=[detection_task, analysis_task],
)


# ==============================================================
# TASK 4 — Execution Task
# ==============================================================
execution_task = Task(
    description=(
        """You are the KHABAR Execution Agent. Execute every action in the response plan using your tools.

INCIDENT ID: {incident_id}
COORDINATES: lat={lat}, lng={lng}

DETECTION RESULT (from Task 1, passed as context):

PLANNING RESULT (from Task 3, passed as context):

STEP-BY-STEP INSTRUCTIONS:
Execute EACH recommended_action from the planning result sequentially:

FOR EACH ACTION:
  - "dispatch rescue" → call dispatch_rescue_team tool with (incident_id, agency, units)
  - "allocate supplies" → call allocate_supplies tool with (incident_id, item_type, quantity)
  - "send Urdu alerts" or "notify agencies" → call broadcast_alert tool with (incident_id, incident_type, location, severity)
  - "reroute traffic" → call update_traffic_route tool with (incident_id, close_road, detour_route)
  - "create emergency tickets" → call create_emergency_ticket tool with (incident_id, target_agency, details, severity)
  - Any other action → use the most appropriate available tool

AFTER ALL ACTIONS:
  - Call update_incident_status with (incident_id, "PIPELINE_COMPLETE", "All 4 agents completed successfully")

TRACKING:
  - Record before_state as the state BEFORE any tools are called (empty active_units, 0 alerts, etc.)
  - Record after_state as the state AFTER all tools have been called
  - List all changed_keys in system_state_diff

ALERTS:
  - generated_alerts must contain the actual bilingual alert messages that were sent
  - Include both Urdu (using Urdu script) and English versions

EXECUTION LOGS:
  - Create realistic timestamped log entries for each tool call
  - Include the tool name, result, and any error handling

CRITICAL RULE:
  - The after_state.active_units MUST show increased unit counts vs before_state if dispatch was called.
  - You MUST call update_incident_status as your LAST action.

Return a JSON object conforming EXACTLY to the ExecutionOutput schema."""
    ),
    expected_output=(
        "A JSON object with: execution_logs (list of LogEntry), executed_actions (list of "
        "ExecutedAction with tool_results), before_state (dict), after_state (dict showing "
        "mutations), system_state_diff (StateDiff with changed_keys and descriptions), "
        "timestamps (dict), execution_reasoning (str), generated_alerts (list of str with "
        "Urdu + English messages), final_outcome (str)."
    ),
    output_pydantic=ExecutionOutput,
    agent=execution_agent,
    tools=[
        DispatchRescueTeamTool(),
        AllocateSuppliesTool(),
        BroadcastAlertTool(),
        UpdateTrafficRouteTool(),
        CreateEmergencyTicketTool(),
        QueryKnowledgeBaseTool(),
        UpdateIncidentStatusTool(),
    ],
    context=[detection_task, analysis_task, planning_task],
)
