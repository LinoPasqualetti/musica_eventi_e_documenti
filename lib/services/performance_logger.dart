// lib/services/performance_logger.dart

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class PerformanceLogger {
  static const bool enableLogging = true; // Metti a false per produzione

  // Timer per operazioni
  static final Map<String, Stopwatch> _timers = {};
  static final Map<String, List<LogEntry>> _logs = {};

  // 🔥 Avvia un timer per un'operazione
  static void start(String operation, {String? details}) {
    if (!enableLogging) return;

    final stopwatch = Stopwatch()..start();
    final key = _getKey(operation);
    _timers[key] = stopwatch;

    _log(
      '⏱️ START',
      operation,
      details: details,
      timestamp: DateTime.now(),
    );
  }

  // 🔥 Ferma il timer e registra il tempo
  static void stop(String operation, {String? details, bool showResult = true}) {
    if (!enableLogging) return;

    final key = _getKey(operation);
    final stopwatch = _timers[key];

    if (stopwatch != null) {
      stopwatch.stop();
      final elapsed = stopwatch.elapsedMilliseconds;

      _log(
        '✅ END',
        operation,
        details: details ?? 'Completato in ${elapsed}ms',
        timestamp: DateTime.now(),
        elapsedMs: elapsed,
      );

      // 🔥 Warning se l'operazione è lenta (> 1 secondo)
      if (elapsed > 1000) {
        _log(
          '⚠️ SLOW',
          operation,
          details: '⚠️ OPERAZIONE LENTA: ${elapsed}ms',
          timestamp: DateTime.now(),
          elapsedMs: elapsed,
          isWarning: true,
        );
      }

      // 🔥 Critico se > 5 secondi
      if (elapsed > 5000) {
        _log(
          '🚨 CRITICAL',
          operation,
          details: '🚨 OPERAZIONE CRITICAMENTE LENTA: ${elapsed}ms',
          timestamp: DateTime.now(),
          elapsedMs: elapsed,
          isWarning: true,
        );
      }

      _timers.remove(key);
    }
  }

  // 🔥 Log di un'operazione generica
  static void info(String message, {String? details}) {
    if (!enableLogging) return;
    _log('ℹ️ INFO', message, details: details);
  }

  // 🔥 Log di un warning
  static void warning(String message, {String? details}) {
    _log('⚠️ WARNING', message, details: details, isWarning: true);
  }

  // 🔥 Log di un errore
  static void error(String message, {String? details, dynamic error}) {
    _log(
      '❌ ERROR',
      message,
      details: details ?? error?.toString(),
      isWarning: true,
    );
  }

  // 🔥 Log delle query SQL
  static void sqlQuery(String query, {List? args, int? rowCount}) {
    if (!enableLogging) return;

    final details = StringBuffer();
    details.write('SQL: $query');
    if (args != null && args.isNotEmpty) {
      details.write('\nArgs: $args');
    }
    if (rowCount != null) {
      details.write('\nRows: $rowCount');
    }

    _log('🗄️ SQL', 'Query eseguita', details: details.toString());
  }

  // 🔥 Log delle operazioni di database
  static void dbOperation(String operation, {String? table, int? affectedRows, dynamic error}) {
    if (!enableLogging) return;

    final details = StringBuffer();
    details.write('Table: ${table ?? 'unknown'}');
    if (affectedRows != null) {
      details.write('\nAffected: $affectedRows');
    }
    if (error != null) {
      details.write('\nError: $error');
    }

    _log(
      error != null ? '❌ DB ERROR' : '💾 DB',
      operation,
      details: details.toString(),
      isWarning: error != null,
    );
  }

  // 🔥 Log della cache
  static void cacheOperation(String operation, {String? key, bool? hit, int? size}) {
    if (!enableLogging) return;

    final details = StringBuffer();
    if (key != null) details.write('Key: $key\n');
    if (hit != null) details.write('Hit: $hit\n');
    if (size != null) details.write('Size: $size');

    _log(
      hit == true ? '✅ CACHE HIT' : '📦 CACHE',
      operation,
      details: details.toString(),
    );
  }

  // 🔥 Ottieni report riassuntivo
  static String getReport() {
    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('📊 PERFORMANCE REPORT');
    buffer.writeln('═══════════════════════════════════════════════════════════');

    // Raggruppa per operazione
    final operations = <String, List<LogEntry>>{};
    for (final entry in _logs.values.expand((list) => list)) {
      operations.putIfAbsent(entry.operation, () => []).add(entry);
    }

    for (final entry in operations.entries) {
      final op = entry.key;
      final logs = entry.value;

      // Calcola statistiche
      final elapsedTimes = logs
          .where((l) => l.elapsedMs != null)
          .map((l) => l.elapsedMs!)
          .toList();

      if (elapsedTimes.isNotEmpty) {
        final avg = elapsedTimes.reduce((a, b) => a + b) / elapsedTimes.length;
        final max = elapsedTimes.reduce((a, b) => a > b ? a : b);
        final min = elapsedTimes.reduce((a, b) => a < b ? a : b);
        final count = elapsedTimes.length;

        buffer.writeln('\n📌 $op');
        buffer.writeln('   Count: $count');
        buffer.writeln('   Avg: ${avg.toStringAsFixed(0)}ms');
        buffer.writeln('   Min: ${min}ms');
        buffer.writeln('   Max: ${max}ms');

        if (max > 1000) {
          buffer.writeln('   ⚠️ LENTO! Considera ottimizzazione');
        }
      }
    }

    buffer.writeln('\n═══════════════════════════════════════════════════════════');
    return buffer.toString();
  }

  // 🔥 Metodi privati
  static String _getKey(String operation) {
    return '${operation}_${DateTime.now().millisecondsSinceEpoch}';
  }

  static void _log(
      String type,
      String operation, {
        String? details,
        DateTime? timestamp,
        int? elapsedMs,
        bool isWarning = false,
      }) {
    final entry = LogEntry(
      type: type,
      operation: operation,
      details: details,
      timestamp: timestamp ?? DateTime.now(),
      elapsedMs: elapsedMs,
      isWarning: isWarning,
    );

    _logs.putIfAbsent(operation, () => []).add(entry);

    // Stampa a console con colori
    final icon = entry.isWarning ? '⚠️' : '';
    final timestampStr = entry.timestamp.toString().substring(11, 19);

    if (entry.isWarning) {
      developer.log(
        '${entry.type} ${entry.operation}',
        name: 'PERF',
        time: entry.timestamp,
        error: details,
      );
    }

    // Stampa dettagliata
    print('${entry.type} $timestampStr - ${entry.operation}');
    if (details != null && details.isNotEmpty) {
      print('   └─ $details');
    }
    if (entry.elapsedMs != null) {
      print('   └─ ⏱️ ${entry.elapsedMs}ms');
    }
  }

  // 🔥 Reset dei log
  static void clear() {
    _timers.clear();
    _logs.clear();
  }
}

class LogEntry {
  final String type;
  final String operation;
  final String? details;
  final DateTime timestamp;
  final int? elapsedMs;
  final bool isWarning;

  LogEntry({
    required this.type,
    required this.operation,
    this.details,
    required this.timestamp,
    this.elapsedMs,
    this.isWarning = false,
  });
}