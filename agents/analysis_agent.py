import json
import logging
from enum import Enum
from typing import List, Optional, Any, Dict
from pydantic import BaseModel, Field, ValidationError

# ==========================================
# 3. INPUT SCHEMA
# ==========================================
class DetectionOutputInput(BaseModel):
    incident_type: str
    severity: str
    priority: str
    detected_location: Dict[str, Any]
    normalized_input: str
    urgency_flags: List[str]

class ContextSignals(BaseModel):
    maps_context: Dict[str, Any] = Field(default={}, description="Context from Maps/GIS")
    weather_signals: Dict[str, Any] = Field(default={}, description="Current weather data")
    traffic_data: Dict[str, Any] = Field(default={}, description="Live traffic speed and volume")
    resource_availability: Dict[str, Any] = Field(default={}, description="Availability of fire, ambulance, rescue")

class AnalysisInputPayload(BaseModel):
    detection_data: DetectionOutputInput
    context: ContextSignals

# ==========================================
# 4. OUTPUT SCHEMA
# ==========================================
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
    impact_score: float = Field(..., ge=0.0, le=100.0, description="Overall impact score out of 100")
    affected_people: int = Field(..., description="Estimated number of affected individuals")
    affected_vehicles: int = Field(..., description="Estimated number of affected vehicles")
    nearby_hospitals: List[Facility] = Field(..., description="List of nearby hospitals")
    nearby_infrastructure: List[str] = Field(..., description="List of nearby critical infrastructure (e.g., power grid, bridges)")
    secondary_risks: List[str] = Field(..., description="Detected secondary hazards (e.g., electrocution, explosions)")
    response_difficulty: ResponseDifficulty
    congestion_level: CongestionLevel
    analysis_reasoning: str = Field(..., description="Detailed step-by-step reasoning for the estimations and impact score")
    english_summary: str = Field(..., description="Concise summary in English")
    urdu_summary: str = Field(..., description="Concise summary translated into Urdu")

# ==========================================
# 2. SYSTEM PROMPT
# ==========================================
SYSTEM_PROMPT = """You are the Analysis Agent for KHABAR (Crisis Intelligence & Response Orchestrator).
Your role is to receive verified incident data along with environmental context (Maps, Weather, Traffic) and generate a comprehensive impact analysis dynamically.

INSTRUCTIONS:
1. Estimate Affected Entities: Using traffic and location data, estimate the number of people and vehicles involved realistically.
2. Identify Facilities & Infrastructure: Correlate location data with nearby hospitals and critical infrastructure.
3. Assess Secondary Risks: Identify hazards that could escalate the situation (e.g., flood water near electrical transformers = electrocution risk).
4. Evaluate Response Logistics:
   - Determine Congestion Level based on traffic data.
   - Estimate Response Difficulty based on weather, congestion, and severity.
5. Calculate Impact Score (0-100): 
   - Base this on severity, affected population, and secondary risks. (e.g., 90+ for mass casualties or critical infrastructure failure).
6. Generate Summaries: Provide a clear, actionable summary in both English and Urdu.
7. Return strictly valid JSON conforming to the Output Schema.

RULES:
- Always consider weather and traffic multipliers. High traffic + heavy rain drastically increases Response Difficulty and Impact Score.
- Urdu summaries must be written in standard, professional Urdu script.
- All reasoning must be highly context-aware based on the user's explicit payload data.
"""

# ==========================================
# 5. IMPACT ANALYSIS LOGIC
# ==========================================
def calculate_base_impact(analysis_output: AnalysisOutput) -> float:
    base_score = analysis_output.impact_score
    if analysis_output.congestion_level == CongestionLevel.GRIDLOCK:
        base_score = min(100.0, base_score + 10.0)
    if analysis_output.response_difficulty == ResponseDifficulty.EXTREME:
        base_score = min(100.0, base_score + 15.0)
    return base_score

def evaluate_escalation_danger(analysis_output: AnalysisOutput) -> bool:
    if analysis_output.impact_score > 85.0 and len(analysis_output.secondary_risks) >= 2:
        logging.critical("⚠️ EXTREME ESCALATION DANGER DETECTED. Multi-agency alert required. ⚠️")
        return True
    return False

# ==========================================
# 10. FAILURE HANDLING
# ==========================================
def fallback_analysis(payload: AnalysisInputPayload, error_msg: str) -> AnalysisOutput:
    logging.error(f"Analysis Agent failed: {error_msg}. Applying fallback high-caution routing.")
    return AnalysisOutput(
        impact_score=99.0,
        affected_people=-1,
        affected_vehicles=-1,
        nearby_hospitals=[],
        nearby_infrastructure=[],
        secondary_risks=["UNKNOWN - ANALYSIS FAILURE"],
        response_difficulty=ResponseDifficulty.EXTREME,
        congestion_level=CongestionLevel.GRIDLOCK,
        analysis_reasoning=f"SYSTEM FAILURE: Automated analysis failed due to: {error_msg}. Escalated for immediate manual analysis.",
        english_summary="CRITICAL: Automated analysis failed. Manual intervention required immediately.",
        urdu_summary="انتہائی اہم: خودکار تجزیہ ناکام ہو گیا۔ فوری انسانی مداخلت کی ضرورت ہے۔"
    )

# ==========================================
# 1. FULL ANTIGRAVITY ANALYSIS AGENT
# ==========================================
class AnalysisAgent:
    def __init__(self, llm_client=None):
        self.llm_client = llm_client
        self.system_prompt = SYSTEM_PROMPT

    async def process_analysis(self, payload: AnalysisInputPayload) -> AnalysisOutput:
        prompt = f"Analysis Payload:\n{payload.model_dump_json()}"
        
        try:
            raw_response = await self.llm_client.generate_json(
                system_prompt=self.system_prompt,
                user_prompt=prompt,
                json_schema_dict=AnalysisOutput.model_json_schema()
            )
            
            parsed_json = json.loads(raw_response)
            output = AnalysisOutput(**parsed_json)
            
            adjusted_impact = calculate_base_impact(output)
            output.impact_score = adjusted_impact
            
            evaluate_escalation_danger(output)
                
            return output

        except ValidationError as e:
            raise RuntimeError(f"AIML API returned invalid JSON structure: {str(e)}")
        except Exception as e:
            raise RuntimeError(f"API Error: {str(e)}")
