$dbPath = "assets\db\musica_eventi_e_documenti.db"
if (Test-Path $dbPath) {
    Write-Host "✅ DB Flutter trovato: $dbPath" -ForegroundColor Green
    $size = (Get-Item $dbPath).Length / 1MB
    Write-Host "   Dimensione: $([math]::Round($size, 2)) MB"
} else {
    Write-Host "❌ DB Flutter non trovato in: $dbPath" -ForegroundColor Red
}
