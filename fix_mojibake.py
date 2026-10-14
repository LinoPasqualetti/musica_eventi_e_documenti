# fix_mojibake.py
# -*- coding: utf-8 -*-
"""
Corregge il mojibake (doppia codifica UTF-8 <-> Latin-1)
nei file del viewer spartito.
Tutte le stringhe sono scritte come escape Unicode: nessun
problema di encoding del sorgente.
"""
import os
import shutil
import sys
from datetime import datetime

# Mappa: pattern_mojibake -> carattere_corretto
# Le chiavi sono scritte come escape \uXXXX, così sono
# indipendenti dall'encoding con cui è salvato il file .py
REPLACEMENTS = {
    # triangoli toggle
    '\u00e2\u2013\u00be': '\u25be',   # Ã¢â€“Â¾ -> ▾
    '\u00e2\u2013\u00b8': '\u25b8',   # Ã¢â€“Â¸ -> ▸
    # quadrato stop
    '\u00e2\u2013\u00a0': '\u25a0',   # Ã¢â€“  -> ■
    # triangolo play
    '\u00e2\u2013\u00b6': '\u25b6',   # Ã¢â€“Â¶ -> ▶
    # frecce download/stop
    '\u00e2\u00ac\u2021': '\u2b07',   # Ã¢Â¬â€¡ -> ⬇
    '\u00e2\u00ac\u0153': '\u23f9',   # Ã¢Â¬Å“ -> ⏹
    # segno meno
    '\u00e2\u02c6\u2019': '\u2212',   # Ã¢Ë†â€™ -> −
    # frecce reset
    '\u00e2\u2020\u00ba': '\u21ba',   # Ã¢â€ â€” -> ↺
    '\u00e2\u2020\u00bb': '\u21bb',   # Ã¢â€ â€” -> ↻
    '\u00e2\u2020':       '\u21ba',   # Ã¢â€  -> ↺
    # emoji (4 byte UTF-8 letti come 2-3 byte Latin-1)
    '\u00f0\u0178\u201c': '\U0001F4C1',        # ðŸ“ -> 📁
    '\u00f0\u0178\u017d\u00b5': '\U0001F3B5',  # ðŸŽµ -> 🎵
    # check / cross / warning
    '\u00e2\u0153\u2026': '\u2705',   # Ã¢Å“â€¦ -> ✅
    '\u00e2\u0152':       '\u274c',   # Ã¢Å’  -> ❌
    '\u00e2\u0161\u00a0': '\u26a0\ufe0f',  # Ã¢Å¡  -> ⚠️
}

def fix_file(path):
    print(f"\n=== {path} ===")
    if not os.path.exists(path):
        print(f"❌ Non trovato: {path}")
        return

    ts = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup = f"{path}.bak_mojibake_{ts}"
    shutil.copy2(path, backup)
    print(f"📦 Backup: {backup}")

    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    total = 0
    for old, new in REPLACEMENTS.items():
        if old in content:
            count = content.count(old)
            content = content.replace(old, new)
            print(f"  ✓ {old!r} -> {new!r} ({count}x)")
            total += count

    with open(path, 'w', encoding='utf-8', newline='') as f:
        f.write(content)

    print(f"✅ {total} sostituzioni")

    with open(path, 'r', encoding='utf-8') as f:
        check = f.read()

    patterns = ['\u00e2\u20ac', '\u00e2\u2020', '\u00e2\u00ac',
                '\u00f0\u0178', '\u00e2\u2013']
    remaining = sum(check.count(p) for p in patterns)
    print(f"Mojibake rimasti: {remaining}")

    if remaining > 0:
        print("Contesto residuo (prime 5 righe):")
        for i, line in enumerate(check.split('\n'), 1):
            if any(p in line for p in patterns):
                print(f"  {i:5}: {line.strip()[:120]}")
                if i > 5:
                    break

if __name__ == '__main__':
    os.chdir(r'C:\musica_eventi_e_documenti')
    fix_file('assets/html/spartito-viewer.html')
    fix_file('assets/html/js/app/main.js')
    fix_file('assets/html/css/spartito-viewer.css')
    print("\n--- Fatto ---")