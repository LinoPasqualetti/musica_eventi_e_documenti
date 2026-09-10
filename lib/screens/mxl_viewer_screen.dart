// lib/screens/mxl_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import '../models/document.dart';
import '../services/mxl_service.dart';

class MxlViewerScreen extends StatefulWidget {
  final Document document;

  const MxlViewerScreen({
    Key? key,
    required this.document,
  }) : super(key: key);

  @override
  State<MxlViewerScreen> createState() => _MxlViewerScreenState();
}

class _MxlViewerScreenState extends State<MxlViewerScreen> {
  bool _isLoading = true;
  String? _xmlContent;
  String? _error;
  Map<String, String> _metadata = {};

  @override
  void initState() {
    super.initState();
    _loadMxl();
  }

  Future<void> _loadMxl() async {
    setState(() => _isLoading = true);
    try {
      final filePath = widget.document.filePath;
      if (filePath == null) {
        setState(() {
          _error = 'Errore: Percorso file mancante';
        });
        setState(() => _isLoading = false);
        return;
      }

      final xmlContent = await MxlService.extractXmlContent(filePath);

      if (xmlContent != null) {
        setState(() {
          _xmlContent = xmlContent;
          _metadata = MxlService.extractMetadata(xmlContent);
        });
      } else {
        setState(() {
          _error = 'Impossibile estrarre il contenuto MXL';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Errore: $e';
      });
    }
    setState(() => _isLoading = false);
  }

  // 🔥 INIETTA L'XML E PREME AUTOMATICAMENTE "GENERA SPARTITO" (per estrarre i brani singoli)
  // 🔥 INIETTA L'XML E PREME AUTOMATICAMENTE "GENERA SPARTITO"
  Future<void> _openInBrowser() async {
    try {
      // 1. Leggi l'HTML dagli asset (funziona su qualsiasi PC e su Android)
      final htmlContent = await rootBundle.loadString('assets/html/spartito-viewer.html');

      // 2. Escapa l'XML e iniettalo nella textarea
      final escapedXml = (_xmlContent ?? '')
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');

      final filledHtml = htmlContent.replaceFirst(
        RegExp(r'(?<=<textarea id="inputText"[^>]*>)(.*?)(?=</textarea>)', dotAll: true),
        escapedXml,
      );

      // 3. Aggiungi lo script che preme automaticamente "Genera spartito"
      final scriptToAdd = '''
      <script>
        setTimeout(function() {
          var btn = document.getElementById('processBtn');
          if (btn) { btn.click(); }
        }, 1000);
      </script>
      ''';

      final finalHtml = filledHtml.replaceFirst('</body>', scriptToAdd + '</body>');

      // 4. Salva e apri nel browser
      final appDocDir = await getApplicationDocumentsDirectory();
      final safeDir = Directory('${appDocDir.path}/viewers');
      if (!await safeDir.exists()) {
        await safeDir.create(recursive: true);
      }

      final outputFile = File(
        '${safeDir.path}/mxl_viewer_${DateTime.now().millisecondsSinceEpoch}.html',
      );
      await outputFile.writeAsString(finalHtml, flush: true);

      // 5. Apri nel browser
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

  // 🔥 APRI CON APP ESTERNA (Finale)
  Future<void> _openWithDefaultApp() async {
    try {
      final file = File(widget.document.filePath ?? '');
      if (await file.exists()) {
        final result = await OpenFilex.open(file.path);
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
          const SnackBar(
            content: Text('File non trovato'),
            backgroundColor: Colors.red,
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🎼 ${widget.document.fileName}'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openInBrowser,
            tooltip: 'Apri nel browser',
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: _openWithDefaultApp,
            tooltip: 'Apri con app predefinita (Finale)',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Caricamento spartito MXL...'),
          ],
        ),
      )
          : _error != null
          ? _buildErrorView()
          : _buildContentView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMxl,
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openWithDefaultApp,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Apri con Finale'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.deepPurple.shade50,
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.deepPurple),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎵 ${_metadata['title'] ?? widget.document.fileName}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '✍️ ${_metadata['composer'] ?? 'Compositore sconosciuto'}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.library_music, size: 80, color: Colors.deepPurple.shade300),
                  const SizedBox(height: 16),
                  Text(
                    '🎼 Spartito MusicXML',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${widget.document.fileName}', style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _openInBrowser,
                        icon: const Icon(Icons.open_in_browser),
                        label: const Text('🌐 Apri nel browser'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _openWithDefaultApp,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('🔧 Apri con Finale'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}