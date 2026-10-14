// lib/services/replica_push_service.dart
//
// Servizio per il push di tabelle intere dal DB Flutter al backend web.
//
// Usa l'endpoint POST /api/sync/replicate.
//
// Supporta le tabelle:
//   - songs
//   - events
//   - event_songs
//   - documents          (⚠️ il campo 'content' viene escluso dal push)
//   - song_documents
//   - event_song_documents
//
// ⚠️ NON supporta registrations (master web, il Flutter le pulla).

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../utils/constants.dart';
import 'web_auth_service.dart';

/// Risultato di un push di tabella.
class ReplicaPushResult {
  final bool success;
  final int httpStatus;
  final String? error;
  final int received;
  final int inserted;
  final int updated;
  final int skipped;
  final int deleted;
  final List<Map<String, dynamic>> errors;
  final List<Map<String, dynamic>> blocked;

  ReplicaPushResult({
    required this.success,
    required this.httpStatus,
    this.error,
    this.received = 0,
    this.inserted = 0,
    this.updated = 0,
    this.skipped = 0,
    this.deleted = 0,
    this.errors = const [],
    this.blocked = const [],
  });

  factory ReplicaPushResult.failure(String error, {int httpStatus = 0}) {
    return ReplicaPushResult(
      success: false,
      httpStatus: httpStatus,
      error: error,
    );
  }

  @override
  String toString() {
    if (!success) return 'ERRORE: $error';
    return 'received=$received, inserted=$inserted, updated=$updated, '
        'errors=${errors.length}, blocked=${blocked.length}';
  }
}

/// Servizio di push di tabelle dal Flutter al web.
class ReplicaPushService {
  /// Campi da escludere dal push per tabella (blob pesanti, non sincronizzabili).
  /// I metadati vengono sincronizzati, i blob restano locali.
  ///
  /// - `documents.content`: blob base64 del PDF/MXL/MP3.
  ///   Il file fisico resta nelle due macchine. Il web ha il suo blob
  ///   caricato a parte via /upload-big. Sincronizzare il content
  ///   via JSON è inutile e produce 413 Payload Too Large.
  static const Map<String, List<String>> _excludedColumns = {
    'documents': ['content'],
  };

  /// Push di una tabella.
  ///
  /// - [db]: il database Flutter (aperto)
  /// - [table]: nome tabella (deve essere in _supportedTables)
  /// - [where]: filtro WHERE opzionale (es. "id > 'xxx'")
  /// - [batchSize]: numero massimo di righe per chiamata (default 500)
  static Future<ReplicaPushResult> pushTable(
      Database db, {
        required String table,
        String? where,
        List<Object?>? whereArgs,
        int batchSize = 500,
      }) async {
    // Whitelist
    const supported = {
      'songs',
      'events',
      'event_songs',
      'documents',
      'song_documents',
      'event_song_documents',
    };

    if (!supported.contains(table)) {
      return ReplicaPushResult.failure(
        'Tabella "$table" non supportata. Valide: ${supported.join(", ")}',
      );
    }

    // 1. Conta le righe
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM $table${where != null ? " WHERE $where" : ""}',
      whereArgs,
    );
    final total = (countResult.first['n'] as int?) ?? 0;

    if (total == 0) {
      return ReplicaPushResult(
        success: true,
        httpStatus: 200,
        received: 0,
      );
    }

    // 2. Leggi a batch
    int offset = 0;
    final totalStats = {
      'received': 0,
      'inserted': 0,
      'updated': 0,
      'skipped': 0,
    };
    final allErrors = <Map<String, dynamic>>[];
    final allBlocked = <Map<String, dynamic>>[];

    while (offset < total) {
      final rawRows = await db.query(
        table,
        where: where,
        whereArgs: whereArgs,
        limit: batchSize,
        offset: offset,
      );

      if (rawRows.isEmpty) break;

      // Applica esclusione campi blob (es. 'content' per documents)
      final excluded = _excludedColumns[table];
      final rows = excluded == null
          ? rawRows
          : rawRows.map((r) {
        final copy = Map<String, dynamic>.from(r);
        for (final col in excluded) {
          copy.remove(col);
        }
        return copy;
      }).toList();

      // 3. Push al web
      final result = await _pushBatch(table, rows);

      if (!result.success) {
        return result;
      }

      totalStats['received'] = totalStats['received']! + result.received;
      totalStats['inserted'] = totalStats['inserted']! + result.inserted;
      totalStats['updated'] = totalStats['updated']! + result.updated;
      totalStats['skipped'] = totalStats['skipped']! + result.skipped;
      allErrors.addAll(result.errors);
      allBlocked.addAll(result.blocked);

      offset += rawRows.length;
    }

    return ReplicaPushResult(
      success: true,
      httpStatus: 200,
      received: totalStats['received']!,
      inserted: totalStats['inserted']!,
      updated: totalStats['updated']!,
      skipped: totalStats['skipped']!,
      errors: allErrors,
      blocked: allBlocked,
    );
  }

  /// Push di un batch di righe.
  static Future<ReplicaPushResult> _pushBatch(
      String table,
      List<Map<String, dynamic>> rows,
      ) async {
    try {
      final token = await WebAuthService.getToken();
      if (token == null) {
        return ReplicaPushResult.failure('Login web fallito');
      }

      final body = {
        'table': table,
        'mode': 'upsert',
        'matchBy': 'id',
        'rows': rows,
      };

      final res = await http.post(
        Uri.parse('${AppConstants.webApiBaseUrl}/api/sync/replicate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 120));

      if (res.statusCode == 401) {
        // Prova refresh token
        final newToken = await WebAuthService.refreshToken();
        if (newToken == null) {
          return ReplicaPushResult.failure('Refresh token fallito');
        }
        // Riprova
        final res2 = await http.post(
          Uri.parse('${AppConstants.webApiBaseUrl}/api/sync/replicate'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $newToken',
          },
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 120));

        if (res2.statusCode != 200) {
          return ReplicaPushResult.failure(
            'HTTP ${res2.statusCode}: ${res2.body}',
            httpStatus: res2.statusCode,
          );
        }
        return _parseResponse(res2);
      }

      if (res.statusCode != 200) {
        return ReplicaPushResult.failure(
          'HTTP ${res.statusCode}: ${res.body}',
          httpStatus: res.statusCode,
        );
      }

      return _parseResponse(res);
    } catch (e) {
      return ReplicaPushResult.failure(e.toString());
    }
  }

  static ReplicaPushResult _parseResponse(http.Response res) {
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return ReplicaPushResult(
      success: true,
      httpStatus: res.statusCode,
      received: (data['received'] as int?) ?? 0,
      inserted: (data['inserted'] as int?) ?? 0,
      updated: (data['updated'] as int?) ?? 0,
      skipped: (data['skipped'] as int?) ?? 0,
      errors: (data['errors'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      blocked: (data['blocked'] as List?)?.cast<Map<String, dynamic>>() ?? [],
    );
  }

  /// Push di tutte le tabelle di contenuto.
  /// Ritorna una mappa tabella → risultato.
  static Future<Map<String, ReplicaPushResult>> pushAllContent(Database db) async {
    final results = <String, ReplicaPushResult>{};

    // Ordine importante: prima i brani e eventi, poi le relazioni.
    // NOTA: documents viene pushata senza il campo content (escluso da _excludedColumns).
    const order = [
      'events',
      'songs',
      'documents',
      'event_songs',
      'song_documents',
      'event_song_documents',
    ];

    for (final table in order) {
      try {
        final result = await pushTable(db, table: table);
        results[table] = result;
        if (!result.success) {
          // Continua con le altre tabelle anche se una fallisce
          print('⚠️ Push $table fallito: ${result.error}');
        }
      } catch (e) {
        results[table] = ReplicaPushResult.failure(e.toString());
      }
    }

    return results;
  }
}