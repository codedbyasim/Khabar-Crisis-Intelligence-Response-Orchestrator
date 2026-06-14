"""
gemini_speech.py — Multilingual audio transcription via AIML API (OpenAI-compatible).
FR-03: Voice recordings transcribed in Urdu/Punjabi/Sindhi/English.
Migrated from google-genai SDK to AIML API (openai client).

Strategy:
  Step 1 — Transcribe audio using AIML-compatible Whisper transcription endpoint.
  Step 2 — Run crisis analysis on the transcription text via chat completions.
"""
import os
import json
import logging
import tempfile
from typing import Dict, Any
from dotenv import load_dotenv

from openai import OpenAI

load_dotenv()


class GeminiSpeech:
    def __init__(self, api_key: str = None):
        raw_key = api_key or os.getenv("AIML_API_KEY")
        if not raw_key:
            raise ValueError(
                "AIML_API_KEY is not set.\n"
                "Please set it in agents/.env as: AIML_API_KEY=your_key_here"
            )
        self.api_key = raw_key.strip()
        self.client = OpenAI(
            base_url="https://api.aimlapi.com/v1",
            api_key=self.api_key,
            max_retries=0,          # Disable SDK auto-retries — we handle fallbacks manually
        )
        self.transcription_model = "whisper-1"
        self.analysis_model = "google/gemini-2.5-flash"
        logging.info(
            f"[GeminiSpeech] Initialized — transcription: {self.transcription_model} | "
            f"analysis: {self.analysis_model} (AIML API)"
        )

    def transcribe_audio(
        self, audio_bytes: bytes, mime_type: str = "audio/wav"
    ) -> Dict[str, Any]:
        """
        Transcribe audio and detect crisis signals.
        Supports Urdu, Punjabi, Sindhi, Roman Urdu, English.

        Step 1: Transcribe audio bytes using Whisper via AIML API.
        Step 2: Analyze transcript for crisis signals using Gemini chat.
        """
        tmp_path = None
        try:
            # Determine correct suffix from mime type
            if "wav" in mime_type:
                suffix = ".wav"
            elif "mp4" in mime_type or "m4a" in mime_type:
                suffix = ".m4a"
            elif "aac" in mime_type:
                suffix = ".aac"
            else:
                suffix = ".mp3"

            # Write audio to a temp file for the transcription API
            with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
                tmp.write(audio_bytes)
                tmp_path = tmp.name

            # --- Step 1: Transcribe ---
            with open(tmp_path, "rb") as audio_file:
                transcription_response = self.client.audio.transcriptions.create(
                    model=self.transcription_model,
                    file=audio_file,
                    response_format="text",
                )
            # transcription_response is a plain string when response_format="text"
            raw_transcript = str(transcription_response).strip()
            logging.info(f"[GeminiSpeech] Transcript: {raw_transcript[:120]}...")

            # --- Step 2: Crisis Analysis ---
            analysis_prompt = f"""You are a multilingual crisis analysis AI for KHABAR — Pakistan's emergency system.
The following text was transcribed from an audio report. Speaker may have used Urdu, Punjabi, Sindhi, Roman Urdu, or English.

Transcribed text:
\"\"\"{raw_transcript}\"\"\"

Analyze for crisis signals and return ONLY valid JSON:
{{
  "transcription_original": "exact transcribed text as provided",
  "transcription_english": "English translation if not already in English",
  "detected_language": "urdu|punjabi|sindhi|roman_urdu|english",
  "crisis_detected": true,
  "crisis_keywords": ["pani bhar gaya", "aag"],
  "crisis_type": "flood|fire|accident|collapse|medical|heatwave|road_blockage|other",
  "urgency_level": "HIGH|MEDIUM|LOW",
  "location_mentions": ["G-10", "Islamabad"],
  "confidence": 0.94,
  "urdu_summary": "اردو میں خلاصہ"
}}

Be sensitive to Pakistani informal crisis phrases like: pani bhar gaya, aag lagi, hadsa, phans gaye, madad karo."""

            analysis_response = self.client.chat.completions.create(
                model=self.analysis_model,
                messages=[
                    {"role": "user", "content": analysis_prompt}
                ],
                response_format={"type": "json_object"},
                temperature=0.1,
            )

            content = analysis_response.choices[0].message.content
            result = json.loads(content)
            # Ensure the original transcript is preserved accurately
            result["transcription_original"] = raw_transcript
            logging.info(
                f"[GeminiSpeech] ✅ lang={result.get('detected_language')} | "
                f"crisis={result.get('crisis_detected')} | type={result.get('crisis_type')}"
            )
            return result

        except Exception as e:
            logging.error(f"[GeminiSpeech] Error: {e}")
            return self._fallback(str(e))
        finally:
            if tmp_path:
                try:
                    os.unlink(tmp_path)
                except Exception:
                    pass

    def _fallback(self, error: str) -> Dict[str, Any]:
        return {
            "transcription_original": "",
            "transcription_english": f"Transcription failed: {error}",
            "detected_language": "unknown",
            "crisis_detected": False,
            "crisis_keywords": [],
            "crisis_type": "unknown",
            "urgency_level": "MEDIUM",
            "location_mentions": [],
            "confidence": 0.0,
            "urdu_summary": "آواز کی تحریر ناکام ہوگئی",
        }
