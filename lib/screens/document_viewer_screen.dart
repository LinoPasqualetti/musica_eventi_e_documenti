// lib/screens/document_viewer_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; // Per MP3
import 'package:open_filex/open_filex.dart'; // Per aprire file con app predefinita
import 'package:path_provider/path_provider.dart'; // Per BLOB
import 'package:flutter_inappwebview/flutter_inappwebview.dart'; // 🔥 PER WEBVIEW SU ANDROID
import 'package:flutter/services.dart' show rootBundle; // 🔥 PER LEGGERE GLI ASSET
import '../models/document.dart';
import '../services/database_service.dart';
import '../services/document_file_resolver.dart';
import '../services/mxl_service.dart'; // 🔥 PER ESTRARRE XML DA MXL
import '../utils/performance_logger.dart';

// 🔥 IMPORT DELLE SCHERMATE INTERNE
import 'abc_viewer_screen.dart'; // Richiede filePath e fileName
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
      // 🔥 LEGGI LA RIGA COMPLETA (con il BLOB) DAL DATABASE!
      final fullDocument = await _db.getDocumentById(widget.document.id);

      // Usa il documento completo (con content) per il resolver
      Document documentToResolve = fullDocument ?? widget.document;

      // Verifica il tipo di documento
      final docType = widget.document.docType.toLowerCase();
      _isMidi = ['mid', 'kar'].contains(docType);
      _isAudio = ['audio_mp3', 'audio_wav', 'mp3', 'wav'].contains(docType);
      _isImage = ['image', 'jpg', 'jpeg', 'png', 'gif', 'svg'].contains(docType);
      _isPdf = docType == 'pdf';
      _isText = ['txt', 'abc'].contains(docType);
      _isStructured = ['mxl', 'abc', 'mid', 'kar'].contains(docType);

      // ✅ Gestione BLOB e Filesystem tramite resolver
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

      // Se non trovato, mostra errore
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

    // Mostra il visualizzatore appropriato in base al tipo
    if (_isImage) return _buildImageViewer();
    if (_isAudio) return _buildAudioViewer();
    if (_isPdf) return _buildPdfViewer();
    if (_isMidi) return _buildMidiViewer();
    if (_isStructured) return _buildStructuredViewer(); // Per MXL e ABC
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
  void _playAudio() async {
    try {
      // 🔥 SE È UN FILE MIDI/KAR, APRI CON APP ESTERNA (OpenFilex)
      if (_isMidi || widget.document.docType == 'kar') {
        final result = await OpenFilex.open(_filePath!);
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Errore apertura MIDI/KAR: ${result.message}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 🔥 PER MP3/WAV: USA AUDIOPLAYERS
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
        SnackBar(
          content: Text('❌ Errore riproduzione: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
            label: const Text('Riproduci con app predefinita'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
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
            onPressed: _openInternalMxlViewer, // Questa apre la pagina HTML interna
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
          // Leggi il file ABC dal percorso o dal BLOB
          if (widget.document.content != null) {
            content = String.fromCharCodes(widget.document.content!);
          } else if (_filePath != null) {
            content = await File(_filePath!).readAsString();
          }
        } else if (widget.document.docType.toLowerCase() == 'mxl') {
          // Estrai il contenuto XML dal file MXL (tramite MxlService)
          if (widget.document.content != null) {
            // Se il file è BLOB, crea un file temporaneo e poi estrai l'XML
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
        // (Questo è FONDAMENTALE per i file ABC con più brani!)
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
              ),
            ),
          ),
        );
        return;
      }

      // 🔥 SU DESKTOP/WEB: usa la vecchia logica (naviga alle schermate specifiche)
      if (widget.document.docType.toLowerCase() == 'abc') {
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MxlViewerScreen(
              document: widget.document,
            ),
          ),
        );
      } else {
        await _openWithDefaultApp();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Errore: Visualizzatore non trovato. $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 📂 APRI CON APP ESTERNA
  Future<void> _openWithDefaultApp() async {
    try {
      final file = File(_filePath!);
      if (await file.exists()) {
        // Usa open_filex per aprire con il programma predefinito (es. Finale, Windows Media Player)
        final result = await OpenFilex.open(_filePath!);

        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Errore apertura: ${result.message}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File non trovato'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
      );
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