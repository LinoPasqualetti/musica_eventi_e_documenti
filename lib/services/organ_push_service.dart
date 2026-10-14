// lib/services/organ_push_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/organ.dart';
import '../models/organ_slot.dart';
import '../utils/constants.dart';
import 'web_auth_service.dart';

/// Risultato di un push (singolo o bulk) di organici al backend web.
class OrganPushResult {
  final bool success;
  final int httpStatus;
  final String? error;
  final int applied;
  final int blocked;
  final int errored;
  final List<Map<String, dynamic>> results;

  OrganPushResult({
    required this.success,
    required this.httpStatus,
    this.error,
    this.applied = 0,
    this.blocked = 0,
    this.errored = 0,
    this.results = const [],
  });

  factory OrganPushResult.failure(String error, {int httpStatus = 0}) {
    return OrganPushResult(
      success: false,
      httpStatus: httpStatus,
      error: error,
    );
  }

  String describeBulk() {
    if (!success) return 'Errore: ${error ?? "sconosciuto"}';
    final parts = <String>[];
    if (applied > 0) parts.add('$applied applicati');
    if (blocked > 0) parts.add('$blocked bloccati');
    if (errored > 0) parts.add('$errored errori');
    return parts.isEmpty ? 'Nessuna modifica' : parts.join(', ');
  }
}

/// Wrapper per bulk push.
class OrganToPush {
  final String eventSongId;
  final Organ organ;
  final List<OrganSlot> slots;

  OrganToPush({
    required this.eventSongId,
    required this.organ,
    required this.slots,
  });
}

/// Servizio per il push degli organici (con slot) al backend web.
class OrganPushService {
  static Future<OrganPushResult> pushOrgan({
    required String eventSongId,
    required Organ organ,
    required List<OrganSlot> slots,
  }) async {
    try {
      final body = {
        'event_song_id': eventSongId,
        'organ': {
          'id': organ.id,
          'name': organ.name,
          'notes': organ.notes,
        },
        'slots': slots.map((s) => {
          'id': s.id,
          'organ_id': s.organId,
          'instrument': s.instrument,
          'section': s.section.dbValue,
          'quantity': s.quantity,
          'notes': s.notes,
          'order_index': s.orderIndex,
        }).toList(),
      };

      return await _postWithAuth(endpoint: '/api/organs/sync', body: body);
    } catch (e) {
      return OrganPushResult.failure(e.toString());
    }
  }

  static Future<OrganPushResult> pushOrganBulk({
    required List<OrganToPush> organs,
  }) async {
    if (organs.isEmpty) {
      return OrganPushResult(success: true, httpStatus: 200);
    }

    try {
      final body = {
        'organs': organs.map((o) => {
          'event_song_id': o.eventSongId,
          'organ': {
            'id': o.organ.id,
            'name': o.organ.name,
            'notes': o.organ.notes,
          },
          'slots': o.slots.map((s) => {
            'id': s.id,
            'organ_id': s.organId,
            'instrument': s.instrument,
            'section': s.section.dbValue,
            'quantity': s.quantity,
            'notes': s.notes,
            'order_index': s.orderIndex,
          }).toList(),
        }).toList(),
      };

      return await _postWithAuth(endpoint: '/api/organs/sync-bulk', body: body);
    } catch (e) {
      return OrganPushResult.failure(e.toString());
    }
  }

  static Future<OrganPushResult> _postWithAuth({
    required String endpoint,
    required Map<String, dynamic> body,
  }) async {
    final token = await WebAuthService.getToken();
    if (token == null) {
      return OrganPushResult.failure('Login web fallito');
    }

    var res = await _post(endpoint: endpoint, body: body, token: token);

    if (res.statusCode == 401) {
      final newToken = await WebAuthService.refreshToken();
      if (newToken == null) {
        return OrganPushResult.failure('Refresh token fallito');
      }
      res = await _post(endpoint: endpoint, body: body, token: newToken);
    }

    if (res.statusCode != 200) {
      return OrganPushResult.failure(
        'HTTP ${res.statusCode}: ${res.body}',
        httpStatus: res.statusCode,
      );
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return OrganPushResult(
      success: true,
      httpStatus: res.statusCode,
      applied: (decoded['applied'] as int?) ??
          (decoded['success'] == true ? 1 : 0),
      blocked: (decoded['blocked'] as int?) ?? 0,
      errored: (decoded['errored'] as int?) ?? 0,
      results: (decoded['results'] as List?)?.cast<Map<String, dynamic>>() ?? [],
    );
  }

  static Future<http.Response> _post({
    required String endpoint,
    required Map<String, dynamic> body,
    required String token,
  }) async {
    return await http.post(
      Uri.parse('${AppConstants.webApiBaseUrl}$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 120));
  }
}