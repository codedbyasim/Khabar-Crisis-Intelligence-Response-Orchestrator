# 📸 Multi-Source Input Pipelines

KHABAR provides citizens with multiple friction-free channels to report metropolitan emergencies, built to handle real-world operational challenges such as local dialects, noisy environments, and unverified reports.

---

## 💬 1. Noisy & Informal Text Processing (Roman Urdu)
Metropolitan citizens in Pakistan frequently report crises using a blend of languages, primarily English, Urdu, and **Roman Urdu** (Urdu written in the Latin alphabet, e.g., *"G-10 mein pani bhar gaya hai, gaariyan phans gayi hain"*). 

### How it works:
1. The **FastAPI Backend Gateway** receives the unstructured text payload via the `POST /report/text` endpoint.
2. The payload is passed to the **Detection Agent** using the `google/gemini-2.5-flash` model.
3. A specialized system prompt instructs Gemini to analyze the informal syntax, extract key entities (e.g., location landmarks like "G-10", "George Town"), detect the type of disaster (e.g., urban flooding), and estimate a confidence score.

---

## 🎙️ 2. Speech-to-Text Voice Pipeline
To support hands-free reporting during active crises, KHABAR features a voice reporting interface in the Flutter app (`VoiceReportScreen`).

### How it works:
1. The citizen records up to 30 seconds of raw audio (supporting English, Urdu, Punjabi, or Pashto).
2. The Flutter application records the audio in `.wav` or `.m4a` format and sends it to the backend via `POST /report/voice`.
3. The backend (`gemini_speech.py`) consumes the raw audio file and directly interfaces with the **Google Gemini API**'s native audio parsing capabilities using the `gemini-2.5-flash` model.
4. Gemini transcribes the audio and extracts the semantic emergency content in a single pass without needing separate Whisper or secondary translation APIs, preserving colloquial nuances.

---

## 📷 3. Vision-Based Damage Verification
Unverified emergency reports can clog up local rescue services. KHABAR includes a photo reporting pipeline (`PhotoVerificationScreen`) to assess damage objectively.

### How it works:
1. The citizen snaps a photo of the incident scene (e.g., structural collapse, road pileup, active fire).
2. The image file is uploaded to the backend via `POST /report/image` alongside any user comments.
3. The backend (`gemini_vision.py`) loads the image binary and forwards it to `gemini-2.5-flash` (Vision configuration).
4. The model processes the visual cues to:
   - Identify the exact disaster signature (e.g., building debris vs. rising water).
   - Rate structural integrity damage on a percentage scale.
   - Verify if the user's report is genuine or a false alarm.
   - Output structured JSON to prioritize the incident in the backend priority queue.
