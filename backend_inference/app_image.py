from fastapi import FastAPI, File, UploadFile
from PIL import Image
import io
import numpy as np
import tensorflow as tf
import uvicorn
import tempfile
import os

app = FastAPI()

# Load Keras/TF model (or TFLite). Example: Keras model
MODEL_PATH = "models/image_danger_model"
try:
    model = tf.keras.models.load_model(MODEL_PATH)
except Exception as e:
    print(f"Warning: Could not load image model: {e}")
    model = None

LABELS = ["normal", "fight", "blood", "fall"]

# Load Whisper model for speech-to-text danger detection (lazy load)
whisper_model = None

def get_whisper_model():
    global whisper_model
    if whisper_model is None:
        try:
            from faster_whisper import WhisperModel
            whisper_model = WhisperModel("tiny", device="cpu", compute_type="int8")
        except ImportError:
            print("Warning: faster_whisper not installed; danger_speech endpoint will not work")
    return whisper_model

def preprocess(img: Image.Image, target=(224,224)):
    img = img.resize(target)
    arr = np.array(img).astype("float32")/255.0
    arr = np.expand_dims(arr, 0)
    return arr

@app.post("/analyze_image")
async def analyze_image(file: UploadFile = File(...)):
    if model is None:
        return {"error": "Image model not loaded"}
    contents = await file.read()
    img = Image.open(io.BytesIO(contents)).convert("RGB")
    x = preprocess(img)
    preds = model.predict(x)[0]
    idx = int(np.argmax(preds))
    score = float(preds[idx])
    label = LABELS[idx] if idx < len(LABELS) else str(idx)
    return {"label": label, "score": score, "all": preds.tolist()}

@app.post("/danger_speech")
async def danger_speech(file: UploadFile = File(...)):
    """
    Detect danger words in audio using Whisper tiny.
    Returns transcription and danger_score (0.0 to 1.0).
    """
    whisper = get_whisper_model()
    if whisper is None:
        return {"error": "Whisper model not available"}
    
    contents = await file.read()
    
    # Write to temp file
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp.write(contents)
        tmp_path = tmp.name
    
    try:
        # Transcribe with Whisper
        segments, info = whisper.transcribe(tmp_path)
        text = " ".join([s.text for s in segments]).lower()
        
        # Check for danger words
        danger_words = ["help", "stop", "police", "please no", "don't hurt", "please help", "emergency"]
        danger_count = sum([1 for word in danger_words if word in text])
        danger_score = min(1.0, danger_count / max(1, len(danger_words)))
        
        return {
            "text": text,
            "danger_score": danger_score,
            "danger_words": [w for w in danger_words if w in text]
        }
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001)
