// lib/providers/registration_sync_provider.dart
import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/web_sync_service.dart';
import '../utils/constants.dart';

/// Stato del processo di sync (per la UI).
class RegistrationSyncState {
  final bool isRunning;
  final String? lastError;
  final int lastPulled;
  final int lastPushed;
  final DateTime? lastRunAt;

  const RegistrationSyncState({
    this.isRunning = false,
    this.lastError,
    this.lastPulled = 0,
    this.lastPushed = 0,
    this.lastRunAt,
  });

  RegistrationSyncState copyWith({
    bool? isRunning,
    String? lastError,
    int? lastPulled,
    int? lastPushed,
    DateTime? lastRunAt,
    bool clearError = false,
  }) {
    return RegistrationSyncState(
      isRunning: isRunning ?? this.isRunning,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastPulled: lastPulled ?? this.lastPulled,
      lastPushed: lastPushed ?? this.lastPushed,
      lastRunAt: lastRunAt ?? this.lastRunAt,
    );
  }
}

/// Provider per la sincronizzazione delle candidature col backend web.
class RegistrationSyncProvider extends ChangeNotifier {
  final WebSyncService _web;
  final DatabaseService _db;

  RegistrationSyncState _state = const RegistrationSyncState();

  RegistrationSyncProvider({
    WebSyncService? web,
    DatabaseService? db,
  })  : _web = web ?? WebSyncService(),
        _db = db ?? DatabaseService();

  RegistrationSyncState get state => _state;
  bool get isRunning => _state.isRunning;
  String? get lastError => _state.lastError;

  void _setState(RegistrationSyncState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Imposta il JWT admin per le chiamate.
  void setToken(String? token) {
    _web.setToken(token);
  }
  /// Assicura che ci sia un token Web valido.
  /// Se non c'è, fa auto-login con le credenziali admin da AppConstants.
  Future<bool> _ensureWebToken() async {
    if (_web.hasToken()) return true;

    print('🔑 Auto-login Web in corso...');
    final ok = await _web.loginWithCredentials(
      email: AppConstants.webAdminEmail,
      password: AppConstants.webAdminPassword,
    );
    if (!ok) {
      print('❌ Auto-login Web fallito');
      return false;
    }
    return true;
  }
  // ═══════════════════════════════════════════════════════════════
  // PULL
  // ═══════════════════════════════════════════════════════════════

  /// Scarica le candidature dal Web e le applica localmente.
  /// Poi chiama ack per marcare il Web come "sincronizzato".
  Future<void> pull() async {
    _setState(_state.copyWith(isRunning: true, clearError: true));
    if (!await _ensureWebToken()) {
      _setState(_state.copyWith(
        isRunning: false,
        lastError: 'Login Web fallito',
      ));
      return;
    }

    try {
      // 1. Leggi ultimo timestamp di pull
      final since = await _db.getLastPullTimestamp();

      // 2. Chiama il Web
      final response = await _web.pull(timestamp: since);

      final remoteList = (response['registrations'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      final serverTime = response['serverTime'] as String?;

      // 3. Applica in locale (idempotente)
      final inserted = await _db.applyPullFromServer(remoteList);

      // 4. Ack: conferma al Web di aver ricevuto
      final ids = remoteList.map((r) => r['id'] as String).toList();
      if (ids.isNotEmpty) {
        try {
          await _web.ack(ids);
        } catch (e) {
          await _db.logSync(
            direction: 'pull',
            action: 'error',
            detail: 'ack fallito: $e',
          );
          // Non blocca: il prossimo pull riproverà
        }
      }

      // 5. Salva timestamp
      if (serverTime != null) {
        await _db.setLastPullTimestamp(serverTime);
      }

      await _db.logSync(
        direction: 'pull',
        action: 'completed',
        detail: '${remoteList.length} ricevuti, $inserted nuovi',
      );

      _setState(_state.copyWith(
        isRunning: false,
        lastPulled: inserted,
        lastRunAt: DateTime.now(),
      ));
    } catch (e) {
      await _db.logSync(direction: 'pull', action: 'error', detail: '$e');
      _setState(_state.copyWith(
        isRunning: false,
        lastError: 'Pull fallito: $e',
      ));
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // PUSH
  // ═══════════════════════════════════════════════════════════════

  /// Invia al Web le candidature modificate localmente (sync_state='dirty').
  Future<void> push() async {
    _setState(_state.copyWith(isRunning: true, clearError: true));
    if (!await _ensureWebToken()) {
      _setState(_state.copyWith(
        isRunning: false,
        lastError: 'Login Web fallito',
      ));
      return;
    }

    try {
      final dirty = await _db.getDirtyRegistrations();
      if (dirty.isEmpty) {
        _setState(_state.copyWith(
          isRunning: false,
          lastPushed: 0,
          lastRunAt: DateTime.now(),
        ));
        return;
      }

      final response = await _web.push(dirty);
      final updated = (response['updated'] as int?) ?? 0;

      // Marca come clean tutti quelli che il server ha confermato
      final results = (response['results'] as List?)?.cast<Map>() ?? [];
      for (final r in results) {
        final id = r['id'] as String?;
        final status = r['status'] as String?;
        if (id == null) continue;
        if (status == 'updated' || status == 'skipped') {
          await _db.markRegistrationClean(id);
        }
      }

      await _db.logSync(
        direction: 'push',
        action: 'completed',
        detail: '$updated aggiornati su ${dirty.length}',
      );

      _setState(_state.copyWith(
        isRunning: false,
        lastPushed: updated,
        lastRunAt: DateTime.now(),
      ));
    } catch (e) {
      await _db.logSync(direction: 'push', action: 'error', detail: '$e');
      _setState(_state.copyWith(
        isRunning: false,
        lastError: 'Push fallito: $e',
      ));
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // SYNC ALL (pull + push)
  // ═══════════════════════════════════════════════════════════════

  Future<void> syncAll() async {
    await push();
    await pull();
  }

  void clearError() {
    _setState(_state.copyWith(clearError: true));
  }

  // ═══════════════════════════════════════════════════════════════
  // ALIAS per compatibilità con admin_registrations.dart
  // ═══════════════════════════════════════════════════════════════

  /// Alias di pull() — usato da admin_registrations.dart
  Future<void> pullPending() => pull();

  /// Alias di push() — usato da admin_registrations.dart
  Future<void> pushDirty() => push();
}
