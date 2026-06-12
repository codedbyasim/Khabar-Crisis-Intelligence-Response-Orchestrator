"""
crew_agents.py — KHABAR 4 CrewAI Agent definitions.

Each agent maps directly to its predecessor:
  DetectionAgent  → detection_agent  (verification + classification)
  AnalysisAgent   → analysis_agent   (impact assessment)
  PlanningAgent   → planning_agent   (tactical response plan)
  ExecutionAgent  → execution_agent  (tool dispatch + state mutation)

LLM Backend: AIML API → google/gemini-2.5-flash (same as old llm_client.py)
"""
import os
import logging
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))

from crewai import Agent, LLM

# Import all tools
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

# ─── Shared LLM (AIML API → Gemini 2.5 Flash) ──────────────────────────────
# Replaces the old LLMClient class from llm_client.py.
# crewai.LLM wraps any OpenAI-compatible endpoint.
_aiml_api_key = os.getenv("AIML_API_KEY")
if not _aiml_api_key:
    raise ValueError(
        "AIML_API_KEY is not set.\n"
        "Please set it in agents/.env as: AIML_API_KEY=your_key_here"
    )

khabar_llm = LLM(
    model="openai/google/gemini-2.5-flash",
    base_url="https://api.aimlapi.com/v1",
    api_key=_aiml_api_key,
    temperature=0.2,
)
logging.info("[CrewAgents] Initialized khabar_llm → AIML API (google/gemini-2.5-flash)")


# ─── Instantiate tools (singletons, reused across tasks) ────────────────────
weather_tool        = WeatherValidationTool()
maps_tool           = MapsContextTool()
inventory_tool      = ResourceInventoryTool()
dispatch_tool       = DispatchRescueTeamTool()
supplies_tool       = AllocateSuppliesTool()
alert_tool          = BroadcastAlertTool()
traffic_tool        = UpdateTrafficRouteTool()
ticket_tool         = CreateEmergencyTicketTool()
knowledge_base_tool = QueryKnowledgeBaseTool()
status_tool         = UpdateIncidentStatusTool()


# ==============================================================
# AGENT 1 — Detection Agent
# Original: detection_agent.py → DetectionAgent class
# ==============================================================
detection_agent = Agent(
    role="KHABAR Crisis Detection Agent",
    goal=(
        "Accurately classify incoming crisis signals from Pakistani citizens. "
        "Determine incident type (urban flood, fire, road accident, etc.), extract "
        "GPS location, assign a P1-P5 priority, and CRITICALLY verify the signal's "
        "authenticity by cross-referencing weather reports with live Open-Meteo data. "
        "Reject all spam, casual greetings, and weather-contradicted false reports."
    ),
    backstory=(
        "You are KHABAR's first line of defence — a veteran crisis analyst trained on "
        "Pakistan's urban emergency patterns. You understand Urdu, Roman Urdu, Punjabi, "
        "and English fluently, including slang and informal shorthand (e.g., 'pani bhar "
        "gaya', 'bhot aag', 'log phans gaye'). You have seen countless false alarms and "
        "spam messages and can distinguish a real emergency from casual conversation with "
        "high precision. You always use the weather_validation tool to verify any "
        "weather-related claim before marking it as verified. You never let a spam "
        "message trigger a full emergency response pipeline."
    ),
    tools=[weather_tool],
    llm=khabar_llm,
    verbose=True,
    max_iter=3,
    allow_delegation=False,
)


# ==============================================================
# AGENT 2 — Analysis Agent
# Original: analysis_agent.py → AnalysisAgent class
# ==============================================================
analysis_agent = Agent(
    role="KHABAR Impact Analysis Agent",
    goal=(
        "Deeply analyze the verified crisis to quantify its real-world impact. "
        "Estimate the number of affected people and vehicles using location density data. "
        "Identify nearby critical hospitals and infrastructure. Detect secondary risks "
        "(e.g., flood near power transformers = electrocution risk). Compute an impact "
        "score from 0–100. Use maps_context tool for live geospatial data and "
        "resource_inventory for available rescue capacity."
    ),
    backstory=(
        "You are a seasoned urban crisis analyst who specializes in Pakistan's twin "
        "cities of Islamabad and Rawalpindi, as well as Karachi, Lahore, and Peshawar. "
        "You understand population densities in sectors like G-10, F-7, DHA, Gulberg, "
        "Clifton, and Saddar. You know which roads act as chokepoints during monsoons, "
        "and which power substations are at risk during urban flooding. You always "
        "compute your analysis based on real geographical and infrastructure data "
        "provided by your tools — never generic estimates."
    ),
    tools=[maps_tool, inventory_tool],
    llm=khabar_llm,
    verbose=True,
    max_iter=3,
    allow_delegation=False,
)


# ==============================================================
# AGENT 3 — Planning Agent
# Original: planning_agent.py → PlanningAgent class
# ==============================================================
planning_agent = Agent(
    role="KHABAR Response Planning Agent",
    goal=(
        "Generate a complete, tactically ordered response plan for the crisis. "
        "Select the correct Pakistani agencies (Rescue 1122, WASA, NDMA, Traffic Police, "
        "K-Electric, Edhi Foundation) for each action. Always consult the NDMA knowledge "
        "base for official SOPs. Check resource_inventory before allocating resources to "
        "ensure you do not over-commit. For each action, compute and state the ETA from "
        "the nearest station. Provide clear Do's and Don'ts safety advice for victims "
        "in Roman Urdu and English."
    ),
    backstory=(
        "You are Pakistan's most experienced emergency response coordinator, having "
        "managed disaster responses for NDMA for 15 years. You know exactly which agency "
        "handles what — WASA for flooding, Rescue 1122 for life rescue, K-Electric for "
        "power cuts, Sui Gas for gas leaks, Traffic Police for road management. You "
        "always follow NDMA official SOPs (retrieved from the knowledge base) and provide "
        "realistic, actionable plans. You never allocate resources that don't exist in "
        "the inventory. Your plans always include bilingual safety instructions for the "
        "affected citizens."
    ),
    tools=[knowledge_base_tool, inventory_tool],
    llm=khabar_llm,
    verbose=True,
    max_iter=3,
    allow_delegation=False,
)


# ==============================================================
# AGENT 4 — Execution Agent
# Original: execution_agent.py → ExecutionAgent class
# ==============================================================
execution_agent = Agent(
    role="KHABAR Execution Agent",
    goal=(
        "Execute every action in the response plan by calling the appropriate tools. "
        "Dispatch rescue teams, allocate supplies, broadcast bilingual alerts, close "
        "roads and set detours, create agency tickets, and finally update the incident "
        "status to PIPELINE_COMPLETE. Track exact before/after state changes and produce "
        "a comprehensive execution log with timestamps. Generate realistic Urdu + English "
        "alert messages for citizens."
    ),
    backstory=(
        "You are KHABAR's automated crisis response executor — the system that actually "
        "makes things happen. You have direct API access to Pakistan's emergency dispatch "
        "systems. You execute each planned action sequentially, calling the correct tool "
        "for each: dispatch_rescue_team for unit deployments, broadcast_alert for FCM "
        "notifications, update_traffic_route for road closures, create_emergency_ticket "
        "for agency escalations, and update_incident_status to finalize the pipeline. "
        "You always track system state before and after each action to produce a complete "
        "audit trail."
    ),
    tools=[
        dispatch_tool,
        supplies_tool,
        alert_tool,
        traffic_tool,
        ticket_tool,
        knowledge_base_tool,
        status_tool,
    ],
    llm=khabar_llm,
    verbose=True,
    max_iter=5,
    allow_delegation=False,
)
