// lib/screens/spartito_viewer_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Sostituisce sia il vecchio AbcViewerScreen (che scriveva un HTML
/// temporaneo e lo apriva con un'app esterna, in modo fragile) sia il
/// comportamento di MxlViewerScreen quando delega all'app di sistema
/// (es. Finale): entrambi i tipi vengono mostrati, eseguiti e trasposti
/// dentro spartito-viewer.html, incorporato con InAppWebView invece che
/// lanciato fuori dall'app.
///
/// Usa loadData() invece di initialFile: initialFile ha un problema noto su
/// Windows, funziona in debug ma non nel pacchetto .exe compilato.
class SpartitoViewerScreen extends StatefulWidget {
  final String filePath; // percorso locale già risolto (vedi DocumentFileResolver)
  final String fileName;
  final String docType; // 'abc' oppure 'mxl'

  const SpartitoViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.docType,
  });

  @override
  State<SpartitoViewerScreen> createState() => _SpartitoViewerScreenState();
}

class _SpartitoViewerScreenState extends State<SpartitoViewerScreen> {
  String? _error;
  String? _htmlTemplate;

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  Future<void> _loadTemplate() async {
    try {
      final html = await rootBundle.loadString('assets/html/spartito-viewer.html');
      if (!mounted) return;
      setState(() {
        _htmlTemplate = html;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossibile caricare spartito-viewer.html: $e';
      });
    }
  }

  Future<void> _pushContent(InAppWebViewController controller) async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final base64Content = base64Encode(bytes);
      await controller.evaluateJavascript(source: '''
        if (window.loadFromFlutter) {
          window.loadFromFlutter(${jsonEncode(base64Content)}, ${jsonEncode(widget.docType)});
        }
      ''');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossibile leggere il documento: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : (_htmlTemplate == null
              ? const Center(child: CircularProgressIndicator())
              : InAppWebView(
                  initialData: InAppWebViewInitialData(
                    data: _htmlTemplate!,
                    baseUrl: WebUri("about:blank"),
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    mediaPlaybackRequiresUserGesture: false,
                  ),
                  onLoadStop: (controller, url) async {
                    await _pushContent(controller);
                  },
                  onConsoleMessage: (controller, msg) {
                    debugPrint('spartito-viewer.html: ${msg.message}');
                  },
                )),
    );
  }
}
