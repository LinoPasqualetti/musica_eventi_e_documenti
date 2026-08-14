// lib/screens/abc_viewer_screen.dart
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

    for (var line in lines) {
      if (line.startsWith('T:')) title = line.substring(2).trim();
      if (line.startsWith('C:')) composer = line.substring(2).trim();
      if (line.startsWith('M:')) meter = line.substring(2).trim();
      if (line.startsWith('K:')) key = line.substring(2).trim();
    }

    return '''
Titolo: $title
Compositore: $composer
Metro: $meter
Tonalità: $key
Righe: ${lines.length}
Caratteri: ${_abcContent.length}
''';
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
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/abcjs@6.0.0/dist/abcjs-basic.css">
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
      max-width: 900px;
      width: 100%;
      background: white;
      border-radius: 12px;
      padding: 20px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }
    #title {
      font-size: 24px;
      font-weight: bold;
      margin-bottom: 16px;
      color: #333;
      text-align: center;
    }
    #abc-container {
      padding: 16px;
      background: #fafafa;
      border-radius: 8px;
      border: 1px solid #e0e0e0;
      min-height: 200px;
      overflow: auto;
    }
    #abc-container svg { max-width: 100%; height: auto; }
    #controls {
      margin-top: 16px;
      display: flex;
      gap: 12px;
      flex-wrap: wrap;
      justify-content: center;
    }
    .btn {
      padding: 10px 20px;
      border: none;
      border-radius: 8px;
      font-size: 14px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s;
    }
    .btn-primary { background: #673ab7; color: white; }
    .btn-primary:hover { background: #7c4dff; transform: scale(1.02); }
    .btn-secondary { background: #e0e0e0; color: #333; }
    .btn-secondary:hover { background: #d0d0d0; }
    .btn-success { background: #4caf50; color: white; }
    .btn-success:hover { background: #66bb6a; }
    .btn-danger { background: #dc3545; color: white; }
    .btn-danger:hover { background: #c82333; }
    #error {
      color: #d32f2f;
      padding: 16px;
      background: #ffebee;
      border-radius: 8px;
      text-align: center;
      margin-top: 16px;
    }
    #abc-source {
      margin-top: 16px;
      padding: 12px;
      background: #263238;
      color: #aed581;
      border-radius: 8px;
      font-family: monospace;
      font-size: 12px;
      max-height: 200px;
      overflow: auto;
      display: none;
      white-space: pre-wrap;
      word-wrap: break-word;
    }
    #playback-status {
      margin-top: 16px;
      padding: 12px;
      background: #f5f5f5;
      border-radius: 8px;
      text-align: center;
      font-weight: 500;
    }
    @media (max-width: 600px) {
      #container { padding: 12px; }
      #title { font-size: 18px; }
      .btn { padding: 8px 16px; font-size: 12px; }
    }
  </style>
</head>
<body>
  <div id="container">
    <div id="title">🎵 ${widget.fileName}</div>
    <div id="abc-container"></div>
    <div id="controls">
      <button class="btn btn-primary" onclick="playABC()">▶ Play</button>
      <button class="btn btn-danger" onclick="stopABC()">⏹ Stop</button>
      <button class="btn btn-success" onclick="exportPDF()">📄 Esporta PDF</button>
      <button class="btn btn-secondary" onclick="toggleSource()">📋 Mostra ABC</button>
    </div>
    <div id="abc-source"></div>
    <div id="error" style="display:none;"></div>
    <div id="playback-status">⏸ In attesa</div>
  </div>
  
  <script src="https://cdn.jsdelivr.net/npm/abcjs@6.0.0/dist/abcjs-basic-min.js"></script>
  <script>
    var abcString = `$escapedAbc`;
    var visualObj = null;
    var isPlaying = false;
    var audioElement = null;
    var currentUrl = null;
    
    function showError(msg) {
      var errorDiv = document.getElementById('error');
      errorDiv.style.display = 'block';
      errorDiv.innerText = msg;
    }
    
    function hideError() {
      document.getElementById('error').style.display = 'none';
    }
    
    function updateStatus(text, color) {
      var status = document.getElementById('playback-status');
      status.innerText = text;
      if (color) status.style.color = color;
    }
    
    if (!abcString || abcString.trim() === '') {
      showError('⚠️ Contenuto ABC vuoto o non valido');
    } else {
      try {
        hideError();
        visualObj = ABCJS.renderAbc('abc-container', abcString, {
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
          showError('⚠️ Errore: ABC non valido o non renderizzabile');
        } else {
          updateStatus('✅ Spartito caricato', '#4caf50');
          
          // Crea l'elemento audio per il MIDI
          try {
            audioElement = new Audio();
            audioElement.controls = false;
            audioElement.style.display = 'none';
            document.body.appendChild(audioElement);
          } catch(e) {
            console.warn('Audio non disponibile:', e);
          }
        }
      } catch(e) {
        showError('❌ Errore render: ' + e.message);
        console.error('ABC render error:', e);
      }
    }
    
    function playABC() {
      if (!visualObj || visualObj.length === 0) {
        alert('Nessuna musica da suonare');
        return;
      }
      
      if (isPlaying) {
        stopABC();
        return;
      }
      
      try {
        // Metodo: usa ABCJS.getMidi per generare il MIDI
        var midiContent = ABCJS.getMidi(abcString);
        if (!midiContent) {
          alert('Impossibile generare il MIDI da questo ABC');
          return;
        }
        
        // Converti i dati MIDI in un blob
        var midiData = midiContent;
        var blob = new Blob([midiData], {type: 'audio/midi'});
        var url = URL.createObjectURL(blob);
        currentUrl = url;
        
        if (audioElement) {
          audioElement.src = url;
          audioElement.play();
          isPlaying = true;
          updateStatus('▶ Riproduzione...', '#4caf50');
          
          audioElement.onended = function() {
            stopABC();
          };
          
          audioElement.onerror = function() {
            // Se il MIDI non funziona, prova con la versione web di abcjs
            alert('Errore: il browser potrebbe non supportare la riproduzione MIDI.\nProva a usare un visualizzatore online.');
            stopABC();
          };
        } else {
          alert('Player audio non disponibile');
        }
      } catch(e) {
        console.error('Errore riproduzione:', e);
        alert('Errore nella riproduzione: ' + e.message);
      }
    }
    
    function stopABC() {
      try {
        if (audioElement) {
          audioElement.pause();
          audioElement.currentTime = 0;
        }
        if (currentUrl) {
          URL.revokeObjectURL(currentUrl);
          currentUrl = null;
        }
        isPlaying = false;
        updateStatus('⏸ Fermo', '#333');
      } catch(e) {
        console.log('Stop error:', e);
      }
    }
    
    function exportPDF() {
      window.print();
    }
    
    function toggleSource() {
      var sourceDiv = document.getElementById('abc-source');
      if (sourceDiv.style.display === 'block') {
        sourceDiv.style.display = 'none';
      } else {
        sourceDiv.style.display = 'block';
        sourceDiv.innerText = abcString;
      }
    }
    
    window.addEventListener('resize', function() {
      if (visualObj) {
        ABCJS.renderAbc('abc-container', abcString, {
          responsive: 'resize',
          staffwidth: Math.min(700, window.innerWidth - 80),
          scale: 1.0,
          paddingtop: 10,
          paddingbottom: 10,
        });
      }
    });
    
    console.log('🎵 ABC Viewer loaded');
    console.log('ABC length:', abcString.length);
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
      print('📂 Apertura in browser: $url');

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
                const Text(
                  'Errore',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _error,
                  style: TextStyle(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
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

            // Legenda colori
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildLegendItem('X:', 'Numero', Colors.blue),
                _buildLegendItem('T:', 'Titolo', Colors.green),
                _buildLegendItem('C:', 'Compositore', Colors.orange),
                _buildLegendItem('M:', 'Metro', Colors.purple),
                _buildLegendItem('K:', 'Tonalità', Colors.red),
                _buildLegendItem('|', 'Battuta', Colors.grey),
                _buildLegendItem('%%', 'Commento', Colors.grey.shade400),
              ],
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
              '💡 Clicca "Apri Spartito" per vedere le note e ascoltare la musica',
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

  Widget _buildLegendItem(String key, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$key $label',
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}