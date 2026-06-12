"""
knowledge_base_data.py — Real Vector Search (RAG) using Gemini Embeddings
Instead of fake keyword matching, this uses real neural embeddings to find the best SOP.
"""
import os
import math
import logging
from google import genai
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), '.env'))

api_key = os.getenv("GEMINI_API_KEY")
client = genai.Client(api_key=api_key) if api_key and not api_key.endswith("HERE") else None

# The Knowledge Base Documents
PAKISTAN_NDMA_PROTOCOLS = [
    "NDMA Flood SOP-01: 1. Deploy WASA dewatering pumps immediately. 2. Disconnect grid power (WAPDA/KE) in submerged areas. 3. Dispatch Rescue 1122 boats if water exceeds 3ft. 4. Evacuate basements.",
    "NDMA Quake SOP-02: 1. Dispatch Urban Search and Rescue (USAR) teams with K9 units. 2. Request heavy lifting machinery from CDCR/NDMA. 3. Establish medical triage zone 100 meters away from fall zone.",
    "NDMA Heatwave SOP-03: 1. Set up NDMA cooling centers. 2. Coordinate with Edhi/Chhipa for hydration ambulances. 3. Issue public alert avoiding sun from 11 AM to 4 PM. 4. Prevent unannounced load-shedding via K-Electric/IESCO.",
    "Traffic Police SOP-04: 1. Secure perimeter via Motorway Police/Traffic Wardens. 2. Dispatch Rescue 1122 trauma ambulances. 3. Clear wreckage within 2 hours. 4. Reroute heavy traffic to alternate arteries.",
    "Fire Brigade SOP-05: 1. Dispatch minimum 2 Fire Tenders. 2. Disconnect local gas (Sui Gas) and electric supply. 3. Evacuate adjacent structures within 50 meters. 4. Request WASA water bowsers for backup supply."
]

# In-memory vector store
VECTOR_STORE = []

def cosine_similarity(v1, v2):
    dot_product = sum(x * y for x, y in zip(v1, v2))
    magnitude_v1 = math.sqrt(sum(x * x for x in v1))
    magnitude_v2 = math.sqrt(sum(y * y for y in v2))
    if magnitude_v1 == 0 or magnitude_v2 == 0:
        return 0.0
    return dot_product / (magnitude_v1 * magnitude_v2)

def build_vector_db():
    """Converts the text protocols into AI Vectors using Gemini gemini-embedding-2."""
    global VECTOR_STORE
    if VECTOR_STORE or not client: 
        return
        
    logging.info("[Knowledge Base] Building Real Vector DB using Gemini Embeddings...")
    try:
        response = client.models.embed_content(
            model='gemini-embedding-2',
            contents=PAKISTAN_NDMA_PROTOCOLS,
        )
        
        for i, emb in enumerate(response.embeddings):
            VECTOR_STORE.append({
                "text": PAKISTAN_NDMA_PROTOCOLS[i],
                "vector": emb.values
            })
        logging.info("[Knowledge Base] ✅ Vector DB built successfully!")
    except Exception as e:
        logging.error(f"[Knowledge Base] Embedding failed: {e}")

def search_ndma_protocols(query: str) -> str:
    """Performs real Semantic Vector Search (RAG) against the query."""
    if not client:
        return "System Error: Gemini API Key missing for Vector Search."
        
    if not VECTOR_STORE:
        build_vector_db()
        
    try:
        query_emb_res = client.models.embed_content(
            model='gemini-embedding-2',
            contents=query,
        )
        query_vector = query_emb_res.embeddings[0].values
        
        best_match = None
        highest_score = -1.0
        
        # Compare query vector with all document vectors
        for item in VECTOR_STORE:
            score = cosine_similarity(query_vector, item["vector"])
            if score > highest_score:
                highest_score = score
                best_match = item["text"]
                
        logging.info(f"[Knowledge Base] Match Score: {highest_score:.2f}")
        
        # If the query is completely unrelated to our documents
        if highest_score < 0.5:
            return "General SOP: Dispatch immediate first responders (Rescue 1122), secure the perimeter, and assess situation."
            
        return best_match
    except Exception as e:
        logging.error(f"[Knowledge Base] Search error: {e}")
        return "Error retrieving from Vector Database."
