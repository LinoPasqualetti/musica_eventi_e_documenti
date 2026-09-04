// lib/services/mxl_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class MxlService {
  /// Estrae il vero contenuto XML musicale da un file .mxl (ZIP)
  static Future<String?> extractXmlContent(String filePath) async {
    try {
      // 1. Leggi il file .mxl come bytes
      final bytes = await File(filePath).readAsBytes();

      // 2. Decomprimi lo ZIP
      final archive = ZipDecoder().decodeBytes(bytes);

      // 3. 🔥 TROVA IL FILE GIUSTO (NON IL CONTAINER!)
      String? targetXmlName;

      // Prima prova a leggere il container per trovare il nome
      final containerFile = archive.files.firstWhere(
            (file) => file.name.endsWith('META-INF/container.xml'),
        orElse: () => throw Exception('Container non trovato'),
      );
      if (containerFile.isFile) {
        final containerContent = utf8.decode(containerFile.content);
        final containerDoc = XmlDocument.parse(containerContent);

        // Cerca l'attributo full-path
        final rootfile = containerDoc.findAllElements('rootfile').firstOrNull;
        if (rootfile != null) {
          targetXmlName = rootfile.getAttribute('full-path');
        }
      }

      // Se il container non ha dato il nome, cerca manualmente un file .xml
      if (targetXmlName == null) {
        targetXmlName = archive.files
            .where((file) => file.name.endsWith('.xml') && !file.name.contains('container'))
            .map((file) => file.name)
            .firstOrNull;
      }

      // 4. Se non abbiamo trovato nulla, errore
      if (targetXmlName == null) {
        throw Exception('Impossibile trovare il file XML dentro il MXL');
      }

      // 5. Estrai e decodifica il file XML vero
      final targetFile = archive.files.firstWhere(
            (file) => file.name == targetXmlName,
        orElse: () => throw Exception('File $targetXmlName non trovato'),
      );

      if (targetFile.isFile) {
        return utf8.decode(targetFile.content);
      }

      return null;
    } catch (e) {
      print('❌ Errore estrazione MXL: $e');
      return null;
    }
  }

  /// Estrae i metadati (titolo, compositore) dall'XML
  static Map<String, String> extractMetadata(String xmlContent) {
    try {
      final document = XmlDocument.parse(xmlContent);

      final title = document
          .findAllElements('work-title')
          .firstOrNull
          ?.innerText ??
          document.findAllElements('movement-title').firstOrNull?.innerText ??
          '';

      final composer = document
          .findAllElements('creator')
          .firstWhere(
            (el) => el.getAttribute('type') == 'composer',
        orElse: () => XmlElement(XmlName('empty')),
      )
          .innerText ?? '';

      return {
        'title': title,
        'composer': composer,
      };
    } catch (e) {
      return {};
    }
  }
}