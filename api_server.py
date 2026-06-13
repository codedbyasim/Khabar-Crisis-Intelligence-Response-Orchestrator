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

from crew_orchestrator import KhabarCrewOrchestrator, RawCrisisSignal, InputSourceType
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
    description="AIML API + Local Gemma 4-agent crisis response pipeline",
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
orchestrator = KhabarCrewOrchestrator()
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
        "ai_backend": "AIML API (Gemini 2.5 Flash) + Local Gemma Fallback",
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


@app.get("/health")
async def health():
    """
    Check if the server and its internet connection are active.
    """
    import httpx
    has_internet = False
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get("https://www.google.com", timeout=2.0)
            has_internet = response.status_code == 200
    except Exception:
        has_internet = False

    return {
        "status": "online",
        "internet": has_internet,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }


@app.get("/live-news")
async def live_news():
    """
    Fetch live emergency and weather news for Islamabad and Rawalpindi from Google News RSS.
    """
    import httpx
    import xml.etree.ElementTree as ET
    url = "https://news.google.com/rss/search?q=Islamabad%20Rawalpindi%20(emergency%20OR%20floods%20OR%20rain%20OR%20weather%20OR%20crisis%20OR%20disaster)%20when:7d&hl=en-PK&gl=PK&ceid=PK:en"
    
    loaded_articles = []
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(url, timeout=5.0)
            if response.status_code == 200:
                root = ET.fromstring(response.text)
                items = root.findall(".//item")
                for item in items[:10]:
                    title_elem = item.find("title")
                    link_elem = item.find("link")
                    pub_date_elem = item.find("pubDate")
                    
                    title = title_elem.text if title_elem is not None else "Emergency Report"
                    link = link_elem.text if link_elem is not None else ""
                    pub_date = pub_date_elem.text if pub_date_elem is not None else "Just now"
                    
                    source_name = "Google News"
                    clean_title = title
                    if " - " in title:
                        parts = title.rsplit(" - ", 1)
                        clean_title = parts[0].strip()
                        source_name = parts[1].strip()
                    
                    urdu_title = "پاکستان ہنگامی الرٹ رپورٹ"
                    lower_title = clean_title.lower()
                    if "rain" in lower_title or "storm" in lower_title:
                        urdu_title = "شدید بارش اور طوفان کا الرٹ"
                    elif "flood" in lower_title or "water" in lower_title:
                        urdu_title = "سائیکلون اور سیلاب کا خطرہ"
                    elif "heat" in lower_title or "hot" in lower_title:
                        urdu_title = "شدید گرمی کی لہر کی وارننگ"
                    elif "fire" in lower_title:
                        urdu_title = "آگ لگنے کا ہنگامی واقعہ"
                    elif "accident" in lower_title or "crash" in lower_title:
                        urdu_title = "ٹریفک حادثہ کی رپورٹ"
                    elif "earthquake" in lower_title or "quake" in lower_title:
                        urdu_title = "زلزلہ کے جھٹکے محسوس کیے گئے"
                        
                    loaded_articles.append({
                        "title": clean_title,
                        "urduTitle": urdu_title,
                        "source": source_name,
                        "date": pub_date,
                        "link": link
                    })
    except Exception as e:
        logging.error(f"Error fetching live-news: {e}")
        
    if not loaded_articles:
        loaded_articles = [
            {
                "title": "Monsoon rain triggers flooding warning in Rawalpindi Nullah Lai",
                "urduTitle": "مون سون کی بارش نے راولپنڈی نالہ لئی میں سیلاب کی وارننگ جاری کر دی",
                "source": "CDA Weather Division",
                "date": "10 mins ago",
                "link": "https://news.google.com"
            },
            {
                "title": "Rescue teams deployed to Sector G-11 for emergency dewatering operations",
                "urduTitle": "ہنگامی ڈی واٹرنگ آپریشنز کے لیے سیکٹر G-11 میں امدادی ٹیمیں تعینات",
                "source": "WASA Islamabad",
                "date": "1 hour ago",
                "link": "https://news.google.com"
            },
            {
                "title": "CDA urges citizens of Islamabad to avoid low-lying roads during heavy rainfall",
                "urduTitle": "سی ڈی اے نے اسلام آباد کے شہریوں کو شدید بارش کے دوران نشیبی سڑکوں سے بچنے کی تاکید کی",
                "source": "CDA Admin",
                "date": "3 hours ago",
                "link": "https://news.google.com"
            }
        ]
        
    return loaded_articles


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
    image: Optional[UploadFile] = File(default=None),
    lat: float = Form(default=33.6844),
    lng: float = Form(default=73.0479),
    background_tasks: BackgroundTasks = None,
):
    """
    Submit audio recording with optional image for Gemini multilingual transcription & vision analysis.
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

    # Run optional image analysis
    vision_result = None
    if image is not None:
        try:
            image_bytes = await image.read()
            img_mime = image.content_type or "image/jpeg"
            vision_result = vision.analyze_crisis_image(image_bytes, img_mime)
        except Exception as e:
            logging.error(f"Image analysis during voice report failed: {e}")
            vision_result = {"description": f"Failed to analyze image: {e}"}

    # Use English transcription as pipeline input
    transcribed = speech_result.get("transcription_english", "")
    combined = (
        f"[VOICE REPORT] Language: {speech_result.get('detected_language', 'unknown')}\n"
        f"Original: {speech_result.get('transcription_original', '')}\n"
        f"English: {transcribed}\n"
        f"Crisis keywords: {', '.join(speech_result.get('crisis_keywords', []))}"
    )

    if vision_result:
        combined += (
            f"\n\n[ATTACHED IMAGE ANALYSIS]\n"
            f"Visual Details: {vision_result.get('description', '')}\n"
            f"Crisis: {vision_result.get('crisis_type', 'unknown')} | "
            f"Severity: {vision_result.get('severity', 'unknown')} | "
            f"Detected: {', '.join(vision_result.get('detected_elements', []))}"
        )

    signal = RawCrisisSignal(
        signal_id=signal_id,
        source_type=InputSourceType.VOICE_TRANSCRIPTION,
        raw_content=combined,
        timestamp=datetime.now(timezone.utc).isoformat(),
        metadata={"lat": lat, "lng": lng, "speech_result": speech_result, "vision_result": vision_result},
    )

    background_tasks.add_task(orchestrator.process_incident, signal)
    orchestrator.memory_block.register_incident(signal)

    firestore.save_incident(signal_id, {
        "incident_id": signal_id,
        "status": "PROCESSING",
        "source": "voice",
        "speech_analysis": speech_result,
        "vision_analysis": vision_result,
        "lat": lat, "lng": lng,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "traces": [
            f"[{datetime.now(timezone.utc).isoformat()}] [SPEECH] Gemini transcribed: "
            f"lang={speech_result.get('detected_language')} | "
            f"crisis={speech_result.get('crisis_detected')} | "
            f"\"{transcribed[:60]}...\"" + (f" | Image Attached and analyzed." if vision_result else "")
        ],
    })

    return {
        "success": True,
        "incident_id": signal_id,
        "status": "PROCESSING",
        "speech_analysis": speech_result,
        "vision_analysis": vision_result,
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
            loc_dict = memory.detection_output.detected_location.model_dump()
            loc_dict["is_verified"] = getattr(memory.detection_output, "is_verified", True)
            loc_dict["verification_reason"] = getattr(memory.detection_output, "verification_reason", "Verified")
            entry.update({
                "incident_type": memory.detection_output.incident_type.value,
                "severity": memory.detection_output.severity.value,
                "priority": memory.detection_output.priority.value,
                "confidence": memory.detection_output.confidence_score,
                "location": loc_dict,
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
# ENDPOINT — DELETE /incidents
# Clear database and in-memory incidents
# ════════════════════════════════════════════
@app.delete("/incidents")
async def clear_all_incidents():
    """
    Clear all incidents from both Postgres database and local memory.
    Resets resource statuses to 'available'.
    """
    try:
        # Clear in-memory active incidents in the orchestrator
        orchestrator.memory_block.active_incidents.clear()
        
        # Clear database and firestore fallback in-memory records
        firestore.clear_all_data()
        
        return {
            "success": True,
            "message": "All incidents successfully cleared and resource statuses reset to available."
        }
    except Exception as e:
        logging.error(f"Error resetting database/memory: {e}")
        raise HTTPException(status_code=500, detail=str(e))


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
# ENDPOINT — POST /resources/add
# Register a new resource unit dynamically
# ════════════════════════════════════════════
class AddResourceRequest(BaseModel):
    resource_id: str
    name: str
    resource_type: str
    quantity_available: int = 1
    status: str = "available"
    location: dict # {"lat": float, "lng": float}


@app.post("/resources/add")
async def add_resource(request: AddResourceRequest):
    """
    Endpoint to add a new resource to database inventory.
    """
    try:
        data = {
            "resource_id": request.resource_id,
            "name": request.name,
            "type": request.resource_type,
            "quantity_available": request.quantity_available,
            "status": request.status,
            "location": request.location
        }
        firestore._save_resource(request.resource_id, data)
        return {
            "success": True,
            "message": f"Resource {request.resource_id} successfully added.",
            "resource": data
        }
    except Exception as e:
        logging.error(f"Error adding resource: {e}")
        return {
            "success": False,
            "error": str(e)
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
        
        # Mark individual resource unit as deployed and link to incident
        try:
            resources = db_client.get_resources()
            target_agency = (request.agency or "Rescue 1122").lower()
            allocated = 0
            for r in resources:
                r_type = (r.get("resource_type") or r.get("type") or "").lower()
                r_name = (r.get("name") or "").lower()
                r_status = (r.get("status") or "available").lower()
                
                matches_agency = target_agency in r_name or target_agency in r_type or (
                    "wasa" in target_agency and "pump" in r_type
                ) or (
                    "rescue" in target_agency and "rescue" in r_type
                ) or (
                    "police" in target_agency and "police" in r_type
                )
                
                if matches_agency and r_status == "available":
                    db_client.update_resource_status(r["resource_id"], "deployed", request.incident_id)
                    allocated += 1
                    if allocated >= (request.units or 1):
                        break
        except Exception as e:
            logging.error(f"Error allocating database resources in execute_action: {e}")

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
        "ai_backend": "AIML API (Gemini 2.5 Flash) + Local Gemma Fallback",
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
            language_rule = "CRITICAL: You MUST write your response ONLY in pure Urdu language using the Arabic/Persian script (اردو رسم الخط). Do NOT write in English or Roman Urdu under any circumstances."
        elif target_lang == "Roman Urdu":
            language_rule = "CRITICAL: You MUST write your response ONLY in Roman Urdu (Urdu written in Latin/English script, e.g., 'Aap kaise hain?', 'Hum help bhej rahe hain', 'Islamabad ke emergency numbers yeh hain'). Do NOT write in Arabic script or English under any circumstances."
        else:
            language_rule = "CRITICAL: You MUST write your response ONLY in English. Do NOT write in Urdu script or Roman Urdu under any circumstances."

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
        
        lat = 33.6844
        lng = 73.0479
        if geocoded.get("found"):
            lat = geocoded["lat"]
            lng = geocoded["lng"]
            closest_info = maps_service.calculate_closest_rescue_hub(lat, lng, rescue_resources)
            estimated_time = closest_info["duration"]
            nearest_resource = closest_info["name"]
            distance_str = closest_info["distance"]
        else:
            # Fallback if geocoding fails or is not found (simple matching logic)
            if "g-11" in user_loc.lower():
                estimated_time = "5 to 8 minutes"
                nearest_resource = "G-11 Fire Station & Rescue Unit"
                distance_str = "2.8 km"
                lat, lng = 33.6766, 73.0132
            elif "f-6" in user_loc.lower():
                estimated_time = "6 to 10 minutes"
                nearest_resource = "F-6 Emergency Response Point"
                distance_str = "3.2 km"
                lat, lng = 33.7299, 73.0746
            elif "e-11" in user_loc.lower():
                estimated_time = "7 to 12 minutes"
                nearest_resource = "E-11 WASA Flood Relief Point"
                distance_str = "4.5 km"
                lat, lng = 33.7001, 72.9812
            elif "saddar" in user_loc.lower():
                estimated_time = "8 to 12 minutes"
                nearest_resource = "Saddar WASA Station"
                distance_str = "5.1 km"
                lat, lng = 33.5984, 73.0544
            elif "faizabad" in user_loc.lower():
                estimated_time = "4 to 7 minutes"
                nearest_resource = "Faizabad Rescue Hub"
                distance_str = "1.8 km"
                lat, lng = 33.6375, 73.0784
            elif "shamsabad" in user_loc.lower() or "lai" in user_loc.lower():
                estimated_time = "10 to 15 minutes"
                nearest_resource = "Faizabad Rescue Hub"
                distance_str = "6.2 km"
                lat, lng = 33.6375, 73.0784

        # Fetch live weather data using detection_agent's helper
        from detection_agent import get_live_weather
        weather_data = get_live_weather(lat, lng)
        weather_context_str = "Weather data currently unavailable."
        if weather_data:
            weather_context_str = (
                f"- Temperature: {weather_data.get('temperature_c')}°C\n"
                f"- Rain: {weather_data.get('rain_mm')} mm\n"
                f"- Showers: {weather_data.get('showers_mm')} mm\n"
                f"- Snowfall: {weather_data.get('snowfall_cm')} cm\n"
                f"- Wind Speed: {weather_data.get('wind_speed_kmh')} km/h"
            )

        # Fetch active incidents from PostgreSQL database via Firestore interface to inform chatbot of live news/incidents
        firestore_incidents = firestore.get_all_incidents()
        incidents_context = []
        for inc in firestore_incidents:
            if not inc:
                continue
            inc_id = inc.get("incident_id")
            inc_type = inc.get("incident_type") or "Emergency"
            status = inc.get("status") or "ACTIVE"
            priority = inc.get("priority") or "P3"
            
            # Location details
            loc = inc.get("location") or {}
            loc_str = "Islamabad/Rawalpindi"
            if isinstance(loc, dict):
                loc_str = loc.get("address") or loc.get("location_name") or f"coordinates: {inc.get('lat')}, {inc.get('lng')}"
            else:
                loc_str = str(loc)
            
            incidents_context.append(
                f"- ID: {inc_id} | Type: {inc_type} | Location: {loc_str} | Priority/Severity: {priority} | Status: {status}"
            )
        
        if incidents_context:
            incidents_list_str = "\n".join(incidents_context)
        else:
            incidents_list_str = "No active incidents currently reported in the database."

        system_prompt = f"""You are Khabar Chatbot, the dedicated chat assistant for KHABAR.
Your goal is to guide citizens in Islamabad and Rawalpindi during weather alerts, floods, fires, or regular safety enquiries.

CURRENT USER LOCATION CONTEXT:
The user has reported their current location/sector as: {user_loc}
The nearest emergency response point/station to them is: '{nearest_resource}'
Calculated response/travel time for help to reach this sector: '{estimated_time}' (precise driving distance: {distance_str})

LIVE WEATHER SENSOR CONTEXT (Open-Meteo):
{weather_context_str}

SYSTEM CONTEXT — ACTIVE REPORTED INCIDENTS IN DATABASE:
{incidents_list_str}

RULES:
1. LANGUAGE COMPLIANCE: {language_rule} This is your most critical instruction. You must write your entire response ONLY in the target language specified.
2. ONLY provide services and information for Islamabad and Rawalpindi. If they ask about other cities like Karachi or Lahore, politely explain that KHABAR is currently active exclusively in Islamabad and Rawalpindi.
3. Provide highly comforting, warm, and clear responses.
4. If they describe a real emergency, advise them to go to the 'Report' tab immediately to submit a formal incident so the 4-agent dispatch pipeline can trigger WASA/Rescue 1122.
5. Keep guidelines actionable (Do's and Don'ts).
6. When they ask about help arrival, WASA, or Rescue teams, utilize the calculated travel time ({estimated_time}) and distance ({distance_str}) from '{nearest_resource}' and inform them.
7. Ensure response is cleanly formatted using bullet points where appropriate and avoid raw markdown symbols that look ugly.
8. When users ask about what incidents occurred or where they occurred (e.g., 'Kahan kahan incident huva hai?', 'Any active news or emergencies?'), look at the 'SYSTEM CONTEXT — ACTIVE REPORTED INCIDENTS IN DATABASE' above and describe exactly where they happened, what type they are, and their current priority/status. Be specific and helpful.
9. When users ask about the weather, temperature, rain, or storm conditions, check the 'LIVE WEATHER SENSOR CONTEXT (Open-Meteo)' above and describe the current conditions for their location in detail, offering safety tips if conditions are severe.

FINAL REMINDER: The user's language is {target_lang}. You MUST follow the language rule: {language_rule}
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
        logging.warning(f"Online chat error: {e}. Falling back to local Qwen model...")
        import local_model
        try:
            target_lang = request.language or "English"
            if target_lang in ("ur", "اردو", "Urdu"):
                lang_code = "ur"
            elif target_lang in ("roman", "Roman Urdu"):
                lang_code = "roman"
            else:
                lang_code = "en"
            response_text = local_model.generate_chat_response(
                message=request.message,
                language=lang_code,
                sector=user_loc,
            )
            return {
                "success": True,
                "response": f"{response_text}\n\n_[🤖 Local AI Fallback Mode — No Internet]_",
            }
        except Exception as local_err:
            logging.error(f"Local fallback chat error: {local_err}")
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
            "api_key": os.getenv("SERPAPI_KEY")
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
        logging.warning(f"SerpAPI news error: {e}. Generating offline local fallback news...")
        
        # Build dynamic news from active database incidents if any
        fallback_news = []
        try:
            firestore_incidents = firestore.get_all_incidents()
        except Exception:
            firestore_incidents = []
            
        for inc in firestore_incidents:
            if not inc:
                continue
            inc_id = inc.get("incident_id", "KH-000")
            inc_type = inc.get("incident_type") or "Emergency"
            loc = inc.get("location") or {}
            loc_str = "Islamabad/Rawalpindi"
            if isinstance(loc, dict):
                loc_str = loc.get("address") or loc.get("location_name") or "Twin Cities"
            else:
                loc_str = str(loc)
            priority = inc.get("priority", "P3")
            status = inc.get("status", "ACTIVE")
            
            fallback_news.append({
                "title": f"Incident {inc_type} at {loc_str} is currently {status} ({priority} alert)",
                "urduTitle": f"ہنگامی الرٹ: {loc_str} پر {inc_type} کی کارروائی جاری ہے ({priority})",
                "source": "Khabar Incident Feed",
                "date": "Just now",
                "link": None
            })
            
        # Add general WASA/CDA standby news so we always have content
        fallback_news.extend([
            {
                "title": "WASA Rawalpindi monitors water levels at Nullah Lai (Currently Normal)",
                "urduTitle": "واسا راولپنڈی: نالہ لئی میں پانی کی سطح کی نگرانی جاری ہے (معمول پر)",
                "source": "WASA Telemetry",
                "date": "5 mins ago",
                "link": None
            },
            {
                "title": "CDA Islamabad launches monsoon drainage cleaning campaign across sectors",
                "urduTitle": "سی ڈی اے اسلام آباد: مون سون سے قبل نالوں کی صفائی کی مہم شروع",
                "source": "CDA Public Feed",
                "date": "15 mins ago",
                "link": None
            },
            {
                "title": "Emergency Response Teams on high standby in Faizabad & G-11 Hubs",
                "urduTitle": "ریسکیو 1122: فیض آباد اور جی الیون ہب پر ٹیمیں الرٹ پر ہیں",
                "source": "Rescue 1122 Feed",
                "date": "30 mins ago",
                "link": None
            }
        ])
        
        return fallback_news


# ════════════════════════════════════════════
# ENDPOINT — POST /local-chat
# Offline AI chat using local Gemma GGUF model
# No internet required — uses H:\khabar\models\gemma-4-E2B-it-UD-IQ2_M.gguf
# ════════════════════════════════════════════
class LocalChatRequest(BaseModel):
    message: str
    language: str = "English"
    sector: str = "Islamabad"


@app.post("/local-chat")
async def local_chat(request: LocalChatRequest):
    """
    Offline AI chat powered by local Qwen GGUF model.
    Uses H:\\khabar\\models\\Qwen2.5-0.5B-Instruct-Q4_K_M.gguf.
    No internet connection required. Ideal for disaster/offline scenarios.
    """
    import local_model
    try:
        target_lang = request.language or "English"
        if target_lang in ("ur", "اردو", "Urdu"):
            lang_code = "ur"
        elif target_lang in ("roman", "Roman Urdu"):
            lang_code = "roman"
        else:
            lang_code = "en"
        response_text = local_model.generate_chat_response(
            message=request.message,
            language=lang_code,
            sector=request.sector,
        )
        return {
            "success": True,
            "response": response_text,
            "mode": "local_qwen" if local_model.is_available() else "error_fallback",
            "model": "Qwen2.5-0.5B-Instruct-Q4_K_M.gguf" if local_model.is_available() else "none",
        }
    except Exception as e:
        logging.error(f"[local-chat] Error: {e}")
        return {
            "success": False,
            "response": "Koi emergency ho toh Rescue 1122 ya Police 15 call karein.",
            "mode": "error_fallback",
        }


# ════════════════════════════════════════════
# ENDPOINT: POST /admin/chat
# Intelligent command assistant for emergency coordinator dashboard
# ════════════════════════════════════════════
class AdminChatRequest(BaseModel):
    message: str
    history: list[dict[str, str]] = []
    language: Optional[str] = "English"


@app.post("/admin/chat")
async def admin_chat(request: AdminChatRequest):
    """
    Intelligent chatbot for emergency coordinators in the admin dashboard.
    Can analyze the active incidents/resources and execute tool actions based on commands.
    """
    import re
    # 1. Fetch active incidents from PostgreSQL / in-memory orchestrator memory block
    active_incidents = []
    
    # In-memory incidents (currently processing)
    for inc_id, memory in orchestrator.memory_block.active_incidents.items():
        loc_str = "Unknown"
        if memory.detection_output:
            loc = memory.detection_output.detected_location
            lat = memory.raw_signal.metadata.get("lat") if memory.raw_signal and memory.raw_signal.metadata else None
            lng = memory.raw_signal.metadata.get("lng") if memory.raw_signal and memory.raw_signal.metadata else None
            lat_lng_str = f" (lat: {lat}, lng: {lng})" if lat is not None and lng is not None else ""
            loc_str = f"{loc.area or ''} {loc.city or ''}{lat_lng_str}".strip()
            if not loc_str:
                loc_str = "Unknown"
        active_incidents.append({
            "incident_id": inc_id,
            "type": memory.detection_output.incident_type.value if memory.detection_output else "Unknown",
            "priority": memory.detection_output.priority.value if memory.detection_output else "P3",
            "status": memory.system_state.status,
            "location": loc_str,
            "active_units": memory.system_state.active_units,
            "closed_roads": memory.system_state.closed_roads,
            "public_alerts": memory.system_state.public_alerts_sent,
        })
        
    # Firestore / Postgres database incidents
    try:
        firestore_incidents = firestore.get_all_incidents()
        memory_ids = {i["incident_id"] for i in active_incidents}
        for fi in firestore_incidents:
            if fi:
                inc_id = fi.get("incident_id")
                if inc_id and inc_id not in memory_ids:
                    loc = fi.get("location") or {}
                    loc_str = loc.get("address") or loc.get("location_name") or f"lat: {fi.get('lat')}, lng: {fi.get('lng')}"
                    active_incidents.append({
                        "incident_id": inc_id,
                        "type": fi.get("incident_type") or "Emergency",
                        "priority": fi.get("priority") or "P3",
                        "status": fi.get("status") or "ACTIVE",
                        "location": loc_str,
                        "active_units": fi.get("active_units") or 0,
                        "closed_roads": fi.get("closed_roads") or [],
                        "public_alerts": fi.get("public_alerts_sent") or 0,
                    })
    except Exception as e:
        logging.error(f"Error fetching incidents for admin chat: {e}")

    # Format incidents string
    incidents_list_str = ""
    for inc in active_incidents:
        incidents_list_str += f"- ID: {inc['incident_id']} | Type: {inc['type']} | Priority: {inc['priority']} | Status: {inc['status']} | Location: {inc['location']} | Units Assigned: {inc['active_units']} | Closed Roads: {inc['closed_roads']}\n"
    if not incidents_list_str:
        incidents_list_str = "No active emergency incidents recorded in the system."

    # 2. Fetch resources
    try:
        resources = firestore.get_resources()
    except Exception:
        resources = []
        
    resources_list_str = ""
    for res in resources:
        resources_list_str += f"- ID: {res.get('resource_id')} | Name: {res.get('name')} | Type: {res.get('resource_type') or res.get('type')} | Status: {res.get('status')} | Quantity: {res.get('quantity_available', res.get('quantity', 1))}\n"
    if not resources_list_str:
        resources_list_str = "No resources cataloged in database inventory."

    # Construct the System Prompt
    system_prompt = f"""You are Khabar Admin Command Assistant, the administrative agent for the emergency response dashboard.
You help emergency coordinators analyze situations, manage resources, and execute operations.

CURRENT SYSTEM STATE:
---
ACTIVE EMERGENCY INCIDENTS:
{incidents_list_str}

RESOURCE INVENTORY:
{resources_list_str}
---

AVAILABLE COMMANDS:
You can execute coordinator commands by including a special command tag in your response. The system parses and executes it automatically.
Command syntax rules:
- Dispatch resources:
  [EXECUTE: dispatch, incident_id="<id>", agency="<agency>", units=<number>]
  (Agencies: "Rescue 1122", "NDMA", "WASA", "Traffic Police", "Edhi Foundation")
- Broadcast public warning:
  [EXECUTE: alert, incident_id="<id>", message="<alert message>", location="<location name>"]
- Update traffic detour:
  [EXECUTE: reroute, incident_id="<id>", location="<road name to close>"]
- Create support ticket:
  [EXECUTE: ticket, incident_id="<id>", agency="<NDMA|WASA|CDA>", message="<details>"]
- Update incident status:
  [EXECUTE: status, incident_id="<id>", new_status="<IN_PROGRESS|RESOLVED|CLOSED|REJECTED>"]
- Add new resource unit:
  [EXECUTE: add_resource, resource_id="<id>", name="<name>", resource_type="<rescue_team|ambulance|dewatering_pump|medical_kit>", quantity_available=<number>, lat=<latitude>, lng=<longitude>]
- Clear all system incidents/data:
  [EXECUTE: clear_database]

RULES:
1. Trigger commands ONLY when the user asks you to perform an action (e.g. "dispatch NDMA", "clear db", "mark as resolved", "alert sector F-7", "close Murree Road").
2. Include the EXACT [EXECUTE: ...] tag at the start of your message, followed by an explanation of what action you are taking.
3. For situation summaries, analyze active cases, priorities, hotspots, and give recommendations.
4. Keep a highly professional, prompt, and direct tone. Match the language the user speaks (English, Urdu, or Roman Urdu).
"""

    messages = [{"role": "system", "content": system_prompt}]
    for h in request.history:
        role = "assistant" if h.get("role") in ("assistant", "model") else "user"
        messages.append({"role": role, "content": h.get("content", "")})
    messages.append({"role": "user", "content": request.message})

    response_text = ""
    command_executed = None
    
    # Try online AIML API only (no local fallback, fast response)
    try:
        client = orchestrator.detection_agent.llm_client.client
        model = orchestrator.detection_agent.llm_client.model
        
        response = await asyncio.wait_for(
            client.chat.completions.create(
                model=model,
                messages=messages,
                temperature=0.3,
            ),
            timeout=10.0
        )
        response_text = response.choices[0].message.content
        logging.info("[Admin Chat] ✅ Successful response from AIML API")
    except Exception as e:
        logging.error(f"[Admin Chat] AIML API call failed or timed out: {e}")
        return {
            "success": False,
            "error": "AIML API is temporarily slow or offline. Please try again.",
            "response": None,
        }

    # Parse command tag
    match = re.search(r'\[EXECUTE:\s*(\w+)(.*?)\]', response_text)
    if match:
        action_type = match.group(1).lower().strip()
        args_str = match.group(2)
        
        args = {}
        for key, val1, val2, val3 in re.findall(r'(\w+)\s*=\s*(?:"([^"]*)"|\'([^\']*)\'|([^\s,\]]+))', args_str):
            val = val1 or val2 or val3
            args[key] = val
            
        logging.info(f"[Admin Chat Command] Intercepted: {action_type} with args: {args}")
        
        try:
            from tool_system import (
                DispatchRescueTeam, BroadcastAlert, UpdateTrafficRoute,
                CreateEmergencyTicket, UpdateIncidentStatus
            )
            
            db_client = firestore
            
            if action_type == "clear_database":
                orchestrator.memory_block.active_incidents.clear()
                db_client.clear_all_data()
                command_executed = {
                    "action_type": "clear_database",
                    "success": True,
                    "detail": "All incidents cleared and resources reset successfully."
                }
            
            elif action_type == "add_resource":
                res_id = args.get("resource_id") or f"RES-{int(datetime.now().timestamp())}"
                name = args.get("name") or "Rescue Unit"
                res_type = args.get("resource_type") or "rescue_team"
                qty = int(args.get("quantity_available") or 1)
                lat = float(args.get("lat") or 33.6844)
                lng = float(args.get("lng") or 73.0479)
                
                data = {
                    "resource_id": res_id,
                    "name": name,
                    "type": res_type,
                    "quantity_available": qty,
                    "status": "available",
                    "location": {"lat": lat, "lng": lng}
                }
                db_client._save_resource(res_id, data)
                command_executed = {
                    "action_type": "add_resource",
                    "success": True,
                    "detail": f"Successfully registered resource '{name}' ({res_type}) in system."
                }
            
            else:
                inc_id = args.get("incident_id")
                memory = orchestrator.memory_block.get_incident(inc_id) if inc_id else None
                
                if not inc_id:
                    command_executed = {
                        "action_type": action_type,
                        "success": False,
                        "detail": "Failed: incident_id is required for this operation."
                    }
                elif not memory:
                    command_executed = {
                        "action_type": action_type,
                        "success": False,
                        "detail": f"Failed: Incident ID '{inc_id}' is not active in memory queue."
                    }
                else:
                    if action_type == "dispatch":
                        tool = DispatchRescueTeam(db_client)
                        response = tool.run(
                            memory.system_state,
                            agency=args.get("agency") or "Rescue 1122",
                            units=int(args.get("units") or 1)
                        )
                        memory.system_state = response.after_state
                        orchestrator.push_to_firestore(memory)
                        command_executed = {
                            "action_type": "dispatch",
                            "success": True,
                            "detail": f"Dispatched {args.get('units', 1)} unit(s) of {args.get('agency', 'Rescue 1122')}."
                        }
                        
                        # Mark individual resource unit as deployed and link to incident
                        try:
                            resources = db_client.get_resources()
                            target_agency = (args.get("agency") or "Rescue 1122").lower()
                            allocated = 0
                            for r in resources:
                                r_type = (r.get("resource_type") or r.get("type") or "").lower()
                                r_name = (r.get("name") or "").lower()
                                r_status = (r.get("status") or "available").lower()
                                
                                matches_agency = target_agency in r_name or target_agency in r_type or (
                                    "wasa" in target_agency and "pump" in r_type
                                ) or (
                                    "rescue" in target_agency and "rescue" in r_type
                                ) or (
                                    "police" in target_agency and "police" in r_type
                                )
                                
                                if matches_agency and r_status == "available":
                                    db_client.update_resource_status(r["resource_id"], "deployed", inc_id)
                                    allocated += 1
                                    if allocated >= int(args.get("units") or 1):
                                        break
                        except Exception as e:
                            logging.error(f"Error allocating database resources in admin_chat dispatch: {e}")
                    
                    elif action_type == "alert":
                        msg = args.get("message") or f"Emergency warning for {inc_id}"
                        loc = args.get("location") or "Islamabad"
                        alert_service.send_alert(msg, loc, incident_id=inc_id)
                        memory.system_state.public_alerts_sent += 1
                        orchestrator.push_to_firestore(memory)
                        command_executed = {
                            "action_type": "alert",
                            "success": True,
                            "detail": f"Broadcasted public warning message to '{loc}'."
                        }
                        
                    elif action_type == "reroute":
                        tool = UpdateTrafficRoute(db_client)
                        loc = args.get("location") or "Main Road"
                        response = tool.run(
                            memory.system_state,
                            close_road=loc,
                            detour_route="Alternate Route"
                        )
                        memory.system_state = response.after_state
                        orchestrator.push_to_firestore(memory)
                        command_executed = {
                            "action_type": "reroute",
                            "success": True,
                            "detail": f"Road '{loc}' closed and traffic detours updated."
                        }
                        
                    elif action_type == "ticket":
                        tool = CreateEmergencyTicket(db_client)
                        agency = args.get("agency") or "NDMA"
                        msg = args.get("message") or "Emergency warning details"
                        response = tool.run(
                            memory.system_state,
                            target_agency=agency,
                            details=msg,
                            severity="HIGH"
                        )
                        memory.system_state = response.after_state
                        orchestrator.push_to_firestore(memory)
                        command_executed = {
                            "action_type": "ticket",
                            "success": True,
                            "detail": f"Emergency ticket opened with agency '{agency}'."
                        }
                        
                    elif action_type == "status":
                        tool = UpdateIncidentStatus(db_client)
                        status_val = args.get("new_status") or "IN_PROGRESS"
                        response = tool.run(
                            memory.system_state,
                            new_status=status_val,
                            reason="Coordinator command assistant override"
                        )
                        memory.system_state = response.after_state
                        orchestrator.push_to_firestore(memory)
                        command_executed = {
                            "action_type": "status",
                            "success": True,
                            "detail": f"Incident status updated to '{status_val}'."
                        }
            
            response_text = re.sub(r'\[EXECUTE:\s*\w+.*?\]', '', response_text).strip()
            
        except Exception as ex:
            logging.error(f"Command execution failed in Admin Chat: {ex}")
            command_executed = {
                "action_type": action_type,
                "success": False,
                "detail": f"Execution failed: {str(ex)}"
            }
            response_text = re.sub(r'\[EXECUTE:\s*\w+.*?\]', '', response_text).strip()

    return {
        "success": True,
        "response": response_text,
        "command_executed": command_executed
    }


# ════════════════════════════════════════════
# HEALTH CHECK
# ════════════════════════════════════════════
@app.get("/health")
async def health():
    # Check if the backend server itself has internet access
    # This is used by the Flutter app's self-healing connectivity logic:
    # If the Android emulator can't reach google.com directly, it asks the backend.
    internet_ok = False
    try:
        import urllib.request as _urlreq
        _urlreq.urlopen("https://www.google.com", timeout=3)
        internet_ok = True
    except Exception:
        internet_ok = False

    return {
        "status": "healthy",
        "internet": internet_ok,
        "active_incidents": len(orchestrator.memory_block.active_incidents),
        "total_alerts_sent": alert_service.total_delivered,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


if __name__ == "__main__":
    import uvicorn
    print("\n" + "="*60)
    print("  KHABAR AI Backend — AIML API (Gemini 2.5 Flash)")
    print("  API: http://127.0.0.1:8000")
    print("  Docs: http://127.0.0.1:8000/docs")
    print("  Dashboard: http://127.0.0.1:8001")
    print("="*60 + "\n")
    uvicorn.run(app, host="0.0.0.0", port=8000)
