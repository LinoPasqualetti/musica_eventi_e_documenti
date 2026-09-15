// [MODIFICA] C:\musica_eventi_e_documenti\lib\utils\constants.dart

class AppConstants {
  static const String appName = 'Inclusione Musicale';
  static const String version = '1.0.0';

  /// Base URL del backend web (Fly.io).
 // static const String webApiBaseUrl =
 //     'https://musica-eventi-e-documenti-web.fly.dev';
// Per test locali — punta al backend sulla tua macchina
  static const String webApiBaseUrl = 'http://localhost:5000';

// Per produzione (Hetzner, quando sarà pronto) — decommentare e aggiornare
// static const String webApiBaseUrl = 'https://tuonome.duckdns.org';
  /// Timeout per le chiamate HTTP di sincronizzazione.
  static const Duration syncHttpTimeout = Duration(seconds: 20);

  /// Chiave univoca locale per lo stato di sync.
  /// (usata come default in registrations.sync_state)
  static const String syncStateClean  = 'clean';
  static const String syncStateDirty  = 'dirty';
  static const String syncStateConflict = 'conflict';
}