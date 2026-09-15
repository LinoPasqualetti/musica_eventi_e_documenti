// [MODIFICA] C:\musica_eventi_e_documenti\lib\screens\abc_viewer_screen.dart

// lib/screens/abc_viewer_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

class AbcViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  final int initialTranspose;
  final int initialInstrument;

  const AbcViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    this.initialTranspose = 0,
    this.initialInstrument = 0,
  });

  @override
  State<AbcViewerScreen> createState() => _AbcViewerScreenState();
}

class _AbcViewerScreenState extends State<AbcViewerScreen> {
  String _abcContent = '';
  bool _isLoading = true;
  bool _isOpening = false;
  String _error = '';

  late int _transpose;
  late int _instrument;

  @override
  void initState() {
    super.initState();
    _transpose = widget.initialTranspose;
    _instrument = widget.initialInstrument;
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
      setState(() => _isLoading = false);
    }
  }

  /// Invia l'ABC al backend web, ottiene un id, apre /viewer?id=... nel browser.
  Future<void> _openInBrowser() async {
    setState(() => _isOpening = true);
    try {
      // 1. POST /api/abc-temp
      final apiBase = AppConstants.webApiBaseUrl;
      final postUri = Uri.parse('$apiBase/api/abc-temp');

      final res = await http
          .post(
        postUri,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'abc': _abcContent,
          'fileName': widget.fileName,
        }),
      )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode != 200) {
        throw 'Backend HTTP ${res.statusCode}: ${res.body}';
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final id = data['id'] as String?;
      if (id == null) {
        throw 'Risposta backend senza id: ${res.body}';
      }

      // 2. Componi URL del viewer
      final viewerUri = Uri.parse('$apiBase/viewer').replace(
        queryParameters: {
          'id': id,
          'fileName': widget.fileName,
          'transpose': _transpose.toString(),
          'instrument': _instrument.toString(),
        },
      );

      print('🌐 Apro viewer: $viewerUri');

      // 3. Apri nel browser di sistema
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

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _abcContent));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📋 ABC copiato negli appunti!'),
          backgroundColor: Colors.green,
        ),
      );
    }
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
                const Text('Errore',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_error,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600)),
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyToClipboard,
            tooltip: 'Copia ABC',
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
                  Expanded(child: Text(_getAbcInfo())),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Preset trasposizione/strumento
            Text('Preset iniziale',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _transpose,
                    decoration: const InputDecoration(
                      labelText: 'Trasposizione (semitoni)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (var i = -12; i <= 12; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(i == 0 ? 'Originale' : '$i'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _transpose = v ?? 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _instrument,
                    decoration: const InputDecoration(
                      labelText: 'Strumento',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Do (nessuna)')),
                      DropdownMenuItem(value: 2, child: Text('Sib')),
                      DropdownMenuItem(value: 14, child: Text('Sib basso')),
                      DropdownMenuItem(value: 9, child: Text('Mib')),
                      DropdownMenuItem(value: 21, child: Text('Mib basso')),
                      DropdownMenuItem(value: 7, child: Text('Fa')),
                    ],
                    onChanged: (v) => setState(() => _instrument = v ?? 0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bottone principale
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isOpening ? null : _openInBrowser,
                icon: _isOpening
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.open_in_new),
                label: Text(
                  _isOpening ? 'Apertura…' : 'Apri Spartito nel Browser',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '💡 Il browser si aprirà con la stessa visualizzazione del web: '
                  'multi-traccia, trasposizione, player audio e zoom.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Anteprima ABC (testo grezzo)
            const Text('Contenuto ABC (anteprima testo):',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
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
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Indietro'),
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
    int tuneCount = 0;
    for (var line in lines) {
      if (line.startsWith('X:')) tuneCount++;
      if (line.startsWith('T:')) title = line.substring(2).trim();
      if (line.startsWith('C:')) composer = line.substring(2).trim();
    }
    return 'Titolo: $title\n'
        'Compositore: $composer\n'
        'Brani: $tuneCount\n'
        'Righe: ${lines.length}';
  }
}