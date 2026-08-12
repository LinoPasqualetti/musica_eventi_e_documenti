// lib/screens/mxl_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
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
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isLoading = true;
  bool _isPlaying = false;
  String? _xmlContent;
  String? _error;
  Map<String, String> _metadata = {};
  bool _isExtracted = false;

  @override
  void initState() {
    super.initState();
    _loadMxl();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadMxl() async {
    setState(() => _isLoading = true);
    try {
      final xmlContent = await MxlService.extractXmlContent(widget.document.filePath);

      if (xmlContent != null) {
        setState(() {
          _xmlContent = xmlContent;
          _metadata = MxlService.extractMetadata(xmlContent);
          _isExtracted = true;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🎼 ${widget.document.fileName}'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadMxl,
            tooltip: 'Scarica MXL',
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openInBrowser,
            tooltip: 'Apri nel browser',
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
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Apri il file direttamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentView() {
    return Column(
      children: [
        // METADATI
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
                    Text(
                      '🎹 Parti: ${_metadata['parts'] ?? 'N/A'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              if (_metadata['partCount'] != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_metadata['partCount']} parti',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(),

        // AZIONI PRINCIPALI
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
                  Text(
                    '🎼 Spartito MusicXML',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.document.fileName}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildActionButton(
                        icon: Icons.open_in_browser,
                        label: '🌐 Apri MXL',
                        onTap: _openInBrowser,
                        color: Colors.blue,
                      ),
                      _buildActionButton(
                        icon: Icons.download,
                        label: '⬇️ Scarica MXL',
                        onTap: _downloadMxl,
                        color: Colors.green,
                      ),
                      _buildActionButton(
                        icon: Icons.text_snippet,
                        label: '📄 Estrai XML',
                        onTap: _extractXml,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '💡 Suggerimenti',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Apri il file MXL con MuseScore, Sibelius o Dorico\n'
                              '• Estrai il contenuto XML per visualizzare i dati\n'
                              '• Scarica il file per usarlo offline',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Colors.deepPurple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // ============================================
  // METODI AZIONE
  // ============================================

  void _downloadMxl() async {
    try {
      final file = File(widget.document.filePath);
      if (await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⬇️ Download MXL iniziato...'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Errore download: $e');
    }
  }

  void _openInBrowser() async {
    try {
      final filePath = widget.document.filePath;
      if (kIsWeb) {
        _showMessage('🌐 Apertura nel browser...');
      } else {
        await Process.run('explorer', [filePath]);
        _showMessage('✅ Apertura con app predefinita');
      }
    } catch (e) {
      _showError('Errore apertura: $e');
    }
  }

  void _extractXml() async {
    try {
      if (_xmlContent != null) {
        await MxlService.saveXmlContent(widget.document.filePath, _xmlContent!);
        _showMessage('✅ XML estratto in: ${widget.document.filePath.replaceAll('.mxl', '.xml')}');
      }
    } catch (e) {
      _showError('Errore estrazione XML: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}