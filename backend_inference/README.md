# backend_inference

Lightweight FastAPI multimodal inference starter for SilentSOS.

This service exposes endpoints:

- `POST /transcribe` - accepts an audio file and returns `{text, language}` (uses `faster-whisper` if available, otherwise returns a placeholder).
- `POST /classify_text` - accepts JSON `{text}` and returns `{label, score}`. Uses `sentence-transformers` if available; otherwise a simple keyword heuristic fallback is used.
- `POST /classify_image` - accepts an image and returns predictions using a Transformers image classifier if available.
- `POST /upload_recording` - saves uploaded audio to `/tmp/recordings` and returns path.

Quick start (Linux / macOS / WSL / PowerShell with python available):

```bash
cd backend_inference
python -m venv .venv
# On Windows PowerShell:
# & .venv\Scripts\Activate.ps1
# On Unix:
# source .venv/bin/activate
pip install -r requirements.txt
python app.py
# or: uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

Notes:
- The server will start even if heavy ML packages fail to install; it will run with fallback heuristics for text/image when the full models are unavailable.
- For production, install all requirements and provide a GPU-enabled host for larger Whisper/transformer models.
- Use the Dockerfile to containerize the service.
