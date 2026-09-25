// lib/services/web_sync_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/registration_model.dart';
import '../utils/constants.dart';
import '../models/organ.dart';
import '../models/organ_slot.dart';

/// Client HTTP verso il backend web per la sync delle candidature.
///
/// Endpoint usati:
///   - GET  /api/registrations/since?timestamp=...   (pull)
///   - POST /api/registrations/ack                   (conferma ricezione)
///   - POST /api/registrations/push                  (invio modifiche)
///
/// Tutti richiedono JWT admin nell'header `Authorization: Bearer ...`.
class WebSyncService {
  final http.Client _client;
  final String _baseUrl;
  String? _token;

  WebSyncService({http.Client? client, String? baseUrl, String? token})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConstants.webApiBaseUrl,
        _token = token;

  /// Imposta il token JWT admin (chiamato dal provider prima di ogni sync).
  void setToken(String? token) {
    _token = token;
  }

  String? get token => _token;

  Map<String, String> _headers() {
    final h = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      h['Authorization'] = 'Bearer $_token';
    }
    return h;
  }

  // ============================================
  // PULL
  // ============================================

  /// GET /api/registrations/since?timestamp=<ISO8601>
  /// Ritorna la lista di candidature modificate dopo <timestamp>.
  Future<Map<String, dynamic>> pull({String? timestamp}) async {
    final qs = timestamp != null && timestamp.isNotEmpty
        ? '?timestamp=${Uri.encodeQueryComponent(timestamp)}'
        : '';
    final uri = Uri.parse('$_baseUrl/api/registrations/since$qs');

    final res = await _client
        .get(uri, headers: _headers())
        .timeout(AppConstants.syncHttpTimeout);

    if (res.statusCode != 200) {
      throw Exception('Pull fallito: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data;
  }

  // ============================================
  // ACK
  // ============================================

  /// POST /api/registrations/ack
  /// Body: { "ids": [...] }
  /// Il Web marca `synced_to_flutter_at = now` per gli id indicati.
  Future<int> ack(List<String> ids) async {
    if (ids.isEmpty) return 0;

    final uri = Uri.parse('$_baseUrl/api/registrations/ack');
    final res = await _client
        .post(
          uri,
          headers: _headers(),
          body: jsonEncode({'ids': ids}),
        )
        .timeout(AppConstants.syncHttpTimeout);

    if (res.statusCode != 200) {
      throw Exception('Ack fallito: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['acknowledged'] as int?) ?? 0;
  }

  // ============================================
  // PUSH
  // ============================================

  /// POST /api/registrations/push
  /// Body: { registrations: [{ id, status, time_description, admin_notes, updated_at, deleted_at }] }
  /// Ritorna il numero di record aggiornati lato Web.
  Future<Map<String, dynamic>> push(List<Registration> registrations) async {
    if (registrations.isEmpty) {
      return {'updated': 0, 'skipped': 0, 'errors': 0, 'results': []};
    }

    final payload = registrations.map((r) => {
      'id': r.id,
      'status': r.status,
      'time_description': r.timeDescription,
      'admin_notes': r.adminNotes,
      'updated_at': r.updatedAt,
      'deleted_at': r.deletedAt,
    }).toList();

    final uri = Uri.parse('$_baseUrl/api/registrations/push');
    final res = await _client
        .post(
          uri,
          headers: _headers(),
          body: jsonEncode({'registrations': payload}),
        )
        .timeout(AppConstants.syncHttpTimeout);

    if (res.statusCode != 200) {
      throw Exception('Push fallito: ${res.statusCode} ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  void dispose() {
    _client.close();
  }
  /// Auto-login Web con le credenziali admin.
  /// Salva il JWT internamente per le chiamate successive.
  Future<bool> loginWithCredentials({
    required String email,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/auth/login');
      final res = await _client
          .post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      )
          .timeout(AppConstants.syncHttpTimeout);

      if (res.statusCode != 200) {
        print('❌ Login Web fallito: ${res.statusCode} ${res.body}');
        return false;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token == null || token.isEmpty) {
        print('❌ Login Web: token mancante');
        return false;
      }

      _token = token;
      print('✅ Login Web OK - token salvato (${token.substring(0, 20)}...)');
      return true;
    } catch (e) {
      print('❌ Login Web eccezione: $e');
      return false;
    }
  }

  /// Verifica se il token è presente.
  bool hasToken() => _token != null && _token!.isNotEmpty;
  // ============================================
  // PUSH ORGANICO (one-shot)
  // ============================================

  /// Invia un organico completo (organ + slots) al backend Web.
  /// Richiede un token admin valido (auto-login già fatto).
  /// Ritorna il numero di slot inviati.
  Future<int> pushOrgan({
    required String eventSongId,
    required Organ organ,
    required List<OrganSlot> slots,
  }) async {
    if (!hasToken()) {
      throw Exception('Token admin mancante per pushOrgan');
    }

    final uri = Uri.parse('$_baseUrl/api/organs/sync');

    final payload = {
      'event_song_id': eventSongId,
      'organ': {
        'id': organ.id,
        'name': organ.name,
        'notes': organ.notes,
      },
      'slots': slots
          .map((s) => {
        'id': s.id,
        'section': s.section.dbValue,
        'instrument': s.instrument,
        'quantity': s.quantity,
        'notes': s.notes,
        'order_index': s.orderIndex,
      })
          .toList(),
    };

    final res = await _client
        .post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    )
        .timeout(AppConstants.syncHttpTimeout);

    if (res.statusCode != 200) {
      throw Exception('Push organico fallito: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
// Leggi lo stats.slotsCreated dal backend, con fallback
    final stats = data['stats'] as Map<String, dynamic>?;
    final slotsCreated = stats?['slotsCreated'] as int?;
    return slotsCreated ?? slots.length;
  }
}
