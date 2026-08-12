// lib/services/mxl_converter.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class MxlToAbcConverter {
  static const String _apiUrl = 'https://abc.musicxml.com/convert';

  static Future<String?> convertMxlToAbc(String mxlFilePath) async {
    try {
      final file = File(mxlFilePath);
      if (!await file.exists()) {
        print('❌ File MXL non trovato: $mxlFilePath');
        return null;
      }

      // Leggi il contenuto del file MXL
      final content = await file.readAsString();

      // Crea la richiesta per il convertitore
      // NOTA: Per ora usiamo una conversione locale con xml2abc
      // In alternativa: usa l'API online o un servizio locale

      // Metodo 1: Convertitore online (richiede internet)
      // final response = await http.post(
      //   Uri.parse(_apiUrl),
      //   headers: {'Content-Type': 'application/xml'},
      //   body: content,
      // );
      //
      // if (response.statusCode == 200) {
      //   return response.body;
      // }

      // Metodo 2: Convertitore locale (richiede xml2abc installato)
      // Esegui xml2abc come processo esterno

      // Metodo 3: Parse manuale MusicXML → ABC
      // Per ora, ritorna un ABC di esempio
      return _manualMxlToAbc(content);

    } catch (e) {
      print('❌ Errore conversione MXL→ABC: $e');
      return null;
    }
  }

  // Conversione manuale semplice (da espandere)
  static String _manualMxlToAbc(String mxlContent) {
    // Parsing base del MusicXML
    // Estrarre titolo, compositore, note, etc.

    String title = 'Brano convertito';
    String composer = 'Sconosciuto';

    // Cerca titolo
    final titleMatch = RegExp(r'<movement-title>(.*?)</movement-title>').firstMatch(mxlContent);
    if (titleMatch != null) {
      title = titleMatch.group(1) ?? title;
    }

    // Cerca compositore
    final composerMatch = RegExp(r'<composer>(.*?)</composer>').firstMatch(mxlContent);
    if (composerMatch != null) {
      composer = composerMatch.group(1) ?? composer;
    }

    // Crea ABC di base
    return '''
X:1
T:$title
C:$composer
M:4/4
K:C
| C C C C | D D D D | E E E E | F F F F |
| G G G G | A A A A | B B B B | C8 ||
    ''';
  }

  // Salva il file ABC convertito
  static Future<String?> saveAbcFile(String abcContent, String fileName) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName.abc');
      await file.writeAsString(abcContent);
      return file.path;
    } catch (e) {
      print('❌ Errore salvataggio ABC: $e');
      return null;
    }
  }
}