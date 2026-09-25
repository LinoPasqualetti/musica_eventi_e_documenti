// lib/services/web_auth_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

/// Servizio di autenticazione verso il backend web (JWT).
///
/// Fa login con le credenziali admin in `AppConstants` e
/// cachea il token in memoria per la sessione corrente.
/// Il token viene riusato da tutti i servizi di push (organici, documenti, ...).
///
/// Se il token scade (401), fa un nuovo login automatico.
class WebAuthService {
  static String? _cachedToken;
  static DateTime? _cachedAt;
  static const Duration _tokenTtl = Duration(hours: 12);

  /// Ritorna il token JWT valido, facendo login se necessario.
  /// Null se il login fallisce.
  static Future<String?> getToken({bool forceRefresh = false}) async {
    // Token in cache ancora valido?
    if (!forceRefresh &&
        _cachedToken != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _tokenTtl) {
      return _cachedToken;
    }

    // Login
    return await _login();
  }

  /// Forza un nuovo login (usato se un altro servizio riceve 401).
  static Future<String?> refreshToken() async {
    _cachedToken = null;
    _cachedAt = null;
    return await _login();
  }

  /// Pulisci il token in memoria (es. dopo logout).
  static void clear() {
    _cachedToken = null;
    _cachedAt = null;
  }

  static Future<String?> _login() async {
    try {
      final res = await http.post(
        Uri.parse('${AppConstants.webApiBaseUrl}/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': AppConstants.webAdminEmail,
          'password': AppConstants.webAdminPassword,
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        print('❌ Login web fallito (${res.statusCode}): ${res.body}');
        return null;
      }

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final token = decoded['token'] as String?;

      if (token == null || token.isEmpty) {
        print('❌ Login web: token mancante nella risposta');
        return null;
      }

      _cachedToken = token;
      _cachedAt = DateTime.now();
      print('✅ Login web OK, token cacheato (${token.substring(0, 20)}...)');
      return token;
    } catch (e) {
      print('❌ Errore login web: $e');
      return null;
    }
  }
}