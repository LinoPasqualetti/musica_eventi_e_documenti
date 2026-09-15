// [MODIFICA] C:\musica_eventi_e_documenti\lib\services\document_push_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/document.dart';
import '../utils/constants.dart';

class DocumentPushService {
  static const int _maxBlobSize = 1024 * 1024; // 1 MB

  /// Pusha un documento al web usando il content già in memoria.
  /// Ritorna true se riuscito.
  static Future<bool> pushDocument(Document doc, {List<String> songIds = const []}) async {
    try {
      final content = doc.content;
      if (content == null || content.isEmpty) {
        print('⚠️ Documento ${doc.id} senza content, skip push');
        return false;
      }

      final fileSize = content.length;
      final useBlob = fileSize <= _maxBlobSize;

      if (useBlob) {
        return await _pushBlob(doc, content, songIds);
      } else {
        return await _pushBig(doc, content, songIds);
      }
    } catch (e) {
      print('❌ Errore push documento ${doc.id}: $e');
      return false;
    }
  }

  static Future<bool> _pushBlob(
      Document doc,
      List<int> content,
      List<String> songIds,
      ) async {
    final contentBase64 = base64Encode(content);

    final res = await http.post(
      Uri.parse('${AppConstants.webApiBaseUrl}/api/documents/sync'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': doc.id,
        'fileName': doc.fileName,
        'docType': doc.docType,
        'fileSize': content.length,
        'contentBase64': contentBase64,
        'mimeType': doc.mimeType,
        'description': doc.description.isNotEmpty ? doc.description : null,
        'isPublic': doc.isPublic,
        'uploadedBy': doc.uploadedBy.isNotEmpty ? doc.uploadedBy : 'desktop',
        'songIds': songIds,
      }),
    ).timeout(const Duration(seconds: 60));

    if (res.statusCode != 200) {
      print('❌ sync BLOB fallito (${res.statusCode}): ${res.body}');
      return false;
    }

    print('✅ Documento pushato come BLOB: ${doc.id} (${content.length} byte)');
    return true;
  }

  static Future<bool> _pushBig(
      Document doc,
      List<int> content,
      List<String> songIds,
      ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConstants.webApiBaseUrl}/api/documents/upload-big'),
    );

    request.fields['id'] = doc.id;
    request.fields['docType'] = doc.docType;
    request.fields['uploadedBy'] = doc.uploadedBy.isNotEmpty ? doc.uploadedBy : 'desktop';
    if (doc.description.isNotEmpty) {
      request.fields['description'] = doc.description;
    }
    request.fields['isPublic'] = doc.isPublic.toString();
    if (songIds.isNotEmpty) {
      request.fields['songIds'] = jsonEncode(songIds);
    }

    // Per MultipartFile.fromBytes dobbiamo passare i bytes
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      content,
      filename: doc.fileName,
    ));

    final streamed = await request.send().timeout(const Duration(seconds: 300));
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200) {
      print('❌ upload-big fallito (${res.statusCode}): ${res.body}');
      return false;
    }

    print('✅ Documento pushato come REMOTE: ${doc.id} (${content.length} byte)');
    return true;
  }
}