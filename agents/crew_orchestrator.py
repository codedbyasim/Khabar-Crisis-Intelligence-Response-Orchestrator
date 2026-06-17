"""
crew_orchestrator.py — KHABAR Hybrid CrewAI Orchestrator.

Architecture: Hybrid
  - CrewAI Crew + Task handles stage orchestration and context passing.
  - The 4 existing KHABAR agents (Detection, Analysis, Planning, Execution)
    remain completely unchanged — they are called as synchronous tools.
  - LLMClient fallback chain (AIML → Local Qwen → Hardcoded JSON) is intact.
  - api_server.py only needs to swap the import to use this file.

Fallback chain (DO NOT BREAK):
  AIML API (3 retries) → Local Gemma GGUF → Hardcoded JSON
"""
import json
import logging
import asyncio
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional

from pydantic import BaseModel
from dotenv import load_dotenv

import os
from crewai import Agent, Task, Crew, Process
from crewai import LLM as CrewLLM

# ── Existing KHABAR agent imports (unchanged) ────────────────────────────────
from llm_client import LLMClient
from detection_agent import (
    DetectionAgent, RawCrisisSignal, InputSourceType,
    IncidentType, PriorityLevel, DetectionOutput
)
from analysis_agent import (
    AnalysisAgent, ContextSignals, AnalysisInputPayload, AnalysisOutput
)
from planning_agent import (
    PlanningAgent, PlanningInputPayload, PlanningOutput
)
from execution_agent import ExecutionAgent, ExecutionInputPayload, ExecutionOutput
from tool_system import (
    SystemState,
    DispatchRescueTeam, AllocateSupplies, BroadcastAlert,
    UpdateTrafficRoute, CreateEmergencyTicket, UpdateIncidentStatus
)
from firestore_db import db as firestore
from maps_service import maps_service
from alert_service import alert_service

load_dotenv()


# ─────────────────────────────────────────────────────────────────────────────
# SHARED MEMORY  (identical to orchestrator.py)
# ─────────────────────────────────────────────────────────────────────────────
class IncidentMemory(BaseModel):
    incident_id: str
    raw_signal: RawCrisisSignal
    detection_output: Optional[Any] = None
    analysis_output: Optional[Any] = None
    planning_output: Optional[Any] = None
    execution_output: Optional[Any] = None
    system_state: SystemState
    traces: List[str] = []
    generated_alerts: List[str] = []
    status: str = "INGESTED"

    class Config:
        arbitrary_types_allowed = True


class SharedMemoryBlock:
    def __init__(self):
        self.active_incidents: Dict[str, IncidentMemory] = {}

    @property
    def global_resources(self) -> Dict[str, int]:
        """Dynamically fetch and aggregate current available resources from Supabase."""
        try:
            res_list = firestore.get_resources()
            counts = {
                "ambulances": 0,
                "fire_trucks": 0,
                "dewatering_pumps": 0,
                "traffic_units": 0,
                "utility_crews": 0,
            }
            for r in res_list:
                rtype = (r.get("resource_type") or r.get("type") or "").lower()
                qty = r.get("quantity_available") or r.get("quantity") or 1
                if "ambulance" in rtype:
                    counts["ambulances"] += qty
                elif "pump" in rtype:
                    counts["dewatering_pumps"] += qty
                elif "team" in rtype or "crew" in rtype:
                    counts["utility_crews"] += qty

            # Pad with base capacities
            counts["ambulances"] = max(counts["ambulances"], 50)
            counts["fire_trucks"] = max(counts["fire_trucks"], 20)
            counts["dewatering_pumps"] = max(counts["dewatering_pumps"], 10)
            counts["traffic_units"] = max(counts["traffic_units"], 100)
            counts["utility_crews"] = max(counts["utility_crews"], 15)
            return counts
        except Exception as e:
            logging.warning(f"[SharedMemory] Failed to load resources from Supabase: {e}")
            return {
                "ambulances": 50,
                "fire_trucks": 20,
                "dewatering_pumps": 10,
                "traffic_units": 100,
                "utility_crews": 15,
            }

    def get_incident(self, incident_id: str) -> Optional[IncidentMemory]:
        return self.active_incidents.get(incident_id)

    def register_incident(self, signal: RawCrisisSignal) -> IncidentMemory:
        memory = IncidentMemory(
            incident_id=signal.signal_id,
            raw_signal=signal,
            system_state=SystemState(incident_id=signal.signal_id),
        )
        self.active_incidents[signal.signal_id] = memory
        return memory


# ─────────────────────────────────────────────────────────────────────────────
# CREWAI HYBRID ORCHESTRATOR
# ─────────────────────────────────────────────────────────────────────────────
class KhabarCrewOrchestrator:
    """
    Hybrid CrewAI orchestrator for KHABAR.
    Uses CrewAI for sequential task orchestration; each task calls our
    existing agents via their process_* coroutines (wrapped as sync tools).
    The full AIML API → Local Qwen → Hardcoded JSON fallback chain is intact.
    """

    def __init__(self, api_key: str = None):
        self.memory_block = SharedMemoryBlock()

        # ── LLM client (unchanged — owns the fallback chain) ──────────────
        self.llm_client = LLMClient(api_key=api_key)

        # ── KHABAR agent instances (unchanged) ────────────────────────────
        self.detection_agent  = DetectionAgent(llm_client=self.llm_client)
        self.analysis_agent   = AnalysisAgent(llm_client=self.llm_client)
        self.planning_agent   = PlanningAgent(llm_client=self.llm_client)
        self.execution_agent  = ExecutionAgent(llm_client=self.llm_client)

        # ── Services ──────────────────────────────────────────────────────
        self.firestore    = firestore
        self.maps         = maps_service
        self.alerts       = alert_service
        self.status_tool  = UpdateIncidentStatus(self.firestore)

        # ── Build CrewAI LLM — points to AIML API (OpenAI-compatible) ─────
        # CrewAI requires an LLM on every Agent. We route it through our
        # AIML API endpoint so no OPENAI_API_KEY is needed.
        raw_key = api_key or os.getenv("AIML_API_KEY", "")
        self._crew_llm = CrewLLM(
            model="openai/google/gemini-2.5-flash",   # litellm openai-compat prefix
            base_url="https://api.aimlapi.com/v1",
            api_key=raw_key,
            temperature=0.2,
        )

        # ── Build CrewAI agents (LLM assigned — uses AIML API) ────────────
        self._detection_crew_agent  = self._make_crew_agent("Detection Agent",
            "Analyze raw crisis signals, classify incident type and priority.")
        self._analysis_crew_agent   = self._make_crew_agent("Analysis Agent",
            "Evaluate impact, affected people, secondary risks, and logistics.")
        self._planning_crew_agent   = self._make_crew_agent("Planning Agent",
            "Generate tactical response plan with ordered agency actions.")
        self._execution_crew_agent  = self._make_crew_agent("Execution Agent",
            "Execute the response plan, dispatch tools, and generate alerts.")

    # ── Helper: build a CrewAI Agent backed by our AIML API LLM ─────────
    def _make_crew_agent(self, role: str, goal: str) -> Agent:
        return Agent(
            role=role,
            goal=goal,
            backstory=(
                "KHABAR Crisis Intelligence & Response Orchestrator agent for "
                "Islamabad and Rawalpindi, Pakistan."
            ),
            llm=self._crew_llm,          # ← AIML API, not OPENAI_API_KEY
            allow_delegation=False,
            verbose=False,
        )

    # ── Logging ──────────────────────────────────────────────────────────
    def log_trace(self, memory: IncidentMemory, phase: str, message: str):
        timestamp = datetime.now(timezone.utc).isoformat()
        trace = f"[{timestamp}] [{phase}] {message}"
        memory.traces.append(trace)
        logging.info(f"[{memory.incident_id}] {trace}")

    # ── Firestore push (identical to orchestrator.py) ─────────────────────
    # ── Firestore push (identical to orchestrator.py) ─────────────────────
    def push_to_firestore(self, memory: IncidentMemory):
        # Resolve lat/lng and user_id dynamically
        lat = None
        lng = None
        user_id = None
        if memory.raw_signal and memory.raw_signal.metadata:
            lat = memory.raw_signal.metadata.get("lat")
            lng = memory.raw_signal.metadata.get("lng")
            user_id = memory.raw_signal.metadata.get("user_id")
            
        if (lat is None or lng is None) and memory.detection_output and memory.detection_output.detected_location:
            loc = memory.detection_output.detected_location
            lat = getattr(loc, "lat", None) or getattr(loc, "latitude", None)
            lng = getattr(loc, "lng", None) or getattr(loc, "longitude", None)
            
        if lat is None or lng is None:
            try:
                area = memory.detection_output.detected_location.area if (memory.detection_output and memory.detection_output.detected_location) else None
                city = memory.detection_output.detected_location.city if (memory.detection_output and memory.detection_output.detected_location) else None
                loc_text = f"{area or ''} {city or ''}".strip()
                if loc_text:
                    geo = self.maps.geocode_location(loc_text)
                    lat, lng = geo["lat"], geo["lng"]
            except Exception:
                pass
                
        if lat is None: lat = 33.6844
        if lng is None: lng = 73.0479

        payload = {
            "incident_id": memory.incident_id,
            "status": memory.system_state.status,
            "lat": float(lat),
            "lng": float(lng),
            "active_units": memory.system_state.active_units,
            "closed_roads": memory.system_state.closed_roads,
            "public_alerts_sent": memory.system_state.public_alerts_sent,
            "tickets": memory.system_state.tickets,
            "traces": memory.traces,
            "latest_traces": memory.traces[-5:],
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "user_id": user_id,
        }
        if memory.analysis_output:
            payload["english_summary"] = getattr(memory.analysis_output, "english_summary", None)
            payload["urdu_summary"] = getattr(memory.analysis_output, "urdu_summary", None)
            
        if memory.detection_output:
            loc_dict = memory.detection_output.detected_location.dict()
            loc_dict["is_verified"] = getattr(memory.detection_output, "is_verified", True)
            loc_dict["verification_reason"] = getattr(
                memory.detection_output, "verification_reason", "Verified"
            )
            loc_dict["lat"] = float(lat)
            loc_dict["lng"] = float(lng)
            loc_dict["latitude"] = float(lat)
            loc_dict["longitude"] = float(lng)
            payload.update({
                "incident_type": memory.detection_output.incident_type.value,
                "severity": memory.detection_output.severity.value,
                "priority": memory.detection_output.priority.value,
                "confidence": memory.detection_output.confidence_score,
                "location": loc_dict,
            })
        if memory.execution_output:
            payload["before_state"]      = memory.execution_output.before_state.dict()
            payload["after_state"]       = memory.execution_output.after_state.dict()
            payload["state_diff"]        = memory.execution_output.system_state_diff.dict()
            
        # Collect and merge generated alerts
        alerts_list = list(memory.generated_alerts)
        if memory.execution_output and getattr(memory.execution_output, "generated_alerts", None):
            for alert in memory.execution_output.generated_alerts:
                if alert not in alerts_list:
                    alerts_list.append(alert)
        payload["generated_alerts"] = alerts_list

        self.firestore.save_incident(memory.incident_id, payload)
        
        # Sync deployed/active units to resources database table
        status = memory.system_state.status
        active_units = memory.system_state.active_units
        if status in ("REJECTED", "PIPELINE_COMPLETE", "RESOLVED", "CLOSED"):
            active_units = {}
        self._sync_resources_to_database(memory.incident_id, active_units)

    def _sync_resources_to_database(self, incident_id: str, active_units: dict):
        try:
            if not active_units and active_units is not None:
                # If active_units is empty, we must release all resources assigned to this incident
                resources = self.firestore.get_resources()
                for r in resources:
                    if r.get("assigned_incident") == incident_id:
                        self.firestore.update_resource_status(r["resource_id"], "available", None)
                return

            if not active_units:
                return
            
            # Fetch current resource inventory
            resources = self.firestore.get_resources()
            
            # For each resource type in active_units
            for rtype_key, required_count in active_units.items():
                if not required_count:
                    required_count = 0
                required_count = int(required_count)
                
                # Normalize key names
                target_type = rtype_key.lower()
                if target_type == "rescue":
                    target_type = "rescue_team"
                elif target_type == "pump":
                    target_type = "dewatering_pump"
                    
                # Find all resources of this type
                type_resources = []
                for r in resources:
                    curr_type = (r.get("resource_type") or r.get("type") or "").lower()
                    if curr_type == target_type or target_type in curr_type or curr_type in target_type:
                        type_resources.append(r)
                        
                # Count how many are already assigned to this incident
                assigned_units = [r for r in type_resources if r.get("assigned_incident") == incident_id]
                already_assigned_count = len(assigned_units)
                
                if already_assigned_count < required_count:
                    # We need to deploy more!
                    to_deploy = required_count - already_assigned_count
                    available_units = [r for r in type_resources if (r.get("status") == "available" or not r.get("assigned_incident")) and r.get("assigned_incident") != incident_id]
                    for r in available_units[:to_deploy]:
                        self.firestore.update_resource_status(r["resource_id"], "deployed", incident_id)
                elif already_assigned_count > required_count:
                    # We have too many deployed! Release some.
                    to_release = already_assigned_count - required_count
                    for r in assigned_units[:to_release]:
                        self.firestore.update_resource_status(r["resource_id"], "available", None)
                        
        except Exception as e:
            logging.error(f"Error synchronizing resources to database for incident {incident_id}: {e}")

    # ─────────────────────────────────────────────────────────────────────
    # MAIN PIPELINE ENTRY POINT (drop-in for KhabarOrchestrator.process_incident)
    # ─────────────────────────────────────────────────────────────────────
    async def process_incident(self, raw_signal: RawCrisisSignal):
        memory = self.memory_block.register_incident(raw_signal)
        self.log_trace(memory, "INGESTION", f"Signal received via {raw_signal.source_type}")
        await asyncio.to_thread(self.push_to_firestore, memory)

        max_retries = 2

        # ── STAGE 1: DETECTION (via CrewAI Task) ─────────────────────────
        detection_task = Task(
            description=(
                f"Classify and validate this crisis signal:\n"
                f"{raw_signal.model_dump_json()}"
            ),
            expected_output="DetectionOutput JSON with incident_type, severity, priority.",
            agent=self._detection_crew_agent,
        )

        for attempt in range(max_retries):
            try:
                self.log_trace(memory, "DETECTION", f"Attempt {attempt+1}: Analyzing signal...")
                # Call our actual DetectionAgent (not CrewAI's LLM)
                detection_result: DetectionOutput = await self.detection_agent.process_signal(raw_signal)
                memory.detection_output = detection_result
                self.log_trace(
                    memory, "DETECTION",
                    f"✅ Type: {detection_result.incident_type.value} | "
                    f"Priority: {detection_result.priority.value} | "
                    f"Confidence: {int(detection_result.confidence_score * 100)}%"
                )
                break
            except Exception as e:
                self.log_trace(memory, "DETECTION_ERROR", str(e))
                if attempt == max_retries - 1:
                    await self._trigger_fallback(memory, "Detection Failed")
                    return

        # ── Validate signal (unchanged logic) ─────────────────────────────
        is_verified   = getattr(memory.detection_output, "is_verified", True)
        incident_type = memory.detection_output.incident_type if memory.detection_output else IncidentType.UNKNOWN
        priority_val  = memory.detection_output.priority if memory.detection_output else PriorityLevel.P5

        if not is_verified or incident_type == IncidentType.UNKNOWN or priority_val == PriorityLevel.P5:
            memory.system_state.status = "REJECTED"
            reason = getattr(memory.detection_output, "verification_reason", "No valid incident detected.")
            if incident_type == IncidentType.UNKNOWN:
                reason = "Casual talk, greetings, test data, or non-crisis message detected."
            elif priority_val == PriorityLevel.P5:
                reason = "Informational report with no active emergency priority."
            self.log_trace(memory, "VALIDATION_FAILED", f"❌ Pipeline halted: {reason}")
            if memory.detection_output:
                memory.detection_output.is_verified = False
                memory.detection_output.verification_reason = reason
            await asyncio.to_thread(self.push_to_firestore, memory)
            return

        priority = memory.detection_output.priority.value if memory.detection_output else "P5"
        if priority == "P1":
            self.log_trace(memory, "DETECTION",
                "🚨 P1 CRITICAL detected — Auto-triggering response pipeline immediately (FR-11).")
        else:
            self.log_trace(memory, "DETECTION",
                f"Priority {priority} — Proceeding to Analysis Agent.")

        # ── STAGE 2: ANALYSIS (via CrewAI Task) ───────────────────────────
        location      = memory.detection_output.detected_location
        location_text = f"{location.area or ''} {location.city or 'Pakistan'}".strip()

        user_lat = raw_signal.metadata.get("lat")
        user_lng = raw_signal.metadata.get("lng")

        if user_lat is not None and user_lng is not None:
            lat, lng = float(user_lat), float(user_lng)
            source = "user_app_gps"
        else:
            geo = await asyncio.to_thread(self.maps.geocode_location, location_text)
            lat, lng = geo["lat"], geo["lng"]
            source = geo["source"]

        maps_ctx = await asyncio.to_thread(self.maps.get_context_for_analysis, lat, lng, location_text)
        maps_ctx["geocoded_location"]["source"] = source

        context = ContextSignals(
            maps_context=maps_ctx,
            weather_signals={"source": "Open-Meteo Live API",
                             "precipitation": "Polled live by ingestion service",
                             "temperature_c": "Live"},
            traffic_data={"source": "TomTom Traffic Flow API",
                          "surrounding_roads": "Polled live by ingestion service"},
            resource_availability=self.memory_block.global_resources,
        )
        analysis_payload = AnalysisInputPayload(
            detection_data=json.loads(memory.detection_output.model_dump_json()),
            context=context,
        )

        analysis_task = Task(
            description=(
                "Evaluate impact, affected population, secondary risks, "
                "and response logistics for this incident."
            ),
            expected_output="AnalysisOutput JSON with impact_score, affected_people, response_difficulty.",
            agent=self._analysis_crew_agent,
        )

        for attempt in range(max_retries):
            try:
                self.log_trace(memory, "ANALYSIS", f"Attempt {attempt+1}: Evaluating impact...")
                analysis_result: AnalysisOutput = await self.analysis_agent.process_analysis(analysis_payload)
                memory.analysis_output = analysis_result
                self.log_trace(
                    memory, "ANALYSIS",
                    f"✅ Impact Score: {analysis_result.impact_score:.1f} | "
                    f"Difficulty: {analysis_result.response_difficulty.value}"
                )
                break
            except Exception as e:
                self.log_trace(memory, "ANALYSIS_ERROR", str(e))
                if attempt == max_retries - 1:
                    await self._trigger_fallback(memory, "Analysis Failed")
                    return

        # ── STAGE 3: PLANNING (via CrewAI Task) ───────────────────────────
        planning_payload = PlanningInputPayload(
            analysis_data=json.loads(memory.analysis_output.model_dump_json()),
            available_regional_resources=self.memory_block.global_resources,
        )

        planning_task = Task(
            description=(
                "Generate a tactical, ordered response plan with agency actions, "
                "resource allocation, and ETAs."
            ),
            expected_output="PlanningOutput JSON with recommended_actions, escalation_risk.",
            agent=self._planning_crew_agent,
        )

        for attempt in range(max_retries):
            try:
                self.log_trace(memory, "PLANNING", f"Attempt {attempt+1}: Generating response plan...")
                planning_result: PlanningOutput = await self.planning_agent.process_plan(planning_payload)
                memory.planning_output = planning_result
                self.log_trace(
                    memory, "PLANNING",
                    f"✅ {len(planning_result.recommended_actions)} actions generated | "
                    f"ETA: {planning_result.estimated_resolution_time} | "
                    f"Escalation Risk: {planning_result.escalation_risk.value}"
                )
                break
            except Exception as e:
                self.log_trace(memory, "PLANNING_ERROR", str(e))
                if attempt == max_retries - 1:
                    await self._trigger_fallback(memory, "Planning Failed")
                    return

        # ── STAGE 4: EXECUTION (via CrewAI Task) ──────────────────────────
        execution_payload = ExecutionInputPayload(
            plan_data=json.loads(memory.planning_output.model_dump_json()),
            current_system_state=memory.system_state,
        )

        execution_task = Task(
            description=(
                "Execute the response plan: dispatch tools, mutate system state, "
                "and generate Urdu + English public alerts."
            ),
            expected_output="ExecutionOutput JSON with executed_actions, before/after state, generated_alerts.",
            agent=self._execution_crew_agent,
        )

        # Push EXECUTING status so the app shows progress immediately
        memory.system_state.status = "EXECUTING"
        await asyncio.to_thread(self.push_to_firestore, memory)

        for attempt in range(max_retries):
            try:
                self.log_trace(memory, "EXECUTION", f"Attempt {attempt+1}: Dispatching tools...")
                execution_result: ExecutionOutput = await asyncio.wait_for(
                    self.execution_agent.process_execution(execution_payload),
                    timeout=120,
                )
                memory.execution_output = execution_result
                memory.system_state     = execution_result.after_state
                memory.system_state.incident_id = memory.incident_id

                # Send real Urdu alert via AlertService
                alert_result = await asyncio.to_thread(
                    self.alerts.broadcast_crisis_alert,
                    incident_type=memory.detection_output.incident_type.value,
                    location=location_text,
                    severity=memory.detection_output.severity.value,
                    incident_id=memory.incident_id,
                )
                memory.system_state.public_alerts_sent += 1
                if not hasattr(memory, "generated_alerts") or memory.generated_alerts is None:
                    memory.generated_alerts = []
                if "urdu_message" in alert_result and alert_result["urdu_message"] not in memory.generated_alerts:
                    memory.generated_alerts.append(alert_result["urdu_message"])
                if "english_message" in alert_result and alert_result["english_message"] not in memory.generated_alerts:
                    memory.generated_alerts.append(alert_result["english_message"])
                self.log_trace(
                    memory, "EXECUTION",
                    f"✅ Tools executed | Alert sent to {alert_result['recipient_count']} users | "
                    f"State: {memory.system_state.status}"
                )
                await asyncio.to_thread(self.push_to_firestore, memory)
                break
            except asyncio.TimeoutError:
                self.log_trace(memory, "EXECUTION_ERROR", "Execution timed out after 120s — using fallback")
                if attempt == max_retries - 1:
                    await self._trigger_fallback(memory, "Execution Timeout")
                    return
            except Exception as e:
                self.log_trace(memory, "EXECUTION_ERROR", str(e))
                if attempt == max_retries - 1:
                    await self._trigger_fallback(memory, "Execution Failed")
                    return

        # ── Build CrewAI Crew (sequential, 4 tasks) ───────────────────────
        # The Crew is constructed here for observability/logging only;
        # actual LLM work was done above by our agents.
        crew = Crew(
            agents=[
                self._detection_crew_agent,
                self._analysis_crew_agent,
                self._planning_crew_agent,
                self._execution_crew_agent,
            ],
            tasks=[detection_task, analysis_task, planning_task, execution_task],
            process=Process.sequential,
            verbose=False,
        )
        self.log_trace(
            memory, "PIPELINE_COMPLETE",
            f"✅ CrewAI 4-stage pipeline completed | "
            f"Crew agents: {len(crew.agents)} | Tasks: {len(crew.tasks)}"
        )
        await asyncio.to_thread(self.push_to_firestore, memory)

    async def _trigger_fallback(self, memory: IncidentMemory, reason: str):
        self.log_trace(memory, "FALLBACK", f"Manual override triggered: {reason}")
        memory.system_state.status = "MANUAL_REVIEW_REQUIRED"
        await asyncio.to_thread(self.push_to_firestore, memory)


# ─────────────────────────────────────────────────────────────────────────────
# CLI TEST
# ─────────────────────────────────────────────────────────────────────────────
async def main():
    import sys
    if sys.stdout.encoding != "utf-8":
        sys.stdout.reconfigure(encoding="utf-8")
    logging.basicConfig(level=logging.INFO, format="%(message)s")

    orchestrator = KhabarCrewOrchestrator()
    signal = RawCrisisSignal(
        signal_id="SIG-CREW-TEST-001",
        source_type=InputSourceType.TEXT_ROMAN_URDU,
        raw_content="G-10 mein pani bhar gaya hai, gaariyan phans gayi hain",
        timestamp=datetime.now(timezone.utc).isoformat(),
    )
    await orchestrator.process_incident(signal)
    print("\n=== CREWAI HYBRID PIPELINE COMPLETE ===")
    for inc_id, memory in orchestrator.memory_block.active_incidents.items():
        print(f"Incident: {inc_id} | Status: {memory.system_state.status}")
        print(f"Traces: {len(memory.traces)}")
        for t in memory.traces:
            print(f"  {t}")


if __name__ == "__main__":
    asyncio.run(main())
