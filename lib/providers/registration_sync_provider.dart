// [MODIFICA] C:\musica_eventi_e_documenti\lib\providers\registration_sync_provider.dart

// lib/providers/registration_sync_provider.dart
import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/web_sync_service.dart';

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

/// Provider per la sincronizzazione delle iscrizioni col backend web.
/// Usa ChangeNotifier (stile `provider` package), coerente col resto dell'app.
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

  /// PULL: scarica le pending dal web, le inserisce localmente,
  /// poi notifica il web con mark-exported.
  Future<void> pullPending() async {
    _setState(_state.copyWith(isRunning: true, clearError: true));
    final insertedIds = <String>[];

    try {
      // 1. Scarica
      final remote = await _web.fetchPending();

      // 2. Inserisci localmente (idempotente)
      for (final reg in remote) {
        final inserted = await _db.insertRegistrationIfAbsent(reg);
        if (inserted) {
          insertedIds.add(reg.id);
          await _db.logSync(
            direction: 'pull',
            action: 'inserted',
            entityId: reg.id,
          );
        } else {
          await _db.logSync(
            direction: 'pull',
            action: 'skipped',
            entityId: reg.id,
          );
        }
      }

// 3. Notifica il web per TUTTE le pending ricevute
//    (anche quelle già presenti localmente, altrimenti restano
//     pending sul web per sempre e vengono riproposte ad ogni pull)
      final allRemoteIds = remote.map((r) => r.id).toList();

      if (allRemoteIds.isNotEmpty) {
        try {
          await _web.markExported(allRemoteIds);
          await _db.markRegistrationsPulled(allRemoteIds);
          await _db.logSync(
            direction: 'pull',
            action: 'marked_exported',
            detail: '${allRemoteIds.length} ids (${insertedIds.length} nuovi)',
          );
        } catch (e) {
          await _db.logSync(
            direction: 'pull',
            action: 'error',
            detail: 'mark-exported fallito: $e',
          );
          _setState(_state.copyWith(
            isRunning: false,
            lastPulled: insertedIds.length,
            lastRunAt: DateTime.now(),
            lastError: 'Pull OK ma mark-exported fallito: $e',
          ));
          return;
        }
      }

      _setState(_state.copyWith(
        isRunning: false,
        lastPulled: insertedIds.length,
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

  /// PUSH: invia al web tutte le registrazioni modificate localmente.
  /// Le voci che falliscono restano `dirty` e verranno ritentate.
  Future<void> pushDirty() async {
    _setState(_state.copyWith(isRunning: true, clearError: true));
    int pushed = 0;

    try {
      final dirty = await _db.getDirtyRegistrations();

      for (final reg in dirty) {
        try {
          await _web.pushStatus(
            reg.id,
            reg.status,
            adminNotes: reg.adminNotes,
          );
          await _db.markRegistrationClean(reg.id);
          await _db.logSync(
            direction: 'push',
            action: 'status_pushed',
            entityId: reg.id,
            detail: reg.status,
          );
          pushed++;
        } catch (e) {
          await _db.logSync(
            direction: 'push',
            action: 'error',
            entityId: reg.id,
            detail: '$e',
          );
          // resta dirty, verrà ritentato
        }
      }

      _setState(_state.copyWith(
        isRunning: false,
        lastPushed: pushed,
        lastRunAt: DateTime.now(),
      ));
    } catch (e) {
      _setState(_state.copyWith(
        isRunning: false,
        lastError: 'Push fallito: $e',
      ));
    }
  }

  void clearError() {
    _setState(_state.copyWith(clearError: true));
  }
}