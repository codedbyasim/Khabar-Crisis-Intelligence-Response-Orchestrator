"""
api_server.py — KHABAR FastAPI Backend
All 8 SRS-required endpoints implemented.
"""
import sys
import os
import json
import logging
from datetime import datetime, timezone
from typing import Optional

from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, File, UploadFile, Form, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse
from pydantic import BaseModel

# Add agents folder to path
sys.path.append(os.path.join(os.path.dirname(__file__), "agents"))

from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), "agents", ".env"))

from orchestrator import KhabarOrchestrator, RawCrisisSignal, InputSourceType
from firestore_db import db as firestore
from gemini_vision import GeminiVision
from gemini_speech import GeminiSpeech
from alert_service import alert_service
from maps_service import maps_service

# Setup dual logging (Console and file)
log_formatter = logging.Formatter("%(asctime)s %(levelname)s %(message)s")
root_logger = logging.getLogger()
root_logger.setLevel(logging.INFO)

# Console Handler (Terminal)
console_handler = logging.StreamHandler(sys.stdout)
console_handler.setFormatter(log_formatter)
root_logger.addHandler(console_handler)

# File Handler (khabar_server.log)
file_handler = logging.FileHandler("khabar_server.log", encoding="utf-8")
file_handler.setFormatter(log_formatter)
root_logger.addHandler(file_handler)

from automated_ingestion import start_automated_ingestion
import asyncio

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Start the background task for FR-04 and FR-05 (Weather & Traffic polling)
    asyncio.create_task(start_automated_ingestion(orchestrator, firestore))
    yield

# ── App ──
app = FastAPI(
    title="KHABAR Crisis Intelligence API",
    description="Google Gemini-powered 4-agent crisis response pipeline",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Singletons ──
orchestrator = KhabarOrchestrator()
vision = GeminiVision()
speech = GeminiSpeech()

# ════════════════════════════════════════════
# ROOT
# ════════════════════════════════════════════
@app.get("/")
async def root():
    return {
        "status": "online",
        "system": "KHABAR Crisis Intelligence & Response Orchestrator",
        "version": "2.0.0",
        "ai_backend": "Google Gemini 2.5 Flash",
        "endpoints": {
            "POST /report/text":     "Submit text crisis report (Urdu/English/Roman Urdu)",
            "POST /report/image":    "Submit photo for Gemini Vision damage assessment",
            "POST /report/voice":    "Submit audio for Gemini Speech transcription",
            "GET  /incidents":       "Get all active incidents with P1-P5 priority queue",
            "GET  /incident/{id}":   "Get single incident with full agent trace",
            "GET  /resources":       "Get current resource inventory & rescue team status",
            "POST /action/execute":  "Manually trigger a tool action (coordinator mode)",
            "GET  /logs/{id}":       "Export Antigravity trace log for an incident",
        },
        "docs": "/docs",
    }


# ════════════════════════════════════════════
# ENDPOINT 1 — POST /report/text
# FR-01, FR-06, FR-07 to FR-11
# ════════════════════════════════════════════
class TextReportRequest(BaseModel):
    text: str
    lat: float = 33.6844
    lng: float = 73.0479


@app.post("/report/text")
async def report_text(request: TextReportRequest, background_tasks: BackgroundTasks):
    """
    Submit a text crisis report in English, Urdu, Roman Urdu, or Punjabi.
    Triggers the full 4-agent Gemini pipeline asynchronously.
    """
    signal_id = f"SIG-{int(datetime.now().timestamp())}-TXT"
    signal = RawCrisisSignal(
        signal_id=signal_id,
        source_type=InputSourceType.TEXT_ROMAN_URDU,
        raw_content=request.text,
        timestamp=datetime.now(timezone.utc).isoformat(),
        metadata={"lat": request.lat, "lng": request.lng},
    )

    # Run pipeline in background so response is immediate
    background_tasks.add_task(orchestrator.process_incident, signal)

    # Register incident immediately so polling can start
    orchestrator.memory_block.register_incident(signal)
    firestore.save_incident(signal_id, {
        "incident_id": signal_id,
        "status": "PROCESSING",
        "source": "text",
        "raw_input": request.text,
        "lat": request.lat,
        "lng": request.lng,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "traces": [f"[{datetime.now(timezone.utc).isoformat()}] [INGESTION] Text signal received. Pipeline starting..."],
    })

    return {
        "success": True,
        "incident_id": signal_id,
        "status": "PROCESSING",
        "message": "Signal accepted. 4-agent Gemini pipeline started.",
        "poll_url": f"/incident/{signal_id}",
    }


# ════════════════════════════════════════════
# ENDPOINT 2 — POST /report/image
# FR-02: Gemini Vision damage assessment
# ════════════════════════════════════════════
@app.post("/report/image")
async def report_image(
    image: UploadFile = File(...),
    lat: float = Form(default=33.6844),
    lng: float = Form(default=73.0479),
    description: str = Form(default=""),
    background_tasks: BackgroundTasks = None,
):
    """
    Submit a photo for Gemini Vision damage assessment.
    FR-02: System shall accept photo uploads and assess damage via Gemini Vision API.
    """
    signal_id = f"SIG-{int(datetime.now().timestamp())}-IMG"

    # Read image bytes
    image_bytes = await image.read()
    mime_type = image.content_type or "image/jpeg"

    # Run Gemini Vision analysis
    try:
        vision_result = vision.analyze_crisis_image(image_bytes, mime_type)
    except Exception as e:
        logging.error(f"Vision analysis error: {e}")
        vision_result = {
            "crisis_type": "unknown", "severity": "HIGH",
            "priority": "P2", "confidence": 0.3,
            "description": f"Vision failed: {str(e)}",
        }

    # Build enriched signal for pipeline
    combined_content = (
        f"[PHOTO REPORT] {description}\n"
        f"Vision Analysis: {vision_result.get('description', '')}\n"
        f"Detected: {', '.join(vision_result.get('detected_elements', []))}\n"
        f"Crisis Type: {vision_result.get('crisis_type', 'unknown')}"
    )
    signal = RawCrisisSignal(
        signal_id=signal_id,
        source_type=InputSourceType.IMAGE_SUMMARY,
        raw_content=combined_content,
        timestamp=datetime.now(timezone.utc).isoformat(),
        metadata={"lat": lat, "lng": lng, "vision_result": vision_result},
    )

    background_tasks.add_task(orchestrator.process_incident, signal)
    orchestrator.memory_block.register_incident(signal)

    firestore.save_incident(signal_id, {
        "incident_id": signal_id,
        "status": "PROCESSING",
        "source": "image",
        "vision_analysis": vision_result,
        "lat": lat, "lng": lng,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "traces": [
            f"[{datetime.now(timezone.utc).isoformat()}] [VISION] Gemini Vision: "
            f"{vision_result.get('crisis_type')} | Priority: {vision_result.get('priority')} | "
            f"Confidence: {int(float(vision_result.get('confidence', 0)) * 100)}%"
        ],
    })

    return {
        "success": True,
        "incident_id": signal_id,
        "status": "PROCESSING",
        "vision_analysis": vision_result,
        "message": "Photo analyzed by Gemini Vision. AI pipeline started.",
        "poll_url": f"/incident/{signal_id}",
    }


# ════════════════════════════════════════════
# ENDPOINT 3 — POST /report/voice
# FR-03: Gemini Speech transcription
# ════════════════════════════════════════════
@app.post("/report/voice")
async def report_voice(
    audio: UploadFile = File(...),
    lat: float = Form(default=33.6844),
    lng: float = Form(default=73.0479),
    background_tasks: BackgroundTasks = None,
):
    """
    Submit audio recording for Gemini multilingual transcription.
    FR-03: Supports Urdu, Punjabi, Sindhi, Roman Urdu, English.
    """
    signal_id = f"SIG-{int(datetime.now().timestamp())}-VOI"
    audio_bytes = await audio.read()
    mime_type = audio.content_type or "audio/wav"

    # Run Gemini Speech transcription
    try:
        speech_result = speech.transcribe_audio(audio_bytes, mime_type)
    except Exception as e:
        logging.error(f"Speech transcription error: {e}")
        speech_result = {
            "transcription_english": f"Transcription failed: {str(e)}",
            "detected_language": "unknown",
            "crisis_detected": True,
            "crisis_type": "unknown",
        }

    # Use English transcription as pipeline input
    transcribed = speech_result.get("transcription_english", "")
    combined = (
        f"[VOICE REPORT] Language: {speech_result.get('detected_language', 'unknown')}\n"
        f"Original: {speech_result.get('transcription_original', '')}\n"
        f"English: {transcribed}\n"
        f"Crisis keywords: {', '.join(speech_result.get('crisis_keywords', []))}"
    )

    signal = RawCrisisSignal(
        signal_id=signal_id,
        source_type=InputSourceType.VOICE_TRANSCRIPTION,
        raw_content=combined,
        timestamp=datetime.now(timezone.utc).isoformat(),
        metadata={"lat": lat, "lng": lng, "speech_result": speech_result},
    )

    background_tasks.add_task(orchestrator.process_incident, signal)
    orchestrator.memory_block.register_incident(signal)

    firestore.save_incident(signal_id, {
        "incident_id": signal_id,
        "status": "PROCESSING",
        "source": "voice",
        "speech_analysis": speech_result,
        "lat": lat, "lng": lng,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "traces": [
            f"[{datetime.now(timezone.utc).isoformat()}] [SPEECH] Gemini transcribed: "
            f"lang={speech_result.get('detected_language')} | "
            f"crisis={speech_result.get('crisis_detected')} | "
            f"\"{transcribed[:60]}...\""
        ],
    })

    return {
        "success": True,
        "incident_id": signal_id,
        "status": "PROCESSING",
        "speech_analysis": speech_result,
        "message": "Audio transcribed by Gemini Speech. AI pipeline started.",
        "poll_url": f"/incident/{signal_id}",
    }


# ════════════════════════════════════════════
# ENDPOINT 4 — GET /incidents
# FR-24: P1-P5 priority queue with live status
# ════════════════════════════════════════════
@app.get("/incidents")
async def get_incidents():
    """
    Get all active incidents in P1-P5 priority order.
    FR-24: Dashboard shall show the full P1-P5 priority queue with live status.
    """
    incidents = []

    # From in-memory pipeline (live processing)
    for inc_id, memory in orchestrator.memory_block.active_incidents.items():
        entry = {
            "incident_id": inc_id,
            "status": memory.system_state.status,
            "active_units": memory.system_state.active_units,
            "closed_roads": memory.system_state.closed_roads,
            "public_alerts_sent": memory.system_state.public_alerts_sent,
            "tickets": memory.system_state.tickets,
            "traces": memory.traces,
            "trace_count": len(memory.traces),
        }
        if memory.detection_output:
            entry.update({
                "incident_type": memory.detection_output.incident_type.value,
                "severity": memory.detection_output.severity.value,
                "priority": memory.detection_output.priority.value,
                "confidence": memory.detection_output.confidence_score,
                "location": memory.detection_output.detected_location.model_dump(),
            })
        if memory.execution_output:
            entry["before_state"] = memory.execution_output.before_state.model_dump()
            entry["after_state"] = memory.execution_output.after_state.model_dump()
            entry["state_diff"] = memory.execution_output.system_state_diff.model_dump()

        incidents.append(entry)

    # Also merge from Firestore (persisted incidents)
    firestore_incidents = firestore.get_all_incidents()
    fs_ids = {i.get("id") or i.get("incident_id") for i in firestore_incidents if i}
    memory_ids = {i.get("incident_id") for i in incidents if i}
    for fi in firestore_incidents:
        if fi:
            inc_id = fi.get("id") or fi.get("incident_id")
            if inc_id and inc_id not in memory_ids:
                incidents.append({**fi, "incident_id": inc_id})

    # Sort by priority (P1 first)
    priority_order = {"P1": 1, "P2": 2, "P3": 3, "P4": 4, "P5": 5}
    incidents.sort(key=lambda x: priority_order.get(x.get("priority", "P5"), 5))

    return {
        "total": len(incidents),
        "incidents": incidents,
        "resource_summary": {
            "ambulances_available": 50,
            "rescue_teams_available": 4,
            "dewatering_pumps": 10,
        },
    }


# ════════════════════════════════════════════
# ENDPOINT 5 — GET /incident/{id}
# FR-25: Full Antigravity agent reasoning trace
# ════════════════════════════════════════════
@app.get("/incident/{incident_id}")
async def get_incident(incident_id: str):
    """
    Get single incident with complete Gemini agent trace.
    FR-25: Dashboard shall render the complete agent reasoning trace.
    """
    # Check in-memory first (freshest)
    memory = orchestrator.memory_block.get_incident(incident_id)
    if memory:
        result = {
            "incident_id": incident_id,
            "status": memory.system_state.status,
            "traces": memory.traces,
            "system_state": memory.system_state.dict(),
        }
        if memory.detection_output:
            result["detection"] = json.loads(memory.detection_output.model_dump_json())
        if memory.analysis_output:
            result["analysis"] = json.loads(memory.analysis_output.model_dump_json())
        if memory.planning_output:
            result["planning"] = json.loads(memory.planning_output.model_dump_json())
        if memory.execution_output:
            result["execution"] = json.loads(memory.execution_output.model_dump_json())
            result["before_state"] = memory.execution_output.before_state.dict()
            result["after_state"] = memory.execution_output.after_state.dict()
            result["state_diff"] = memory.execution_output.system_state_diff.dict()
        return result

    # Fall back to Firestore
    fs_data = firestore.get_incident(incident_id)
    if fs_data:
        return fs_data

    raise HTTPException(status_code=404, detail=f"Incident '{incident_id}' not found.")


# ════════════════════════════════════════════
# ENDPOINT: GET /geocode
# Geocode queries securely via Google Maps API
# ════════════════════════════════════════════
@app.get("/geocode")
async def geocode(query: str):
    """
    Geocode address/query using Google Maps Geocoding API via MapsService
    """
    result = maps_service.geocode_location(query)
    return {
        "success": result["found"],
        "lat": result["lat"],
        "lng": result["lng"],
        "display_name": result["address"],
        "city": result["city"]
    }


# ════════════════════════════════════════════
# ENDPOINT 6 — GET /resources
# SRS Section 7.2: Resource Inventory
# ════════════════════════════════════════════
@app.get("/resources")
async def get_resources():
    """
    Get current resource inventory and rescue team status.
    """
    resources = firestore.get_resources()
    summary = {
        "rescue_teams": {"available": 0, "en_route": 0, "deployed": 0},
        "ambulances": {"available": 0, "en_route": 0},
        "dewatering_pumps": {"available": 0},
        "medical_kits": {"available": 0},
    }
    for r in resources:
        rtype = r.get("resource_type", "")
        status = r.get("status", "available")
        qty = r.get("quantity_available", 1)
        if rtype == "rescue_team":
            if status == "available":
                summary["rescue_teams"]["available"] += 1
            elif status == "en_route":
                summary["rescue_teams"]["en_route"] += 1
            else:
                summary["rescue_teams"]["deployed"] += 1
        elif rtype == "ambulance":
            key = "available" if status == "available" else "en_route"
            summary["ambulances"][key] = summary["ambulances"].get(key, 0) + qty
        elif rtype == "dewatering_pump":
            summary["dewatering_pumps"]["available"] += qty
        elif rtype == "medical_kit":
            summary["medical_kits"]["available"] += qty

    return {
        "resources": resources,
        "summary": summary,
        "last_updated": datetime.now(timezone.utc).isoformat(),
    }


# ════════════════════════════════════════════
# ENDPOINT 7 — POST /action/execute
# FR-18: Coordinator manual tool execution
# ════════════════════════════════════════════
class ActionRequest(BaseModel):
    incident_id: str
    action_type: str        # dispatch|alert|reroute|ticket|status
    agency: Optional[str] = None
    units: Optional[int] = 1
    message: Optional[str] = None
    location: Optional[str] = None
    new_status: Optional[str] = None


@app.post("/action/execute")
async def execute_action(request: ActionRequest):
    """
    Manually trigger a tool action (coordinator mode).
    FR-18: At minimum one action shall be fully simulated end-to-end.
    """
    from tool_system import (
        DispatchRescueTeam, BroadcastAlert, UpdateTrafficRoute,
        CreateEmergencyTicket, UpdateIncidentStatus
    )

    memory = orchestrator.memory_block.get_incident(request.incident_id)
    if not memory:
        raise HTTPException(status_code=404, detail=f"Incident {request.incident_id} not found.")

    action_type = request.action_type.lower()
    db_client = firestore
    result = {}

    if action_type == "dispatch":
        tool = DispatchRescueTeam(db_client)
        response = tool.run(memory.system_state, agency=request.agency or "Rescue 1122", units=request.units or 1)
        memory.system_state = response.after_state
        result = response.dict()

    elif action_type == "alert":
        msg = request.message or f"Emergency alert for incident {request.incident_id}"
        alert_result = alert_service.send_alert(msg, request.location or "Pakistan", incident_id=request.incident_id)
        memory.system_state.public_alerts_sent += 1
        result = alert_result

    elif action_type == "reroute":
        tool = UpdateTrafficRoute(db_client)
        response = tool.run(memory.system_state, close_road=request.location or "Main Road", detour_route="Alternate Route")
        memory.system_state = response.after_state
        result = response.dict()

    elif action_type == "ticket":
        tool = CreateEmergencyTicket(db_client)
        response = tool.run(memory.system_state, target_agency=request.agency or "NDMA", details=request.message or "Emergency", severity="HIGH")
        memory.system_state = response.after_state
        result = response.dict()

    elif action_type == "status":
        tool = UpdateIncidentStatus(db_client)
        response = tool.run(memory.system_state, new_status=request.new_status or "IN_PROGRESS", reason="Manual coordinator update")
        memory.system_state = response.after_state
        result = response.dict()
    else:
        raise HTTPException(status_code=400, detail=f"Unknown action_type: {action_type}. Use: dispatch|alert|reroute|ticket|status")

    orchestrator.push_to_firestore(memory)

    return {
        "success": True,
        "incident_id": request.incident_id,
        "action_executed": action_type,
        "result": result,
        "updated_state": memory.system_state.dict(),
    }


# ════════════════════════════════════════════
# ENDPOINT 8 — GET /logs/{id}
# SRS: Antigravity trace logs exportable as files
# ════════════════════════════════════════════
@app.get("/logs/{incident_id}")
async def export_logs(incident_id: str):
    """
    Export complete Gemini agent trace log for an incident.
    SRS: Agent transparency — trace logs must be exportable for submission.
    """
    memory = orchestrator.memory_block.get_incident(incident_id)
    if not memory:
        fs_data = firestore.get_incident(incident_id)
        if not fs_data:
            raise HTTPException(status_code=404, detail=f"Incident '{incident_id}' not found.")
        traces = fs_data.get("traces", [])
        detection = {}
    else:
        traces = memory.traces
        detection = json.loads(memory.detection_output.model_dump_json()) if memory.detection_output else {}

    log_content = {
        "incident_id": incident_id,
        "export_time": datetime.now(timezone.utc).isoformat(),
        "system": "KHABAR Crisis Intelligence & Response Orchestrator",
        "ai_backend": "Google Gemini 2.5 Flash",
        "agent_pipeline": ["Detection Agent", "Analysis Agent", "Planning Agent", "Execution Agent"],
        "detection_summary": detection,
        "trace_count": len(traces),
        "traces": traces,
    }

    return JSONResponse(
        content=log_content,
        headers={"Content-Disposition": f"attachment; filename=khabar_trace_{incident_id}.json"},
    )


class ChatRequest(BaseModel):
    message: str
    history: list[dict[str, str]] = []
    language: str = "English"
    user_location: Optional[str] = "Faizabad (Rawalpindi)"

@app.post("/chat")
async def chat(request: ChatRequest):
    """
    Direct Chat with Antigravity AI (Gemini 2.5 Flash).
    Guides user about emergencies, weather, safety, and dispatches in Islamabad/Rawalpindi.
    """
    try:
        # Enforce exact language response matching target language
        target_lang = request.language or "English"
        
        language_rule = ""
        if target_lang == "اردو":
            language_rule = "CRITICAL: You MUST write your response ONLY in pure Urdu language using the Arabic/Persian script (اردو رسم الخط). Do NOT use English or Roman Urdu."
        elif target_lang == "Roman Urdu":
            language_rule = "CRITICAL: You MUST write your response ONLY in Roman Urdu (Urdu written in Latin script, e.g., 'Aap kaise hain?', 'Hum help bhej rahe hain'). Do NOT use Arabic script or pure English."
        else:
            language_rule = "CRITICAL: You MUST write your response ONLY in English. Do NOT use Urdu script or Roman Urdu."

        user_loc = request.user_location or "Faizabad (Rawalpindi)"

        # Define rescue points resources targets in Islamabad & Rawalpindi
        # Fulfilling: "islamabad ka liya kam kara waha multiple points pa resources add kar dai... phir us hisab se user ki location ko dekh kar un resources ka ana ka time and AI user ko response kara"
        rescue_resources = [
            {"name": "Faizabad Rescue Hub", "sector": "Faizabad (Rawalpindi)", "ambulances": 5, "rescue_teams": 2, "lat": 33.6375, "lng": 73.0784},
            {"name": "Saddar WASA Station", "sector": "Saddar (Rawalpindi)", "dewatering_pumps": 4, "lat": 33.5984, "lng": 73.0544},
            {"name": "G-11 Fire Station & Rescue Unit", "sector": "Sector G-11 (Islamabad)", "fire_trucks": 3, "rescue_teams": 1, "lat": 33.6766, "lng": 73.0132},
            {"name": "F-6 Emergency Response Point", "sector": "Sector F-6 (Islamabad)", "ambulances": 2, "lat": 33.7299, "lng": 73.0746},
            {"name": "E-11 WASA Flood Relief Point", "sector": "Sector E-11 (Islamabad)", "dewatering_pumps": 3, "lat": 33.7001, "lng": 72.9812},
        ]

        # Calculate travel time and closest resource hub dynamically using Google Maps API
        geocoded = maps_service.geocode_location(user_loc)
        estimated_time = "15 to 20 minutes"
        nearest_resource = "Faizabad Rescue Hub"
        distance_str = "8.5 km"
        
        if geocoded.get("found"):
            closest_info = maps_service.calculate_closest_rescue_hub(geocoded["lat"], geocoded["lng"], rescue_resources)
            estimated_time = closest_info["duration"]
            nearest_resource = closest_info["name"]
            distance_str = closest_info["distance"]
        else:
            # Fallback if geocoding fails or is not found (simple matching logic)
            if "g-11" in user_loc.lower():
                estimated_time = "5 to 8 minutes"
                nearest_resource = "G-11 Fire Station & Rescue Unit"
                distance_str = "2.8 km"
            elif "f-6" in user_loc.lower():
                estimated_time = "6 to 10 minutes"
                nearest_resource = "F-6 Emergency Response Point"
                distance_str = "3.2 km"
            elif "e-11" in user_loc.lower():
                estimated_time = "7 to 12 minutes"
                nearest_resource = "E-11 WASA Flood Relief Point"
                distance_str = "4.5 km"
            elif "saddar" in user_loc.lower():
                estimated_time = "8 to 12 minutes"
                nearest_resource = "Saddar WASA Station"
                distance_str = "5.1 km"
            elif "faizabad" in user_loc.lower():
                estimated_time = "4 to 7 minutes"
                nearest_resource = "Faizabad Rescue Hub"
                distance_str = "1.8 km"
            elif "shamsabad" in user_loc.lower() or "lai" in user_loc.lower():
                estimated_time = "10 to 15 minutes"
                nearest_resource = "Faizabad Rescue Hub"
                distance_str = "6.2 km"

        system_prompt = f"""You are Antigravity AI, the dedicated chat assistant for KHABAR.
Your goal is to guide citizens in Islamabad and Rawalpindi during weather alerts, floods, fires, or regular safety enquiries.

CURRENT USER LOCATION CONTEXT:
The user has reported their current location/sector as: {user_loc}
The nearest emergency response point/station to them is: '{nearest_resource}'
Calculated response/travel time for help to reach this sector: '{estimated_time}' (precise driving distance: {distance_str})

LANGUAGE RULE:
{language_rule}

RULES:
1. ONLY provide services and information for Islamabad and Rawalpindi. If they ask about other cities like Karachi or Lahore, politely explain that KHABAR is currently active exclusively in Islamabad and Rawalpindi.
2. Provide highly comforting, warm, and clear responses.
3. If they describe a real emergency, advise them to go to the 'Report' tab immediately to submit a formal incident so the 4-agent dispatch pipeline can trigger WASA/Rescue 1122.
4. Keep guidelines actionable (Do's and Don'ts).
5. When they ask about help arrival, WASA, or Rescue teams, utilize the calculated travel time ({estimated_time}) and distance ({distance_str}) from '{nearest_resource}' and inform them.
6. Ensure response is cleanly formatted using bullet points where appropriate and avoid raw markdown symbols that look ugly.
"""
        messages = [{"role": "system", "content": system_prompt}]
        for h in request.history:
            role = h.get("role", "user")
            text = h.get("content", "")
            # OpenAI API roles must be either system, user, or assistant.
            # In history it's user or assistant
            openai_role = "assistant" if role == "assistant" or role == "model" else "user"
            messages.append({"role": openai_role, "content": text})
            
        messages.append({"role": "user", "content": request.message})
        
        client = orchestrator.detection_agent.llm_client.client
        model = orchestrator.detection_agent.llm_client.model
        
        response = await client.chat.completions.create(
            model=model,
            messages=messages,
            temperature=0.7,
        )
        
        return {
            "success": True,
            "response": response.choices[0].message.content
        }
    except Exception as e:
        logging.error(f"Chat error: {e}")
        return {
            "success": False,
            "error": str(e),
            "response": "Maazrat, main is waqt connect nahi ho pa raha. Bara-e-meharbani dobara koshish karein."
        }


# ════════════════════════════════════════════
# ENDPOINT: GET /live-news
# ════════════════════════════════════════════
@app.get("/live-news")
async def get_live_news():
    """
    Fetches real-time localized news alerts for Islamabad and Rawalpindi via SerpAPI Google News engine.
    Translates headlines for cross-language compatibility natively.
    """
    try:
        from serpapi import GoogleSearch
        
        # Enforce search query targeting rain, floods, WASA, Rescue 1122 and warnings in twin cities with last 7 days constraint
        search = GoogleSearch({
            "engine": "google_news",
            "q": "Islamabad Rawalpindi rain flood WASA OR Rescue 1122 OR alert when:7d",
            "gl": "pk",
            "hl": "en",
            "api_key": "e1310da5ab09d0c4bfb32e0bfc5e514c8c3a29248d2173eb666546c34fc4ca5c"
        })
        results = search.get_dict()
        news_results = results.get("news_results", [])
        
        formatted_news = []
        for news in news_results[:12]:
            title = news.get("title", "Local Emergency Update")
            
            # Simple clean up of publisher suffix
            clean_title = title
            source_name = "Local Source"
            if " - " in title:
                parts = title.rsplit(" - ", 1)
                clean_title = parts[0].strip()
                source_name = parts[1].strip()
            elif news.get("source", {}).get("name"):
                source_name = news["source"]["name"]

            # Dynamic Urdu Translation Mapping for localization compliance
            urdu_title = "قومی ہنگامی الرٹ رپورٹ"
            lower_title = clean_title.lower()
            if "rain" in lower_title or "storm" in lower_title or "monsoon" in lower_title:
                urdu_title = "شدید بارش اور طوفان کا الرٹ"
            elif "flood" in lower_title or "water" in lower_title or "nullah" in lower_title:
                urdu_title = "سائیکلون اور سیلاب کا خطرہ"
            elif "heat" in lower_title or "hot" in lower_title or "temperature" in lower_title:
                urdu_title = "شدید گرمی کی لہر کی وارننگ"
            elif "fire" in lower_title or "blast" in lower_title:
                urdu_title = "آگ لگنے کا ہنگامی واقعہ"
            elif "accident" in lower_title or "crash" in lower_title or "traffic" in lower_title:
                urdu_title = "ٹریفک حادثہ کی رپورٹ"
            elif "earthquake" in lower_title or "quake" in lower_title:
                urdu_title = "زلزلہ کے جھٹکے محسوس کیے گئے"

            formatted_news.append({
                "title": clean_title,
                "urduTitle": urdu_title,
                "source": source_name,
                "date": news.get("date", "Recently"),
                "link": news.get("link")
            })
            
        return formatted_news
    except Exception as e:
        logging.error(f"SerpAPI news error: {e}")
        # Return empty list to trigger RSS fallback safely on client
        return []


# ════════════════════════════════════════════
# HEALTH CHECK
# ════════════════════════════════════════════
@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "active_incidents": len(orchestrator.memory_block.active_incidents),
        "total_alerts_sent": alert_service.total_delivered,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


if __name__ == "__main__":
    import uvicorn
    print("\n" + "="*60)
    print("  KHABAR AI Backend — Google Gemini 2.5 Flash")
    print("  API: http://127.0.0.1:8000")
    print("  Docs: http://127.0.0.1:8000/docs")
    print("  Dashboard: http://127.0.0.1:8001")
    print("="*60 + "\n")
    uvicorn.run(app, host="0.0.0.0", port=8000)
