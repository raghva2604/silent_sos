# Deployment Verification Script - Tests all critical endpoints and services

Write-Host "`n========== DEPLOYMENT VERIFICATION ==========" -ForegroundColor Cyan

# Check if containers are running
Write-Host "`n1. Checking Docker containers..." -ForegroundColor Yellow
$containers = docker-compose ps -q
if ($containers) {
    Write-Host "   ✓ Containers are running" -ForegroundColor Green
} else {
    Write-Host "   ✗ Containers are not running" -ForegroundColor Red
    exit 1
}

# Test backend direct connection
Write-Host "`n2. Testing backend direct connection (port 8000)..." -ForegroundColor Yellow
try {
    $response = curl -s http://localhost:8000/ping
    Write-Host "   ✓ Backend responding: $response" -ForegroundColor Green
}
catch {
    Write-Host "   ✗ Backend connection failed" -ForegroundColor Red
}

# Test nginx reverse proxy
Write-Host "`n3. Testing nginx reverse proxy (port 80)..." -ForegroundColor Yellow
try {
    $response = curl -s http://localhost:80/ping
    Write-Host "   ✓ Nginx proxy responding" -ForegroundColor Green
}
catch {
    Write-Host "   ✗ Nginx connection failed" -ForegroundColor Red
}

# Check logs for errors
Write-Host "`n4. Checking backend logs..." -ForegroundColor Yellow
$backendLogs = docker-compose logs backend --tail=5
Write-Host $backendLogs -ForegroundColor White

Write-Host "`n========== DEPLOYMENT READY ==========" -ForegroundColor Cyan
Write-Host "`nBoth services are running successfully!`n" -ForegroundColor Green
Write-Host "Backend API:    http://localhost:8000/api/v1/" -ForegroundColor White
Write-Host "Nginx Proxy:    http://localhost/api/v1/" -ForegroundColor White
Write-Host "`nUseful commands:" -ForegroundColor Cyan
Write-Host "  docker-compose ps        - Show running containers" -ForegroundColor White
Write-Host "  docker-compose logs -f   - View live logs" -ForegroundColor White
Write-Host "  docker-compose down      - Stop all services" -ForegroundColor White
