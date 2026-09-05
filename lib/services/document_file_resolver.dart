// lib/services/document_file_resolver.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/document.dart';

class DocumentFileResolver {
  static Future<Document> resolve(Document document) async {
    // 🔥 Se il BLOB esiste (from fullDocument), crea un file temporaneo
    if (document.content != null) {
      // Se il filePath esiste già e il file esiste, usalo (caso Windows)
      if (document.filePath != null && await File(document.filePath!).exists()) {
        return document;
      }

      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory(p.join(tempDir.path, 'blob_docs'));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final safeName = (document.fileName ?? 'documento').replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final cachedFile = File(p.join(cacheDir.path, '${document.id}_$safeName'));

      final needsWrite = !(await cachedFile.exists()) ||
          (await cachedFile.length()) != document.content!.length;

      if (needsWrite) {
        await cachedFile.writeAsBytes(document.content!, flush: true);
      }

      return document.copyWith(filePath: cachedFile.path);
    }

    // 🔥 Se NON è un BLOB ma il percorso non esiste (Android), usa il "Download"
    if (!kIsWeb && document.filePath != null) {
      final originalFile = File(document.filePath!);
      if (await originalFile.exists()) {
        return document;
      }
      // Cerca nella cartella Download
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

  static Future<void> clearCache() async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory(p.join(tempDir.path, 'blob_docs'));
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  }
}