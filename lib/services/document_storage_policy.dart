// lib/services/document_storage_policy.dart
import 'package:path/path.dart' as p;

class DocumentStoragePolicy {
  /// Soglia blob: sotto questa dimensione → blob; sopra → filesystem.
  static const int sogliaBlob = 1024 * 1024; // 1 MB

  /// Estensioni che sono SEMPRE filesystem (audio/video/pdf).
  static const Set<String> heavyExts = {
    '.mp3', '.wav', '.mp4', '.m4a', '.pdf',
  };

  /// Estensioni che sono SEMPRE blob se sotto soglia.
  static const Set<String> lightExts = {
    '.mid', '.midi', '.kar', '.abc', '.xml', '.mxl', '.txt',
  };

  /// Ritorna 'blob' o 'filesystem'.
  static String decide({
    required String filePath,
    required int fileSize,
  }) {
    final ext = p.extension(filePath).toLowerCase();

    if (heavyExts.contains(ext)) return 'filesystem';
    if (fileSize >= sogliaBlob) return 'filesystem';
    return 'blob';
  }

  /// Ritorna true se il contenuto va letto e salvato nel campo `content`.
  static bool shouldStoreContent({
    required String filePath,
    required int fileSize,
  }) {
    return decide(filePath: filePath, fileSize: fileSize) == 'blob';
  }
}