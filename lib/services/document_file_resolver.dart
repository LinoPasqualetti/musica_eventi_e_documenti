// lib/services/document_file_resolver.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/document.dart';

/// I viewer esistenti (AbcViewerScreen, MxlViewerScreen, MidiPlayerScreen, ecc.)
/// leggono i documenti da un percorso su disco (document.filePath). Con lo storage
/// a BLOB, il contenuto vive nel DB e non su un file reale: questo resolver
/// materializza il BLOB in un file temporaneo la prima volta che serve, e
/// restituisce sempre un filePath valido, qualunque sia lo storage_mode.
class DocumentFileResolver {
  /// Restituisce un Document con filePath garantito utilizzabile:
  /// - storage_mode == 'filesystem' -> il documento originale, invariato.
  /// - storage_mode == 'blob'       -> una copia con filePath che punta a un
  ///   file temporaneo scritto a partire da document.content.
  static Future<Document> resolve(Document document) async {
    if (!document.isBlob) return document;

    if (document.content == null) {
      throw Exception(
        "Il documento '${document.fileName}' è marcato come blob ma non ha "
        "contenuto: esegui lib/scripts/populate_blob_content.dart per popolarlo.",
      );
    }

    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory(p.join(tempDir.path, 'blob_docs'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final safeName = document.fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final cachedFile = File(p.join(cacheDir.path, '${document.id}_$safeName'));

    // Riscrive solo se manca o la dimensione non coincide (evita I/O inutile ad
    // ogni apertura, ma si autocorregge se il contenuto nel DB è cambiato).
    final needsWrite = !(await cachedFile.exists()) ||
        (await cachedFile.length()) != document.content!.length;

    if (needsWrite) {
      await cachedFile.writeAsBytes(document.content!, flush: true);
    }

    return document.copyWith(filePath: cachedFile.path);
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
