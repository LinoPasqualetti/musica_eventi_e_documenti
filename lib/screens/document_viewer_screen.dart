// lib/screens/document_viewer_screen.dart
import 'package:url_launcher/url_launcher.dart';
//
// import 'package:android_intent_plus/android_intent.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:audioplayers/audioplayers.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/document.dart';
import '../services/database_service.dart';
import '../services/document_file_resolver.dart';
import '../services/mxl_service.dart';
import '../utils/performance_logger.dart';

// 🔥 IMPORT DELLE SCHERMATE INTERNE
import 'abc_viewer_screen.dart';
import 'mxl_viewer_screen.dart';


class DocumentViewerScreen extends StatefulWidget {
  final Document document;

  const DocumentViewerScreen({Key? key, required this.document}) : super(key: key);

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  final DatabaseService _db = DatabaseService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isLoading = true;
  String? _filePath;
  String? _error;
  bool _isMidi = false;
  bool _isAudio = false;
  bool _isImage = false;
  bool _isPdf = false;
  bool _isText = false;
  bool _isStructured = false;

  // 🔥 VARIABILE PER IL CONTENUTO (ABC o XML)
  String _content = '';

  @override
  void initState() {
    super.initState();
    PerformanceLogger.info('DocumentViewerScreen inizializzato');
    _resolveDocumentPath();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _resolveDocumentPath() async {
    PerformanceLogger.start('_resolveDocumentPath');

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fullDocument = await _db.getDocumentById(widget.document.id);
      Document documentToResolve = fullDocument ?? widget.document;

      final docType = widget.document.docType.toLowerCase();
      _isMidi = ['mid', 'kar'].contains(docType);
      _isAudio = ['audio_mp3', 'audio_wav', 'mp3', 'wav'].contains(docType);
      _isImage = ['image', 'jpg', 'jpeg', 'png', 'gif', 'svg'].contains(docType);
      _isPdf = docType == 'pdf';
      _isText = ['txt', 'abc'].contains(docType);
      _isStructured = ['mxl', 'abc', 'mid', 'kar'].contains(docType);

      final resolvedDocument = await DocumentFileResolver.resolve(documentToResolve);

      if (resolvedDocument.filePath != null) {
        final path = resolvedDocument.filePath!;
        final file = File(path);
        if (await file.exists()) {
          setState(() {
            _filePath = path;
            _isLoading = false;
          });
          PerformanceLogger.info('File trovato', details: path);
          PerformanceLogger.stop('_resolveDocumentPath');
          return;
        }
      }

      setState(() {
        _error = 'File non trovato: ${widget.document.fileName}';
        _isLoading = false;
      });
      PerformanceLogger.error('File non trovato', details: widget.document.fileName);

    } catch (e) {
      setState(() {
        _error = 'Errore: $e';
        _isLoading = false;
      });
      PerformanceLogger.error('_resolveDocumentPath fallito', error: e);
    }

    PerformanceLogger.stop('_resolveDocumentPath');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.fileName),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showDocumentInfo,
            tooltip: 'Informazioni documento',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Torna indietro')),
          ],
        ),
      );
    }

    if (_filePath == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.file_present, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Documento non disponibile'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Torna indietro')),
          ],
        ),
      );
    }

    // 🔥 SU WINDOWS: per MIDI/KAR usa l'app esterna
    if (Platform.isWindows) {
      final docType = widget.document.docType.toLowerCase();
      if (_isMidi || docType == 'kar') {
        return _buildMidiViewer();
      }
    }

    if (_isImage) return _buildImageViewer();
    if (_isAudio) return _buildAudioViewer();
    if (_isPdf) return _buildPdfViewer();
    if (_isMidi) return _buildMidiViewer();
    if (_isStructured) return _buildStructuredViewer();
    if (_isText) return _buildTextViewer();
    return _buildGenericViewer();
  }

  // 🎵 VISUALIZZATORE AUDIO
  Widget _buildAudioViewer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.audiotrack, size: 64, color: Colors.deepPurple.shade300),
          const SizedBox(height: 16),
          Text(widget.document.fileName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('File audio: ${_formatFileSize(widget.document.fileSize ?? 0)}', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _playAudio,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Ascolta'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // 🎵 IMPLEMENTAZIONE AUDIO REALE
// 🎵 IMPLEMENTAZIONE AUDIO REALE
  void _playAudio() async {
    try {
      if (_isMidi || widget.document.docType == 'kar') {
        // 🔥 SU WINDOWS: usa open_filex/oOpenFilex (apre Windows Media Player)
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          await _openWithDefaultApp();
          return;
        }
        // 🔥 SU ANDROID: usa SEMPRE "Apri esterno" (funziona sempre)
        await _playMidiWithSystemPlayer();
        return;
      }

      // 🔥 PER MP3/WAV
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(_filePath!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎵 Riproduzione in corso...'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Errore riproduzione: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 🎼 APRI MIDI/KAR IN WEBVIEW (OFFLINE - GESTIONE BLOB)
// 🎼 APRI MIDI/KAR IN WEBVIEW (OFFLINE - GESTIONE BLOB con WebView)
// 🎼 APRI MIDI/KAR IN WEBVIEW (usa CDN - nessun file locale)
  Future<void> _openMidiInWebView() async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await _openWithDefaultApp();
        return;
      }

      // 🔥 LEGGI I BYTES DEL FILE
      List<int> bytes;
      if (widget.document.content != null && widget.document.content!.isNotEmpty) {
        bytes = widget.document.content!;
      } else if (_filePath != null) {
        final file = File(_filePath!);
        if (!await file.exists()) {
          throw Exception('File non trovato: $_filePath');
        }
        bytes = await file.readAsBytes();
      } else {
        final fullDoc = await _db.getDocumentById(widget.document.id);
        if (fullDoc != null && fullDoc.content != null && fullDoc.content!.isNotEmpty) {
          bytes = fullDoc.content!;
        } else {
          throw Exception('Nessun dato disponibile per il MIDI');
        }
      }

      final base64Data = base64Encode(bytes);

      final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>MIDI Player</title>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/midi.js/4.0.0/midi.min.js"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Segoe UI', Arial, sans-serif;
      padding: 20px;
      background: linear-gradient(135deg, #1a1a2e, #16213e, #0f3460);
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      color: #fff;
    }
    .container {
      background: rgba(255,255,255,0.05);
      backdrop-filter: blur(10px);
      border-radius: 20px;
      padding: 30px 24px;
      box-shadow: 0 8px 32px rgba(0,0,0,0.3);
      max-width: 400px;
      width: 100%;
      text-align: center;
      border: 1px solid rgba(255,255,255,0.1);
    }
    .icon { font-size: 64px; margin-bottom: 12px; }
    h3 {
      color: #fff;
      font-size: 16px;
      word-break: break-word;
      margin-bottom: 8px;
      font-weight: 500;
    }
    .file-info {
      color: rgba(255,255,255,0.5);
      font-size: 12px;
      margin-bottom: 20px;
    }
    .status {
      margin: 16px 0;
      padding: 12px 16px;
      border-radius: 12px;
      background: rgba(255,255,255,0.05);
      font-size: 14px;
      color: rgba(255,255,255,0.7);
      min-height: 48px;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.3s;
    }
    .status.loading { background: rgba(255,193,7,0.15); color: #ffc107; }
    .status.playing { background: rgba(76,175,80,0.15); color: #4caf50; }
    .status.stopped { background: rgba(255,255,255,0.05); color: rgba(255,255,255,0.5); }
    .status.error { background: rgba(244,67,54,0.15); color: #f44336; }
    .btn-group {
      display: flex;
      gap: 12px;
      justify-content: center;
      flex-wrap: wrap;
      margin-top: 8px;
    }
    button {
      padding: 12px 28px;
      border: none;
      border-radius: 12px;
      font-size: 15px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s;
      min-width: 110px;
    }
    button:active { transform: scale(0.95); }
    button:disabled { opacity: 0.5; cursor: not-allowed; transform: none; }
    #playBtn {
      background: linear-gradient(135deg, #4caf50, #2e7d32);
      color: white;
    }
    #playBtn:hover:not(:disabled) {
      box-shadow: 0 4px 20px rgba(76,175,80,0.3);
      transform: translateY(-1px);
    }
    #stopBtn {
      background: linear-gradient(135deg, #f44336, #c62828);
      color: white;
    }
    #stopBtn:hover:not(:disabled) {
      box-shadow: 0 4px 20px rgba(244,67,54,0.3);
      transform: translateY(-1px);
    }
    .progress {
      margin-top: 16px;
      width: 100%;
      height: 4px;
      background: rgba(255,255,255,0.1);
      border-radius: 4px;
      overflow: hidden;
    }
    .progress-bar {
      height: 100%;
      background: linear-gradient(90deg, #4caf50, #8bc34a);
      width: 0%;
      transition: width 0.1s;
      border-radius: 4px;
    }
    .time-display {
      display: flex;
      justify-content: space-between;
      font-size: 11px;
      color: rgba(255,255,255,0.3);
      margin-top: 4px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="icon">🎵</div>
    <h3>${widget.document.fileName}</h3>
    <div class="file-info">File MIDI/KAR</div>
    
    <div id="status" class="status stopped">⏸ Pronto per riprodurre</div>
    
    <div class="progress">
      <div id="progressBar" class="progress-bar"></div>
    </div>
    <div class="time-display">
      <span id="currentTime">0:00</span>
      <span id="totalTime">0:00</span>
    </div>
    
    <div class="btn-group">
      <button id="playBtn" onclick="playMidi()">▶ Play</button>
      <button id="stopBtn" onclick="stopMidi()" disabled>⏹ Stop</button>
    </div>
    <div style="margin-top:12px;font-size:11px;color:rgba(255,255,255,0.2);">
      MIDI.js player
    </div>
  </div>

  <script>
    let player = null;
    let isPlaying = false;
    let progressInterval = null;
    let isInitialized = false;
    
    const statusEl = document.getElementById('status');
    const playBtn = document.getElementById('playBtn');
    const stopBtn = document.getElementById('stopBtn');
    const progressBar = document.getElementById('progressBar');
    const currentTimeEl = document.getElementById('currentTime');
    const totalTimeEl = document.getElementById('totalTime');
    
    function updateStatus(text, type) {
      statusEl.textContent = text;
      statusEl.className = 'status ' + type;
    }
    
    function updateProgress(percent) {
      progressBar.style.width = Math.min(percent, 100) + '%';
    }
    
    function formatTime(seconds) {
      if (!seconds || isNaN(seconds)) return '0:00';
      const mins = Math.floor(seconds / 60);
      const secs = Math.floor(seconds % 60);
      return mins + ':' + (secs < 10 ? '0' : '') + secs;
    }
    
    function playMidi() {
      try {
        if (isPlaying) {
          stopMidi();
          return;
        }
        
        playBtn.disabled = true;
        playBtn.textContent = '⏳ Caricamento...';
        updateStatus('⏳ Caricamento MIDI...', 'loading');
        
        if (typeof MIDI === 'undefined') {
          updateStatus('❌ MIDI.js non disponibile. Usa "Apri esterno".', 'error');
          playBtn.disabled = false;
          playBtn.textContent = '▶ Play';
          return;
        }
        
        if (!isInitialized) {
          MIDI.loadPlugin({
            soundfontUrl: 'https://cdnjs.cloudflare.com/ajax/libs/midi.js/4.0.0/soundfonts/',
            onprogress: function(state, percent) {
              updateProgress(percent);
              updateStatus('⏳ Caricamento strumenti: ' + percent + '%', 'loading');
            },
            onsuccess: function() {
              isInitialized = true;
              startPlayback();
            },
            onerror: function(error) {
              console.error('Soundfont error:', error);
              startPlaybackFallback();
            }
          });
        } else {
          startPlayback();
        }
      } catch (error) {
        console.error('Play error:', error);
        updateStatus('❌ Errore: ' + error.message, 'error');
        playBtn.disabled = false;
        playBtn.textContent = '▶ Play';
      }
    }
    
    function startPlayback() {
      try {
        player = new MIDI.Player();
        player.loadDataUri('data:audio/midi;base64,$base64Data');
        player.onload = function() {
          isPlaying = true;
          playBtn.textContent = '⏸ Pausa';
          playBtn.disabled = false;
          stopBtn.disabled = false;
          totalTimeEl.textContent = formatTime(player.duration);
          updateStatus('▶ Riproduzione in corso...', 'playing');
          if (progressInterval) clearInterval(progressInterval);
          progressInterval = setInterval(function() {
            if (player.currentTime && player.duration) {
              const percent = (player.currentTime / player.duration) * 100;
              updateProgress(percent);
              currentTimeEl.textContent = formatTime(player.currentTime);
            }
          }, 100);
          player.play();
        };
        player.onend = function() {
          stopMidi();
          updateStatus('✅ Riproduzione completata', 'stopped');
          updateProgress(100);
          currentTimeEl.textContent = totalTimeEl.textContent;
        };
        player.onerror = function(error) {
          console.error('MIDI error:', error);
          updateStatus('❌ Errore: ' + (error.message || 'riproduzione fallita'), 'error');
          playBtn.textContent = '▶ Play';
          playBtn.disabled = false;
          stopBtn.disabled = true;
        };
      } catch (error) {
        console.error('Start playback error:', error);
        updateStatus('❌ Errore: ' + error.message, 'error');
        playBtn.disabled = false;
        playBtn.textContent = '▶ Play';
      }
    }
    
    function startPlaybackFallback() {
      try {
        const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        updateStatus('🎵 Riproduzione con fallback (suoni semplici)...', 'loading');
        const notes = [60, 62, 64, 65, 67, 69, 71, 72];
        let noteIndex = 0;
        function playNote() {
          if (!isPlaying) return;
          try {
            const osc = audioCtx.createOscillator();
            const gain = audioCtx.createGain();
            osc.connect(gain);
            gain.connect(audioCtx.destination);
            osc.frequency.value = 440 * Math.pow(2, (notes[noteIndex % notes.length] - 69) / 12);
            osc.type = 'triangle';
            gain.gain.setValueAtTime(0.1, audioCtx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.3);
            osc.start(audioCtx.currentTime);
            osc.stop(audioCtx.currentTime + 0.3);
            noteIndex++;
          } catch(e) { /* ignore */ }
        }
        isPlaying = true;
        playBtn.textContent = '⏸ Pausa';
        playBtn.disabled = false;
        stopBtn.disabled = false;
        let interval = setInterval(playNote, 300);
        updateStatus('🎵 Riproduzione fallback (MIDI non supportato)', 'playing');
        window._fallbackStop = function() {
          clearInterval(interval);
          isPlaying = false;
          playBtn.textContent = '▶ Play';
          stopBtn.disabled = true;
          updateStatus('⏸ Fermo', 'stopped');
        };
        setTimeout(() => {
          if (isPlaying) {
            window._fallbackStop();
            updateStatus('✅ Riproduzione fallback completata', 'stopped');
          }
        }, 8000);
      } catch (e) {
        updateStatus('❌ MIDI non supportato su questo dispositivo', 'error');
        playBtn.disabled = false;
        playBtn.textContent = '▶ Play';
        stopBtn.disabled = true;
      }
    }
    
    function stopMidi() {
      try {
        if (player) {
          player.stop();
          player = null;
        }
        if (progressInterval) {
          clearInterval(progressInterval);
          progressInterval = null;
        }
        if (window._fallbackStop) {
          window._fallbackStop();
        }
        isPlaying = false;
        updateProgress(0);
        currentTimeEl.textContent = '0:00';
        updateStatus('⏸ Fermo', 'stopped');
        playBtn.textContent = '▶ Play';
        playBtn.disabled = false;
        stopBtn.disabled = true;
      } catch (error) {
        console.error('Stop error:', error);
      }
    }
    
    window.addEventListener('beforeunload', function() {
      if (player) {
        player.stop();
        player = null;
      }
      if (progressInterval) {
        clearInterval(progressInterval);
        progressInterval = null;
      }
      if (window._fallbackStop) {
        window._fallbackStop();
      }
    });
  </script>
</body>
</html>
    ''';

      // 🔥 Naviga DIRETTAMENTE alla WebView senza dialog intermedi
      if (!mounted) return;

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadHtmlString(htmlContent)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) {
              print('✅ Pagina MIDI caricata con successo');
            },
            onWebResourceError: (error) {
              print('❌ Errore WebView: ${error.description}');
              if (Platform.isAndroid) {
                // Mostra un unico SnackBar per l'errore
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ Caricamento MIDI fallito. Prova "Apri esterno".'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
        );

      // 🔥 Naviga SENZA mostrare dialog aggiuntivi
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text('🎼 ${widget.document.fileName}'),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            body: WebViewWidget(controller: controller),
          ),
        ),
      );
    } catch (e) {
      if (Platform.isAndroid) {
        // Mostra un unico SnackBar per l'errore
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Errore: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        // Prova con app esterna SOLO se l'utente clicca sul pulsante "Apri esterno"
        // Non farlo automaticamente per evitare dialog duplicati
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Errore MIDI: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
// 🎵 APRI MIDI CON PLAYER DI SISTEMA (per Android - con dialog iniziale)
  Future<void> _playMidiWithSystemPlayer() async {
    try {
      // 🔥 MOSTRA IL DIALOG INIZIALE CON SUGGERIMENTI
      final shouldContinue = await _showMidiPlayerDialog(context);

      // Se l'utente ha annullato, esci
      if (!shouldContinue) {
        return;
      }

      // 🔥 LEGGI I BYTES DEL FILE
      List<int> bytes;

      if (widget.document.content != null && widget.document.content!.isNotEmpty) {
        bytes = widget.document.content!;
        print('✅ Usato content BLOB: ${bytes.length} bytes');
      } else if (_filePath != null) {
        final file = File(_filePath!);
        if (!await file.exists()) {
          throw Exception('File non trovato: $_filePath');
        }
        bytes = await file.readAsBytes();
        print('✅ Letto da filesystem: ${bytes.length} bytes');
      } else {
        final fullDoc = await _db.getDocumentById(widget.document.id);
        if (fullDoc != null && fullDoc.content != null && fullDoc.content!.isNotEmpty) {
          bytes = fullDoc.content!;
          print('✅ Recuperato BLOB dal DB: ${bytes.length} bytes');
        } else {
          throw Exception('Nessun dato disponibile per il MIDI');
        }
      }

      // 🔥 SALVA IN UNA CARTELLA PERMANENTE
      final appDocDir = await getApplicationDocumentsDirectory();
      final midiDir = Directory('${appDocDir.path}/midi_files');

      if (!await midiDir.exists()) {
        await midiDir.create(recursive: true);
        print('📁 Creata cartella: ${midiDir.path}');
      }

      // 🔥 Usa il nome ORIGINALE del file
      String fileName = widget.document.fileName;

      // Per compatibilità, se è .kar, usa .mid
      if (fileName.toLowerCase().endsWith('.kar')) {
        fileName = fileName.replaceAll(RegExp(r'\.kar$', caseSensitive: false), '.mid');
        print('🔄 Convertito .kar → .mid per compatibilità');
      }

      final midiFile = File('${midiDir.path}/$fileName');

      // 🔥 Scrivi il file
      await midiFile.writeAsBytes(bytes, flush: true);
      await Future.delayed(const Duration(milliseconds: 300));

      print('✅ File salvato: ${midiFile.path}');
      print('📊 Dimensione: ${bytes.length} bytes');

      // 🔥 Prova con OpenFilex
      final result = await OpenFilex.open(midiFile.path);

      if (result.type == ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Apertura "${fileName}" in corso...'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // 🔥 Se fallisce, mostra un messaggio di errore
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Impossibile aprire il file. Riprova.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
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

// 🔥 DIALOG INIZIALE CON SUGGERIMENTI PER IL LETTORE MIDI
  Future<bool> _showMidiPlayerDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Apertura file MIDI'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Per ascoltare il file MIDI verrà aperta un\'app esterna.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '⚠️ Attenzione:',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Se il lettore MIDI si blocca o non funziona, potrebbe essere '
                          'necessario cambiare app predefinita o installare un lettore MIDI.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '💡 Consigli:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 6),
              _buildTipItem(
                icon: Icons.play_arrow,
                text: 'Installa "MIDI Player" dal Play Store',
              ),
              const SizedBox(height: 4),
              _buildTipItem(
                icon: Icons.swap_horiz,
                text: 'Cambia l\'app predefinita per i file MIDI',
              ),
              const SizedBox(height: 4),
              _buildTipItem(
                icon: Icons.settings,
                text: 'Vai su Impostazioni > App > App predefinite',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('Annulla'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context, false);
              _openPlayStoreSearch(context);
            },
            icon: const Icon(Icons.shopping_cart, size: 18),
            label: const Text('Cerca app'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.deepPurple,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continua'),
          ),
        ],
      ),
    ) ?? false;
  }

// 🔥 HELPER PER GLI ITEM DEL DIALOG
  Widget _buildTipItem({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.deepPurple.shade400),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

// 🔥 APRI PLAY STORE CON RICERCA PER LETTORI MIDI
  void _openPlayStoreSearch(BuildContext context) async {
    final Uri playStoreUrl = Uri.parse(
      'https://play.google.com/store/search?q=midi%20player&c=apps',
    );

    try {
      if (await canLaunchUrl(playStoreUrl)) {
        await launchUrl(playStoreUrl);
      } else {
        final Uri browserUrl = Uri.parse(
          'https://www.google.com/search?q=midi+player+android',
        );
        if (await canLaunchUrl(browserUrl)) {
          await launchUrl(browserUrl);
        }
      }
    } catch (e) {
      print('❌ Errore apertura Play Store: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Impossibile aprire il Play Store'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // 📄 VISUALIZZATORE PDF
  Widget _buildPdfViewer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.picture_as_pdf, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(widget.document.fileName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('PDF: ${_formatFileSize(widget.document.fileSize ?? 0)}', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openWithDefaultApp,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Apri con app predefinita'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  // 🎼 VISUALIZZATORE MIDI / KAR
  Widget _buildMidiViewer() {
    // 🔥 Su Windows: usa app esterna
    if (Platform.isWindows) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, size: 64, color: Colors.deepPurple.shade300),
            const SizedBox(height: 16),
            Text(widget.document.fileName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('File MIDI/KAR: ${_formatFileSize(widget.document.fileSize ?? 0)}', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openWithDefaultApp,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Apri con Windows Media Player'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    // 🔥 Su Android: usa SEMPRE "Apri esterno" (funziona sempre)
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note, size: 64, color: Colors.deepPurple.shade300),
          const SizedBox(height: 16),
          Text(widget.document.fileName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('File MIDI/KAR: ${_formatFileSize(widget.document.fileSize ?? 0)}', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _playMidiWithSystemPlayer, // 🔥 Usa sempre "Apri esterno"
            icon: const Icon(Icons.open_in_new),
            label: const Text('Apri con app esterna'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '💡 Apre il file MIDI/KAR con l\'app musicale del telefono',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 🎼 VISUALIZZATORE STRUTTURATO (MXL / ABC)
  Widget _buildStructuredViewer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description, size: 64, color: Colors.green.shade600),
          const SizedBox(height: 16),
          Text(widget.document.fileName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('File strutturato (MXL/ABC)', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openInternalMxlViewer,
            icon: const Icon(Icons.web),
            label: const Text('Visualizza online'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _openWithDefaultApp,
            child: const Text('Apri con app esterna (es. Finale)'),
          ),
        ],
      ),
    );
  }

  // 🖼️ VISUALIZZATORE IMMAGINE
  Widget _buildImageViewer() {
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.file(File(_filePath!), fit: BoxFit.contain),
      ),
    );
  }

  // 📝 VISUALIZZATORE TESTO
  Widget _buildTextViewer() {
    return FutureBuilder<String>(
      future: _readTextFile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Errore: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        return Container(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(child: Text(snapshot.data ?? 'Nessun contenuto', style: const TextStyle(fontFamily: 'monospace', fontSize: 14))),
        );
      },
    );
  }

  Future<String> _readTextFile() async {
    try {
      final file = File(_filePath!);
      return await file.exists() ? await file.readAsString() : 'File non trovato';
    } catch (e) {
      return 'Errore nella lettura del file: $e';
    }
  }

  // 📂 GENERICO
  Widget _buildGenericViewer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insert_drive_file, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(widget.document.fileName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Tipo: ${widget.document.docType}', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openWithDefaultApp,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Apri con app predefinita'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  // 🖥️ APRI PAGINA INTERNA PER MXL/ABC (SU ANDROID USA WEBVIEW)
  void _openInternalMxlViewer() async {
    try {
      // 🔥 SU ANDROID: usa WebView per aprire l'HTML DENTRO l'app
      if (Platform.isAndroid) {
        // 1. LEGGI IL CONTENUTO (ABC o XML) dal file o dal BLOB
        String content = '';

        if (widget.document.docType.toLowerCase() == 'abc') {
          if (widget.document.content != null) {
            content = String.fromCharCodes(widget.document.content!);
          } else if (_filePath != null) {
            content = await File(_filePath!).readAsString();
          }
        } else if (widget.document.docType.toLowerCase() == 'mxl') {
          if (widget.document.content != null) {
            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/${widget.document.fileName}');
            await tempFile.writeAsBytes(widget.document.content!);
            content = await MxlService.extractXmlContent(tempFile.path) ?? '';
          } else if (_filePath != null) {
            content = await MxlService.extractXmlContent(_filePath!) ?? '';
          }
        }

        // 2. LEGGI L'HTML DAGLI ASSET
        final htmlString = await rootBundle.loadString('assets/html/spartito-viewer.html');

        // 3. INIETTA IL CONTENUTO NELLA TEXTAREA
        final filledHtml = htmlString.replaceFirst(
          RegExp(r'(?<=<textarea id="inputText"[^>]*>)(.*?)(?=</textarea>)', dotAll: true),
          content,
        );

        // 4. 🔥 AGGIUNGI UN SCRIPT CHE PREME "GENERA SPARTITO" DOPO 1 SECONDO
        final scriptToAdd = '''
        <script>
          setTimeout(function() {
            var btn = document.getElementById('processBtn');
            if (btn) {
              btn.click();
            }
          }, 1000);
        </script>
        ''';

        final finalHtml = filledHtml.replaceFirst('</body>', scriptToAdd + '</body>');

        // 5. COPIA L'HTML NELLA MEMORIA DEL TELEFONO
        final appDocDir = await getApplicationDocumentsDirectory();
        final htmlFile = File('${appDocDir.path}/spartito_viewer.html');
        await htmlFile.writeAsString(finalHtml);

        // 6. 🔥 APRI CON WEBVIEW
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text('Visualizza spartito'),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              body: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(htmlFile.path)),
                onWebViewCreated: (controller) {
                  print('✅ WebView creata per spartito');
                },
                onLoadError: (controller, url, code, message) {
                  print('❌ WebView spartito error: $code - $message');
                },
              ),
            ),
          ),
        );
        return;
      }

      // 🔥 SU DESKTOP/WEB: usa la vecchia logica
      if (widget.document.docType.toLowerCase() == 'abc') {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AbcViewerScreen(
              filePath: _filePath!,
              fileName: widget.document.fileName,
            ),
          ),
        );
      } else if (widget.document.docType.toLowerCase() == 'mxl') {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MxlViewerScreen(
              document: widget.document.copyWith(filePath: _filePath),
            ),
          ),
        );
      } else {
        await _openWithDefaultApp();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore: Visualizzatore non trovato. $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 📂 APRI CON APP ESTERNA
// 📂 APRI CON APP ESTERNA (Windows e Desktop)
// 📂 APRI CON APP ESTERNA (Windows e Desktop - con nome originale)
  Future<void> _openWithDefaultApp() async {
    try {
      // 🔥 Per Windows, se il file è MIDI/KAR, salvalo in una cartella permanente
      if (Platform.isWindows) {
        final file = File(_filePath!);
        if (await file.exists()) {
          print('📂 Apro file su Windows: ${file.path}');

          // Copia il file in una cartella permanente se è nella cache
          final String path = file.path;
          if (path.contains('cache') || path.contains('temp')) {
            // 🔥 Copia il file in una cartella permanente
            final appDocDir = await getApplicationDocumentsDirectory();
            final midiDir = Directory('${appDocDir.path}/midi_files');
            if (!await midiDir.exists()) {
              await midiDir.create(recursive: true);
            }

            String fileName = widget.document.fileName;
            final newFile = File('${midiDir.path}/$fileName');
            await file.copy(newFile.path);
            print('📂 File copiato in: ${newFile.path}');

            final result = await OpenFilex.open(newFile.path);
            if (result.type != ResultType.done && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚠️ Errore apertura: ${result.message}'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }

          final result = await OpenFilex.open(path);
          if (result.type != ResultType.done && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ Errore apertura: ${result.message}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      // 🔥 Per le altre piattaforme
      final file = File(_filePath!);
      if (await file.exists()) {
        final result = await OpenFilex.open(_filePath!);
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Errore apertura: ${result.message}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File non trovato'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // INFO
  void _showDocumentInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📄 Informazioni documento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Nome', widget.document.fileName),
            _buildInfoRow('Tipo', widget.document.docType),
            _buildInfoRow('Dimensione', _formatFileSize(widget.document.fileSize ?? 0)),
            if (widget.document.description.isNotEmpty) _buildInfoRow('Descrizione', widget.document.description),
            _buildInfoRow('Storage', widget.document.storageMode),
            _buildInfoRow('Caricato da', widget.document.uploadedBy),
            _buildInfoRow('Data', widget.document.createdAt.substring(0, 10)),
            _buildInfoRow('Pubblico', widget.document.isPublic ? 'Sì' : 'No'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi'))],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text('$label:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}