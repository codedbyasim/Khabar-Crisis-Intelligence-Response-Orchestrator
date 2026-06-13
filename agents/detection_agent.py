import json
import logging
import httpx
from enum import Enum
from typing import List, Optional, Any, Dict
from pydantic import BaseModel, Field, ValidationError

def get_live_weather(lat: float, lng: float) -> dict:
    """Fetches real-time weather from Open-Meteo for validation/cross-referencing."""
    try:
        url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lng}&current=temperature_2m,rain,showers,snowfall,wind_speed_10m&timezone=auto"
        with httpx.Client(timeout=5, verify=True) as client:
            response = client.get(url)
            if response.status_code == 200:
                current = response.json().get("current", {})
                return {
                    "temperature_c": current.get("temperature_2m"),
                    "rain_mm": current.get("rain"),
                    "showers_mm": current.get("showers"),
                    "snowfall_cm": current.get("snowfall"),
                    "wind_speed_kmh": current.get("wind_speed_10m")
                }
    except Exception as e:
        logging.warning(f"[Weather Validation] Live weather fetch failed: {e}")
    return {}

# ==========================================
# 3. INPUT SCHEMA
# ==========================================
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
    metadata: Optional[Dict[str, Any]] = Field(default={}, description="Additional metadata like author, GPS coords, etc.")

# ==========================================
# 4. OUTPUT SCHEMA
# ==========================================
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
    CRITICAL = "CRITICAL" # Life-threatening, immediate action required
    HIGH = "HIGH"         # Severe property damage or high risk of injury
    MEDIUM = "MEDIUM"     # Moderate impact, localized issue
    LOW = "LOW"           # Minor issue, no immediate threat

class PriorityLevel(str, Enum):
    P1 = "P1" # Highest - triggers immediate full response pipeline
    P2 = "P2"
    P3 = "P3"
    P4 = "P4"
    P5 = "P5" # Lowest

class DetectedLocation(BaseModel):
    city: Optional[str] = Field(None, description="Extracted city name")
    area: Optional[str] = Field(None, description="Extracted local area, street, or landmark")
    raw_location_mentions: List[str] = Field(default=[], description="Exact phrases mentioning location")

class DetectionOutput(BaseModel):
    incident_type: IncidentType
    severity: Severity
    priority: PriorityLevel
    confidence_score: float = Field(..., ge=0.0, le=1.0, description="Confidence in the extraction (0.0 to 1.0)")
    detected_location: DetectedLocation
    normalized_input: str = Field(..., description="Cleaned, normalized English translation/version of the input")
    reasoning_trace: str = Field(..., description="Step-by-step reasoning explaining the classification and priority")
    urgency_flags: List[str] = Field(default=[], description="Specific keywords or phrases indicating high urgency")
    is_verified: bool = Field(default=True, description="Whether the incident has been verified against external API context (e.g. weather data). Mark false if suspicious or fake.")
    verification_reason: str = Field(default="Standard report validation", description="Reasoning explaining the validation assessment based on live sensors.")

# ==========================================
# 2. SYSTEM PROMPT
# ==========================================
SYSTEM_PROMPT = """You are the Detection Agent for KHABAR (Crisis Intelligence & Response Orchestrator).
Your role is to analyze raw, noisy, and informal crisis signals (in English, Urdu, Punjabi, or Roman Urdu), validate their authenticity, and extract structured incident data.

INSTRUCTIONS:
1. Normalize Input: Translate Urdu, Punjabi, or Roman Urdu into clear English. Correct typos and informal grammar.
2. Identify Incident Type: Map the situation to exactly one of the supported incident types. If multiple, pick the most severe. If the message is a greeting (e.g. "hi", "hello"), casual talk ("main theek hoon", "sub thik hai"), or has no clear emergency reported, map it to "unknown".
3. Extract Location: Identify any city, neighborhood, road, or landmark mentioned.
4. Assess Severity & Priority:
   - Priority P1: Severe life-threatening incidents (e.g., building collapse with people trapped, massive fire, catastrophic flood).
   - Priority P2: High risk to life/property (e.g., severe road accident, major infrastructure failure).
   - Priority P3: Moderate impact (e.g., localized flooding, non-fatal accident).
   - Priority P4: Low immediate risk (e.g., road blockage, minor fire).
   - Priority P5: Non-emergency, test, greeting, or informational.
5. Identify Urgency Flags: Extract exact phrases like "help fast", "log phans gaye hain", "bhot aag", "dying".
6. Validate Authenticity (Real vs Fake / Emergency vs Spam):
   - First, check if the user is actually reporting a real emergency/crisis. If the text is conversational ("sab theek hai", "hi", "how are you", "main biryani kha rha hoon") or explicitly states there is no problem, set `is_verified` to false and `verification_reason` to "No active emergency or problem reported in the message."
   - Second, if the user reports weather-related issues (e.g., urban flooding, heavy rainfall, storm, or extreme heatwave):
     * Cross-reference with the provided "LIVE ENVIRONMENTAL SENSOR CONTEXT".
     * E.g., if they report "severe flooding/heavy rain" but live rain_mm/showers_mm is 0.0mm and weather is clear, mark `is_verified` as false and set `verification_reason` to "Reported urban flooding/heavy rain but live weather sensors show clear weather with 0mm precipitation, indicating a potentially fake or outdated report."
     * E.g., if they report "extreme heatwave" but the live temperature is cool (e.g. under 30°C), mark `is_verified` as false and set `verification_reason` to "Reported extreme heatwave but live temperature sensor is cool."
     * If the weather data is empty, unavailable, or correlates reasonably, or if it is a non-weather event (like a road accident, fire, building collapse, or medical emergency) which cannot be checked by weather sensors, mark `is_verified` as true.
7. Generate Reasoning Trace: Provide a concise logical path justifying your classification, priority mapping, and verification check.
8. Return strictly valid JSON conforming to the Output Schema.

RULES:
- If life is in immediate danger, Priority MUST be P1 and Severity MUST be CRITICAL.
- P1 incidents will trigger the full response pipeline automatically. Be highly sensitive to life-threat indicators.
- Handle noisy and mixed-code text robustly.
- Be objective and thorough in the verification step to prevent fake news or false alarms from wasting rescue resources.
"""

# ==========================================
# 5. REASONING LOGIC & 9. TRIGGER CONDITIONS
# ==========================================
def evaluate_triggers(output: DetectionOutput) -> bool:
    if output.priority == PriorityLevel.P1 or output.severity == Severity.CRITICAL:
        logging.warning("🚨 CRITICAL TRIGGER CONDITION MET! Triggering full response pipeline. 🚨")
        return True
    return False

# ==========================================
# 10. FAILURE HANDLING
# ==========================================
def fallback_processing(raw_signal: RawCrisisSignal, error_msg: str) -> DetectionOutput:
    logging.error(f"Processing failed: {error_msg}. Applying fallback safety routing.")
    return DetectionOutput(
        incident_type=IncidentType.UNKNOWN,
        severity=Severity.HIGH,
        priority=PriorityLevel.P2,
        confidence_score=0.1,
        detected_location=DetectedLocation(city=None, area=None, raw_location_mentions=[]),
        normalized_input=raw_signal.raw_content,
        reasoning_trace=f"SYSTEM FAILURE: Automated parsing failed due to: {error_msg}. Escalated for manual review.",
        urgency_flags=["SYSTEM_PARSING_FAILURE"]
    )

# ==========================================
# 1. FULL ANTIGRAVITY DETECTION AGENT
# ==========================================
class DetectionAgent:
    def __init__(self, llm_client=None):
        self.llm_client = llm_client
        self.system_prompt = SYSTEM_PROMPT

    async def process_signal(self, signal: RawCrisisSignal) -> DetectionOutput:
        lat = 33.6844
        lng = 73.0479
        if signal.metadata:
            lat = float(signal.metadata.get("lat") or 33.6844)
            lng = float(signal.metadata.get("lng") or 73.0479)
            
        weather_info = get_live_weather(lat, lng)
        
        sensor_context = f"""
LIVE ENVIRONMENTAL SENSOR CONTEXT:
- Latitude: {lat}
- Longitude: {lng}
- Current Weather Data: {json.dumps(weather_info)}
"""
        prompt = f"{sensor_context}\nRaw Signal:\n{signal.model_dump_json()}"
        
        try:
            raw_response = await self.llm_client.generate_json(
                system_prompt=self.system_prompt,
                user_prompt=prompt,
                json_schema_dict=DetectionOutput.model_json_schema()
            )
            
            parsed_json = json.loads(raw_response)
            output = DetectionOutput(**parsed_json)
            
            if evaluate_triggers(output):
                logging.info(f"Dispatching signal {signal.signal_id} to Response Orchestrator Pipeline.")
                
            return output

        except ValidationError as e:
            raise RuntimeError(f"AIML API returned invalid JSON structure: {str(e)}")
        except Exception as e:
            raise RuntimeError(f"API/Network Error: {str(e)}")
