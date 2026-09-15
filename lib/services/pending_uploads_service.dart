// [NUOVO] C:\musica_eventi_e_documenti\lib\services\pending_uploads_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Gestisce un file JSON con la lista dei documenti la cui sincronizzazione
/// al web è fallita.
///
/// Il file NON è nel DB: è separato, quindi non viene copiato da
/// sync-incremental.js, non finisce nel DB web, non finisce su Turso.
class PendingUploadsService {
  static const String _fileName = 'musica_eventi_documenti_pending.json';

  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Legge la lista dei pending. Ritorna lista vuota se il file non esiste.
  static Future<List<Map<String, dynamic>>> readAll() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final decoded = jsonDecode(content);
      if (decoded is List) return List<Map<String, dynamic>>.from(decoded);
      return [];
    } catch (e) {
      print('⚠️ Errore lettura pending_uploads: $e');
      return [];
    }
  }

  /// Aggiunge un documento alla lista dei pending.
  static Future<void> add(String documentId, String sourceFilePath) async {
    try {
      final file = await _getFile();
      final current = await readAll();
      // Rimuovi eventuale duplicato
      current.removeWhere((e) => e['documentId'] == documentId);
      current.add({
        'documentId': documentId,
        'sourcePath': sourceFilePath,
        'addedAt': DateTime.now().toIso8601String(),
      });
      await file.writeAsString(jsonEncode(current));
      print('📝 Aggiunto a pending_uploads: $documentId');
    } catch (e) {
      print('❌ Errore aggiunta pending_upload: $e');
    }
  }

  /// Rimuove un documento dalla lista dei pending.
  static Future<void> remove(String documentId) async {
    try {
      final file = await _getFile();
      final current = await readAll();
      current.removeWhere((e) => e['documentId'] == documentId);
      await file.writeAsString(jsonEncode(current));
    } catch (e) {
      print('❌ Errore rimozione pending_upload: $e');
    }
  }

  /// Ritorna il numero di pending.
  static Future<int> count() async {
    return (await readAll()).length;
  }
}