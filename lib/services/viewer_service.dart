// lib/services/viewer_service.dart
//
// Genera un file HTML "viewer" in locale, sostituendo il placeholder
// __ABC_VIEWER_PAYLOAD__ con i dati reali (ABC o MusicXML).
// Il file viene salvato in /tmp e aperto con il browser di sistema.
//
// Niente backend: tutto in locale.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class ViewerService {
  /// Genera un viewer HTML da contenuto ABC.
  static Future<String> buildAbcViewer({
    required String abcContent,
    required String fileName,
    int transpose = 0,
    int instrument = 0,
    double zoom = 1.0,
  }) async {
    return _buildViewer(
      content: abcContent,
      fileName: fileName,
      transpose: transpose,
      instrument: instrument,
      zoom: zoom,
      contentType: 'abc',
    );
  }

  /// Genera un viewer HTML da contenuto MusicXML (testo).
  static Future<String> buildMusicXmlViewer({
    required String musicXmlContent,
    required String fileName,
    int transpose = 0,
    int instrument = 0,
    double zoom = 1.0,
  }) async {
    return _buildViewer(
      content: musicXmlContent,
      fileName: fileName,
      transpose: transpose,
      instrument: instrument,
      zoom: zoom,
      contentType: 'musicxml',
    );
  }

  /// Genera un viewer HTML da un file .mxl (ZIP compresso).
  static Future<String> buildMxlViewerFromFile({
    required String mxlFilePath,
    required String fileName,
    int transpose = 0,
    int instrument = 0,
    double zoom = 1.0,
  }) async {
    final bytes = await File(mxlFilePath).readAsBytes();
    final base64Content = base64Encode(bytes);

    return _buildViewer(
      content: base64Content,
      fileName: fileName,
      transpose: transpose,
      instrument: instrument,
      zoom: zoom,
      contentType: 'mxl_base64',
    );
  }

  static Future<String> _buildViewer({
    required String content,
    required String fileName,
    required int transpose,
    required int instrument,
    required double zoom,
    required String contentType,
  }) async {
    // 1. Leggi il template HTML dagli assets come BYTE e decodifica in UTF-8 esplicito
    //    (rootBundle.loadString puo cadere in Latin-1 su alcuni asset -> mojibake)
    final templateBytes = await rootBundle.load('assets/html/spartito-viewer.html');
    final template = utf8.decode(templateBytes.buffer.asUint8List());

    // 2. Prepara il payload JSON
    final payload = {
      'abc': content,
      'transpose': transpose,
      'instrument': instrument,
      'zoom': zoom,
      'fileName': fileName,
      'contentType': contentType,
    };

    // 3. Sostituisci il placeholder con il payload reale
    final injection =
        'window.__ABC_VIEWER_PAYLOAD__ = ${jsonEncode(payload)};';
    final html = template.replaceFirst(
      '/*__ABC_VIEWER_PAYLOAD__*/',
      injection,
    );

    // 4. Salva il file in /tmp
    final tempDir = await getTemporaryDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[^\w\-.]'), '_');
    final outFile = File(
      '${tempDir.path}/viewer_${DateTime.now().millisecondsSinceEpoch}_$safeName.html',
    );
    await outFile.writeAsString(html, encoding: utf8);

    print('📄 Viewer generato: ${outFile.path} (${html.length} byte)');
    return outFile.path;
  }

  /// Elimina i viewer vecchi (> 1 giorno) nella cartella temporanea.
  static Future<void> cleanupOldViewers() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cutoff = DateTime.now().subtract(const Duration(days: 1));

      await for (final entity in tempDir.list()) {
        if (entity is File && entity.path.contains('viewer_')) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      print('⚠️ Cleanup viewer fallito: $e');
    }
  }
}
