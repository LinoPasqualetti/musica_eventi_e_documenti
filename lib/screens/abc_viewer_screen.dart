// lib/screens/abc_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class AbcViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const AbcViewerScreen({
    Key? key,
    required this.filePath,
    required this.fileName,
  }) : super(key: key);

  @override
  State<AbcViewerScreen> createState() => _AbcViewerScreenState();
}

class _AbcViewerScreenState extends State<AbcViewerScreen> {
  late WebViewController _controller;
  String _abcContent = '';
  String _error = '';
  bool _isLoading = true;
  bool _isWebViewReady = false;

  @override
  void initState() {
    super.initState();
    _loadAbcContent();
    _initWebView();
  }

  void _loadAbcContent() {
    try {
      final file = File(widget.filePath);
      if (file.existsSync()) {
        _abcContent = file.readAsStringSync();
        print('📄 ABC caricato: ${_abcContent.length} caratteri');
      } else {
        _error = 'File non trovato: ${widget.filePath}';
        print('❌ $_error');
        setState(() { _isLoading = false; });
      }
    } catch (e) {
      _error = 'Errore: $e';
      print('❌ $_error');
      setState(() { _isLoading = false; });
    }
  }

  void _initWebView() {
    final htmlContent = _buildHtmlContent();

    _saveHtmlToTemp(htmlContent).then((path) {
      if (path != null) {
        _controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (int progress) {
                print('🔵 WebView progress: $progress%');
              },
              onPageStarted: (String url) {
                print('🔵 WebView page started: $url');
                setState(() {
                  _isLoading = true;
                });
              },
              onPageFinished: (String url) {
                print('🔵 WebView page finished: $url');
                setState(() {
                  _isLoading = false;
                  _isWebViewReady = true;
                });
              },
              onWebResourceError: (WebResourceError error) {
                print('❌ WebView error: ${error.description}');
                setState(() {
                  _error = 'Errore WebView: ${error.description}';
                  _isLoading = false;
                });
              },
            ),
          )
          ..loadFile(path);
      } else {
        setState(() {
          _error = 'Impossibile creare il file HTML temporaneo';
          _isLoading = false;
        });
      }
    });
  }

  Future<String?> _saveHtmlToTemp(String htmlContent) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/abc_viewer_${DateTime.now().millisecondsSinceEpoch}.html');
      await file.writeAsString(htmlContent, flush: true);
      print('✅ HTML salvato: ${file.path}');
      return file.path;
    } catch (e) {
      print('❌ Errore salvataggio HTML: $e');
      return null;
    }
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
    #error {
      color: #d32f2f;
      padding: 16px;
      background: #ffebee;
      border-radius: 8px;
      text-align: center;
    }
    #playback-controls {
      margin-top: 16px;
      padding: 16px;
      background: #f5f5f5;
      border-radius: 8px;
    }
    .midi-controls {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 16px;
      flex-wrap: wrap;
    }
    .midi-btn {
      padding: 8px 16px;
      border: none;
      border-radius: 8px;
      font-size: 20px;
      cursor: pointer;
      background: #673ab7;
      color: white;
    }
    .midi-btn:hover { background: #7c4dff; }
    .midi-btn:disabled { opacity: 0.5; cursor: not-allowed; }
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
      <button class="btn btn-secondary" onclick="stopABC()">⏹ Stop</button>
      <button class="btn btn-success" onclick="exportPDF()">📄 Esporta PDF</button>
      <button class="btn btn-secondary" onclick="toggleSource()">📋 Mostra ABC</button>
    </div>
    <div id="playback-controls">
      <div class="midi-controls">
        <button class="midi-btn" id="playBtn" onclick="playABC()">▶</button>
        <span id="playback-status">⏸ In attesa</span>
        <input type="range" id="tempoSlider" min="40" max="200" value="120" 
               onchange="setTempo(this.value)" style="width:120px;">
        <span id="tempoLabel">120 BPM</span>
        <button class="midi-btn" onclick="stopABC()">⏹</button>
      </div>
    </div>
    <div id="abc-source"></div>
    <div id="error" style="display:none;"></div>
  </div>
  
  <script src="https://cdn.jsdelivr.net/npm/abcjs@6.0.0/dist/abcjs-basic-min.js"></script>
  <script>
    var abcString = `$escapedAbc`;
    var visualObj = null;
    var midiPlayer = null;
    var isPlaying = false;
    
    if (!abcString || abcString.trim() === '') {
      document.getElementById('error').style.display = 'block';
      document.getElementById('error').innerText = '⚠️ Contenuto ABC vuoto o non valido';
    } else {
      try {
        visualObj = ABCJS.renderAbc('abc-container', abcString, {
          responsive: 'resize',
          staffwidth: 700,
          scale: 1.0,
          paddingtop: 10,
          paddingbottom: 10,
          add_classes: true,
          generateParts: true,
          generatePartNames: true,
        });
        
        if (!visualObj || visualObj.length === 0) {
          document.getElementById('error').style.display = 'block';
          document.getElementById('error').innerText = '⚠️ Errore: ABC non valido o non renderizzabile';
        } else {
          try {
            midiPlayer = new ABCJS.synth.SynthController();
            midiPlayer.load('/',
              function() { console.log('🎵 MIDI Synth caricato'); },
              function(error) { console.warn('⚠️ MIDI Synth error:', error); }
            );
          } catch(e) { console.log('MIDI non disponibile:', e); }
        }
      } catch(e) {
        document.getElementById('error').style.display = 'block';
        document.getElementById('error').innerText = '❌ Errore render: ' + e.message;
        console.error('ABC render error:', e);
      }
    }
    
    function playABC() {
      if (!visualObj || visualObj.length === 0) { alert('Nessuna musica da suonare'); return; }
      if (isPlaying) { stopABC(); return; }
      
      try {
        var synth = new ABCJS.synth.SynthController();
        var midiData = synth.prepare(abcString);
        synth.prime(midiData);
        synth.start();
        isPlaying = true;
        document.getElementById('playBtn').innerHTML = '⏸';
        document.getElementById('playback-status').innerText = '▶ Riproduzione in corso...';
        
        var duration = visualObj[0]?.duration || 30;
        setTimeout(function() { if (isPlaying) stopABC(); }, duration * 1000 + 1000);
      } catch(e) {
        console.error('Errore riproduzione:', e);
        alert('Errore nella riproduzione: ' + e.message);
      }
    }
    
    function stopABC() {
      try {
        if (window.abcjs && window.abcjs.synth) {
          var players = document.querySelectorAll('audio');
          players.forEach(function(p) { p.pause(); });
        }
        isPlaying = false;
        document.getElementById('playBtn').innerHTML = '▶';
        document.getElementById('playback-status').innerText = '⏸ Fermo';
      } catch(e) { console.log('Stop error:', e); }
    }
    
    function setTempo(value) {
      document.getElementById('tempoLabel').innerText = value + ' BPM';
    }
    
    function exportPDF() { window.print(); }
    
    function toggleSource() {
      var sourceDiv = document.getElementById('abc-source');
      if (sourceDiv.style.display === 'block') {
        sourceDiv.style.display = 'none';
      } else {
        sourceDiv.style.display = 'block';
        sourceDiv.innerText = abcString;
      }
    }
    
    window.addEventListener('resize', function() {});
    console.log('🎵 ABC Viewer loaded');
  </script>
</body>
</html>
    ''';
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
                  onPressed: () => _openWithDefaultApp(),
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Apri con app predefinita'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoading || !_isWebViewReady) {
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
            icon: const Icon(Icons.download),
            onPressed: () => _downloadAbc(),
            tooltip: 'Download',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareAbc(),
            tooltip: 'Condividi',
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => _openWithDefaultApp(),
            tooltip: 'Apri con app predefinita',
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }

  void _downloadAbc() async {
    try {
      final file = File(widget.filePath);
      if (await file.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⬇️ Download: ${widget.fileName}'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Errore: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _shareAbc() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🔗 Condivisione ABC'), backgroundColor: Colors.blue),
    );
  }

  void _openWithDefaultApp() async {
    try {
      final result = await OpenFile.open(widget.filePath);
      if (result.type == ResultType.done) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Aperto: ${widget.fileName}'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Errore: $e'), backgroundColor: Colors.red),
      );
    }
  }
}