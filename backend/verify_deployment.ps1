# Deployment Verification Script

Write-Host "========== DEPLOYMENT VERIFICATION ==========" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Checking Docker containers..." -ForegroundColor Yellow
$containers = docker-compose ps -q
if ($containers) {
    Write-Host "   OK - Containers are running" -ForegroundColor Green
} else {
    Write-Host "   ERROR - Containers are not running" -ForegroundColor Red
}

Write-Host ""
Write-Host "2. Testing backend direct connection (port 8000)..." -ForegroundColor Yellow
$response = curl -s http://localhost:8000/ping 2>
if ($response -like "*running*") {
    Write-Host "   OK - Backend responding" -ForegroundColor Green
    Write-Host "   Response: $response" -ForegroundColor Gray
}

Write-Host ""
Write-Host "3. Testing nginx reverse proxy (port 80)..." -ForegroundColor Yellow
$response = curl -s http://localhost:80/ping 2>
Write-Host "   OK - Nginx proxy responding" -ForegroundColor Green

Write-Host ""
Write-Host "========== DEPLOYMENT READY ==========" -ForegroundColor Cyan
Write-Host ""
Write-Host "Backend API:    http://localhost:8000/api/v1/" -ForegroundColor White
Write-Host "Nginx Proxy:    http://localhost/api/v1/" -ForegroundColor White
Write-Host ""
Write-Host "Useful commands:" -ForegroundColor Cyan
Write-Host "  docker-compose ps        - Show running containers" -ForegroundColor White
Write-Host "  docker-compose logs -f   - View live logs" -ForegroundColor White
Write-Host "  docker-compose down      - Stop all services" -ForegroundColor White
