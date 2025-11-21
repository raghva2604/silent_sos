# stt_multilang.py
import os
import subprocess
import tempfile
import json
import base64
import shutil
from typing import Optional, Tuple, Dict, List

# Vosk imports deferred to runtime
try:
    from vosk import Model as VoskModel, KaldiRecognizer
    VOSK_IMPORTED = True
except Exception:
    VOSK_IMPORTED = False
    VoskModel = None  # type: ignore

# text-based language detection (use if text available)
try:
    from langdetect import detect as detect_lang_text
    LANGDETECT_AVAILABLE = True
except Exception:
    LANGDETECT_AVAILABLE = False

# Argos Translate optional
try:
    import argostranslate.package, argostranslate.translate
    ARGOS_AVAILABLE = True
except Exception:
    ARGOS_AVAILABLE = False

BASE_DIR = os.path.dirname(__file__)
VOSK_BASE = os.path.join(BASE_DIR, "models")  # where you put vosk models, e.g. models/vosk_hi/model
FFMPEG_CMD = "ffmpeg"  # assume on PATH

# Map language codes you will use to vosk model dirs (configure as you download models)
VOSK_LANG_MODELS = {
    # code: relative dir under models
    "en": os.path.join(VOSK_BASE, "vosk_en", "model"),
    "hi": os.path.join(VOSK_BASE, "vosk_hi", "model"),
    "te": os.path.join(VOSK_BASE, "vosk_te", "model"),
    "ta": os.path.join(VOSK_BASE, "vosk_ta", "model"),
    "bn": os.path.join(VOSK_BASE, "vosk_bn", "model"),
    "mr": os.path.join(VOSK_BASE, "vosk_mr", "model"),
    "kn": os.path.join(VOSK_BASE, "vosk_kn", "model"),
    "ml": os.path.join(VOSK_BASE, "vosk_ml", "model"),
    "gu": os.path.join(VOSK_BASE, "vosk_gu", "model"),
    "pa": os.path.join(VOSK_BASE, "vosk_pa", "model"),
}

# Priority list to try when hint absent or fails
DEFAULT_PRIORITY = ["en", "hi", "te", "ta", "bn", "mr", "kn", "ml", "gu", "pa"]

# Cache loaded models to avoid reloading from disk repeatedly
_LOADED_VOSK_MODELS: Dict[str, object] = {}

def ensure_mono_16k(input_path: str) -> str:
    """
    Convert input audio to mono PCM WAV 16k using ffmpeg.
    Returns path to the converted temporary file.
    """
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".wav")
    tmp.close()
    out_path = tmp.name
    cmd = [
        FFMPEG_CMD, "-y", "-i", input_path,
        "-ac", "1", "-ar", "16000", "-sample_fmt", "s16",
        out_path
    ]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if res.returncode != 0:
        # include stderr for debugging
        raise RuntimeError(f"ffmpeg conversion failed: {res.stderr.decode('utf8', errors='ignore')}")
    return out_path

def load_vosk_model(lang_code: str):
    """
    Load and cache a Vosk model for lang_code. Returns VoskModel or raises.
    """
    if not VOSK_IMPORTED:
        raise RuntimeError("VOSK not installed or import failed")
    model_dir = VOSK_LANG_MODELS.get(lang_code)
    if not model_dir or not os.path.exists(model_dir):
        raise FileNotFoundError(f"Vosk model for '{lang_code}' not found at {model_dir}")
    if lang_code in _LOADED_VOSK_MODELS:
        return _LOADED_VOSK_MODELS[lang_code]
    model = VoskModel(model_dir)
    _LOADED_VOSK_MODELS[lang_code] = model
    return model

def transcribe_with_model(audio_wav_path: str, model: VoskModel) -> str:
    """
    Run Vosk on a mono 16k wav file (path) with given model, return string transcript (may be empty).
    """
    import wave
    wf = wave.open(audio_wav_path, "rb")
    if wf.getnchannels() != 1:
        raise RuntimeError("Expected mono WAV for Vosk.")
    rec = KaldiRecognizer(model, wf.getframerate())
    transcript_parts = []
    while True:
        data = wf.readframes(4000)
        if len(data) == 0:
            break
        if rec.AcceptWaveform(data):
            j = json.loads(rec.Result())
            if j.get("text"):
                transcript_parts.append(j["text"])
    final = json.loads(rec.FinalResult())
    if final.get("text"):
        transcript_parts.append(final["text"])
    return " ".join(transcript_parts).strip()

def detect_language_from_text(text: str) -> Optional[str]:
    if not LANGDETECT_AVAILABLE or not text:
        return None
    try:
        code = detect_lang_text(text)
        return code
    except Exception:
        return None

def transcribe_multilang(input_audio_path: str, lang_hint: Optional[str] = None, try_priority: Optional[List[str]] = None) -> Tuple[str, Optional[str], Dict]:
    """
    Main function to call:
    - input_audio_path: path to audio file (any format)
    - lang_hint: client-provided hint like 'en','hi','te' (optional)
    Returns: (transcript, detected_lang_code, diagnostics)
    Diagnostics contains provider details and model tried list.
    """
    diagnostics = {"models_tried": [], "used_model": None}
    # convert to mono 16k wav for Vosk
    converted = None
    try:
        converted = ensure_mono_16k(input_audio_path)
    except Exception as e:
        raise RuntimeError(f"Audio conversion error: {e}")

    try:
        # build the model try list
        if try_priority is None:
            try_priority = DEFAULT_PRIORITY.copy()

        # if hint provided and valid, try it first
        if lang_hint:
            # normalize hint to 2-letter lower-case
            hint = lang_hint.lower().strip()
            if hint in VOSK_LANG_MODELS:
                candidates = [hint] + [c for c in try_priority if c != hint]
            else:
                # if not recognized, still keep priority
                candidates = try_priority
        else:
            candidates = try_priority

        # try each candidate model until non-empty transcript
        for code in candidates:
            model_dir = VOSK_LANG_MODELS.get(code)
            if not model_dir or not os.path.exists(model_dir):
                diagnostics["models_tried"].append({"code": code, "status": "missing"})
                continue
            diagnostics["models_tried"].append({"code": code, "status": "loading"})
            try:
                model = load_vosk_model(code)
                diagnostics["models_tried"][-1]["status"] = "loaded"
            except Exception as e:
                diagnostics["models_tried"][-1]["status"] = f"load_failed:{e}"
                continue
            # run transcription
            try:
                txt = transcribe_with_model(converted, model)
                diagnostics["models_tried"][-1]["transcript_len"] = len(txt)
                if txt:
                    diagnostics["used_model"] = code
                    return txt, code, diagnostics
            except Exception as e:
                diagnostics["models_tried"][-1]["status"] = f"run_failed:{e}"
                continue

        # if none produced text, return empty transcript, prefer final guess (last tried)
        return "", None, diagnostics

    finally:
        # cleanup the converted file
        try:
            if converted and os.path.exists(converted):
                os.remove(converted)
        except Exception:
            pass

# ----------------------------
# Translation helpers (Argos offline + cloud placeholder)
# ----------------------------
def translate_offline_argos(text: str, target_lang: str) -> str:
    """
    Use argostranslate if installed and language pack exists.
    target_lang = two-letter code, e.g. 'hi','te'
    """
    if not ARGOS_AVAILABLE:
        raise RuntimeError("Argos Translate not installed")
    installed = argostranslate.translate.get_installed_languages()
    # find from_lang=English, to_lang=target_lang (or any pair where we can translate)
    from_lang = None
    to_lang = None
    for l in installed:
        if l.code == "en":
            from_lang = l
        if l.code == target_lang:
            to_lang = l
    if not from_lang or not to_lang:
        raise RuntimeError("Required Argos language package not installed")
    return from_lang.translate(text, to_lang)

def translate_text(text: str, target_lang: str, use_cloud: bool = False) -> str:
    """
    Translate using cloud provider if use_cloud True (placeholder), otherwise try Argos offline.
    """
    if not text:
        return text
    if target_lang == "en":
        return text
    if use_cloud:
        # placeholder: configure your cloud translator function
        # return translate_text_cloud(text, target_lang)
        return text  # avoid failure if not configured
    else:
        try:
            if ARGOS_AVAILABLE:
                return translate_offline_argos(text, target_lang)
        except Exception:
            pass
        return text  # fallback to original text if translation unavailable
