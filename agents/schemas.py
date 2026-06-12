"""
schemas.py — Centralized Pydantic models for KHABAR CrewAI pipeline.
All data contracts for the 4-agent pipeline in one place.
Previously scattered across detection_agent.py, analysis_agent.py,
planning_agent.py, execution_agent.py, and tool_system.py.
"""
from enum import Enum
from typing import List, Dict, Any, Optional
from pydantic import BaseModel, Field


# ============================================================
# RAW SIGNAL SCHEMA (Input to pipeline)
# ============================================================

class InputSourceType(str, Enum):
    TEXT_URDU = "urdu_text"
    TEXT_ROMAN_URDU = "roman_urdu"
    TEXT_ENGLISH = "english_text"
    SOCIAL_MEDIA = "social_media_complaint"
    VOICE_TRANSCRIPTION = "voice_transcription"
    IMAGE_SUMMARY = "image_analysis_summary"
    WEATHER_ALERT = "weather_alert"
    TRAFFIC_ALERT = "traffic_alert"


class RawCrisisSignal(BaseModel):
    signal_id: str = Field(..., description="Unique identifier for the incoming signal")
    source_type: InputSourceType = Field(..., description="Type of input source")
    raw_content: str = Field(..., description="Raw unstructured text from the signal")
    timestamp: str = Field(..., description="ISO 8601 timestamp of the signal")
    metadata: Optional[Dict[str, Any]] = Field(
        default={}, description="Additional metadata like GPS coords, author, etc."
    )


# ============================================================
# DETECTION AGENT OUTPUT SCHEMA
# ============================================================

class IncidentType(str, Enum):
    URBAN_FLOOD = "urban flood"
    ROAD_ACCIDENT = "road accident"
    BUILDING_COLLAPSE = "building collapse"
    FIRE = "fire"
    HEATWAVE = "heatwave"
    ROAD_BLOCKAGE = "road blockage"
    INFRASTRUCTURE_FAILURE = "infrastructure failure"
    MEDICAL_EMERGENCY = "medical emergency"
    UNKNOWN = "unknown"


class Severity(str, Enum):
    CRITICAL = "CRITICAL"
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"


class PriorityLevel(str, Enum):
    P1 = "P1"
    P2 = "P2"
    P3 = "P3"
    P4 = "P4"
    P5 = "P5"


class DetectedLocation(BaseModel):
    city: Optional[str] = Field(None, description="Extracted city name")
    area: Optional[str] = Field(None, description="Extracted local area or landmark")
    raw_location_mentions: List[str] = Field(
        default=[], description="Exact location phrases from the signal"
    )


class DetectionOutput(BaseModel):
    incident_type: IncidentType
    severity: Severity
    priority: PriorityLevel
    confidence_score: float = Field(..., ge=0.0, le=1.0)
    detected_location: DetectedLocation
    normalized_input: str = Field(..., description="Cleaned English version of the input")
    reasoning_trace: str = Field(..., description="Step-by-step classification reasoning")
    urgency_flags: List[str] = Field(default=[])
    is_verified: bool = Field(
        default=True,
        description="False if spam, casual talk, or weather contradiction detected"
    )
    verification_reason: str = Field(
        default="Standard report validation",
        description="Reason for the verification decision"
    )


# ============================================================
# ANALYSIS AGENT OUTPUT SCHEMA
# ============================================================

class CongestionLevel(str, Enum):
    NONE = "NONE"
    MODERATE = "MODERATE"
    HEAVY = "HEAVY"
    GRIDLOCK = "GRIDLOCK"


class ResponseDifficulty(str, Enum):
    EASY = "EASY"
    MODERATE = "MODERATE"
    HARD = "HARD"
    EXTREME = "EXTREME"


class Facility(BaseModel):
    name: str
    distance_km: float
    estimated_travel_time_mins: int
    status: str = Field(default="UNKNOWN")


class AnalysisOutput(BaseModel):
    impact_score: float = Field(..., ge=0.0, le=100.0)
    affected_people: int
    affected_vehicles: int
    nearby_hospitals: List[Facility]
    nearby_infrastructure: List[str]
    secondary_risks: List[str]
    response_difficulty: ResponseDifficulty
    congestion_level: CongestionLevel
    analysis_reasoning: str
    english_summary: str
    urdu_summary: str


# ============================================================
# PLANNING AGENT OUTPUT SCHEMA
# ============================================================

class ActionType(str, Enum):
    DISPATCH_RESCUE = "dispatch rescue"
    REROUTE_TRAFFIC = "reroute traffic"
    ALLOCATE_SUPPLIES = "allocate supplies"
    SEND_URDU_ALERTS = "send Urdu alerts"
    NOTIFY_AGENCIES = "notify agencies"
    CREATE_EMERGENCY_TICKETS = "create emergency tickets"
    DEPLOY_AMBULANCE = "deploy ambulance"
    ACTIVATE_HEATWAVE_RESPONSE = "activate heatwave response"


class Agency(str, Enum):
    RESCUE_1122 = "Rescue 1122"
    NDMA = "NDMA"
    PDMA = "PDMA"
    TRAFFIC_POLICE = "Traffic Police"
    POLICE = "Police"
    WASA = "WASA"
    K_ELECTRIC = "K-Electric"
    EDHI = "Edhi Foundation"
    CHHIPA = "Chhipa"
    SUI_GAS = "Sui Gas"
    WAPDA = "WAPDA"
    OTHER = "Other"


class ActionPriority(str, Enum):
    P1_IMMEDIATE = "P1_IMMEDIATE"
    P2_URGENT = "P2_URGENT"
    P3_STANDARD = "P3_STANDARD"


class RecommendedAction(BaseModel):
    action_type: ActionType
    priority: ActionPriority
    target_agency: Agency
    description: str
    required_units: int = Field(default=0)


class EscalationRisk(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class PlanningOutput(BaseModel):
    recommended_actions: List[RecommendedAction]
    action_priority: str
    resource_requirements: Dict[str, int]
    response_strategy: str
    estimated_resolution_time: str
    escalation_risk: EscalationRisk
    planning_reasoning: str
    fallback_actions: List[RecommendedAction] = Field(default=[])


# ============================================================
# EXECUTION AGENT OUTPUT SCHEMA
# ============================================================

class LogEntry(BaseModel):
    timestamp: str
    level: str
    message: str


class ToolResult(BaseModel):
    tool_name: str
    status: str
    output: Any


class ExecutedAction(BaseModel):
    action: str
    agency: str
    success: bool
    tool_results: List[ToolResult]


class StateDiff(BaseModel):
    changed_keys: List[str]
    descriptions: List[str]


class ExecutionOutput(BaseModel):
    execution_logs: List[LogEntry]
    executed_actions: List[ExecutedAction]
    before_state: Dict[str, Any]
    after_state: Dict[str, Any]
    system_state_diff: StateDiff
    timestamps: Dict[str, str] = Field(default_factory=dict)
    execution_reasoning: str
    generated_alerts: List[str]
    final_outcome: str


# ============================================================
# SHARED MUTABLE SYSTEM STATE (updated by execution tools)
# ============================================================

class SystemState(BaseModel):
    incident_id: str
    status: str = "OPEN"
    active_units: Dict[str, int] = Field(default_factory=dict)
    allocated_supplies: Dict[str, int] = Field(default_factory=dict)
    closed_roads: List[str] = Field(default_factory=list)
    public_alerts_sent: int = 0
    tickets: List[str] = Field(default_factory=list)
    knowledge_queries: int = 0
    last_update: str = ""


# ============================================================
# INCIDENT MEMORY (shared state across the pipeline, stored
# in SharedMemoryBlock — same as before)
# ============================================================

class IncidentMemory(BaseModel):
    incident_id: str
    raw_signal: RawCrisisSignal
    detection_output: Optional[Any] = None
    analysis_output: Optional[Any] = None
    planning_output: Optional[Any] = None
    execution_output: Optional[Any] = None
    system_state: SystemState
    traces: List[str] = []
    status: str = "INGESTED"
    lat: Optional[float] = None
    lng: Optional[float] = None

    class Config:
        arbitrary_types_allowed = True
