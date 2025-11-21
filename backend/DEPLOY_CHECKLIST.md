# Production deployment checklist for Silent SOS Backend

Before deploying to production:

## 1. Security
- [ ] Rotate any leaked API keys (check `.env` for plaintext secrets)
- [ ] Move API keys to environment variables, not `.env` file
- [ ] Enable HTTPS (TLS certificates in `./certs/`)
- [ ] Set nginx to enforce HTTPS and redirect HTTP → HTTPS

## 2. Models
- [ ] Ensure `./models/vosk_*/model/` directories exist with all language models
- [ ] Run `backend/scripts/download_vosk_models.ps1` locally to download models (from Windows)
- [ ] Copy models folder to server: `scp -r ./models/ user@server:/app/models/`

## 3. Docker Setup
- [ ] Docker and docker-compose installed on server
- [ ] `./certs/fullchain.pem` and `./certs/privkey.pem` in place (or disable 443 in nginx if HTTP-only)
- [ ] Firewall allows ports 80/443 (and 8000 if direct access needed)

## 4. Environment
- [ ] Set `STT_API_KEY` in environment if using external STT (currently not needed for Vosk-only setup)
- [ ] Set `PYTHONUNBUFFERED=1` in docker-compose for real-time logs

## 5. Deployment Commands

```bash
cd backend

# Build image (takes ~5-10 min first time, includes Python deps + ffmpeg)
docker-compose build

# Start services in background
docker-compose up -d

# Check logs
docker-compose logs -f

# Test endpoint
curl http://localhost:8000/api/v1/transcribe_and_analyze

# Restart if needed
docker-compose restart
```

## 6. Post-Deployment
- [ ] Monitor logs for errors: `docker-compose logs -f`
- [ ] Set up log rotation or export logs to external service (e.g., CloudWatch, ELK)
- [ ] Configure backups for model files (if using cloud storage)
- [ ] Set up monitoring/alerting for API response times

## 7. Scale (Optional)
- [ ] Increase `--workers` in `server.py` CMD in Dockerfile for multi-worker uvicorn
- [ ] Add load balancer (nginx upstream) if deploying multiple backend replicas
- [ ] Use a cloud-managed service (AWS ECS, Google Cloud Run, etc.) for auto-scaling

## Quick Deploy Script (for VPS)

```bash
#!/bin/bash
set -e
cd /home/user/silent_sos/backend
docker-compose pull  # get latest images
docker-compose build --no-cache
docker-compose down  # stop old version
docker-compose up -d # start new version
docker-compose logs -f
```
