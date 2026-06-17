# 📥 Multi-Source Input System

KHABAR accepts crisis signals from **two distinct input modalities** — text and image — both processed through the same 4-agent pipeline.

---

## Input Modalities

```
┌──────────────────────────────────────────────────┐
│              CITIZEN INPUT MODALITIES            │
│                                                  │
│  ┌────────────────┐         ┌────────────────┐  │
│  │  📝 TEXT       │         │  📷 IMAGE      │  │
│  │  /report/text  │         │  /report/image │  │
│  │                │         │                │  │
│  │ Urdu, English  │         │ JPEG/PNG       │  │
│  │ Roman Urdu     │         │ + description  │  │
│  │ Punjabi        │         │                │  │
│  └───────┬────────┘         └───────┬────────┘  │
│          └────────────────┬─────────┘           │
│                           │ RawCrisisSignal     │
└───────────────────────────┼─────────────────────┘
                            ↓
                KhabarCrewOrchestrator.process_incident()
                            ↓
                [4-Agent Pipeline: Detection → Execution]
```

---

## 1. 📝 Text Input (`POST /report/text`)

**Supported Languages:**
- English
- اردو (Urdu — Arabic script)
- Roman Urdu (e.g., "Nullah Lai mein paani aa gaya")
- Punjabi

**Handling:** Raw text is passed directly to the Detection Agent as `raw_content`.

**Flutter Screen:** `lib/screens/text_signal_screen.dart`
- Google Maps draggable marker for GPS coordinates
- Language confidence indicator
- Real-time character count


---

## 2. 📷 Image Input (`POST /report/image`)

**Accepted formats:** JPEG, PNG  
**Processing:** AIML Vision API (OpenAI-compatible, base64 encoded)

**Two-step process:**
```
1. AIML Vision API analyzes image
   → crisis_type, severity, priority, confidence, detected_elements

2. Vision result is combined with any text description
   → merged into RawCrisisSignal → 4-agent pipeline
```

**Vision Output Example:**
```json
{
  "crisis_type": "urban_flooding",
  "severity": "HIGH",
  "priority": "P2",
  "confidence": 0.95,
  "description": "Flooding of roadway with multiple partially submerged vehicles.",
  "detected_elements": ["floodwater", "submerged_car", "road_closure"]
}
```

**Flutter Screen:** `lib/screens/photo_verification_screen.dart`
- Multi-Source capture: Live camera shutter OR local gallery photo upload (via `image_picker`)
- Optional text description field alongside photo
- Interactive preview showing details before sending to the Gemini AI pipeline

## 3. 🤖 Automated Ingestion (`automated_ingestion.py`)

Beyond manual citizen reports, KHABAR automatically monitors:

| Source | Trigger Condition | Signal Type |
|---|---|---|
| Open-Meteo API | Precipitation > 50mm/hr | `AUTOMATED_WEATHER` |
| Open-Meteo API | Temperature > 43°C | `AUTOMATED_HEATWAVE` |
| TomTom Traffic | Speed < 30% of free-flow | `AUTOMATED_TRAFFIC` |

These auto-generated signals enter the same `KhabarCrewOrchestrator.process_incident()` pipeline as manual reports.

---

## 4. Signal Lifecycle

```
RawCrisisSignal created
  ├── signal_id: "SIG-{timestamp}-{TXT|IMG}"
  ├── source_type: TEXT_ROMAN_URDU | IMAGE_SUMMARY | AUTOMATED_*
  ├── raw_content: string
  ├── timestamp: ISO 8601
  └── metadata: {lat, lng, vision_result?}

         ↓ orchestrator.process_incident(signal)

  Immediately saved to Supabase with status="PROCESSING"
  Background task runs 4-agent pipeline
  Status updated to "PIPELINE_COMPLETE" or "REJECTED"
```
