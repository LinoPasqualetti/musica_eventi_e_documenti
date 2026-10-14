// lib/services/full_push_service.dart
//
// "Push Completo": invia l'intero DB Flutter al backend Web,
// che esegue replace-all + merge-registrations e ritorna un report.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'database_service.dart';
import 'web_auth_service.dart';

class FullPushTableResult {
  final bool ok;
  final int web;
  final int flutter;
  final String? reason;
  final String? error;

  FullPushTableResult({
    required this.ok,
    required this.web,
    required this.flutter,
    this.reason,
    this.error,
  });

  factory FullPushTableResult.fromJson(Map<String, dynamic> j) {
    return FullPushTableResult(
      ok: j['ok'] == true,
      web: (j['web'] as num?)?.toInt() ?? 0,
      flutter: (j['flutter'] as num?)?.toInt() ?? 0,
      reason: j['reason'] as String?,
      error: j['error'] as String?,
    );
  }
}

class FullPushRegResult {
  final bool ok;
  final int inserted;
  final int updated;
  final int skipped;
  final int deleted;
  final int softDeleted;
  final int errors;

  FullPushRegResult({
    required this.ok,
    this.inserted = 0,
    this.updated = 0,
    this.skipped = 0,
    this.deleted = 0,
    this.softDeleted = 0,
    this.errors = 0,
  });

  factory FullPushRegResult.fromJson(Map<String, dynamic> j) {
    return FullPushRegResult(
      ok: j['ok'] == true,
      inserted: (j['inserted'] as num?)?.toInt() ?? 0,
      updated: (j['updated'] as num?)?.toInt() ?? 0,
      skipped: (j['skipped'] as num?)?.toInt() ?? 0,
      deleted: (j['deleted'] as num?)?.toInt() ?? 0,
      softDeleted: (j['softDeleted'] as num?)?.toInt() ?? 0,
      errors: (j['errors'] as num?)?.toInt() ?? 0,
    );
  }
}

class FullPushReport {
  final bool ok;
  final Map<String, FullPushTableResult> tables;
  final FullPushRegResult registrations;
  final int orphansCleaned;
  final List<dynamic> errors;
  final int durationMs;
  final List<dynamic> foreignKeyIssues;

  FullPushReport({
    required this.ok,
    required this.tables,
    required this.registrations,
    required this.orphansCleaned,
    required this.errors,
    required this.durationMs,
    required this.foreignKeyIssues,
  });

  factory FullPushReport.fromJson(Map<String, dynamic> j) {
    final tablesRaw = (j['tables'] as Map?) ?? {};
    final tables = <String, FullPushTableResult>{};
    tablesRaw.forEach((k, v) {
      if (v is Map) {
        tables[k.toString()] =
            FullPushTableResult.fromJson(Map<String, dynamic>.from(v));
      }
    });

    return FullPushReport(
      ok: j['ok'] == true,
      tables: tables,
      registrations: FullPushRegResult.fromJson(
        Map<String, dynamic>.from((j['registrations'] as Map?) ?? {}),
      ),
      orphansCleaned: (j['orphansCleaned'] as num?)?.toInt() ?? 0,
      errors: (j['errors'] as List?) ?? [],
      durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
      foreignKeyIssues: (j['foreignKeyIssues'] as List?) ?? [],
    );
  }

  String describe() {
    final buf = StringBuffer();
    buf.writeln('Durata: ${durationMs}ms');
    buf.writeln();
    buf.writeln('Tabelle catalogo:');
    for (final e in tables.entries) {
      final r = e.value;
      final mark = r.ok ? 'OK ' : '!! ';
      buf.writeln('  $mark${e.key}: web=${r.web} flutter=${r.flutter}');
      if (r.reason != null) buf.writeln('     motivo: ${r.reason}');
      if (r.error != null) buf.writeln('     errore: ${r.error}');
    }
    buf.writeln();
    buf.writeln('Registrations:');
    final reg = registrations;
    buf.writeln('  inserite:      ${reg.inserted}');
    buf.writeln('  aggiornate:    ${reg.updated}');
    buf.writeln('  skippate:      ${reg.skipped}');
    buf.writeln('  cancellate:    ${reg.deleted}');
    buf.writeln('  soft-deleted:  ${reg.softDeleted}');
    buf.writeln('  errori:        ${reg.errors}');
    if (orphansCleaned > 0) {
      buf.writeln();
      buf.writeln('Orfane pulite: $orphansCleaned');
    }
    if (errors.isNotEmpty) {
      buf.writeln();
      buf.writeln('Errori: ${errors.length}');
    }
    if (foreignKeyIssues.isNotEmpty) {
      buf.writeln();
      buf.writeln('FK issues: ${foreignKeyIssues.length}');
    }
    return buf.toString();
  }
}

class FullPushService {
  static Future<FullPushReport> pushFull() async {
    final dbPath = await DatabaseService().getDatabasePath();
    if (dbPath.contains('(web)')) {
      throw Exception('Push completo non supportato su Web');
    }

    // getToken() fa già login automatico se non c'è token in cache
    var token = await WebAuthService.getToken();
    if (token == null) {
      throw Exception('Login Web fallito');
    }

    final uri = Uri.parse('${AppConstants.webApiBaseUrl}/api/admin/sync/full');

    Future<http.Response> send(String tk) async {
      final req = http.MultipartRequest('POST', uri);
      req.headers['Authorization'] = 'Bearer $tk';
      req.files.add(await http.MultipartFile.fromPath('flutterDb', dbPath));
      final st = await req.send().timeout(const Duration(minutes: 5));
      return await http.Response.fromStream(st);
    }

    var response = await send(token);

    if (response.statusCode == 401) {
      final newToken = await WebAuthService.refreshToken();
      if (newToken == null) throw Exception('Refresh token Web fallito');
      response = await send(newToken);
    }

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    return FullPushReport.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

