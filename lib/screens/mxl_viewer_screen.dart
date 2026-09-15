// [MODIFICA] C:\musica_eventi_e_documenti\lib\screens\mxl_viewer_screen.dart

// lib/screens/mxl_viewer_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import '../models/document.dart';
import '../services/mxl_service.dart';
import '../utils/constants.dart';

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
  bool _isOpening = false;
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
        setState(() => _error = 'Errore: Percorso file mancante');
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
        setState(() => _error = 'Impossibile estrarre il contenuto MXL');
      }
    } catch (e) {
      setState(() => _error = 'Errore: $e');
    }
    setState(() => _isLoading = false);
  }

  /// 🔥 NUOVO FLUSSO: carica il .mxl sul backend e apre /mxl-viewer?id=...
  /// Il backend serve il binario, il browser lo converte e lo renderizza
  /// con ScoreViewer.jsx (stessa logica del web).
  Future<void> _openInBrowser() async {
    setState(() => _isOpening = true);
    try {
      final filePath = widget.document.filePath;
      if (filePath == null) throw 'Percorso file mancante';

      final file = File(filePath);
      if (!await file.exists()) throw 'File non trovato: $filePath';

      final bytes = await file.readAsBytes();

      final apiBase = AppConstants.webApiBaseUrl;
      final postUri = Uri.parse('$apiBase/api/mxl-temp').replace(
        queryParameters: {'fileName': widget.document.fileName},
      );

      final res = await http
          .post(
            postUri,
            headers: {
              'Content-Type': 'application/octet-stream',
              'X-File-Name': widget.document.fileName,
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 60));

      if (res.statusCode != 200) {
        throw 'Backend HTTP ${res.statusCode}: ${res.body}';
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final id = data['id'] as String?;
      if (id == null) throw 'Risposta backend senza id';

      final viewerUri = Uri.parse('$apiBase/mxl-viewer').replace(
        queryParameters: {
          'id': id,
          'fileName': widget.document.fileName,
        },
      );

      print('🌐 Apro viewer MXL: $viewerUri');

      if (await canLaunchUrl(viewerUri)) {
        await launchUrl(viewerUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Impossibile aprire il browser per $viewerUri';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  /// Apre il file con l'app di sistema (Finale, MuseScore, ecc.)
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
            onPressed: _isOpening ? null : _openInBrowser,
            tooltip: 'Apri nel browser (rendering web)',
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
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
                  Icon(
                    Icons.library_music,
                    size: 80,
                    color: Colors.deepPurple.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '🎼 Spartito MusicXML',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.document.fileName,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  if (_isOpening)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Caricamento spartito sul server…'),
                        ],
                      ),
                    )
                  else
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