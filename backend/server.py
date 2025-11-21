from fastapi import FastAPI, File, UploadFile, Form, Request
from fastapi.responses import JSONResponse
import uuid, time
from fastapi.middleware.cors import CORSMiddleware

import os
import numpy as np
from PIL import Image
from dotenv import load_dotenv

# Import multi-language STT helper
from stt_multilang import transcribe_multilang

# Load environment variables from a local .env file if present (do NOT commit .env)
load_dotenv()
try:
    from tflite_runtime.interpreter import Interpreter
except Exception:
    try:
        from tensorflow.lite.python.interpreter import Interpreter
    except Exception:
        Interpreter = None
import base64
import tempfile
import shutil
import logging
import requests

# faster-whisper for local transcription
try:
    from faster_whisper import WhisperModel
except Exception:
    WhisperModel = None

# vosk for simple offline transcription
try:
    from vosk import Model, KaldiRecognizer
except Exception:
    Model = None
    KaldiRecognizer = None

# wave module (needed for Vosk audio processing)
import wave

# TFLite model paths
MODELS_DIR = os.path.join(os.path.dirname(__file__), "models")
TFLITE_MODEL_PATH = os.path.join(MODELS_DIR, "injury_detector.tflite")
LABELS_PATH = os.path.join(MODELS_DIR, "labels.txt")

_tflite_cache = None
_whisper_cache = None

# Whisper model selection (override via env)
WHISPER_MODEL_NAME = os.environ.get("WHISPER_MODEL", "large-v2")
# Device can be 'cpu' or 'cuda' (if available). Override with env var.
WHISPER_DEVICE = os.environ.get("WHISPER_DEVICE", "cpu")

def load_tflite():
    global _tflite_cache
    if _tflite_cache is not None:
        return _tflite_cache
    if not os.path.exists(TFLITE_MODEL_PATH):
        return None
    interpreter = Interpreter(model_path=TFLITE_MODEL_PATH)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    _tflite_cache = (interpreter, input_details, output_details)
    return _tflite_cache

def run_tflite_image_model(image_path: str):
    """
    Returns (label, confidence) or (None, 0.0)
    """
    res = load_tflite()
    if res is None:
        return None, 0.0
    interpreter, input_details, output_details = res

    # load and preprocess
    img = Image.open(image_path).convert("RGB")
    # model expects input shape [1, h, w, 3]
    in_shape = input_details[0]['shape']
    h, w = int(in_shape[1]), int(in_shape[2])
    img = img.resize((w, h))
    arr = np.array(img).astype(np.float32) / 255.0
    input_data = np.expand_dims(arr, axis=0)

    # set input and run
    interpreter.set_tensor(input_details[0]['index'], input_data)
    interpreter.invoke()
    out = interpreter.get_tensor(output_details[0]['index'])
    probs = np.squeeze(out)
    top = int(np.argmax(probs))
    conf = float(probs[top])

    # read labels
    if os.path.exists(LABELS_PATH):
        with open(LABELS_PATH, "r", encoding="utf-8") as f:
            labels = [l.strip() for l in f.readlines()]
        label = labels[top] if top < len(labels) else f"class_{top}"
    else:
        label = f"class_{top}"
    return label, conf


def load_whisper():
    global _whisper_cache
    if _whisper_cache is not None:
        return _whisper_cache
    if WhisperModel is None:
        return None
    try:
        model = WhisperModel(WHISPER_MODEL_NAME, device=WHISPER_DEVICE)
        _whisper_cache = model
        return model
    except Exception as e:
        logging.exception("Failed to load Whisper model: %s", e)
        return None


def transcribe_with_faster_whisper(audio_path: str, lang_hint: str = "auto"):
    """
    Transcribe audio using faster-whisper. Returns (transcript_text, detected_language)
    """
    model = load_whisper()
    if model is None:
        return None, None

    try:
        # faster-whisper returns (segments, info)
        segments, info = model.transcribe(audio_path, language=None if lang_hint in (None, "auto") else lang_hint)
        texts = []
        for segment in segments:
            # each segment has .text
            texts.append(segment.text)
        transcript = "".join(texts).strip()
        detected_lang = getattr(info, "language", None)
        return transcript, detected_lang
    except Exception:
        logging.exception("Whisper transcription failed")
        return None, None


def transcribe_with_openai(audio_path: str, model: str = "whisper-1"):
    """
    Debug wrapper for OpenAI transcription - prints request/response for troubleshooting.
    Returns (transcript_text, detected_language_or_None).
    """
    import sys
    api_key = os.environ.get("STT_API_KEY")
    if not api_key:
        print("[STT DEBUG] STT_API_KEY is NOT set in environment", file=sys.stderr)
        raise RuntimeError("STT_API_KEY not set in environment")

    url = "https://api.openai.com/v1/audio/transcriptions"
    try:
        with open(audio_path, "rb") as f:
            files = {"file": (os.path.basename(audio_path), f, "application/octet-stream")}
            data = {"model": model}
            headers = {"Authorization": f"Bearer {api_key}"}

            print(f"[STT DEBUG] Sending transcription request to {url} with model={model}, file={audio_path}", file=sys.stderr)
            resp = requests.post(url, headers=headers, data=data, files=files, timeout=120)

        print(f"[STT DEBUG] Response status: {resp.status_code}", file=sys.stderr)
        # Print response body (may contain error details)
        print(f"[STT DEBUG] Response body: {resp.text}", file=sys.stderr)

        resp.raise_for_status()
        j = resp.json()
        transcript = j.get("text") or j.get("transcript") or ""
        print(f"[STT DEBUG] Transcript extracted length={len(transcript)}", file=sys.stderr)
        return transcript, None

    except requests.HTTPError as e:
        # Print HTTP error detail
        print(f"[STT DEBUG] HTTPError: {type(e).__name__} - {getattr(e,'response',None) and e.response.text}", file=sys.stderr)
        raise
    except Exception as e:
        print(f"[STT DEBUG] Exception during transcription: {type(e).__name__}: {e}", file=sys.stderr)
        raise


def transcribe_with_vosk(audio_path: str):
    """
    Returns (transcript, language). Expects a mono WAV file (PCM).
    """
    if not Model or not KaldiRecognizer:
        raise RuntimeError("Vosk is not properly installed. Install with: pip install vosk")
    
    # adjust the model path if your extracted folder includes the versioned name
    # e.g. "models/vosk_en/vosk-model-small-en-us-0.15" or "models/vosk_en/model"
    model_folder = os.path.join(os.path.dirname(__file__), "models", "vosk_en")
    # if versioned folder exists, use it
    if os.path.exists(os.path.join(model_folder, "model")):
        model_path = os.path.join(model_folder, "model")
    else:
        # maybe extracted into a versioned folder, find first matching dir
        children = [d for d in os.listdir(model_folder) if os.path.isdir(os.path.join(model_folder, d))]
        if children:
            model_path = os.path.join(model_folder, children[0])
        else:
            model_path = model_folder  # fallback

    if not os.path.exists(model_path):
        raise RuntimeError(f"Vosk model not found at: {model_path}")

    # open wav
    wf = wave.open(audio_path, "rb")
    # Vosk expects mono; check and raise helpful error
    if wf.getnchannels() != 1:
        raise RuntimeError("Audio must be mono WAV (1 channel). Convert with ffmpeg: ffmpeg -i in.wav -ac 1 out.wav")

    sample_rate = wf.getframerate()
    model = Model(model_path)
    rec = KaldiRecognizer(model, sample_rate)

    transcript_parts = []
    while True:
        data = wf.readframes(4000)
        if len(data) == 0:
            break
        if rec.AcceptWaveform(data):
            import json
            res = rec.Result()
            parsed = json.loads(res)
            text = parsed.get("text", "")
            if text:
                transcript_parts.append(text)
    # final
    final = rec.FinalResult()
    import json
    parsed_final = json.loads(final)
    if parsed_final.get("text"):
        transcript_parts.append(parsed_final.get("text"))

    transcript = " ".join(transcript_parts).strip()
    return transcript, "en"
async def save_uploadfile_to_temp(upload_file: UploadFile) -> str:
    """Save an incoming FastAPI UploadFile to a temp file. Returns the path."""
    suffix = os.path.splitext(upload_file.filename)[-1] or ".wav"
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
    # use async read
    contents = await upload_file.read()
    tmp.write(contents)
    tmp.flush()
    tmp.close()
    return tmp.name


def save_b64_to_temp(b64: str, suffix: str = ".wav") -> str:
    """Decode base64 string to a temp file and return the path."""
    data = base64.b64decode(b64)
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
    tmp.write(data)
    tmp.flush()
    tmp.close()
    return tmp.name


# --- Core analysis logic (extracted so endpoints can reuse) ------------
def analyze_core(text: str | None, image_path: str | None, audio_path: str | None, lang_hint: str = "auto", device_offline: bool = False):
    """Run image model and simple rule-engine over provided inputs.
    Returns a dict with keys: severity, instruction, call_emergency, diagnostics
    """
    diagnostics = {}

    # Run TFLite image model if we have an image file
    if image_path is not None:
        label, confidence = run_tflite_image_model(image_path)
        diagnostics.update({"image_label": label, "image_confidence": confidence})

    # Simple rule engine using transcript/text
    txt = (text or "")
    severity = "critical" if "bleeding" in txt.lower() else "moderate"

    if severity == "critical":
        instruction = [
            "Apply direct pressure to the wound.",
            "Use a clean cloth.",
            "Elevate the injured part if possible.",
            "Call emergency services immediately."
        ]
    else:
        instruction = [
            "Monitor the person.",
            "Provide basic first aid.",
            "Call emergency services if condition worsens."
        ]

    return {
        "severity": severity,
        "instruction": instruction,
        "call_emergency": severity == "critical",
        "diagnostics": diagnostics,
    }


app = FastAPI(title="Silent SOS - Emergency AI Backend (offline-first)")

# ---- Add this CORS middleware block (development only) ----
# For development allow all origins. In production restrict to your app domain.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],                # use ["https://your-domain.com"] in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
# -------------------------------------------------------------

@app.post("/api/v1/analyze")
async def analyze(
    request: Request,
    lang_hint: str = Form("auto"),
    device_offline: bool = Form(False),
    text: str = Form(None),
    image: UploadFile = File(None),
    audio: UploadFile = File(None),
    image_b64: str = Form(None),
    audio_b64: str = Form(None),
):
    request_id = str(uuid.uuid4())

    # diagnostics placeholder (will include model results if available)
    diagnostics = {}
    saved_image_path = None
    saved_audio_path = None

    # If request was sent as JSON (web path), extract base64 fields from JSON body
    content_type = request.headers.get("content-type", "")
    if content_type.startswith("application/json"):
        try:
            body = await request.json()
            # override Form values with JSON values when present
            text = body.get("text", text)
            image_b64 = body.get("image_b64", image_b64)
            audio_b64 = body.get("audio_b64", audio_b64)
            lang_hint = body.get("lang_hint", lang_hint)
            # device_offline may be sent as string
            dev_off = body.get("device_offline", device_offline)
            if isinstance(dev_off, str):
                device_offline = dev_off.lower() in ("1", "true", "yes")
            else:
                device_offline = bool(dev_off)
        except Exception:
            pass

    # If base64-encoded image/audio present, decode into temp files first
    if image_b64:
        try:
            b = base64.b64decode(image_b64)
            tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg")
            tmp.write(b)
            tmp.flush()
            tmp.close()
            saved_image_path = tmp.name
        except Exception:
            saved_image_path = None

    if audio_b64:
        try:
            b = base64.b64decode(audio_b64)
            tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".wav")
            tmp.write(b)
            tmp.flush()
            tmp.close()
            saved_audio_path = tmp.name
        except Exception:
            saved_audio_path = None

    # If multipart UploadFile present, prefer it over base64 data
    if image is not None:
        ext = os.path.splitext(image.filename)[1] or ".jpg"
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=ext)
        contents = await image.read()
        tmp.write(contents)
        tmp.flush()
        tmp.close()
        saved_image_path = tmp.name

    if audio is not None:
        ext = os.path.splitext(audio.filename)[1] or ".wav"
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=ext)
        contents = await audio.read()
        tmp.write(contents)
        tmp.flush()
        tmp.close()
        saved_audio_path = tmp.name

    # Delegate core analysis to reusable function
    core = analyze_core(text, saved_image_path, saved_audio_path, lang_hint, device_offline)

    return JSONResponse({
        "request_id": request_id,
        "processing_ms": int(time.time() * 1000),
        **core
    })


@app.post("/api/v1/transcribe_and_analyze")
async def transcribe_and_analyze(
    request: Request,
    lang_hint: str = Form("auto"),
    device_offline: bool = Form(False),
    text: str = Form(None),
    image: UploadFile = File(None),
    audio: UploadFile = File(None),
    image_b64: str = Form(None),
    audio_b64: str = Form(None),
):
    """Accepts audio (multipart or base64) and an optional image; transcribes audio locally
    using faster-whisper (if available) then runs the same lightweight analysis pipeline.
    """
    request_id = str(uuid.uuid4())
    diagnostics = {}
    saved_image_path = None
    saved_audio_path = None

    content_type = request.headers.get("content-type", "")
    if content_type.startswith("application/json"):
        try:
            body = await request.json()
            text = body.get("text", text)
            image_b64 = body.get("image_b64", image_b64)
            audio_b64 = body.get("audio_b64", audio_b64)
            lang_hint = body.get("lang_hint", lang_hint)
            dev_off = body.get("device_offline", device_offline)
            if isinstance(dev_off, str):
                device_offline = dev_off.lower() in ("1", "true", "yes")
            else:
                device_offline = bool(dev_off)
        except Exception:
            pass

    # decode base64 if present
    try:
        if image_b64:
            b = base64.b64decode(image_b64)
            tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg")
            tmp.write(b)
            tmp.flush()
            tmp.close()
            saved_image_path = tmp.name
    except Exception:
        saved_image_path = None

    try:
        if audio_b64:
            b = base64.b64decode(audio_b64)
            tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".wav")
            tmp.write(b)
            tmp.flush()
            tmp.close()
            saved_audio_path = tmp.name
    except Exception:
        saved_audio_path = None

    # multipart uploads override
    if image is not None:
        ext = os.path.splitext(image.filename)[1] or ".jpg"
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=ext)
        contents = await image.read()
        tmp.write(contents)
        tmp.flush()
        tmp.close()
        saved_image_path = tmp.name

    if audio is not None:
        ext = os.path.splitext(audio.filename)[1] or ".wav"
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=ext)
        contents = await audio.read()
        tmp.write(contents)
        tmp.flush()
        tmp.close()
        saved_audio_path = tmp.name

    # Multi-language transcription: use Vosk with language hint preference
    if saved_audio_path:
        try:
            transcript, detected_language, mlang_diagnostics = transcribe_multilang(
                saved_audio_path, 
                lang_hint=lang_hint
            )
            diagnostics["transcription_provider"] = "vosk_multilang"
            diagnostics["transcription_available"] = bool(transcript)
            diagnostics["models_tried"] = mlang_diagnostics.get("models_tried", [])
            if mlang_diagnostics.get("used_model"):
                diagnostics["used_model"] = mlang_diagnostics["used_model"]
        except Exception as e:
            import sys
            print(f"[MULTILANG STT] transcription error: {e}", file=sys.stderr)
            transcript = ""
            detected_language = "en"
            diagnostics["transcription_available"] = False
            diagnostics["transcription_provider"] = None
    else:
        transcript = ""
        detected_language = "en"

    # Delegate core analysis to reusable function (use transcript as text)
    core = analyze_core(transcript, saved_image_path, saved_audio_path, lang_hint, device_offline)

    # cleanup temp files (best-effort)
    try:
        if saved_image_path and os.path.exists(saved_image_path):
            os.remove(saved_image_path)
        if saved_audio_path and os.path.exists(saved_audio_path):
            os.remove(saved_audio_path)
    except Exception:
        logging.exception("Failed cleaning up temp files")

    # merge core diagnostics with any transcription diagnostics
    response_diagnostics = core.get("diagnostics", {}).copy()
    response_diagnostics.update(diagnostics)

    resp = {
        "request_id": request_id,
        "processing_ms": int(time.time() * 1000),
        **{k: v for k, v in core.items() if k != "diagnostics"},
        "diagnostics": response_diagnostics,
        "transcript": transcript,
        "detected_language": detected_language,
    }

    return JSONResponse(resp)

@app.get("/ping")
async def ping():
    return {"status": "Silent SOS backend running"}
