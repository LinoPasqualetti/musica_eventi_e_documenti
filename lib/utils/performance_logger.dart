// lib/utils/performance_logger.dart

class PerformanceLogger {
  static const bool enableLogging = true;

  static final Map<String, Stopwatch> _timers = {};

  static void start(String operation) {
    if (!enableLogging) return;
    final stopwatch = Stopwatch()..start();
    _timers[operation] = stopwatch;
    print('⏱️ START: $operation');
  }

  static void stop(String operation) {
    if (!enableLogging) return;
    final stopwatch = _timers[operation];
    if (stopwatch != null) {
      stopwatch.stop();
      final elapsed = stopwatch.elapsedMilliseconds;
      print('✅ END: $operation - ${elapsed}ms');
      if (elapsed > 1000) {
        print('⚠️ SLOW: $operation - ${elapsed}ms');
      }
      _timers.remove(operation);
    }
  }

  static void info(String message, {String? details}) {
    if (!enableLogging) return;
    if (details != null && details.isNotEmpty) {
      print('ℹ️ $message - $details');
    } else {
      print('ℹ️ $message');
    }
  }

  static void warning(String message, {String? details}) {
    if (!enableLogging) return;
    if (details != null && details.isNotEmpty) {
      print('⚠️ WARNING: $message - $details');
    } else {
      print('⚠️ WARNING: $message');
    }
  }

  static void error(String message, {String? details, dynamic error}) {
    if (!enableLogging) return;
    String msg = '❌ ERROR: $message';
    if (details != null && details.isNotEmpty) {
      msg += ' - $details';
    }
    if (error != null) {
      msg += ' - $error';
    }
    print(msg);
  }

  static void clear() {
    _timers.clear();
  }
}