# 📥 Multi-Source Input System

KHABAR accepts crisis signals from **three distinct input modalities** — text, image, and voice — all processed through the same 4-agent pipeline.

---

## Input Modalities

```
┌─────────────────────────────────────────────────────────┐
│              CITIZEN INPUT MODALITIES                   │
│                                                         │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────┐  │
│  │  📝 TEXT       │  │  📷 IMAGE      │  │ 🎙 VOICE │  │
│  │  /report/text  │  │  /report/image │  │ /report/ │  │
│  │                │  │                │  │ voice    │  │
│  │ Urdu, English  │  │ JPEG/PNG       │  │ M4A/WAV  │  │
│  │ Roman Urdu     │  │ + description  │  │ + photo  │  │
│  │ Punjabi        │  │                │  │          │  │
│  └───────┬────────┘  └───────┬────────┘  └────┬─────┘  │
│          └──────────────┬────┘                │         │
│                         │    RawCrisisSignal   │         │
└─────────────────────────┼──────────────────────┘         
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

---

## 3. 🎙 Voice Input (`POST /report/voice`)

**Accepted formats:** M4A, WAV, OGG  
**Processing:** OpenAI Whisper API via AIML API endpoint

**Optional:** Attach a photo alongside the voice recording for dual-modal analysis.

**Two-step process:**
```
1. Whisper API transcribes audio
   → detected_language, transcription_original (Urdu script or Roman),
     transcription_english (translated)

2. If photo attached → Vision API runs simultaneously
   → Both results merged into combined RawCrisisSignal

3. Combined signal → 4-agent pipeline
```

**Speech Output Example:**
```json
{
  "detected_language": "Urdu",
  "transcription_original": "گاڑیاں ڈوب رہی ہیں اور راستہ بند ہے",
  "transcription_english": "Cars are sinking and the road is blocked.",
  "audio_quality": "clear",
  "confidence": 0.92
}
```

**Flutter Screen:** `lib/screens/voice_report_screen.dart`
- Multi-Source capture: Record live voice (mic) OR upload pre-recorded audio files (via `file_picker`)
- Optional photo attachment
- Animated waveform amplitude visualizer

---

## 4. 🤖 Automated Ingestion (`automated_ingestion.py`)

Beyond manual citizen reports, KHABAR automatically monitors:

| Source | Trigger Condition | Signal Type |
|---|---|---|
| Open-Meteo API | Precipitation > 50mm/hr | `AUTOMATED_WEATHER` |
| Open-Meteo API | Temperature > 43°C | `AUTOMATED_HEATWAVE` |
| TomTom Traffic | Speed < 30% of free-flow | `AUTOMATED_TRAFFIC` |

These auto-generated signals enter the same `KhabarCrewOrchestrator.process_incident()` pipeline as manual reports.

---

## 5. Signal Lifecycle

```
RawCrisisSignal created
  ├── signal_id: "SIG-{timestamp}-{TXT|IMG|VOI}"
  ├── source_type: TEXT_ROMAN_URDU | IMAGE_SUMMARY | VOICE_TRANSCRIPT | AUTOMATED_*
  ├── raw_content: string
  ├── timestamp: ISO 8601
  └── metadata: {lat, lng, vision_result?, speech_result?}

         ↓ orchestrator.process_incident(signal)

  Immediately saved to Supabase with status="PROCESSING"
  Background task runs 4-agent pipeline
  Status updated to "PIPELINE_COMPLETE" or "REJECTED"
```
