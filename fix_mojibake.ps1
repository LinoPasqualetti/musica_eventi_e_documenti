# fix_mojibake.ps1
# Corregge mojibake in main.js e spartito-viewer.html

$ErrorActionPreference = 'Stop'
cd C:\musica_eventi_e_documenti

# Mappa mojibake -> carattere corretto
$replacements = [ordered]@{
    'â–¾'  = '▾'   # U+25BE small down triangle
    'â–¸'  = '▸'   # U+25B8 small right triangle
    'â– '  = '■'   # U+25A0 black square
    'â–¶'  = '▶'   # U+25B6 black right triangle
    'â¬‡'  = '⬇'   # U+2B07 down arrow
    'â¬œ'  = '⏹'   # U+23F9 stop
    'âˆ’'  = '−'   # U+2212 minus
    'â†º'  = '↺'   # U+21BA counterclockwise
    'â†»'  = '↻'   # U+21BB clockwise
    'â†'   = '↺'   # U+21BA variant
    'ðŸ“'  = '📁'  # U+1F4C1 folder
    'ðŸŽµ' = '🎵'  # U+1F3B5 music
    'âœ…'  = '✅'   # U+2705 check
    'âŒ'   = '❌'   # U+274C cross
    'âš '  = '⚠️'  # U+26A0 warning
}

function Fix-File($filePath) {
    Write-Host "`n=== $filePath ===" -ForegroundColor Cyan

    if (-not (Test-Path $filePath)) {
        Write-Host "❌ File non trovato" -ForegroundColor Red
        return
    }

    $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
    Copy-Item $filePath "$filePath.bak_mojibake_$ts"
    Write-Host "📦 Backup: $filePath.bak_mojibake_$ts" -ForegroundColor DarkGray

    # Leggi come UTF-8
    $content = [System.IO.File]::ReadAllText((Resolve-Path $filePath), [System.Text.Encoding]::UTF8)

    $total = 0
    foreach ($k in $replacements.Keys) {
        $old = $content
        $content = $content.Replace($k, $replacements[$k])
        if ($content.Length -ne $old.Length) {
            $delta = $old.Length - $content.Length
            Write-Host "  ✓ '$k' → '$($replacements[$k])' ($delta char)" -ForegroundColor Green
            $total += $delta
        }
    }

    # Scrivi come UTF-8 senza BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Resolve-Path $filePath), $content, $utf8NoBom)

    Write-Host "✅ $total modifiche applicate" -ForegroundColor Green

    # Verifica
    $check = [System.IO.File]::ReadAllText((Resolve-Path $filePath), [System.Text.Encoding]::UTF8)
    $remaining = ([regex]::Matches($check, 'â€|â†|â¬|ðŸ|â–')).Count
    Write-Host "Mojibake rimasti: $remaining" -ForegroundColor $(if ($remaining -eq 0) {'Green'} else {'Yellow'})

    if ($remaining -gt 0) {
        Write-Host "Contesto residuo:" -ForegroundColor Yellow
        Select-String -Path $filePath -Pattern "â€|â†|â¬|ðŸ|â–" |
            ForEach-Object { "  {0,5}: {1}" -f $_.LineNumber, $_.Line.Trim() } |
            Select-Object -First 10
    }
}

# Applica a tutti i file del viewer
Fix-File "assets\html\spartito-viewer.html"
Fix-File "assets\html\js\app\main.js"
Fix-File "assets\html\css\spartito-viewer.css"

Write-Host "`n--- Fatto ---" -ForegroundColor Cyan