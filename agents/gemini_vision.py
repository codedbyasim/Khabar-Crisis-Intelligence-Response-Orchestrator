"""
gemini_vision.py — Crisis image analysis via AIML API (OpenAI-compatible).
FR-02: Photo damage assessment using vision model.
Migrated from google-genai SDK to AIML API (openai client).
"""
import os
import json
import base64
import logging
from typing import Dict, Any
from dotenv import load_dotenv

from openai import OpenAI

load_dotenv()


class GeminiVision:
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
        self.model = "google/gemini-2.5-flash"
        logging.info(f"[GeminiVision] Initialized — model: {self.model} (AIML API)")

    def analyze_crisis_image(
        self, image_bytes: bytes, mime_type: str = "image/jpeg"
    ) -> Dict[str, Any]:
        """Analyze a crisis scene image using AIML Vision API."""
        try:
            # Normalize mime_type: if application/octet-stream or not starting with image/, default to image/jpeg
            if not mime_type or not mime_type.startswith("image/") or mime_type == "application/octet-stream":
                mime_type = "image/jpeg"

            # Resize and compress image using Pillow to prevent large payloads causing 400 errors
            from io import BytesIO
            from PIL import Image

            try:
                original_size = len(image_bytes)
                img = Image.open(BytesIO(image_bytes))
                
                # Convert RGBA to RGB if saving as JPEG
                if img.mode in ("RGBA", "P") and mime_type in ("image/jpeg", "image/jpg"):
                    img = img.convert("RGB")
                
                # Downscale if dimensions exceed 1024
                max_dim = 1024
                if max(img.width, img.height) > max_dim:
                    img.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)
                
                # Save back to bytes
                out_io = BytesIO()
                # Determine format name
                img_format = "JPEG"
                if "png" in mime_type.lower():
                    img_format = "PNG"
                elif "webp" in mime_type.lower():
                    img_format = "WEBP"
                elif "gif" in mime_type.lower():
                    img_format = "GIF"
                    
                img.save(out_io, format=img_format, quality=75 if img_format != "PNG" else None)
                image_bytes = out_io.getvalue()
                logging.info(
                    f"[GeminiVision] Compressed image from {original_size} bytes to {len(image_bytes)} bytes "
                    f"(dimensions: {img.width}x{img.height}, format: {img_format})"
                )
            except Exception as resize_err:
                logging.warning(f"[GeminiVision] Image resizing/compression failed: {resize_err}. Using original bytes.")

            # Encode image to base64 data URL (OpenAI vision format)
            b64_image = base64.b64encode(image_bytes).decode("utf-8")
            data_url = f"data:{mime_type};base64,{b64_image}"

            prompt = """You are a crisis detection AI for KHABAR — Pakistan's emergency response system.
Analyze this image and identify any crisis or emergency situation.

Return ONLY valid JSON:
{
  "crisis_type": "flood|fire|accident|building_collapse|heatwave|road_blockage|medical|unknown",
  "severity": "CRITICAL|HIGH|MEDIUM|LOW",
  "priority": "P1|P2|P3|P4|P5",
  "confidence": 0.92,
  "detected_elements": ["stranded vehicles", "rising water"],
  "affected_count_estimate": 50,
  "description": "Clear description of what is visible",
  "urdu_description": "اردو میں تفصیل",
  "location_clues": ["road signs", "landmarks"],
  "immediate_actions": ["dispatch rescue", "close road"],
  "gemini_reasoning": "Why you classified this as this type/severity"
}

Priority: P1=life-threatening, P2=serious, P3=moderate, P4=low, P5=info."""

            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {
                                "type": "image_url",
                                "image_url": {"url": data_url},
                            },
                        ],
                    }
                ],
                response_format={"type": "json_object"},
                temperature=0.1,
            )

            content = response.choices[0].message.content
            result = json.loads(content)
            logging.info(
                f"[GeminiVision] ✅ {result.get('crisis_type')} | "
                f"Priority: {result.get('priority')} | "
                f"Confidence: {int(float(result.get('confidence', 0)) * 100)}%"
            )
            return result

        except Exception as e:
            logging.error(f"[GeminiVision] Error: {e}")
            return self._fallback(str(e))

    def _fallback(self, error: str) -> Dict[str, Any]:
        return {
            "crisis_type": "unknown", "severity": "HIGH", "priority": "P2",
            "confidence": 0.3, "detected_elements": ["analysis_unavailable"],
            "affected_count_estimate": 0,
            "description": f"Vision analysis failed: {error}. Manual review required.",
            "urdu_description": "تصویر کا تجزیہ ناکام ہوگیا۔",
            "location_clues": [], "immediate_actions": ["manual_review_required"],
            "gemini_reasoning": f"System error: {error}",
        }
