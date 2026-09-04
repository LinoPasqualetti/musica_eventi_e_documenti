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

  // 🔥 PERCORSO DEL FILE HTML ORIGINALE
  String get _htmlPath => 'C:/musica_eventi_e_documenti/assets/html/spartito-viewer.html';

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

  // 🔥 INIETTA L'ABC E PREME AUTOMATICAMENTE "GENERA SPARTITO" (per distinguere i brani)
  Future<void> _openInBrowser() async {
    try {
      // 1. Percorso del tuo HTML originale
      final htmlFile = File(_htmlPath);
      if (!await htmlFile.exists()) {
        throw Exception('File HTML non trovato: $_htmlPath');
      }

      // 2. Leggi il contenuto del file HTML
      final htmlContent = await htmlFile.readAsString();

      // 3. Inietta l'ABC nella textarea (id="inputText")
      final filledHtml = htmlContent.replaceFirst(
        RegExp(r'(?<=<textarea id="inputText"[^>]*>)(.*?)(?=</textarea>)', dotAll: true),
        _abcContent,
      );

      // 4. 🔥 AGGIUNGI UNO SCRIPT CHE PREME IL PULSANTE DOPO 1 SECONDO
      // In questo modo il tuo HTML trova i brani multipli e mostra il menu a tendina
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

      // Inserisci lo script prima della chiusura del body
      final finalHtml = filledHtml.replaceFirst('</body>', scriptToAdd + '</body>');

      // 5. Salva il file HTML aggiornato in una cartella sicura
      final appDocDir = await getApplicationDocumentsDirectory();
      final safeDir = Directory('${appDocDir.path}/viewers');
      if (!await safeDir.exists()) {
        await safeDir.create(recursive: true);
      }

      final outputFile = File('${safeDir.path}/abc_viewer_${DateTime.now().millisecondsSinceEpoch}.html');
      await outputFile.writeAsString(finalHtml, flush: true);

      // 6. Apri nel browser
      if (await canLaunchUrl(Uri.file(outputFile.path))) {
        await launchUrl(Uri.file(outputFile.path), mode: LaunchMode.externalApplication);
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
}