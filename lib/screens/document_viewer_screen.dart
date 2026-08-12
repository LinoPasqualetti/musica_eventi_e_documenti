// lib/screens/document_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import '../models/document.dart';
import 'mxl_viewer_screen.dart';
import 'midi_player_screen.dart';
import 'abc_viewer_screen.dart';  // <-- NUOVO IMPORT

class DocumentViewerScreen extends StatefulWidget {
  final Document document;

  const DocumentViewerScreen({
    Key? key,
    required this.document,
  }) : super(key: key);

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _audioError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkFile();
    _setupAudioListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioListeners() {
    // Ascolta la durata del brano
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    // Ascolta la posizione durante la riproduzione
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    // Ascolta il completamento della riproduzione
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
          _isLoading = false;
        });
      }
    });

    // Ascolta gli errori - usando onLog per debug
    _audioPlayer.onLog.listen((log) {
      print('🎵 Audio log: $log');
    });

    // Monitora lo stato del player
    _audioPlayer.onPlayerStateChanged.listen((state) {
      print('🎵 Player state: $state');
      if (mounted) {
        setState(() {
          if (state == PlayerState.stopped) {
            _isPlaying = false;
            _isLoading = false;
          } else if (state == PlayerState.playing) {
            _isPlaying = true;
            _isLoading = false;
          } else if (state == PlayerState.paused) {
            _isPlaying = false;
          }
        });
      }
    });
  }

  void _checkFile() {
    final filePath = widget.document.filePath;
    final exists = File(filePath).existsSync();

    // Per i file audio, verifica che il file esista
    if (widget.document.docType == 'audio_mp3' ||
        widget.document.docType == 'audio_wav') {
      if (!exists) {
        setState(() {
          _audioError = 'File audio non trovato: $filePath';
        });
      }
    }
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
            icon: const Icon(Icons.download),
            onPressed: () => _downloadDocument(),
            tooltip: 'Download',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareDocument(),
            tooltip: 'Condividi',
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => _openWithDefaultApp(),
            tooltip: 'Apri con app predefinita',
          ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    switch (widget.document.docType) {
      case 'pdf':
        return _buildPdfViewer();
      case 'mxl':
      // Visualizzazione MXL con conversione integrata
        return MxlViewerScreen(document: widget.document);
      case 'abc':
      // Visualizzazione ABC integrata con abcjs
        return AbcViewerScreen(
          filePath: widget.document.filePath,
          fileName: widget.document.fileName,
        );
      case 'audio_mp3':
      case 'audio_wav':
        return _buildAudioPlayer();
      case 'mid':
      case 'kar':
        return MidiPlayerScreen(document: widget.document);
      case 'image':
        return _buildImageViewer();
      default:
        return _buildDefaultViewer();
    }
  }

  // ============================================
  // PLAYER AUDIO - VERSIONE CORRETTA
  // ============================================

  Widget _buildAudioPlayer() {
    final filePath = widget.document.filePath;
    final exists = File(filePath).existsSync();

    // Se il file non esiste, mostra errore
    if (!exists) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'File audio non trovato',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Percorso: $filePath',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openWithDefaultApp(),
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Apri con app predefinita'),
            ),
          ],
        ),
      );
    }

    // Se c'è un errore di riproduzione
    if (_audioError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'Errore audio',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _audioError!,
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _audioError = null;
                });
                _playAudio();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icona animata durante la riproduzione
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                _isPlaying ? Icons.equalizer : Icons.audiotrack,
                size: 80,
                color: _isPlaying ? Colors.deepPurple : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.document.fileName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _isLoading ? 'Caricamento...' : 'Audio file (MP3)',
              style: TextStyle(
                color: _isLoading ? Colors.deepPurple : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),

            // Progress bar della riproduzione
            if (_duration.inSeconds > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    iconSize: 48,
                    onPressed: _isLoading ? null : _togglePlayback,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        Slider(
                          value: _position.inSeconds.toDouble(),
                          max: _duration.inSeconds.toDouble(),
                          onChanged: (value) {
                            _audioPlayer.seek(Duration(seconds: value.toInt()));
                          },
                          activeColor: Colors.deepPurple,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_position),
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              _formatDuration(_duration),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Mostra pulsante play anche se la durata non è ancora caricata
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                iconSize: 64,
                onPressed: _isLoading ? null : _togglePlayback,
                color: Colors.deepPurple,
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
            ],

            const SizedBox(height: 16),

            // Pulsanti aggiuntivi
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _downloadDocument(),
                  icon: const Icon(Icons.download),
                  label: const Text('Scarica Audio'),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => _openWithDefaultApp(),
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Apri con...'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // METODO PER RIPRODURRE L'AUDIO - USANDO AUDIOPLAYERS
  // ============================================

  Future<void> _playAudio() async {
    try {
      setState(() {
        _isLoading = true;
        _audioError = null;
      });

      final filePath = widget.document.filePath;

      // Verifica che il file esista
      final file = File(filePath);
      if (!await file.exists()) {
        setState(() {
          _audioError = 'File non trovato: $filePath';
          _isLoading = false;
        });
        return;
      }

      // Costruisci l'URL per il player (diverso per Windows)
      String audioUrl;
      if (Platform.isWindows) {
        // Per Windows: file:///C:/percorso/file.mp3
        String path = filePath.replaceAll('\\', '/');
        audioUrl = 'file:///$path';
      } else {
        audioUrl = 'file://$filePath';
      }

      print('🎵 Riproduzione audio da: $audioUrl');

      // Sospendi qualsiasi riproduzione in corso
      await _audioPlayer.stop();

      // Riproduci il file
      await _audioPlayer.play(UrlSource(audioUrl));

      print('🎵 Riproduzione avviata');

      if (mounted) {
        setState(() {
          _isPlaying = true;
          _isLoading = false;
        });
      }

    } catch (e) {
      print('❌ Errore riproduzione audio: $e');
      if (mounted) {
        setState(() {
          _audioError = 'Errore: ${e.toString()}';
          _isPlaying = false;
          _isLoading = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    } else {
      await _playAudio();
    }
  }

  // ============================================
  // VISUALIZZATORE PDF
  // ============================================

  Widget _buildPdfViewer() {
    final filePath = widget.document.filePath;
    final exists = File(filePath).existsSync();

    if (!exists) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'File PDF non trovato',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Percorso: $filePath',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openWithDefaultApp(),
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Apri con app predefinita'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf,
            size: 80,
            color: Colors.red.shade700,
          ),
          const SizedBox(height: 16),
          Text(
            '📄 ${widget.document.fileName}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'PDF Document',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Dimensione: ${_getFileSize()}',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _openWithDefaultApp(),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('📂 Apri PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => _downloadDocument(),
                icon: const Icon(Icons.download),
                label: const Text('💾 Scarica'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '💡 Suggerimento: il PDF verrà aperto con il visualizzatore predefinito del sistema',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getFileSize() {
    try {
      final file = File(widget.document.filePath);
      if (file.existsSync()) {
        final size = file.lengthSync();
        if (size > 1024 * 1024) {
          return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
        } else if (size > 1024) {
          return '${(size / 1024).toStringAsFixed(1)} KB';
        } else {
          return '$size bytes';
        }
      }
    } catch (e) {
      return 'N/A';
    }
    return 'N/A';
  }

  // ============================================
  // VISUALIZZATORE IMMAGINI
  // ============================================

  Widget _buildImageViewer() {
    final filePath = widget.document.filePath;
    final exists = File(filePath).existsSync();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: exists
                    ? Image.file(
                  File(filePath),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildImagePlaceholder();
                  },
                )
                    : _buildImagePlaceholder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _downloadDocument(),
                  icon: const Icon(Icons.download),
                  label: const Text('Scarica Immagine'),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => _openWithDefaultApp(),
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Apri'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            '🖼️ ${widget.document.fileName}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Immagine non disponibile',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ============================================
  // VISUALIZZATORE DEFAULT
  // ============================================

  Widget _buildDefaultViewer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insert_drive_file, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            '📄 ${widget.document.fileName}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tipo: ${widget.document.docType}',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _downloadDocument(),
                icon: const Icon(Icons.download),
                label: const Text('Download'),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => _openWithDefaultApp(),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Apri'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================
  // METODI UTILITY
  // ============================================

  Future<void> _downloadDocument() async {
    try {
      final file = File(widget.document.filePath);
      if (await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⬇️ Download: ${widget.document.fileName}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('File non trovato');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Errore: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareDocument() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔗 Condivisione documento'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _openWithDefaultApp() async {
    try {
      final filePath = widget.document.filePath;
      final result = await OpenFile.open(filePath);

      if (result.type == ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Aperto: ${widget.document.fileName}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Impossibile aprire il file: ${result.message}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Errore: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _copyToClipboard(String text) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Copiato negli appunti!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}