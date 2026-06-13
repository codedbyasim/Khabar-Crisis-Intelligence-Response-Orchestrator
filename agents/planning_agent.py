import json
import logging
from enum import Enum
from typing import List, Optional, Any, Dict
from pydantic import BaseModel, Field, ValidationError

# ==========================================
# 3. INPUT SCHEMA
# ==========================================
class AnalysisOutputInput(BaseModel):
    impact_score: float
    affected_people: int
    affected_vehicles: int
    nearby_hospitals: List[Dict[str, Any]]
    nearby_infrastructure: List[str]
    secondary_risks: List[str]
    response_difficulty: str
    congestion_level: str

class PlanningInputPayload(BaseModel):
    analysis_data: AnalysisOutputInput
    available_regional_resources: Dict[str, int] = Field(default={}, description="Global view of available resources")

# ==========================================
# 4. OUTPUT SCHEMA
# ==========================================
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
    RESCUE_1122   = "Rescue 1122"
    NDMA          = "NDMA"
    PDMA          = "PDMA"
    TRAFFIC_POLICE = "Traffic Police"
    WASA          = "WASA"
    IESCO         = "IESCO"           # Islamabad & Rawalpindi power utility
    CDA           = "CDA"             # Capital Development Authority (Islamabad)
    RDA           = "RDA"             # Rawalpindi Development Authority
    PUNJAB_EMERGENCY = "Punjab Emergency Service"

class ActionPriority(str, Enum):
    P1_IMMEDIATE = "P1_IMMEDIATE"
    P2_URGENT = "P2_URGENT"
    P3_STANDARD = "P3_STANDARD"

class RecommendedAction(BaseModel):
    action_type: ActionType
    priority: ActionPriority
    target_agency: Agency
    description: str
    required_units: int = Field(default=0, description="Number of units needed")

class EscalationRisk(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"

class PlanningOutput(BaseModel):
    recommended_actions: List[RecommendedAction]
    action_priority: str = Field(..., description="Overall mission priority focus")
    resource_requirements: Dict[str, int] = Field(..., description="Aggregated total resources required")
    response_strategy: str = Field(..., description="High-level summary of the tactical approach")
    estimated_resolution_time: str = Field(..., description="Estimated time to resolve the immediate crisis")
    escalation_risk: EscalationRisk
    planning_reasoning: str = Field(..., description="Step-by-step logic explaining action selection and resource allocation")
    fallback_actions: List[RecommendedAction] = Field(default=[], description="Alternative actions if primary resources fail")

# ==========================================
# 2. SYSTEM PROMPT
# ==========================================
SYSTEM_PROMPT = """You are the Planning Agent for KHABAR (Crisis Intelligence & Response Orchestrator).
Your role is to receive the impact analysis of an incident and dynamically generate a tactical, ordered response plan tailored to Pakistan's emergency ecosystem.

INSTRUCTIONS:
1. Develop a Tactical Response Strategy: Outline how to contain the crisis and save lives based on real analysis inputs.
2. Formulate Recommended Actions: Map out specific actions. You MUST use the exact Action Types provided.
3. Assign Target Agencies: Route actions to the correct Pakistani agencies (Rescue 1122, Edhi, WASA, NDMA, Traffic Police, etc.).
4. Allocate Resources: Estimate the number of units required based on affected people and vehicles. Do not exceed typical regional capacities.
5. Determine Escalation Risk: Assess if the situation is likely to worsen.
6. Provide Fallback Actions: What to do if primary routes/resources are blocked.
7. Islamabad Distance-Based ETA Integration:
   - Check the input analysis data. Inside 'maps_context', there is a 'resource_etas' dictionary detailing the distance and travel time (ETA) for each resource type in Islamabad.
   - For EACH dispatched action, you MUST mention the source station name, distance in km, and computed travel time (ETA) in minutes inside the action's description or inside the 'estimated_resolution_time' / 'response_strategy' fields.
   - You MUST generate clear, comforting, and highly actionable safety advice for the victim (in Roman Urdu / English) under 'response_strategy' or action descriptions, detailing exactly **what they SHOULD do** and **what they should NOT do** (Do's and Don'ts) while waiting for that specific resource to arrive.
   - Misaal ke taur par: "WASA dewatering team G-10 Markaz Depot (4.5 km door) se nikal chuki hai aur 9 minutes mein pahuchegi. DO: Bijli ke switch band karein aur unche maqam par jayen. DO NOT: Paani mein kharay hokar wire ko hath lagayen."
8. Return strictly valid JSON conforming to the Output Schema.

RULES:
- Actions must be realistically ordered by ActionPriority (P1 first).
- Avoid resource conflicts. Allocate realistically.
- You MUST restrict the keys in the 'resource_requirements' dictionary strictly to one of: 'ambulances', 'fire_trucks', 'dewatering_pumps', 'traffic_units', 'utility_crews'. Do NOT introduce any new keys under any circumstances.
- P1_IMMEDIATE actions must focus on life-saving and immediate hazard mitigation.
- The plan must be completely dynamic and dependent on the provided analysis data and computed resource ETAs.
"""

# ==========================================
# 5. ACTION PRIORITIZATION LOGIC
# ==========================================
def sort_and_validate_priorities(plan: PlanningOutput) -> PlanningOutput:
    priority_order = {
        ActionPriority.P1_IMMEDIATE: 1,
        ActionPriority.P2_URGENT: 2,
        ActionPriority.P3_STANDARD: 3
    }
    
    plan.recommended_actions.sort(key=lambda x: priority_order[x.priority])
    
    if plan.escalation_risk in [EscalationRisk.HIGH, EscalationRisk.CRITICAL]:
        p1_count = sum(1 for a in plan.recommended_actions if a.priority == ActionPriority.P1_IMMEDIATE)
        if p1_count == 0:
            logging.warning("⚠️ High escalation risk but no P1 actions found! Upgrading first action to P1_IMMEDIATE.")
            if plan.recommended_actions:
                plan.recommended_actions[0].priority = ActionPriority.P1_IMMEDIATE
                
    return plan

def validate_resource_allocation(plan: PlanningOutput, available_resources: Dict[str, int]) -> PlanningOutput:
    conflict_detected = False
    normalized_requirements = {}
    for resource_type, required_amount in plan.resource_requirements.items():
        rtype = resource_type.lower()
        if "ambulance" in rtype:
            mapped_type = "ambulances"
        elif "pump" in rtype or "dewatering" in rtype:
            mapped_type = "dewatering_pumps"
        elif "kit" in rtype or "medical" in rtype:
            mapped_type = "medical_kits"
        else:
            mapped_type = "rescue_teams"
            
        normalized_requirements[mapped_type] = normalized_requirements.get(mapped_type, 0) + required_amount

    # Update plan resource requirements with clean database mappings
    plan.resource_requirements = normalized_requirements

    for resource_type, required_amount in plan.resource_requirements.items():
        available = available_resources.get(resource_type, 100)
        if required_amount > available:
            logging.error(f"RESOURCE CONFLICT: Plan requires {required_amount} {resource_type}s, but only {available} are available!")
            conflict_detected = True
            
    if conflict_detected:
        plan.response_strategy = "[WARNING: RESOURCE DEFICIT DETECTED] " + plan.response_strategy
        
    return plan

# ==========================================
# 10. FAILURE HANDLING
# ==========================================
def fallback_planning(payload: PlanningInputPayload, error_msg: str) -> PlanningOutput:
    logging.error(f"Planning Agent failed: {error_msg}. Applying generic emergency plan.")
    generic_action = RecommendedAction(
        action_type=ActionType.NOTIFY_AGENCIES,
        priority=ActionPriority.P1_IMMEDIATE,
        target_agency=Agency.RESCUE_1122,
        description=f"SYSTEM FAILURE IN PLANNING. Manual dispatch required. Incident impact score: {payload.analysis_data.impact_score}",
        required_units=1
    )
    
    return PlanningOutput(
        recommended_actions=[generic_action],
        action_priority="EMERGENCY_MANUAL_OVERRIDE",
        resource_requirements={"generic_response_units": 1},
        response_strategy="Automated planning failed. Handing over to human dispatchers immediately.",
        estimated_resolution_time="UNKNOWN",
        escalation_risk=EscalationRisk.CRITICAL,
        planning_reasoning=f"Error occurred: {error_msg}",
        fallback_actions=[]
    )

# ==========================================
# 1. FULL ANTIGRAVITY PLANNING AGENT
# ==========================================
class PlanningAgent:
    def __init__(self, llm_client=None):
        self.llm_client = llm_client
        self.system_prompt = SYSTEM_PROMPT

    async def process_plan(self, payload: PlanningInputPayload) -> PlanningOutput:
        prompt = f"Planning Payload:\n{payload.model_dump_json()}"
        
        try:
            raw_response = await self.llm_client.generate_json(
                system_prompt=self.system_prompt,
                user_prompt=prompt,
                json_schema_dict=PlanningOutput.model_json_schema()
            )
            
            parsed_json = json.loads(raw_response)
            output = PlanningOutput(**parsed_json)
            
            output = sort_and_validate_priorities(output)
            output = validate_resource_allocation(output, payload.available_regional_resources)
                
            return output

        except ValidationError as e:
            raise RuntimeError(f"AIML API returned invalid JSON structure: {str(e)}")
        except Exception as e:
            raise RuntimeError(f"API Error: {str(e)}")
