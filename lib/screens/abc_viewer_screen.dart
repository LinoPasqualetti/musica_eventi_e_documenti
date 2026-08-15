// lib/screens/abc_viewer_screen.dart
// Versione che usa il browser per la riproduzione (funziona su Android)

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class AbcViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const AbcViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<AbcViewerScreen> createState() => _AbcViewerScreenState();
}

class _AbcViewerScreenState extends State<AbcViewerScreen> {
  String _abcContent = '';
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadAbcContent();
  }

  void _loadAbcContent() {
    try {
      final file = File(widget.filePath);
      if (file.existsSync()) {
        _abcContent = file.readAsStringSync();
        print('📄 ABC caricato: ${_abcContent.length} caratteri');
      } else {
        _error = 'File non trovato: ${widget.filePath}';
      }
    } catch (e) {
      _error = 'Errore: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getAbcInfo() {
    final lines = _abcContent.split('\n');
    String title = '';
    String composer = '';
    String meter = '';
    String key = '';

    int tuneCount = 0;
    for (var line in lines) {
      if (line.startsWith('X:')) tuneCount++;
      if (line.startsWith('T:')) title = line.substring(2).trim();
      if (line.startsWith('C:')) composer = line.substring(2).trim();
      if (line.startsWith('M:')) meter = line.substring(2).trim();
      if (line.startsWith('K:')) key = line.substring(2).trim();
    }

    return 'Titolo: $title\nCompositore: $composer\nMetro: $meter\nTonalità: $key\nBrani totali: $tuneCount\nRighe: ${lines.length}';
  }

  String _buildHtmlContent() {
    final escapedAbc = _abcContent
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('"', '\\"');

    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ABC Viewer</title>
    <script src="https://cdn.jsdelivr.net/npm/abcjs@6.0.0/dist/abcjs-basic-min.js">
    </script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f5f5;
            padding: 16px;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
        }
        #container {
            max-width: 1000px;
            width: 100%;
            background: white;
            border-radius: 12px;
            padding: 20px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        #title { font-size: 24px; font-weight: bold; margin-bottom: 16px; color: #333; text-align: center; }
        #abc-container { padding: 16px; background: #fafafa; border-radius: 8px; border: 1px solid #e0e0e0; min-height: 200px; overflow: auto; }
        #abc-container svg { max-width: 100%; height: auto; }
        #controls { margin-top: 16px; display: flex; gap: 12px; justify-content: center; flex-wrap: wrap; }
        .btn { padding: 10px 20px; border: none; border-radius: 8px; font-size: 14px; font-weight: 600; cursor: pointer; transition: all 0.2s; }
        .btn-play { background: #4caf50; color: white; }
        .btn-play:hover { background: #66bb6a; transform: scale(1.02); }
        .btn-play.playing { background: #ff9800; }
        .btn-stop { background: #f44336; color: white; }
        .btn-stop:hover { background: #ef5350; transform: scale(1.02); }
        .btn-pdf { background: #2196f3; color: white; }
        .btn-pdf:hover { background: #42a5f5; transform: scale(1.02); }
        #status { margin-top: 12px; padding: 8px; text-align: center; font-size: 14px; color: #666; }
        #error { color: #d32f2f; padding: 12px; background: #ffebee; border-radius: 8px; text-align: center; margin-top: 8px; display: none; }
        .tune-selector { margin: 12px 0; display: flex; flex-wrap: wrap; gap: 6px; justify-content: center; }
        .tune-btn { padding: 4px 12px; border: 2px solid #673ab7; border-radius: 16px; background: transparent; color: #673ab7; cursor: pointer; font-size: 12px; font-weight: 500; transition: all 0.2s; }
        .tune-btn.active { background: #673ab7; color: white; }
        .tune-btn:hover { background: #7c4dff; color: white; }
        .midi-warning {
            margin-top: 8px;
            padding: 8px;
            background: #fff3cd;
            border-radius: 8px;
            font-size: 12px;
            color: #856404;
            text-align: center;
        }
    </style>
</head>
<body>
    <div id="container">
        <div id="title">🎵 ${widget.fileName}</div>
        <div id="tune-selector" class="tune-selector"></div>
        <div id="abc-container"></div>
        <div id="controls">
            <button class="btn btn-play" id="playBtn" onclick="playABC()">▶ Play</button>
            <button class="btn btn-stop" onclick="stopABC()">⏹ Stop</button>
            <button class="btn btn-pdf" onclick="exportPDF()">📄 PDF</button>
        </div>
        <div id="status">⏸ In attesa</div>
        <div id="error"></div>
        <div class="midi-warning">💡 Clicca Play per ascoltare</div>
    </div>
    <script>
        var abcString = `$escapedAbc`;
        var visualObj = null;
        var isPlaying = false;
        var currentTuneIndex = 0;
        var tunes = [];
        var tuneTitles = [];
        var audioElement = null;
        var midiUrl = null;

        function showError(msg) {
            var errorDiv = document.getElementById('error');
            errorDiv.style.display = 'block';
            errorDiv.innerText = '❌ ' + msg;
        }

        function hideError() {
            document.getElementById('error').style.display = 'none';
        }

        function updateStatus(text, color) {
            var status = document.getElementById('status');
            status.innerText = text;
            if (color) status.style.color = color;
        }

        function extractTunes(fullAbc) {
            var lines = fullAbc.split('\\n');
            var result = [], titles = [], current = [], currentTitle = '', inTune = false;
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i];
                if (line.trim().startsWith('X:')) {
                    if (inTune && current.length > 0) {
                        result.push(current.join('\\n'));
                        titles.push(currentTitle || 'Brano ' + result.length);
                    }
                    current = [];
                    currentTitle = '';
                    inTune = true;
                }
                if (inTune) {
                    if (line.trim().startsWith('T:') && !currentTitle) {
                        currentTitle = line.trim().substring(2).trim();
                    }
                    current.push(line);
                }
            }
            if (inTune && current.length > 0) {
                result.push(current.join('\\n'));
                titles.push(currentTitle || 'Brano ' + result.length);
            }
            return { tunes: result, titles: titles };
        }

        function renderTune(tuneContent, index) {
            try {
                hideError();
                document.getElementById('abc-container').innerHTML = '';

                visualObj = ABCJS.renderAbc('abc-container', tuneContent, {
                    responsive: 'resize',
                    staffwidth: 700,
                    scale: 1.0,
                    paddingtop: 10,
                    paddingbottom: 10,
                    add_classes: true,
                    generateParts: true,
                    generatePartNames: true,
                    generatePlayback: true,
                });

                if (!visualObj || visualObj.length === 0) {
                    showError('Errore: ABC non valido');
                    updateStatus('❌ Errore', '#d32f2f');
                } else {
                    var title = tuneTitles[index] || 'Brano ' + (index + 1);
                    document.getElementById('title').innerText = '🎵 ' + title;
                    updateStatus('✅ Spartito caricato', '#4caf50');
                }
            } catch (e) {
                showError('Errore render: ' + e.message);
                console.error('ABC render error:', e);
            }
        }

        function initTuneSelector() {
            var selector = document.getElementById('tune-selector');
            selector.innerHTML = '';
            if (tunes.length <= 1) { selector.style.display = 'none'; return; }
            selector.style.display = 'flex';
            for (var i = 0; i < tunes.length; i++) {
                var btn = document.createElement('button');
                btn.className = 'tune-btn' + (i === 0 ? ' active' : '');
                var title = tuneTitles[i] || 'Brano ' + (i + 1);
                btn.textContent = title.length > 25 ? title.substring(0, 22) + '...' : title;
                btn.setAttribute('data-index', i);
                btn.onclick = function(e) {
                    var idx = parseInt(this.getAttribute('data-index'));
                    var btns = document.querySelectorAll('.tune-btn');
                    btns.forEach(function(b) { b.classList.remove('active'); });
                    this.classList.add('active');
                    currentTuneIndex = idx;
                    stopPlayback();
                    renderTune(tunes[idx], idx);
                };
                selector.appendChild(btn);
            }
        }

        function generateMidiFromAbc(abcContent) {
            try {
                // Usa ABCJS.getMidi
                if (typeof ABCJS.getMidi === 'function') {
                    return ABCJS.getMidi(abcContent);
                }
                
                // Fallback: crea MIDI con renderAbc
                var tempDiv = document.createElement('div');
                tempDiv.style.display = 'none';
                document.body.appendChild(tempDiv);
                var tempVisual = ABCJS.renderAbc(tempDiv.id, abcContent, {
                    generatePlayback: true
                });
                document.body.removeChild(tempDiv);
                
                if (tempVisual && tempVisual.length > 0 && tempVisual[0].getMidi) {
                    return tempVisual[0].getMidi();
                }
                return null;
            } catch (e) {
                console.error('Errore generazione MIDI:', e);
                return null;
            }
        }

        function playABC() {
            if (isPlaying) { stopABC(); return; }
            if (!visualObj || visualObj.length === 0) { alert('Nessuna musica da suonare'); return; }

            var playBtn = document.getElementById('playBtn');
            var currentTune = tunes[currentTuneIndex] || abcString;

            try {
                var midiData = generateMidiFromAbc(currentTune);
                if (!midiData) {
                    alert('Impossibile generare il MIDI');
                    return;
                }

                var blob = new Blob([midiData], {type: 'audio/midi'});
                var url = URL.createObjectURL(blob);
                midiUrl = url;

                if (!audioElement) {
                    audioElement = new Audio();
                    audioElement.controls = false;
                    audioElement.style.display = 'none';
                    document.body.appendChild(audioElement);
                }

                audioElement.src = url;
                audioElement.play()
                    .then(function() {
                        isPlaying = true;
                        playBtn.textContent = '⏸ Pausa';
                        playBtn.classList.add('playing');
                        updateStatus('▶ Riproduzione...', '#4caf50');
                    })
                    .catch(function(error) {
                        console.error('Errore play:', error);
                        alert('Errore riproduzione: ' + error.message);
                        isPlaying = false;
                        playBtn.textContent = '▶ Play';
                        playBtn.classList.remove('playing');
                    });

                audioElement.onended = function() { stopABC(); };

            } catch (e) {
                console.error('Errore:', e);
                alert('Errore: ' + e.message);
            }
        }

        function stopABC() {
            try {
                if (audioElement) {
                    audioElement.pause();
                    audioElement.currentTime = 0;
                }
                if (midiUrl) {
                    URL.revokeObjectURL(midiUrl);
                    midiUrl = null;
                }
            } catch (e) {}
            isPlaying = false;
            document.getElementById('playBtn').textContent = '▶ Play';
            document.getElementById('playBtn').classList.remove('playing');
            updateStatus('⏸ Fermo', '#333');
        }

        function exportPDF() { window.print(); }

        function init() {
            if (!abcString || abcString.trim() === '') {
                showError('Contenuto ABC vuoto');
                return;
            }

            try {
                var extracted = extractTunes(abcString);
                tunes = extracted.tunes;
                tuneTitles = extracted.titles;

                if (tunes.length === 0) {
                    showError('Nessun brano trovato');
                    return;
                }

                initTuneSelector();
                renderTune(tunes[0], 0);
            } catch (e) {
                showError('Errore: ' + e.message);
                console.error('Init error:', e);
            }
        }

        init();
        console.log('🎵 ABC Viewer loaded');
    </script>
</body>
</html>
    ''';
  }

  Future<void> _openInBrowser() async {
    try {
      final htmlContent = _buildHtmlContent();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/abc_viewer_${DateTime.now().millisecondsSinceEpoch}.html');
      await file.writeAsString(htmlContent, flush: true);

      final url = file.path;

      if (await canLaunchUrl(Uri.file(url))) {
        await launchUrl(Uri.file(url), mode: LaunchMode.externalApplication);
      } else {
        throw 'Impossibile aprire il browser';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyToClipboard() async {
    try {
      await Clipboard.setData(ClipboardData(text: _abcContent));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📋 ABC copiato negli appunti!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _downloadAbc() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⬇️ Download ABC'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.fileName),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Errore', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_error, style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Indietro'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.fileName),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Caricamento...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openInBrowser,
            tooltip: 'Apri nel browser con spartito',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyToClipboard,
            tooltip: 'Copia ABC',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadAbc,
            tooltip: 'Download',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info file
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.deepPurple.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.deepPurple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getAbcInfo(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Contenuto ABC
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _abcContent,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Pulsanti
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Indietro'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openInBrowser,
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Apri Spartito'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '💡 Clicca "Apri Spartito" per vedere lo spartito e ascoltare la musica',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}