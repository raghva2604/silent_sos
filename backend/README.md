Backend: Vosk model installation

This folder contains the backend server and optional offline speech-to-text models.

Where to put Vosk models
- Models should be placed under `backend/models/vosk_<code>/model`.
  Examples:
    - `backend/models/vosk_en/model`
    - `backend/models/vosk_hi/model`
    - `backend/models/vosk_te/model`
    - `backend/models/vosk_gu/model`

Automated installer
- A PowerShell helper exists at `backend/scripts/download_vosk_models.ps1`.
  Usage (PowerShell):

  ```powershell
  # download English (default)
  pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\download_vosk_models.ps1

  # download multiple languages
  pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\download_vosk_models.ps1 -Languages en,hi,te,gu
  ```

- The script is idempotent: it will skip models already installed.

Notes
- Vosk model files are large — check available disk space.
- Models are excluded from git via `.gitignore`; do not commit model binaries to source control.
- After installing models, restart the backend (e.g. `python run.py`) if it was already running so `stt_multilang.py` can load the models.

Deployment (quick)
------------------

Run locally (venv):

```powershell
cd C:\projects\silent_sos\backend
& .\.venv\Scripts\Activate.ps1
python -m uvicorn server:app --host 0.0.0.0 --port 8000 --workers 1
```

Docker (quickstart):

```bash
cd backend
docker-compose build
docker-compose up -d
```

Notes:
- Mount `./models` into the container to keep model files outside the image:
  `- ./models:/app/models`
- Keep TLS certificates under `./certs` and reference them in your `nginx.conf`.
- In production, run behind an authenticated proxy and enforce HTTPS.
