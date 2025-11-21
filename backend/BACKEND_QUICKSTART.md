# Silent SOS Backend – Quick Start Guide

## Environment Setup

### Windows (PowerShell)
```powershell
cd C:\projects\silent_sos\backend

# Create virtualenv (first time only)
python -m venv .venv
& .\.venv\Scripts\Activate.ps1

# Install dependencies
pip install -U pip
pip install -r requirements.txt
pip install faster-whisper
```

### Linux/macOS (Bash)
```bash
cd backend

# Create virtualenv (first time only)
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -U pip
pip install -r requirements.txt
pip install faster-whisper
```

## Start the Server

### Windows – Option A: Using start_server.bat
```powershell
cd C:\projects\silent_sos\backend
.\start_server.bat
```

### Windows – Option B: Manual (PowerShell)
```powershell
cd C:\projects\silent_sos\backend
& .\.venv\Scripts\Activate.ps1
$env:WHISPER_MODEL='small'
$env:WHISPER_DEVICE='cpu'
python -m uvicorn server:app --host 0.0.0.0 --port 3001 --workers 1
```

### Linux/macOS – Option A: Using start_server.sh
```bash
cd backend
chmod +x start_server.sh
./start_server.sh
```

### Linux/macOS – Option B: Manual (Bash)
```bash
cd backend
source .venv/bin/activate
export WHISPER_MODEL=small
export WHISPER_DEVICE=cpu
python -m uvicorn server:app --host 0.0.0.0 --port 3001 --workers 1
```

## Test the Endpoint

### Option 1: Test /ping (Health check)
```powershell
Invoke-RestMethod -Uri 'http://127.0.0.1:3001/ping' -Method Get
```

### Option 2: Test Transcription with test_sine.py
```powershell
cd C:\projects\silent_sos\backend
python test_sine.py
```
This generates a small WAV file and sends it to `/api/v1/transcribe_and_analyze`.

### Option 3: Manual test with curl
```bash
curl -X POST "http://127.0.0.1:3001/api/v1/transcribe_and_analyze" \
  -F "audio=@test_sine.wav" \
  -F "lang_hint=en"
```

## Docker Deployment (Production)

### Build the image
```bash
docker build -t silent-sos-backend:latest .
```

### Run the container
```bash
docker run -d \
  --name silent-sos-backend \
  -p 8000:8000 \
  -e WHISPER_MODEL=large-v2 \
  -e WHISPER_DEVICE=cpu \
  -v $(pwd)/models:/app/models \
  silent-sos-backend:latest
```

### Using docker-compose (optional)
```yaml
version: '3'
services:
  backend:
    build: .
    ports:
      - "8000:8000"
    environment:
      WHISPER_MODEL: large-v2
      WHISPER_DEVICE: cpu
    volumes:
      - ./models:/app/models
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WHISPER_MODEL` | `large-v2` | Whisper model size (tiny, base, small, medium, large-v2) |
| `WHISPER_DEVICE` | `cpu` | Device (cpu or cuda if NVIDIA GPU available) |
| `USE_CUDA` | `0` | Deprecated; use WHISPER_DEVICE instead |

## Troubleshooting

### Port Already in Use
```powershell
# Windows: Find and stop process using port 3001
netstat -ano | findstr :3001
taskkill /PID <PID> /F

# Linux/macOS:
lsof -i :3001
kill -9 <PID>
```

### Module Not Found
Ensure all dependencies are installed:
```bash
pip install -r requirements.txt
pip install faster-whisper pillow
```

### ffmpeg Not Found
Install via system package manager:
- Windows: `choco install ffmpeg` (requires Chocolatey) or download from ffmpeg.org
- Ubuntu/Debian: `sudo apt-get install ffmpeg`
- macOS: `brew install ffmpeg`

### Server Exits Immediately
Check for errors in the terminal output. Common issues:
- Port is already in use
- Missing dependencies (run `pip install -r requirements.txt`)
- Python module path issues (ensure you're in the backend folder)

## API Endpoints

### `/ping` (GET)
Health check. Returns `{"status": "Silent SOS backend running"}`

### `/api/v1/analyze` (POST)
Analyzes image/audio (multipart or JSON base64).
- Supports web (JSON base64) and native (multipart) clients.
- Returns severity, instructions, and diagnostics.

### `/api/v1/transcribe_and_analyze` (POST)
Transcribes audio using local Whisper model, then analyzes.
- Accepts audio as multipart file or JSON base64.
- Returns transcript, detected language, severity, and instructions.

## Notes

- For development, use `WHISPER_MODEL=small` for fast startup (smaller model download).
- For production, use `WHISPER_MODEL=large-v2` for best accuracy (requires ~3GB download and RAM).
- If you have an NVIDIA GPU, set `WHISPER_DEVICE=cuda` and install CUDA-compatible pytorch/ctranslate2 for faster inference.
- The backend will download the Whisper model on first run; this may take several minutes.
