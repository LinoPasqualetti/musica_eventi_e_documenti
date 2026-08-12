// lib/services/mxl_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class MxlService {
  static const String MXL_EXTENSION = '.mxl';

  // ✅ DECOMPRIME IL FILE MXL E RESTITUISCE IL CONTENUTO XML
  static Future<String?> extractXmlContent(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ File non trovato: $filePath');
        return null;
      }

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Cerca il file .xml all'interno dell'archivio
      String? xmlContent;
      for (final file in archive) {
        if (file.isFile && file.name.endsWith('.xml')) {
          xmlContent = utf8.decode(file.content as List<int>);
          break;
        }
      }

      return xmlContent;
    } catch (e) {
      print('❌ Errore estrazione MXL: $e');
      return null;
    }
  }

  // ✅ ESTRAE METADATI DAL MUSICXML
  static Map<String, String> extractMetadata(String xmlContent) {
    try {
      final document = XmlDocument.parse(xmlContent);

      // Cerca titolo
      final titleNode = document.findAllElements('work-title');
      final title = titleNode.isNotEmpty ? titleNode.first.text : 'Senza titolo';

      // Cerca compositore
      final creatorNodes = document.findAllElements('creator');
      String? composer;
      for (final node in creatorNodes) {
        if (node.getAttribute('type') == 'composer') {
          composer = node.text;
          break;
        }
      }

      // Cerca parti strumentali
      final partList = document.findAllElements('score-part');
      final parts = partList.map((p) {
        final partName = p.findAllElements('part-name');
        return partName.isNotEmpty ? partName.first.text : 'Parte';
      }).toList();

      return {
        'title': title,
        'composer': composer ?? 'Sconosciuto',
        'parts': parts.join(', '),
        'partCount': parts.length.toString(),
      };
    } catch (e) {
      print('❌ Errore parsing metadata: $e');
      return {
        'title': 'Errore lettura',
        'composer': 'Sconosciuto',
        'parts': 'N/A',
        'partCount': '0',
      };
    }
  }

  // ✅ SALVA IL FILE XML ESTRATTO
  static Future<void> saveXmlContent(String filePath, String xmlContent) async {
    final outputPath = filePath.replaceAll('.mxl', '.xml');
    final file = File(outputPath);
    await file.writeAsString(xmlContent);
    print('✅ XML estratto salvato in: $outputPath');
  }
}