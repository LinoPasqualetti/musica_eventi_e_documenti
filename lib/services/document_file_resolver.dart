// lib/services/document_file_resolver.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/document.dart';

class DocumentFileResolver {
  /// Restituisce un Document con filePath garantito utilizzabile:
  /// - storage_mode == 'filesystem' -> il documento originale, invariato.
  /// - storage_mode == 'blob'       -> una copia con filePath che punta a un
  ///   file temporaneo scritto a partire da document.content.
  static Future<Document> resolve(Document document) async {
    // 🔥 SE IL FILE È UN BLOB, CREA UN FILE TEMPORANEO
    if (document.content != null) {
      // Se il filePath esiste già e il file esiste, usalo (caso Windows)
      if (document.filePath != null && await File(document.filePath!).exists()) {
        return document;
      }

      // 🔥 CREA UN FILE TEMPORANEO (per Android, dove il percorso originale non esiste)
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory(p.join(tempDir.path, 'blob_docs'));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final safeName = (document.fileName ?? 'documento').replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final cachedFile = File(p.join(cacheDir.path, '${document.id}_$safeName'));

      // Riscrive se il file non esiste o se la dimensione non coincide
      final needsWrite = !(await cachedFile.exists()) ||
          (await cachedFile.length()) != document.content!.length;

      if (needsWrite) {
        await cachedFile.writeAsBytes(document.content!, flush: true);
      }

      return document.copyWith(filePath: cachedFile.path);
    }

    // 🔥 SE NON È UN BLOB, MA IL PERCORSO NON ESISTE (Android), CERCA NEL DOWNLOAD
    if (!kIsWeb && document.filePath != null) {
      final originalFile = File(document.filePath!);
      if (await originalFile.exists()) {
        return document;
      }

      // Cerca nella cartella Download del telefono
      final downloadDir = Directory('/storage/emulated/0/Download/');
      if (await downloadDir.exists()) {
        final downloadFile = File('${downloadDir.path}/${document.fileName}');
        if (await downloadFile.exists()) {
          return document.copyWith(filePath: downloadFile.path);
        }
      }
    }

    return document;
  }

  /// Svuota la cache dei file materializzati da blob (utile da un pulsante
  /// "libera spazio" nelle impostazioni, se serve).
  static Future<void> clearCache() async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory(p.join(tempDir.path, 'blob_docs'));
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  }
}