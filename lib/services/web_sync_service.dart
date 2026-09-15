// [NUOVO] C:\musica_eventi_e_documenti\lib\services\web_sync_service.dart

// lib/services/web_sync_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/registration_model.dart';
import '../utils/constants.dart';

/// Client HTTP verso il backend web su Fly.io.
/// Incapsula le 3 chiamate necessarie al ciclo di sync delle iscrizioni:
///   - GET  /api/registrations?status=pending      (pull)
///   - POST /api/registrations/mark-exported       (notifica post-insert)
///   - PUT  /api/registrations/:id/status          (push dello status finale)
class WebSyncService {
  final http.Client _client;
  final String _baseUrl;

  WebSyncService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConstants.webApiBaseUrl;

  /// GET /api/registrations?status=pending
  /// Ritorna la lista di Registration pronte da importare.
  /// Il controller web risponde con un array JSON puro.
  Future<List<Registration>> fetchPending() async {
    final uri = Uri.parse('$_baseUrl/api/registrations?status=pending');
    final res = await _client.get(uri).timeout(AppConstants.syncHttpTimeout);

    if (res.statusCode != 200) {
      throw Exception(
        'GET pending fallito: ${res.statusCode} ${res.body}',
      );
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! List) {
      throw Exception(
        'Risposta inattesa da GET pending: atteso List, ricevuto ${decoded.runtimeType}',
      );
    }

    return decoded
        .cast<Map<String, dynamic>>()
        .map((json) => Registration.fromMap(json))
        .toList();
  }

  /// POST /api/registrations/mark-exported
  /// Body: { "ids": [...] }
  /// Idempotente lato web: aggiorna solo le registrazioni con status 'pending'.
  Future<void> markExported(List<String> ids) async {
    if (ids.isEmpty) return;

    final uri = Uri.parse('$_baseUrl/api/registrations/mark-exported');
    final res = await _client
        .post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ids': ids}),
    )
        .timeout(AppConstants.syncHttpTimeout);

    if (res.statusCode != 200) {
      throw Exception(
        'mark-exported fallito: ${res.statusCode} ${res.body}',
      );
    }
  }

  /// PUT /api/registrations/:id/status
  /// Body: { "status": "validated" | "rejected" | ..., "admin_notes"?: "..." }
  Future<void> pushStatus(
      String id,
      String status, {
        String? adminNotes,
      }) async {
    final uri = Uri.parse('$_baseUrl/api/registrations/$id/status');
    final body = <String, dynamic>{'status': status};
    if (adminNotes != null) body['admin_notes'] = adminNotes;

    final res = await _client
        .put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    )
        .timeout(AppConstants.syncHttpTimeout);

    if (res.statusCode != 200) {
      throw Exception(
        'PUT status ($id -> $status) fallito: ${res.statusCode} ${res.body}',
      );
    }
  }

  /// Chiude il client HTTP (utile nei test o alla chiusura dell'app).
  void dispose() {
    _client.close();
  }
}