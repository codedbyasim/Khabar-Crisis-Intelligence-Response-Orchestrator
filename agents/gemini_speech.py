"""
gemini_speech.py — Gemini multilingual audio transcription (google-genai SDK).
FR-03: Voice recordings transcribed in Urdu/Punjabi/Sindhi/English.
"""
import os
import json
import logging
import tempfile
from typing import Dict, Any
from dotenv import load_dotenv

load_dotenv()

from google import genai
from google.genai import types


class GeminiSpeech:
    def __init__(self, api_key: str = None):
        self.api_key = api_key or os.getenv("GEMINI_API_KEY")
        self.client = genai.Client(api_key=self.api_key)
        self.model = "models/gemini-2.5-flash"
        logging.info(f"[GeminiSpeech] Initialized — model: {self.model}")

    def transcribe_audio(
        self, audio_bytes: bytes, mime_type: str = "audio/wav"
    ) -> Dict[str, Any]:
        """
        Transcribe audio and detect crisis signals.
        Supports Urdu, Punjabi, Sindhi, Roman Urdu, English.
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
                
            with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
                tmp.write(audio_bytes)
                tmp_path = tmp.name

            # Upload file via Files API
            uploaded = self.client.files.upload(
                path=tmp_path,
                config=types.UploadFileConfig(mime_type=mime_type),
            )

            prompt = """You are a multilingual crisis transcription AI for KHABAR — Pakistan's emergency system.
Transcribe this audio. Speaker may use Urdu, Punjabi, Sindhi, Roman Urdu, or English.

Return ONLY valid JSON:
{
  "transcription_original": "exact words spoken",
  "transcription_english": "English translation",
  "detected_language": "urdu|punjabi|sindhi|roman_urdu|english",
  "crisis_detected": true,
  "crisis_keywords": ["pani bhar gaya", "aag"],
  "crisis_type": "flood|fire|accident|collapse|medical|heatwave|road_blockage|other",
  "urgency_level": "HIGH|MEDIUM|LOW",
  "location_mentions": ["G-10", "Islamabad"],
  "confidence": 0.94,
  "urdu_summary": "اردو میں خلاصہ"
}

Be sensitive to Pakistani informal crisis phrases like: pani bhar gaya, aag lagi, hadsa, phans gaye, madad karo."""

            response = self.client.models.generate_content(
                model=self.model,
                contents=[prompt, uploaded],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.1,
                ),
            )

            # Cleanup uploaded file
            try:
                self.client.files.delete(name=uploaded.name)
            except Exception:
                pass

            result = json.loads(response.text)
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
