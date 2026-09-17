# avvia-tutto.ps1 - Avvia backend + frontend dev + tunnel Cloudflare

$cloudflaredPath = "C:\Program Files (x86)\cloudflared\cloudflared.exe"
$backendPath = "C:\musica_eventi_e_documenti_web\backend"
$frontendPath = "C:\musica_eventi_e_documenti_web\frontend"

# 1. Backend
Write-Host "🔄 [1/3] Avvio backend..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$backendPath'; npm start"

Write-Host "⏳ Attendo 10 secondi che il backend sia pronto..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# 2. Frontend dev mode
Write-Host "🔄 [2/3] Avvio frontend Vite..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$frontendPath'; npm run dev"

Write-Host "⏳ Attendo 5 secondi che Vite sia pronto..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# 3. Tunnel Cloudflare (verso backend, che serve la versione buildata)
Write-Host "🔄 [3/3] Avvio tunnel Cloudflare (backend)..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "& '$cloudflaredPath' tunnel --url http://127.0.0.1:5000"

Write-Host ""
Write-Host "✅ Tutto avviato in 3 finestre:" -ForegroundColor Green
Write-Host "   1. Backend (porta 5000)" -ForegroundColor White
Write-Host "   2. Frontend Vite (porta 5173)" -ForegroundColor White
Write-Host "   3. Tunnel Cloudflare (URL pubblico)" -ForegroundColor White
Write-Host ""
Write-Host "📋 Controlla le finestre per gli URL e verificare che tutto sia attivo." -ForegroundColor Yellow
Write-Host "   Backend locale: http://localhost:5000" -ForegroundColor White
Write-Host "   Frontend dev:   http://localhost:5173" -ForegroundColor White
Write-Host "   URL pubblico:   vedi la finestra del tunnel" -ForegroundColor White