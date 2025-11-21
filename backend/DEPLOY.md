# Silent SOS Backend — Production Deployment with Docker

## Quick Start

### Prerequisites
- Docker and docker-compose installed on your server
- Models in `./models/vosk_*/model` (they'll be mounted as a volume)
- TLS certificates in `./certs/` (optional for HTTPS)

### 1. Build and Run

```bash
cd backend
docker-compose build
docker-compose up -d
```

Check logs:
```bash
docker-compose logs -f backend
docker-compose logs -f nginx
```

### 2. Verify

Test the endpoint:
```bash
curl http://localhost:8000/api/v1/health
# or from emulator: http://10.0.2.2:8000/api/v1/transcribe_and_analyze
```

### 3. Stop/Restart

```bash
# Stop all services
docker-compose down

# Restart
docker-compose up -d

# View running containers
docker ps
```

## Production Notes

- **Port 8000**: Backend API (internal, not exposed)
- **Port 80**: Nginx HTTP (reverse proxy to backend)
- **Port 443**: Nginx HTTPS (requires TLS certs in `./certs/`)
- **Models volume**: `./models:/app/models` keeps model files outside the Docker image (safe for updates)

## Enable HTTPS (Let's Encrypt)

1. Place your TLS certificate and key in `./certs/`:
   ```bash
   ./certs/fullchain.pem   # certificate chain
   ./certs/privkey.pem     # private key
   ```

2. Update `nginx.conf` to serve HTTPS (uncomment 443 block and set cert paths).

3. Restart:
   ```bash
   docker-compose restart nginx
   ```

## Troubleshooting

- **Port 8000/80/443 already in use**: Change `docker-compose.yml` ports mapping (e.g., `"8001:8000"`)
- **Model not loading**: Ensure `./models/vosk_*/model/` exists with Vosk files. Run `backend/scripts/download_vosk_models.ps1` locally first, then copy to server.
- **Nginx 502 Bad Gateway**: Check backend container is running (`docker ps`) and logs (`docker-compose logs backend`)

## Example: Remote Deployment to VPS

1. Copy `backend/` folder to server:
   ```bash
   scp -r backend/ user@your-vps.com:/home/user/silent_sos/
   ```

2. SSH in and run:
   ```bash
   cd /home/user/silent_sos/backend
   docker-compose up -d
   ```

3. Configure DNS to point to your VPS IP and test:
   ```bash
   curl https://api.yourdomain.com/api/v1/transcribe_and_analyze
   ```
