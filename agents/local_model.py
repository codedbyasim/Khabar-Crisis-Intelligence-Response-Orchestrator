"""
local_model.py — Local Gemma GGUF model loader for KHABAR offline fallback.
Uses llama-cpp-python to run H:\\khabar\\models\\gemma-4-E2B-it-UD-IQ2_M.gguf on CPU.

Chain:  AIML API  →  Local Gemma (this module)  →  Hardcoded JSON (last resort)

Features:
  - Lazy loading: model loads only on first call (server starts instantly)
  - Thread-safe singleton
  - JSON-mode enforcement with retry
  - Graceful degradation if llama-cpp-python is not installed
"""
import os
import json
import logging
import threading
from typing import Optional

# Path to local model file
MODEL_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "models", "Qwen2.5-0.5B-Instruct-Q4_K_M.gguf")

_llm = None
_llm_lock = threading.Lock()
_load_attempted = False


def _load_model() -> bool:
    """Load the local Qwen GGUF model. Returns True if successful."""
    global _llm, _load_attempted
    if _load_attempted:
        return _llm is not None
    _load_attempted = True

    if not os.path.exists(MODEL_PATH):
        logging.warning(
            f"[LocalModel] GGUF model not found at: {MODEL_PATH}\n"
            "Local model fallback will be unavailable."
        )
        return False

    try:
        from llama_cpp import Llama  # type: ignore
        logging.info(f"[LocalModel] Loading Qwen GGUF from: {MODEL_PATH} ...")
        _llm = Llama(
            model_path=MODEL_PATH,
            n_ctx=2048,          # context window
            n_threads=4,         # CPU threads
            n_gpu_layers=0,      # CPU-only (no GPU required)
            verbose=False,
        )
        logging.info("[LocalModel] ✅ Qwen GGUF loaded successfully!")
        return True
    except ImportError:
        logging.warning(
            "[LocalModel] llama-cpp-python is not installed. "
            "Run: pip install llama-cpp-python\n"
            "Local model fallback will be unavailable."
        )
        return False
    except Exception as e:
        logging.error(f"[LocalModel] Failed to load GGUF model: {e}")
        return False


def is_available() -> bool:
    """Check if the local model is available (model file exists + llama-cpp installed)."""
    with _llm_lock:
        return _load_model()


def generate_json(system_prompt: str, user_prompt: str, max_tokens: int = 1024) -> Optional[str]:
    """
    Generate a JSON response from the local Gemma model.
    Returns JSON string on success, None on failure.
    """
    with _llm_lock:
        if not _load_model():
            return None

    try:
        # Format prompt in ChatML template for Qwen
        full_prompt = (
            f"<|im_start|>system\n"
            f"{system_prompt}\n\n"
            f"CRITICAL: Respond ONLY with valid JSON, no markdown, no explanation.<|im_end|>\n"
            f"<|im_start|>user\n"
            f"INPUT: {user_prompt}<|im_end|>\n"
            f"<|im_start|>assistant\n"
            "{"
        )

        response = _llm(
            full_prompt,
            max_tokens=max_tokens,
            temperature=0.1,
            stop=["<|im_end|>", "<|im_start|>"],
            echo=False,
        )

        raw_text = "{" + response["choices"][0]["text"].strip()

        # Try to extract valid JSON
        # Find the last closing brace to handle any trailing text
        brace_count = 0
        end_idx = -1
        for i, ch in enumerate(raw_text):
            if ch == '{':
                brace_count += 1
            elif ch == '}':
                brace_count -= 1
                if brace_count == 0:
                    end_idx = i
                    break

        if end_idx != -1:
            json_str = raw_text[:end_idx + 1]
            json.loads(json_str)  # validate
            logging.info("[LocalModel] ✅ Local Qwen generated valid JSON response.")
            return json_str

        logging.warning("[LocalModel] Could not extract valid JSON from local model output.")
        return None

    except Exception as e:
        logging.error(f"[LocalModel] Inference error: {e}")
        return None


def generate_chat_response(message: str, language: str = "en", sector: str = "Islamabad") -> str:
    """
    Generate a conversational crisis-assistant response for the /local-chat endpoint.
    Returns a plain text/markdown string.
    """
    with _llm_lock:
        if not _load_model():
            return "⚠️ Local Qwen GGUF model is not loaded (missing llama-cpp-python or model file)."

    try:
        if language == "ur":
            system_prompt = (
                "You are KHABAR, the offline crisis assistant for Islamabad and Rawalpindi. "
                f"The user is located in sector/area: {sector}. You MUST reply ONLY in pure Urdu language using Arabic script (اردو رسم الخط).\n"
                "Facts:\n"
                "- ریسکیو 1122 (ایمبولینس، فائر، ریسکیو): 1122\n"
                "- پولیس ایمرجنسی: 15\n"
                "- فائر بریگیڈ (اسلام آباد): 16\n"
                "- واسا (پانی اور سیوریج): 1334\n"
                "- نالہ لئی میں پانی کی سطح: 18 فٹ سے زیادہ ہونے پر واسا الرٹ جاری کرتا ہے۔\n"
                "- حفاظتی تدابیر: بارش میں گھر کے اندر رہیں، بجلی کے کھمبوں سے دور رہیں، اور انڈر پاسز سے بچیں۔\n"
                "- اگر گھر میں پانی آ جائے: بجلی کے آلات کے سوئچ بند کر دیں، دوسری منزل یا اونچی جگہ پر چلے جائیں، اور ہنگامی صورت میں 1122 پر کال کریں۔\n\n"
                "CRITICAL: Answer concisely. Only provide facts listed above. Do NOT make up any instructions or numbers."
            )
            few_shot = (
                "<|im_start|>user\nاسلام آباد کے ہنگامی نمبرز؟<|im_end|>\n"
                "<|im_start|>assistant\nاسلام آباد کے ہنگامی رابطہ نمبر یہ ہیں:\n"
                "- ریسکیو (ایمبولینس، آگ): 1122\n"
                "- پولیس: 15\n"
                "- فائر بریگیڈ: 16\n"
                "- واسا (پانی کی فراہمی): 1334<|im_end|>\n"
                "<|im_start|>user\nبارش میں کیا حفاظتی تدابیر ہونی چاہئیں؟<|im_end|>\n"
                "<|im_start|>assistant\nبارش کے دوران درج ذیل حفاظتی تدابیر اختیار کریں:\n"
                "- گھر کے اندر رہیں اور غیر ضروری سفر سے گریز کریں۔\n"
                "- بجلی کے کھمبوں اور تاروں سے دور رہیں۔\n"
                "- نچلے علاقوں اور انڈر پاسز میں جانے سے بچیں۔<|im_end|>\n"
            )
        elif language == "roman":
            system_prompt = (
                "You are KHABAR, the offline crisis assistant for Islamabad and Rawalpindi. "
                f"The user is located in sector/area: {sector}. You MUST reply ONLY in Roman Urdu (Urdu written in Latin/English script, e.g. 'Aap 1122 call karein').\n"
                "Facts:\n"
                "- Rescue 1122 (Ambulance, Fire, Rescue): 1122\n"
                "- Police Emergency: 15\n"
                "- Fire Brigade (Islamabad): 16\n"
                "- WASA (Water Supply & Sewerage): 1334\n"
                "- Nullah Lai Water Levels: WASA monitors. Warning if exceeds 18 feet.\n"
                "- Safety Rules: Barish mein ghar pe rahein, bijli ke khambon se door rahein, underpasses se bachein.\n"
                "- Agar ghar mein pani aa jaye: Bijli ke appliances unplug karein, doosri floor ya oonchi jagah chale jayein, aur 1122 call karein.\n\n"
                "CRITICAL: Answer concisely. Only provide facts listed above. Do NOT make up any instructions or numbers."
            )
            few_shot = (
                "<|im_start|>user\nIslamabad key emergency contact numbers batao?<|im_end|>\n"
                "<|im_start|>assistant\nIslamabad ke emergency contact numbers yeh hain:\n"
                "- Rescue 1122 (Ambulance, Fire): 1122\n"
                "- Police: 15\n"
                "- Fire Brigade: 16\n"
                "- WASA (Water Supply): 1334<|im_end|>\n"
                "<|im_start|>user\nBarish mein kya safety rules hain?<|im_end|>\n"
                "<|im_start|>assistant\nBarish aur flooding mein safety ke liye yeh karein:\n"
                "- Ghar pe rahein aur non-essential travel se bachein.\n"
                "- Bijli ke khambon aur wires se door rahein.\n"
                "- Underpasses aur flooded areas mein gaadi na chalayein.<|im_end|>\n"
            )
        else:
            system_prompt = (
                "You are KHABAR, the offline crisis assistant for Islamabad and Rawalpindi. "
                f"The user is located in sector/area: {sector}. You MUST reply ONLY in English.\n"
                "Facts:\n"
                "- Rescue 1122 (Ambulance, Fire, Rescue): 1122\n"
                "- Police Emergency: 15\n"
                "- Fire Brigade (Islamabad): 16\n"
                "- WASA (Water Supply & Sewerage): 1334\n"
                "- Nullah Lai Water Levels: Monitored by WASA. Alert if exceeds 18 feet.\n"
                "- Safety Rules: Stay indoors during heavy rain, avoid underpasses, stay away from electrical poles.\n"
                "- If water enters the house: Unplug appliances, move to a higher floor/ground, call 1122 for emergency help.\n\n"
                "CRITICAL: Answer concisely. Only provide facts listed above. Do NOT make up any instructions or numbers."
            )
            few_shot = (
                "<|im_start|>user\nEmergency contact numbers for Islamabad?<|im_end|>\n"
                "<|im_start|>assistant\nEmergency contact numbers for Islamabad are:\n"
                "- Rescue 1122 (Ambulance, Fire): 1122\n"
                "- Police Emergency: 15\n"
                "- Fire Brigade: 16\n"
                "- WASA: 1334<|im_end|>\n"
                "<|im_start|>user\nWhat are the safety rules for heavy rain?<|im_end|>\n"
                "<|im_start|>assistant\nDuring heavy rain, follow these safety guidelines:\n"
                "- Stay indoors and avoid non-essential travel.\n"
                "- Avoid underpasses and flooded roadways.\n"
                "- Stay away from electrical poles and fallen wires.<|im_end|>\n"
            )

        full_prompt = (
            f"<|im_start|>system\n{system_prompt}<|im_end|>\n"
            f"{few_shot}"
            f"<|im_start|>user\n{message}<|im_end|>\n"
            f"<|im_start|>assistant\n"
        )

        response = _llm(
            full_prompt,
            max_tokens=256,
            temperature=0.1,  # lower temperature for more deterministic/factual output
            stop=["<|im_end|>", "<|im_start|>"],
            echo=False,
        )
        reply = response["choices"][0]["text"].strip()
        if reply:
            logging.info("[LocalModel] ✅ Local Qwen chat response generated.")
            return reply
        return "⚠️ Local Qwen GGUF model generated an empty response. Please retry."

    except Exception as e:
        logging.error(f"[LocalModel] Chat inference error: {e}")
        return f"⚠️ Local Qwen model inference failed: {str(e)[:150]}"
