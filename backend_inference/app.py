import os
from fastapi import FastAPI, UploadFile, File
from pydantic import BaseModel
import io
import uvicorn

app = FastAPI()

# Try to import heavy ML libs; if missing we provide lightweight fallbacks so the
# server can start for smoke tests without installing large packages.
whisper = None
sentence_model = None
image_clf = None
try:
    from faster_whisper import WhisperModel
    from sentence_transformers import SentenceTransformer
    from transformers import pipeline
    from PIL import Image

    WHISPER_MODEL_SIZE = os.environ.get("WHISPER_MODEL", "small")
    try:
        whisper = WhisperModel(WHISPER_MODEL_SIZE, device="cpu", compute_type="int8")
    except Exception:
        whisper = None

    try:
        sentence_model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')
    except Exception:
        sentence_model = None

    try:
        image_clf = pipeline("image-classification", model="google/vit-base-patch16-224", device=-1)
    except Exception:
        image_clf = None
except Exception:
    # If imports failed, leave whisper/sentence_model/image_clf as None
    whisper = None
    sentence_model = None
    image_clf = None

class TextReq(BaseModel):
    text: str

@app.post("/transcribe")
async def transcribe(file: UploadFile = File(...)):
    # expects an audio file (wav/mp3/m4a)
    contents = await file.read()
    # faster-whisper expects path or bytes; save quickly to a temp file
    tmp = f"/tmp/upload_audio_{os.getpid()}.wav"
    with open(tmp, "wb") as f:
        f.write(contents)
    if whisper is None:
        # fallback: return a placeholder indicating transcription is not available
        return {"text": "", "language": "unknown", "warning": "Whisper not available on this host"}
    segments, info = whisper.transcribe(tmp, beam_size=5)
    text = " ".join([s.text for s in segments])
    return {"text": text, "language": info.language}

@app.post("/classify_text")
async def classify_text(req: TextReq):
    text = req.text
    # example: a simple semantic similarity against few labels (you can fine-tune later)
    labels = ["safe", "injury", "panic", "fall", "unknown"]
    if sentence_model is None:
        # lightweight fallback: keyword-based heuristic
        low = text.lower()
        if any(k in low for k in ["bleed", "blood", "injury", "hurt"]):
            return {"label": "injury", "score": 0.8, "fallback": True}
        if any(k in low for k in ["help", "please", "panic", "scared", "danger"]):
            return {"label": "panic", "score": 0.7, "fallback": True}
        if any(k in low for k in ["fell", "fall", "fallen"]):
            return {"label": "fall", "score": 0.75, "fallback": True}
        return {"label": "safe", "score": 0.5, "fallback": True}

    embedded = sentence_model.encode([text] + labels)
    text_emb = embedded[0]
    label_embs = embedded[1:]
    import numpy as np
    sims = np.dot(label_embs, text_emb) / (np.linalg.norm(label_embs, axis=1)*np.linalg.norm(text_emb)+1e-9)
    best_idx = int(np.argmax(sims))
    return {"label": labels[best_idx], "score": float(sims[best_idx])}

@app.post("/classify_image")
async def classify_image(file: UploadFile = File(...)):
    contents = await file.read()
    if image_clf is None:
        return {"predictions": [], "warning": "image classifier not available on this host"}
    img = Image.open(io.BytesIO(contents)).convert("RGB")
    # pipeline returns list of {label, score}
    out = image_clf(img, top_k=3)
    return {"predictions": out}

@app.post("/upload_recording")
async def upload_recording(file: UploadFile = File(...), meta: str = ""):
    # save file and optionally trigger transcription / notify contacts
    outpath = f"/tmp/recordings/{file.filename}"
    os.makedirs(os.path.dirname(outpath), exist_ok=True)
    contents = await file.read()
    with open(outpath, "wb") as f:
        f.write(contents)
    # optionally run transcription (not executed here by default)
    return {"ok": True, "path": outpath}

if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
