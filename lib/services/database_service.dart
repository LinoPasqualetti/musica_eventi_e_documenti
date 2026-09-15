// [MODIFICA] C:\musica_eventi_e_documenti\lib\services\database_service.dart

// lib/services/database_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/document.dart';
import '../models/song_document.dart';
import 'document_push_service.dart';
import 'pending_uploads_service.dart';
// Importa FFI per desktop
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
// Importa FFI per web
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/event_model.dart';
import '../models/song_model.dart';
import '../models/registration_model.dart';
import '../models/musical_document.dart';
import '../models/user_model.dart';
//import '../models/event_song.dart'; // RIMOSSO - ora in event_model.dart
import 'database_migration.dart';

// 🔥 IMPORT DEL LOGGER
import '../utils/performance_logger.dart';

class DatabaseService {
  static Database? _database;
  static bool _initialized = false;
  static bool _isWeb = kIsWeb;
  static bool _forceCopyFromAsset = false;

  // Versione del database - AUMENTATA A 4 PER LA SYNC REGISTRAZIONI
  static const int DB_VERSION = 4;

  DatabaseService() {
    _initDatabaseFactory();
  }

  void _initDatabaseFactory() {
    if (_initialized) return;

    if (_isWeb) {
      try {
        databaseFactory = databaseFactoryFfiWeb;
      } catch (e) {
        // Ignora
      }
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        ffi.sqfliteFfiInit();
        databaseFactory = ffi.databaseFactoryFfi;
      } catch (e) {
        // Ignora
      }
    }

    _initialized = true;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    PerformanceLogger.start('_initDatabase');

    String path;

    if (_isWeb) {
      path = 'musica_eventi_e_documenti.db';
    } else {
      final appDocDir = await getApplicationDocumentsDirectory();
      path = join(appDocDir.path, 'musica_eventi_e_documenti.db');
    }

    print('📁 Database path: $path');

    final bool shouldCopy = await _shouldCopyDatabase(path);

    if (shouldCopy) {
      print('🔄 Copia database da asset (versione $DB_VERSION)...');
      await _copyDatabaseFromAsset(path);
    } else {
      print('ℹ️ Database già esistente, uso quello esistente');
    }

    final db = await openDatabase(
      path,
      version: DB_VERSION,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) {
        print('✅ Database aperto con successo');
      },
    );

    PerformanceLogger.stop('_initDatabase');
    return db;
  }

  Future<bool> _shouldCopyDatabase(String path) async {
    if (_isWeb) {
      return false;
    }

    if (_forceCopyFromAsset) {
      print('🔧 Copia forzata da asset attiva');
      return true;
    }

    final File file = File(path);

    if (await file.exists()) {
      print('📂 Database locale esiste, lo uso - COPIA DA ASSET BLOCCATA');
      return false;
    }

    print('📂 Database locale non esiste, copio da assets (primo avvio)');
    return true;
  }

  Future<void> forceCopyFromAsset() async {
    print('🔄 FORZATURA COPIA DA ASSET richiesta dall\'admin');
    _forceCopyFromAsset = true;

    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final path = join(appDocDir.path, 'musica_eventi_e_documenti.db');

    await _copyDatabaseFromAsset(path);

    _database = await openDatabase(
      path,
      version: DB_VERSION,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) {
        print('✅ Database riaperto dopo copia da asset');
      },
    );

    _forceCopyFromAsset = false;
    print('✅ Copia da asset completata');
  }

  Future<void> _copyDatabaseFromAsset(String destinationPath) async {
    try {
      print('📁 Copia database da asset a: $destinationPath');

      final byteData = await rootBundle.load('assets/db/musica_eventi_e_documenti.db');
      final bytes = byteData.buffer.asUint8List();

      if (_isWeb) {
        final db = await openDatabase(destinationPath);
        await db.close();
      } else {
        final file = File(destinationPath);
        await file.writeAsBytes(bytes);
        print('✅ Database copiato da asset con successo');
      }
    } catch (e) {
      print('⚠️ Errore nel copiare database da asset: $e');
      print('🔄 Creazione database da zero...');
      await _createEmptyDatabase(destinationPath);
    }
  }

  Future<void> _createEmptyDatabase(String path) async {
    final db = await openDatabase(
      path,
      version: DB_VERSION,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await db.close();
    print('✅ Database vuoto creato (solo tabelle)');
  }

  /// Dopo un aggiornamento dell'app, i documenti passati a storage_mode='blob'
  /// hanno content=NULL sul dispositivo (i file originali non ci sono mai
  /// stati, solo sul PC dove è stato preparato il DB). Questo metodo apre il
  /// DB bundlato nel nuovo asset (che il processo di build ha già popolato
  /// con lo script populate_blob_content.dart) e copia SOLO i content
  /// mancanti nel DB locale, per id corrispondente — non tocca nient'altro
  /// (eventi, registrazioni, brani, modifiche admin locali restano intatti).
  Future<void> _backfillBlobContentFromAsset(Database liveDb) async {
    if (_isWeb) return; // su web non c'è un file system locale su cui operare così

    PerformanceLogger.start('_backfillBlobContentFromAsset');

    String? tempAssetDbPath;
    Database? assetDb;
    try {
      final rows = await liveDb.query(
        'documents',
        columns: ['id'],
        where: "storage_mode = 'blob' AND content IS NULL",
      );
      if (rows.isEmpty) {
        print('ℹ️ Nessun content mancante da recuperare dall\'asset');
        PerformanceLogger.stop('_backfillBlobContentFromAsset');
        return;
      }

      PerformanceLogger.info('Backfill BLOB', details: '${rows.length} documenti da recuperare');

      final byteData = await rootBundle.load('assets/db/musica_eventi_e_documenti.db');
      final bytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      tempAssetDbPath = join(
        tempDir.path,
        'asset_reference_${DateTime.now().millisecondsSinceEpoch}.db',
      );
      await File(tempAssetDbPath).writeAsBytes(bytes);

      assetDb = await openDatabase(tempAssetDbPath, readOnly: true);

      var filled = 0;
      for (final row in rows) {
        final id = row['id'] as String;
        final assetRows = await assetDb.query(
          'documents',
          columns: ['content'],
          where: 'id = ? AND content IS NOT NULL',
          whereArgs: [id],
        );
        if (assetRows.isNotEmpty) {
          await liveDb.update(
            'documents',
            {'content': assetRows.first['content']},
            where: 'id = ?',
            whereArgs: [id],
          );
          filled++;
        }
      }
      print('✅ Backfill content da asset: $filled/${rows.length} documenti recuperati');
      PerformanceLogger.info('Backfill completato', details: '$filled/${rows.length} documenti');

    } catch (e) {
      // Non blocca l'avvio dell'app: i documenti rimasti senza content
      // segnaleranno l'errore solo quando l'utente prova ad aprirli.
      print('⚠️ Backfill content da asset fallito: $e');
      PerformanceLogger.error('Backfill fallito', error: e);
    } finally {
      if (assetDb != null) await assetDb.close();
      if (tempAssetDbPath != null) {
        final f = File(tempAssetDbPath);
        if (await f.exists()) await f.delete();
      }
      PerformanceLogger.stop('_backfillBlobContentFromAsset');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    PerformanceLogger.start('_onCreate');
    print('🔄 Creazione tabelle versione $version');
    await _createTables(db);
    await _createViews(db);
    print('✅ Tabelle e viste create');
    PerformanceLogger.stop('_onCreate');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    PerformanceLogger.start('_onUpgrade');
    print('🔄 Aggiornamento database da versione $oldVersion a $newVersion');

    if (oldVersion < 2) {
      // Esegui la migrazione per la nuova tabella event_song_documents
      await DatabaseMigration.runMigrations(db);
      // Crea le viste dopo la migrazione
      await _createViews(db);
    }

    if (oldVersion < 3) {
      // Aggiunge storage_mode/content/mime_type a documents per mxl/abc/mid/kar
      await DatabaseMigration.runBlobStorageMigration(db);
      // Il DB locale già installato sul dispositivo non ha mai avuto i file
      // originali: recupera il `content` mancante dal DB bundlato nella nuova
      // versione dell'asset (dove lo script di popolamento lo ha già scritto),
      // senza toccare il resto dei dati locali dell'utente.
      await _backfillBlobContentFromAsset(db);
    }

    if (oldVersion < 4) {
      // Aggiunge colonne di sync a registrations + tabella sync_log
      // (per la sincronizzazione delle iscrizioni col backend web)
      await DatabaseMigration.runRegistrationsSyncMigration(db);
    }

    PerformanceLogger.stop('_onUpgrade');
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        full_name TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'user',
        status TEXT NOT NULL DEFAULT 'active',
        profile_picture TEXT,
        bio TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        last_login TEXT,
        login_attempts INTEGER DEFAULT 0,
        locked_until TEXT,
        reset_token TEXT,
        reset_token_expiry TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        theme TEXT NOT NULL,
        description TEXT,
        image_url TEXT,
        date TEXT NOT NULL,
        location TEXT NOT NULL,
        category TEXT DEFAULT 'concerto',
        status TEXT DEFAULT 'published',
        capacity INTEGER DEFAULT 999,
        registration_deadline TEXT,
        difficulty TEXT DEFAULT 'intermediate',
        duration TEXT,
        contact_email TEXT,
        contact_phone TEXT,
        video_url TEXT,
        created_by TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS songs (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        composer TEXT,
        difficulty TEXT,
        genre TEXT,
        duration_seconds INTEGER,
        tempo INTEGER,
        key_signature TEXT,
        time_signature TEXT,
        lyrics TEXT,
        created_by TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS song_infos (
        id TEXT PRIMARY KEY,
        song_id TEXT NOT NULL,
        info_type TEXT NOT NULL,
        info_value TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS musical_documents (
        id TEXT PRIMARY KEY,
        song_id TEXT NOT NULL,
        doc_type TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_size INTEGER,
        mime_type TEXT,
        description TEXT,
        is_public BOOLEAN DEFAULT 1,
        uploaded_by TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS documents (
        id TEXT PRIMARY KEY,
        doc_type TEXT NOT NULL,
        file_name TEXT NOT NULL,
        storage_mode TEXT NOT NULL DEFAULT 'filesystem',
        content BLOB,
        file_path TEXT,
        file_size INTEGER,
        mime_type TEXT,
        description TEXT,
        is_public BOOLEAN DEFAULT 1,
        uploaded_by TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS song_documents (
        id TEXT PRIMARY KEY,
        song_id TEXT NOT NULL,
        document_id TEXT NOT NULL,
        order_index INTEGER DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE,
        FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE,
        UNIQUE(song_id, document_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS event_songs (
        id TEXT PRIMARY KEY,
        event_id TEXT NOT NULL,
        song_id TEXT NOT NULL,
        order_index INTEGER DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
        FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE,
        UNIQUE(event_id, song_id)
      )
    ''');

    // NUOVA TABELLA: event_song_documents
    await db.execute('''
      CREATE TABLE IF NOT EXISTS event_song_documents (
        id TEXT PRIMARY KEY,
        event_song_id TEXT NOT NULL,
        document_id TEXT NOT NULL,
        order_index INTEGER DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (event_song_id) REFERENCES event_songs(id) ON DELETE CASCADE,
        FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE,
        UNIQUE(event_song_id, document_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS instrument_parts (
        id TEXT PRIMARY KEY,
        song_id TEXT NOT NULL,
        instrument TEXT NOT NULL,
        part_content TEXT NOT NULL,
        difficulty TEXT DEFAULT 'intermediate',
        description TEXT,
        created_by TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // ═══════════════════════════════════════════════════════════════
    // TABELLA registrations - AGGIORNATA con colonne di sync
    // ═══════════════════════════════════════════════════════════════
    await db.execute('''
      CREATE TABLE IF NOT EXISTS registrations (
        id TEXT PRIMARY KEY,
        event_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        instrument_choice TEXT,
        reading_level INTEGER DEFAULT 1,
        improvisation_level INTEGER DEFAULT 1,
        selected_song_ids TEXT,
        notes TEXT,
        admin_notes TEXT,
        confirmed_at TEXT,
        cancelled_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        sync_state TEXT NOT NULL DEFAULT 'clean',
        last_pulled_at TEXT,
        last_pushed_at TEXT,
        remote_updated_at TEXT
      )
    ''');

    // ═══════════════════════════════════════════════════════════════
    // TABELLA sync_log - NUOVA
    // ═══════════════════════════════════════════════════════════════
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ts TEXT NOT NULL,
        direction TEXT NOT NULL,
        action TEXT NOT NULL,
        entity TEXT NOT NULL DEFAULT 'registrations',
        entity_id TEXT,
        detail TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS event_suggestions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        theme TEXT,
        suggested_date TEXT,
        suggested_location TEXT,
        category TEXT DEFAULT 'concerto',
        difficulty TEXT DEFAULT 'intermediate',
        status TEXT DEFAULT 'pending',
        admin_notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS image_suggestions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        event_id TEXT NOT NULL,
        image_url TEXT NOT NULL,
        description TEXT,
        source TEXT,
        status TEXT DEFAULT 'pending',
        admin_notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_feedback (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        event_id TEXT,
        rating INTEGER,
        comment TEXT,
        suggestions TEXT,
        status TEXT DEFAULT 'pending',
        admin_reply TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS activity_log (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        action TEXT NOT NULL,
        details TEXT,
        ip_address TEXT,
        user_agent TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS downloads (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        document_id TEXT NOT NULL,
        file_path TEXT,
        file_size INTEGER,
        download_date TEXT NOT NULL,
        last_accessed TEXT
      )
    ''');

    // Crea indici per performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_esd_event_song ON event_song_documents(event_song_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_esd_document ON event_song_documents(document_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_reg_status ON registrations(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_reg_sync_state ON registrations(sync_state)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_log_ts ON sync_log(ts)');
  }

  // ============================================
  // CREAZIONE VISTE
  // ============================================

  Future<void> _createViews(Database db) async {
    print('📋 Creazione viste...');

    // Vista: documenti per evento
    await db.execute('''
      DROP VIEW IF EXISTS v_event_documents
    ''');

    await db.execute('''
      CREATE VIEW v_event_documents AS
      SELECT 
        e.id AS event_id,
        e.title AS event_title,
        e.date AS event_date,
        e.location AS event_location,
        s.id AS song_id,
        s.title AS song_title,
        s.composer AS song_composer,
        d.id AS document_id,
        d.file_name AS document_name,
        d.doc_type AS document_type,
        d.file_path AS document_path,
        d.file_size AS document_size,
        d.description AS document_description,
        esd.id AS event_song_document_id,
        esd.order_index AS document_order,
        esd.notes AS document_notes,
        es.order_index AS song_order,
        'event_specific' AS document_source
      FROM events e
      JOIN event_songs es ON e.id = es.event_id
      JOIN songs s ON es.song_id = s.id
      JOIN event_song_documents esd ON es.id = esd.event_song_id
      JOIN documents d ON esd.document_id = d.id

      UNION ALL

      SELECT 
        e.id AS event_id,
        e.title AS event_title,
        e.date AS event_date,
        e.location AS event_location,
        s.id AS song_id,
        s.title AS song_title,
        s.composer AS song_composer,
        d.id AS document_id,
        d.file_name AS document_name,
        d.doc_type AS document_type,
        d.file_path AS document_path,
        d.file_size AS document_size,
        d.description AS document_description,
        NULL AS event_song_document_id,
        sd.order_index AS document_order,
        sd.notes AS document_notes,
        es.order_index AS song_order,
        'global' AS document_source
      FROM events e
      JOIN event_songs es ON e.id = es.event_id
      JOIN songs s ON es.song_id = s.id
      JOIN song_documents sd ON s.id = sd.song_id
      JOIN documents d ON sd.document_id = d.id
      WHERE NOT EXISTS (
        SELECT 1 
        FROM event_song_documents esd 
        WHERE esd.event_song_id = es.id 
        AND esd.document_id = d.id
      )
    ''');

    // Vista riassuntiva: conteggio documenti per evento e brano
    await db.execute('''
      DROP VIEW IF EXISTS v_event_documents_summary
    ''');

    await db.execute('''
      CREATE VIEW v_event_documents_summary AS
      SELECT 
        e.id AS event_id,
        e.title AS event_title,
        s.id AS song_id,
        s.title AS song_title,
        COUNT(DISTINCT d.id) AS total_documents,
        COUNT(DISTINCT CASE WHEN esd.id IS NOT NULL THEN d.id END) AS event_specific_documents,
        COUNT(DISTINCT CASE WHEN sd.id IS NOT NULL AND esd.id IS NULL THEN d.id END) AS global_documents,
        GROUP_CONCAT(DISTINCT d.doc_type) AS document_types,
        es.order_index AS song_order
      FROM events e
      JOIN event_songs es ON e.id = es.event_id
      JOIN songs s ON es.song_id = s.id
      LEFT JOIN song_documents sd ON s.id = sd.song_id
      LEFT JOIN documents d ON sd.document_id = d.id
      LEFT JOIN event_song_documents esd ON es.id = esd.event_song_id AND esd.document_id = d.id
      GROUP BY e.id, s.id
      ORDER BY e.date DESC, es.order_index ASC
    ''');

    print('✅ Viste create');
  }

  // ========== METODI UTILITY ==========

  String generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> getDatabasePath() async {
    if (_isWeb) {
      return 'musica_eventi_e_documenti.db (web)';
    }
    final appDocDir = await getApplicationDocumentsDirectory();
    return join(appDocDir.path, 'musica_eventi_e_documenti.db');
  }

  Future<String> getBackupDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(join(appDocDir.path, 'backup'));

    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
      print('📁 Cartella backup creata: ${backupDir.path}');
    }

    return backupDir.path;
  }

  Future<String> createBackup() async {
    try {
      final currentPath = await getDatabasePath();
      final file = File(currentPath);

      if (!await file.exists()) {
        print('⚠️ Database non trovato');
        return '';
      }

      final timestamp = DateTime.now().toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-')
          .substring(0, 19);

      final backupDirPath = await getBackupDirectory();
      final backupPath = join(backupDirPath, 'musica_per_tutti_backup_$timestamp.db');

      await file.copy(backupPath);
      print('✅ Backup creato: $backupPath');
      return backupPath;

    } catch (e) {
      print('❌ Errore creazione backup: $e');
      rethrow;
    }
  }

  Future<List<FileSystemEntity>> listBackups() async {
    try {
      final backupDirPath = await getBackupDirectory();
      final backupDir = Directory(backupDirPath);
      final backups = await backupDir.list().toList();
      return backups
          .where((file) => file.path.endsWith('.db'))
          .toList()
        ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    } catch (e) {
      print('❌ Errore lettura backup: $e');
      return [];
    }
  }

  Future<void> restoreFromBackup(String backupPath) async {
    try {
      final currentPath = await getDatabasePath();
      final file = File(backupPath);

      if (!await file.exists()) {
        throw Exception('File backup non trovato');
      }

      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      await file.copy(currentPath);
      print('✅ Database ripristinato da backup: $backupPath');

      _database = await openDatabase(
        currentPath,
        version: DB_VERSION,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) {
          print('✅ Database riaperto dopo ripristino');
        },
      );

    } catch (e) {
      print('❌ Errore ripristino backup: $e');
      rethrow;
    }
  }

  Future<void> exportDatabase(String exportPath) async {
    final currentPath = await getDatabasePath();
    final file = File(currentPath);
    if (await file.exists()) {
      await file.copy(exportPath);
      print('✅ Database esportato in: $exportPath');
    } else {
      throw Exception('Database non trovato');
    }
  }

  // ========== METODI PER LE VISTE ==========

  /// Ottiene tutti i documenti di un evento con dettagli (usa la vista)
  Future<List<Map<String, dynamic>>> getEventDocumentsWithDetails(String eventId) async {
    PerformanceLogger.start('getEventDocumentsWithDetails');
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT * FROM v_event_documents
        WHERE event_id = ?
        ORDER BY song_order ASC, document_order ASC
      ''', [eventId]);
      PerformanceLogger.info('Documenti evento con dettagli', details: '${result.length} documenti');
      PerformanceLogger.stop('getEventDocumentsWithDetails');
      return result;
    } catch (e) {
      PerformanceLogger.error('getEventDocumentsWithDetails fallito', error: e);
      return [];
    }
  }

  /// Ottiene il riepilogo dei documenti per evento
  Future<List<Map<String, dynamic>>> getEventDocumentsSummary(String eventId) async {
    PerformanceLogger.start('getEventDocumentsSummary');
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT * FROM v_event_documents_summary
        WHERE event_id = ?
        ORDER BY song_order ASC
      ''', [eventId]);
      PerformanceLogger.info('Riepilogo documenti evento', details: '${result.length} righe');
      PerformanceLogger.stop('getEventDocumentsSummary');
      return result;
    } catch (e) {
      PerformanceLogger.error('getEventDocumentsSummary fallito', error: e);
      return [];
    }
  }

  /// Ottiene tutti i documenti di un evento (raggruppati per brano)
  Future<Map<String, List<Map<String, dynamic>>>> getEventDocumentsGrouped(String eventId) async {
    PerformanceLogger.start('getEventDocumentsGrouped');
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT * FROM v_event_documents
        WHERE event_id = ?
        ORDER BY song_order ASC, document_order ASC
      ''', [eventId]);

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var row in result) {
        final songId = row['song_id'] as String;
        if (!grouped.containsKey(songId)) {
          grouped[songId] = [];
        }
        grouped[songId]!.add(row);
      }
      PerformanceLogger.info('Documenti raggruppati', details: '${grouped.length} brani');
      PerformanceLogger.stop('getEventDocumentsGrouped');
      return grouped;
    } catch (e) {
      PerformanceLogger.error('getEventDocumentsGrouped fallito', error: e);
      return {};
    }
  }

  // ========== METODI EVENTI ==========

  Future<List<Event>> getAllEvents() async {
    PerformanceLogger.start('getAllEvents');
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'events',
        orderBy: 'date DESC',
      );
      print('📊 Trovati ${maps.length} eventi');
      PerformanceLogger.info('Eventi trovati', details: '${maps.length} eventi');
      PerformanceLogger.stop('getAllEvents');
      return List.generate(maps.length, (i) {
        return Event.fromMap(maps[i]);
      });
    } catch (e) {
      print('❌ Errore in getAllEvents: $e');
      PerformanceLogger.error('getAllEvents fallito', error: e);
      return [];
    }
  }

  Future<Event?> getEventById(String id) async {
    PerformanceLogger.start('getEventById');
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'events',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        PerformanceLogger.stop('getEventById');
        return Event.fromMap(maps.first);
      }
      PerformanceLogger.stop('getEventById');
      return null;
    } catch (e) {
      print('❌ Errore in getEventById: $e');
      PerformanceLogger.error('getEventById fallito', error: e);
      return null;
    }
  }

  Future<void> insertEvent(Event event) async {
    PerformanceLogger.start('insertEvent');
    try {
      final db = await database;
      await db.insert(
        'events',
        event.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✅ Evento inserito: ${event.title}');
      PerformanceLogger.info('Evento inserito', details: event.title);
      PerformanceLogger.stop('insertEvent');
    } catch (e) {
      PerformanceLogger.error('insertEvent fallito', error: e);
      rethrow;
    }
  }

  Future<void> updateEvent(Event event) async {
    PerformanceLogger.start('updateEvent');
    try {
      final db = await database;
      await db.update(
        'events',
        event.toMap(),
        where: 'id = ?',
        whereArgs: [event.id],
      );
      print('✅ Evento aggiornato: ${event.title}');
      PerformanceLogger.info('Evento aggiornato', details: event.title);
      PerformanceLogger.stop('updateEvent');
    } catch (e) {
      PerformanceLogger.error('updateEvent fallito', error: e);
      rethrow;
    }
  }

  Future<void> deleteEvent(String id) async {
    PerformanceLogger.start('deleteEvent');
    try {
      final db = await database;
      await db.delete(
        'events',
        where: 'id = ?',
        whereArgs: [id],
      );
      print('🗑️ Evento eliminato: $id');
      PerformanceLogger.stop('deleteEvent');
    } catch (e) {
      PerformanceLogger.error('deleteEvent fallito', error: e);
      rethrow;
    }
  }

  // ========== METODI CANZONI ==========

  Future<List<Song>> getAllSongs() async {
    PerformanceLogger.start('getAllSongs');
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'songs',
        orderBy: 'title ASC',
      );
      PerformanceLogger.info('Canzoni trovate', details: '${maps.length} canzoni');
      PerformanceLogger.stop('getAllSongs');
      return List.generate(maps.length, (i) {
        return Song.fromMap(maps[i]);
      });
    } catch (e) {
      PerformanceLogger.error('getAllSongs fallito', error: e);
      return [];
    }
  }

  Future<void> insertSong(Song song) async {
    PerformanceLogger.start('insertSong');
    try {
      final db = await database;
      await db.insert('songs', song.toMap());
      print('✅ Brano inserito: ${song.title}');
      PerformanceLogger.stop('insertSong');
    } catch (e) {
      PerformanceLogger.error('insertSong fallito', error: e);
      rethrow;
    }
  }

  Future<void> updateSong(Song song) async {
    PerformanceLogger.start('updateSong');
    try {
      final db = await database;

      // 🔥 Verifica che il brano esista prima di aggiornarlo
      final existing = await db.query(
        'songs',
        where: 'id = ?',
        whereArgs: [song.id],
      );

      if (existing.isEmpty) {
        print('⚠️ Brano con ID ${song.id} non trovato! Inserisco come nuovo...');
        await db.insert('songs', song.toMap());
        print('✅ Brano inserito (era mancante): ${song.title}');
        PerformanceLogger.stop('updateSong');
        return;
      }

      // 🔥 Salva le relazioni esistenti PRIMA dell'aggiornamento
      final eventRelations = await db.query(
        'event_songs',
        where: 'song_id = ?',
        whereArgs: [song.id],
      );

      final docRelations = await db.query(
        'song_documents',
        where: 'song_id = ?',
        whereArgs: [song.id],
      );

      print('📊 Relazioni esistenti - Eventi: ${eventRelations.length}, Documenti: ${docRelations.length}');

      // 🔥 Aggiorna il brano
      await db.update(
        'songs',
        song.toMap(),
        where: 'id = ?',
        whereArgs: [song.id],
      );

      // 🔥 Verifica che le relazioni siano ancora intatte
      final afterEventRelations = await db.query(
        'event_songs',
        where: 'song_id = ?',
        whereArgs: [song.id],
      );

      final afterDocRelations = await db.query(
        'song_documents',
        where: 'song_id = ?',
        whereArgs: [song.id],
      );

      print('📊 Relazioni dopo aggiornamento - Eventi: ${afterEventRelations.length}, Documenti: ${afterDocRelations.length}');

      // 🔥 Se le relazioni sono state perse, ripristinale!
      if (afterEventRelations.isEmpty && eventRelations.isNotEmpty) {
        print('⚠️ RELAZIONI EVENTO PERSATE! Ripristino...');
        for (var rel in eventRelations) {
          await db.insert('event_songs', rel);
        }
        print('✅ Relazioni evento ripristinate: ${eventRelations.length}');
      }

      if (afterDocRelations.isEmpty && docRelations.isNotEmpty) {
        print('⚠️ RELAZIONI DOCUMENTI PERSATE! Ripristino...');
        for (var rel in docRelations) {
          await db.insert('song_documents', rel);
        }
        print('✅ Relazioni documenti ripristinate: ${docRelations.length}');
      }

      print('✅ Brano aggiornato: ${song.title} (ID: ${song.id})');
      PerformanceLogger.info('Brano aggiornato', details: '${song.title} - ID: ${song.id}');
      PerformanceLogger.stop('updateSong');

    } catch (e) {
      PerformanceLogger.error('updateSong fallito', error: e);
      print('❌ Errore updateSong: $e');
      rethrow;
    }
  }

  Future<void> deleteSong(String id) async {
    PerformanceLogger.start('deleteSong');
    try {
      final db = await database;
      await db.delete(
        'event_songs',
        where: 'song_id = ?',
        whereArgs: [id],
      );
      await db.delete(
        'songs',
        where: 'id = ?',
        whereArgs: [id],
      );
      print('🗑️ Brano eliminato: $id');
      PerformanceLogger.stop('deleteSong');
    } catch (e) {
      PerformanceLogger.error('deleteSong fallito', error: e);
      rethrow;
    }
  }

  // 🔥 NUOVO METODO: Ottiene le relazioni di un brano (eventi e documenti associati)
  /// Ottiene le relazioni di un brano (eventi e documenti associati)
  Future<Map<String, dynamic>> getSongRelations(String songId) async {
    PerformanceLogger.start('getSongRelations');
    try {
      final db = await database;

      // Eventi associati
      final events = await db.rawQuery('''
        SELECT e.id, e.title, e.date, e.location
        FROM events e
        JOIN event_songs es ON e.id = es.event_id
        WHERE es.song_id = ?
      ''', [songId]);

      // Documenti associati
      final documents = await db.rawQuery('''
        SELECT d.id, d.file_name, d.doc_type
        FROM documents d
        JOIN song_documents sd ON d.id = sd.document_id
        WHERE sd.song_id = ?
      ''', [songId]);

      final result = {
        'song_id': songId,
        'events': events,
        'documents': documents,
        'event_count': events.length,
        'document_count': documents.length,
      };

      PerformanceLogger.info('Relazioni brano', details: 'Eventi: ${events.length}, Documenti: ${documents.length}');
      PerformanceLogger.stop('getSongRelations');
      return result;
    } catch (e) {
      PerformanceLogger.error('getSongRelations fallito', error: e);
      return {'song_id': songId, 'error': e.toString()};
    }
  }

  // ========== METODI SONG EVENTI ==========

  Future<void> addSongToEvent(String eventId, String songId, {int orderIndex = 0}) async {
    PerformanceLogger.start('addSongToEvent');
    try {
      final db = await database;

      final existing = await db.query(
        'event_songs',
        where: 'event_id = ? AND song_id = ?',
        whereArgs: [eventId, songId],
      );

      if (existing.isNotEmpty) {
        print('ℹ️ Canzone già associata all\'evento');
        PerformanceLogger.stop('addSongToEvent');
        return;
      }

      final eventSong = EventSong(
        id: generateId(),
        eventId: eventId,
        songId: songId,
        orderIndex: orderIndex,
        createdAt: DateTime.now().toIso8601String(),
      );

      await db.insert('event_songs', eventSong.toMap());
      print('✅ Canzone associata all\'evento: $songId → $eventId');
      PerformanceLogger.stop('addSongToEvent');
    } catch (e) {
      PerformanceLogger.error('addSongToEvent fallito', error: e);
      rethrow;
    }
  }

  Future<void> removeSongFromEvent(String eventId, String songId) async {
    PerformanceLogger.start('removeSongFromEvent');
    try {
      final db = await database;
      await db.delete(
        'event_songs',
        where: 'event_id = ? AND song_id = ?',
        whereArgs: [eventId, songId],
      );
      print('🗑️ Canzone rimossa dall\'evento');
      PerformanceLogger.stop('removeSongFromEvent');
    } catch (e) {
      PerformanceLogger.error('removeSongFromEvent fallito', error: e);
      rethrow;
    }
  }

  Future<List<Song>> getSongsByEvent(String eventId) async {
    PerformanceLogger.start('getSongsByEvent');
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT s.* 
      FROM songs s
      INNER JOIN event_songs es ON s.id = es.song_id
      WHERE es.event_id = ?
      ORDER BY es.order_index ASC, s.title ASC
    ''', [eventId]);

      final songs = List.generate(maps.length, (i) {
        return Song.fromMap(maps[i]);
      });
      PerformanceLogger.info('Canzoni per evento', details: '${songs.length} canzoni');
      PerformanceLogger.stop('getSongsByEvent');
      return songs;
    } catch (e) {
      PerformanceLogger.error('getSongsByEvent fallito', error: e);
      return [];
    }
  }

  Future<List<Event>> getEventsBySong(String songId) async {
    PerformanceLogger.start('getEventsBySong');
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT e.* 
      FROM events e
      INNER JOIN event_songs es ON e.id = es.event_id
      WHERE es.song_id = ?
      ORDER BY e.date DESC
    ''', [songId]);

      final events = List.generate(maps.length, (i) {
        return Event.fromMap(maps[i]);
      });
      PerformanceLogger.info('Eventi per canzone', details: '${events.length} eventi');
      PerformanceLogger.stop('getEventsBySong');
      return events;
    } catch (e) {
      PerformanceLogger.error('getEventsBySong fallito', error: e);
      return [];
    }
  }

  Future<void> updateSongOrder(String eventId, String songId, int orderIndex) async {
    PerformanceLogger.start('updateSongOrder');
    try {
      final db = await database;
      await db.update(
        'event_songs',
        {'order_index': orderIndex, 'updated_at': DateTime.now().toIso8601String()},
        where: 'event_id = ? AND song_id = ?',
        whereArgs: [eventId, songId],
      );
      PerformanceLogger.stop('updateSongOrder');
    } catch (e) {
      PerformanceLogger.error('updateSongOrder fallito', error: e);
      rethrow;
    }
  }

  Future<Song?> getSongById(String id) async {
    PerformanceLogger.start('getSongById');
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'songs',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        PerformanceLogger.stop('getSongById');
        return Song.fromMap(maps.first);
      }
      PerformanceLogger.stop('getSongById');
      return null;
    } catch (e) {
      PerformanceLogger.error('getSongById fallito', error: e);
      return null;
    }
  }

  // ========== METODI ISCRIZIONE ==========

  Future<List<Registration>> getRegistrationsByEvent(String eventId) async {
    PerformanceLogger.start('getRegistrationsByEvent');
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'registrations',
        where: 'event_id = ?',
        whereArgs: [eventId],
      );
      final registrations = List.generate(maps.length, (i) {
        return Registration.fromMap(maps[i]);
      });
      PerformanceLogger.info('Iscrizioni per evento', details: '${registrations.length} iscrizioni');
      PerformanceLogger.stop('getRegistrationsByEvent');
      return registrations;
    } catch (e) {
      PerformanceLogger.error('getRegistrationsByEvent fallito', error: e);
      return [];
    }
  }

  Future<Map<String, int>> getDocumentsCountBySong() async {
    PerformanceLogger.start('getDocumentsCountBySong');
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 
        sd.song_id,
        COUNT(DISTINCT sd.document_id) as count
      FROM song_documents sd
      GROUP BY sd.song_id
    ''');

      final Map<String, int> countMap = {};
      for (var row in result) {
        countMap[row['song_id'] as String] = row['count'] as int;
      }
      PerformanceLogger.info('Conteggio documenti per canzone', details: '${countMap.length} canzoni');
      PerformanceLogger.stop('getDocumentsCountBySong');
      return countMap;
    } catch (e) {
      PerformanceLogger.error('getDocumentsCountBySong fallito', error: e);
      return {};
    }
  }

  Future<Map<String, List<String>>> getInstrumentsBySongForEvent(String eventId) async {
    PerformanceLogger.start('getInstrumentsBySongForEvent');
    try {
      final db = await database;
      final registrations = await getRegistrationsByEvent(eventId);

      final Map<String, List<String>> result = {};

      for (var reg in registrations) {
        if (reg.selectedSongIds != null && reg.selectedSongIds!.isNotEmpty) {
          final songIds = reg.selectedSongIds!.split(',');
          for (var songId in songIds) {
            if (!result.containsKey(songId)) {
              result[songId] = [];
            }
            if (reg.instrumentChoice != null) {
              result[songId]!.add(reg.instrumentChoice!);
            }
          }
        }
      }
      PerformanceLogger.info('Strumenti per canzone', details: '${result.length} canzoni');
      PerformanceLogger.stop('getInstrumentsBySongForEvent');
      return result;
    } catch (e) {
      PerformanceLogger.error('getInstrumentsBySongForEvent fallito', error: e);
      return {};
    }
  }

  Future<Map<String, int>> getRegistrationsCountBySongForEvent(String eventId) async {
    PerformanceLogger.start('getRegistrationsCountBySongForEvent');
    try {
      final db = await database;

      final registrations = await db.query(
        'registrations',
        where: 'event_id = ? AND status = ?',
        whereArgs: [eventId, 'confirmed'],
      );

      final Map<String, int> result = {};

      for (var reg in registrations) {
        final selectedSongIds = reg['selected_song_ids'] as String?;
        if (selectedSongIds != null && selectedSongIds.isNotEmpty) {
          final songIds = selectedSongIds.split(',');
          for (var songId in songIds) {
            result[songId] = (result[songId] ?? 0) + 1;
          }
        }
      }
      PerformanceLogger.info('Conteggio iscrizioni per canzone', details: '${result.length} canzoni');
      PerformanceLogger.stop('getRegistrationsCountBySongForEvent');
      return result;
    } catch (e) {
      PerformanceLogger.error('getRegistrationsCountBySongForEvent fallito', error: e);
      return {};
    }
  }

  // ========== METODI DOCUMENTI ==========

  Future<List<Document>> getAllDocuments() async {
    PerformanceLogger.start('getAllDocuments');
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
          'documents',
          columns: ['id', 'doc_type', 'file_name', 'file_path', 'file_size', 'mime_type', 'description', 'storage_mode', 'is_public', 'uploaded_by', 'created_at', 'updated_at'] // 🔥 NO content!
      );
      final documents = List.generate(maps.length, (i) {
        return Document.fromMap(maps[i]);
      });
      PerformanceLogger.info('Tutti i documenti', details: '${documents.length} documenti');
      PerformanceLogger.stop('getAllDocuments');
      return documents;
    } catch (e) {
      PerformanceLogger.error('getAllDocuments fallito', error: e);
      return [];
    }
  }

  Future<Document?> getDocumentById(String id) async {
    PerformanceLogger.start('getDocumentById');
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'documents',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        PerformanceLogger.stop('getDocumentById');
        return Document.fromMap(maps.first);
      }
      PerformanceLogger.stop('getDocumentById');
      return null;
    } catch (e) {
      PerformanceLogger.error('getDocumentById fallito', error: e);
      return null;
    }
  }
  /// Ritorna un documento includendo il campo `content` (BLOB).
  /// Usato per il retry di push al web (che richiede il BLOB).
  Future<Document?> getDocumentByIdWithContent(String id) async {
    try {
      final db = await database;
      final maps = await db.query(
        'documents',
        where: 'id = ?',
        whereArgs: [id],
        // include TUTTE le colonne, incluso content
      );
      if (maps.isEmpty) return null;
      return Document.fromMap(maps.first);
    } catch (e) {
      print('❌ getDocumentByIdWithContent fallito: $e');
      return null;
    }
  }

  Future<void> insertDocument(Document document) async {
    PerformanceLogger.start('insertDocument');
    try {
      final db = await database;
      final Map<String, dynamic> documentMap = document.toMap();
      final dynamic songId = documentMap.remove('song_id');
      documentMap.remove('songId');

      await db.insert('documents', documentMap);

      if (songId != null && songId.toString().isNotEmpty) {
        final existing = await db.query(
          'song_documents',
          where: 'document_id = ? AND song_id = ?',
          whereArgs: [document.id, songId.toString()],
        );

        if (existing.isEmpty) {
          await db.insert('song_documents', {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'document_id': document.id,
            'song_id': songId.toString(),
            'order_index': 0,
            'notes': null,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': null,
          });
        }
      }

      print('✅ Documento inserito: ${document.fileName}');
      PerformanceLogger.info('Documento inserito', details: document.fileName);
      PerformanceLogger.stop('insertDocument');

      // ─── NUOVO: PUSH AL WEB (fire and forget) ─────────────────────
      _pushDocumentToWeb(document, songId?.toString()).catchError((e) {
        print('⚠️ Push documento al web fallito: $e');
      });
    } catch (e) {
      PerformanceLogger.error('insertDocument fallito', error: e);
      rethrow;
    }
  }

  /// Pusha il documento al backend web in background.
  /// Se fallisce, lo aggiunge a pending_uploads.json per un retry successivo.
  Future<void> _pushDocumentToWeb(Document doc, String? songId) async {
    final songIds = <String>[];
    if (songId != null && songId.isNotEmpty) {
      songIds.add(songId);
    }

    final ok = await DocumentPushService.pushDocument(doc, songIds: songIds);

    if (ok) {
      // Se era in pending (es. retry), rimuovilo
      await PendingUploadsService.remove(doc.id);
    } else {
      // Salva in pending per retry
      await PendingUploadsService.add(doc.id, doc.filePath ?? '');
      print('📝 Documento salvato in pending_uploads: ${doc.id}');
    }
  }

  Future<void> updateDocument(Document document) async {
    PerformanceLogger.start('updateDocument');
    try {
      final db = await database;
      await db.update(
        'documents',
        document.toMap(),
        where: 'id = ?',
        whereArgs: [document.id],
      );
      print('✅ Documento aggiornato: ${document.fileName}');
      PerformanceLogger.info('Documento aggiornato', details: document.fileName);
      PerformanceLogger.stop('updateDocument');
    } catch (e) {
      PerformanceLogger.error('updateDocument fallito', error: e);
      rethrow;
    }
  }

  Future<void> deleteDocument(String id) async {
    PerformanceLogger.start('deleteDocument');
    try {
      final db = await database;
      await db.delete(
        'song_documents',
        where: 'document_id = ?',
        whereArgs: [id],
      );
      await db.delete(
        'documents',
        where: 'id = ?',
        whereArgs: [id],
      );
      print('🗑️ Documento eliminato: $id');
      PerformanceLogger.stop('deleteDocument');
    } catch (e) {
      PerformanceLogger.error('deleteDocument fallito', error: e);
      rethrow;
    }
  }

  // ========== METODI RELAZIONE DOCUMENTO-BRANO ==========

  Future<void> addDocumentToSong(String documentId, String songId, {int orderIndex = 0}) async {
    PerformanceLogger.start('addDocumentToSong');
    try {
      final db = await database;
      final existing = await db.query(
        'song_documents',
        where: 'document_id = ? AND song_id = ?',
        whereArgs: [documentId, songId],
      );
      if (existing.isNotEmpty) {
        print('ℹ️ Documento già associato al brano');
        PerformanceLogger.stop('addDocumentToSong');
        return;
      }
      final id = generateId();
      await db.insert('song_documents', {
        'id': id,
        'document_id': documentId,
        'song_id': songId,
        'order_index': orderIndex,
        'created_at': DateTime.now().toIso8601String(),
      });
      print('✅ Documento associato al brano');
      PerformanceLogger.stop('addDocumentToSong');
    } catch (e) {
      PerformanceLogger.error('addDocumentToSong fallito', error: e);
      rethrow;
    }
  }

  Future<void> removeDocumentFromSong(String documentId, String songId) async {
    PerformanceLogger.start('removeDocumentFromSong');
    try {
      final db = await database;
      await db.delete(
        'song_documents',
        where: 'document_id = ? AND song_id = ?',
        whereArgs: [documentId, songId],
      );
      print('🗑️ Documento rimosso dal brano');
      PerformanceLogger.stop('removeDocumentFromSong');
    } catch (e) {
      PerformanceLogger.error('removeDocumentFromSong fallito', error: e);
      rethrow;
    }
  }

  Future<List<Document>> getDocumentsBySong(String songId) async {
    PerformanceLogger.start('getDocumentsBySong');
    try {
      final db = await database;

      // 🔥 IMPORTANTE: NON leggere il BLOB (content) in questa query!
      // Su Android, un BLOB grande non entra nella CursorWindow e causa errore.
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT d.id, d.doc_type, d.file_name, d.file_path, d.file_size, d.mime_type, 
             d.description, d.storage_mode, d.is_public, d.uploaded_by, d.created_at, d.updated_at
      FROM documents d
      INNER JOIN song_documents sd ON d.id = sd.document_id
      WHERE sd.song_id = ?
      ORDER BY sd.order_index ASC, d.file_name ASC
    ''', [songId]);

      final documents = List.generate(maps.length, (i) {
        return Document.fromMap(maps[i]);
      });
      PerformanceLogger.info('Documenti per brano', details: '${documents.length} documenti');
      PerformanceLogger.stop('getDocumentsBySong');
      return documents;
    } catch (e) {
      PerformanceLogger.error('getDocumentsBySong fallito', error: e);
      return [];
    }
  }

  Future<List<Document>> getDocumentsByType(String docType) async {
    PerformanceLogger.start('getDocumentsByType');
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'documents',
        where: 'doc_type = ?',
        whereArgs: [docType],
        orderBy: 'file_name ASC',
      );
      final documents = List.generate(maps.length, (i) {
        return Document.fromMap(maps[i]);
      });
      PerformanceLogger.info('Documenti per tipo', details: '$docType - ${documents.length} documenti');
      PerformanceLogger.stop('getDocumentsByType');
      return documents;
    } catch (e) {
      PerformanceLogger.error('getDocumentsByType fallito', error: e);
      return [];
    }
  }

  // ========== METODI EVENT_SONG_DOCUMENTS (NUOVI) ==========

  /// Ottiene l'event_song_id per un evento e un brano
  Future<String?> getEventSongId(String eventId, String songId) async {
    PerformanceLogger.start('getEventSongId');
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.query(
        'event_songs',
        where: 'event_id = ? AND song_id = ?',
        whereArgs: [eventId, songId],
        limit: 1,
      );
      if (result.isEmpty) {
        PerformanceLogger.stop('getEventSongId');
        return null;
      }
      PerformanceLogger.stop('getEventSongId');
      return result.first['id'] as String;
    } catch (e) {
      PerformanceLogger.error('getEventSongId fallito', error: e);
      return null;
    }
  }

  /// Ottiene i documenti specifici per un evento-brano
  Future<List<EventSongDocument>> getDocumentsForEventSong(String eventSongId) async {
    PerformanceLogger.start('getDocumentsForEventSong');
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'event_song_documents',
        where: 'event_song_id = ?',
        whereArgs: [eventSongId],
        orderBy: 'order_index ASC',
      );
      final documents = List.generate(maps.length, (i) {
        return EventSongDocument.fromMap(maps[i]);
      });
      PerformanceLogger.info('Documenti per evento-brano', details: '${documents.length} documenti');
      PerformanceLogger.stop('getDocumentsForEventSong');
      return documents;
    } catch (e) {
      PerformanceLogger.error('getDocumentsForEventSong fallito', error: e);
      return [];
    }
  }

  /// Aggiunge un documento a un evento-brano
  Future<void> addDocumentToEventSong(String eventSongId, String documentId, {int orderIndex = 0, String? notes}) async {
    PerformanceLogger.start('addDocumentToEventSong');
    try {
      final db = await database;
      final id = generateId();
      await db.insert(
        'event_song_documents',
        {
          'id': id,
          'event_song_id': eventSongId,
          'document_id': documentId,
          'order_index': orderIndex,
          'notes': notes,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✅ Documento aggiunto a evento-brano');
      PerformanceLogger.stop('addDocumentToEventSong');
    } catch (e) {
      PerformanceLogger.error('addDocumentToEventSong fallito', error: e);
      rethrow;
    }
  }

  /// Rimuove un documento da un evento-brano
  Future<void> removeDocumentFromEventSong(String eventSongId, String documentId) async {
    PerformanceLogger.start('removeDocumentFromEventSong');
    try {
      final db = await database;
      await db.delete(
        'event_song_documents',
        where: 'event_song_id = ? AND document_id = ?',
        whereArgs: [eventSongId, documentId],
      );
      print('🗑️ Documento rimosso da evento-brano');
      PerformanceLogger.stop('removeDocumentFromEventSong');
    } catch (e) {
      PerformanceLogger.error('removeDocumentFromEventSong fallito', error: e);
      rethrow;
    }
  }

  /// Ottiene i documenti di un evento-brano con i dettagli del documento
  Future<List<Map<String, dynamic>>> getEventSongDocumentsWithDetails(String eventSongId) async {
    PerformanceLogger.start('getEventSongDocumentsWithDetails');
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT 
          esd.*,
          d.id as document_id,
          d.file_name,
          d.doc_type,
          d.file_path,
          d.file_size,
          d.description,
          d.is_public
        FROM event_song_documents esd
        LEFT JOIN documents d ON esd.document_id = d.id
        WHERE esd.event_song_id = ?
        ORDER BY esd.order_index ASC
      ''', [eventSongId]);

      PerformanceLogger.info('Documenti evento-brano con dettagli', details: '${result.length} documenti');
      PerformanceLogger.stop('getEventSongDocumentsWithDetails');
      return result;
    } catch (e) {
      PerformanceLogger.error('getEventSongDocumentsWithDetails fallito', error: e);
      return [];
    }
  }

  /// Conta, per ogni event_song di un evento, quanti documenti specifici
  /// sono assegnati (da event_song_documents). Ritorna una mappa
  /// songId -> conteggio.
  Future<Map<String, int>> getEventSongDocumentsCountForEvent(String eventId) async {
    PerformanceLogger.start('getEventSongDocumentsCountForEvent');
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT es.song_id AS song_id, COUNT(esd.id) AS count
        FROM event_songs es
        LEFT JOIN event_song_documents esd ON es.id = esd.event_song_id
        WHERE es.event_id = ?
        GROUP BY es.song_id
      ''', [eventId]);

      final Map<String, int> countMap = {};
      for (var row in result) {
        final songId = row['song_id'] as String?;
        final count = (row['count'] as int?) ?? 0;
        if (songId != null) {
          countMap[songId] = count;
        }
      }
      PerformanceLogger.info('Conteggio documenti per event-song',
          details: '${countMap.length} brani');
      PerformanceLogger.stop('getEventSongDocumentsCountForEvent');
      return countMap;
    } catch (e) {
      PerformanceLogger.error('getEventSongDocumentsCountForEvent fallito', error: e);
      return {};
    }
  }
  /// Ottiene tutti i documenti di un evento (raggruppati per brano) - usa la vista
  Future<Map<String, List<Map<String, dynamic>>>> getDocumentsByEvent(String eventId) async {
    return getEventDocumentsGrouped(eventId);
  }

  /// Ottiene i documenti di un evento per un brano specifico
  Future<List<Map<String, dynamic>>> getDocumentsForEventAndSong(String eventId, String songId) async {
    PerformanceLogger.start('getDocumentsForEventAndSong');
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT 
          esd.*,
          d.id as document_id,
          d.file_name,
          d.doc_type,
          d.file_path,
          d.file_size,
          d.description,
          d.is_public
        FROM event_songs es
        LEFT JOIN event_song_documents esd ON es.id = esd.event_song_id
        LEFT JOIN documents d ON esd.document_id = d.id
        WHERE es.event_id = ? AND es.song_id = ?
        ORDER BY esd.order_index ASC
      ''', [eventId, songId]);

      PerformanceLogger.info('Documenti per evento e brano', details: '${result.length} documenti');
      PerformanceLogger.stop('getDocumentsForEventAndSong');
      return result;
    } catch (e) {
      PerformanceLogger.error('getDocumentsForEventAndSong fallito', error: e);
      return [];
    }
  }

  /// Collega un documento (esistente o appena creato) a un evento-brano.
  Future<void> insertEventSongDocument({
    required String eventSongId,
    required String documentId,
    int orderIndex = 0,
    String? notes,
  }) async {
    PerformanceLogger.start('insertEventSongDocument');
    try {
      final db = await database;
      await db.insert(
        'event_song_documents',
        {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'event_song_id': eventSongId,
          'document_id': documentId,
          'order_index': orderIndex,
          'notes': notes,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': null,
        },
      );
      print('🔗 Documento $documentId collegato a evento-brano $eventSongId');
      PerformanceLogger.stop('insertEventSongDocument');
    } catch (e) {
      PerformanceLogger.error('insertEventSongDocument fallito', error: e);
      rethrow;
    }
  }

  /// Aggiorna l'ordine di un documento in un evento-brano
  Future<void> updateEventSongDocumentOrder(String eventSongDocumentId, int orderIndex) async {
    PerformanceLogger.start('updateEventSongDocumentOrder');
    try {
      final db = await database;
      await db.update(
        'event_song_documents',
        {'order_index': orderIndex, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [eventSongDocumentId],
      );
      PerformanceLogger.stop('updateEventSongDocumentOrder');
    } catch (e) {
      PerformanceLogger.error('updateEventSongDocumentOrder fallito', error: e);
      rethrow;
    }
  }

  /// Elimina tutti i documenti di un evento-brano
  Future<void> clearDocumentsFromEventSong(String eventSongId) async {
    PerformanceLogger.start('clearDocumentsFromEventSong');
    try {
      final db = await database;
      await db.delete(
        'event_song_documents',
        where: 'event_song_id = ?',
        whereArgs: [eventSongId],
      );
      print('🗑️ Tutti i documenti rimossi da evento-brano');
      PerformanceLogger.stop('clearDocumentsFromEventSong');
    } catch (e) {
      PerformanceLogger.error('clearDocumentsFromEventSong fallito', error: e);
      rethrow;
    }
  }

  // ========== METODI REGISTRAZIONI ==========

  Future<List<Registration>> getAllRegistrations() async {
    PerformanceLogger.start('getAllRegistrations');
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'registrations',
        orderBy: 'created_at DESC',
      );
      final registrations = List.generate(maps.length, (i) {
        return Registration.fromMap(maps[i]);
      });
      PerformanceLogger.info('Tutte le iscrizioni', details: '${registrations.length} iscrizioni');
      PerformanceLogger.stop('getAllRegistrations');
      return registrations;
    } catch (e) {
      PerformanceLogger.error('getAllRegistrations fallito', error: e);
      return [];
    }
  }

  Future<int> countRegistrationsByEvent(String eventId) async {
    PerformanceLogger.start('countRegistrationsByEvent');
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM registrations WHERE event_id = ?',
        [eventId],
      );
      final count = Sqflite.firstIntValue(result) ?? 0;
      PerformanceLogger.stop('countRegistrationsByEvent');
      return count;
    } catch (e) {
      PerformanceLogger.error('countRegistrationsByEvent fallito', error: e);
      return 0;
    }
  }

  Future<bool> isAlreadyRegistered(String eventId, String userId) async {
    PerformanceLogger.start('isAlreadyRegistered');
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'registrations',
        where: 'event_id = ? AND user_id = ?',
        whereArgs: [eventId, userId],
      );
      final registered = maps.isNotEmpty;
      PerformanceLogger.stop('isAlreadyRegistered');
      return registered;
    } catch (e) {
      PerformanceLogger.error('isAlreadyRegistered fallito', error: e);
      return false;
    }
  }

  Future<void> insertRegistration(Registration registration) async {
    PerformanceLogger.start('insertRegistration');
    try {
      final db = await database;
      await db.insert(
        'registrations',
        registration.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      PerformanceLogger.stop('insertRegistration');
    } catch (e) {
      PerformanceLogger.error('insertRegistration fallito', error: e);
      rethrow;
    }
  }

  Future<void> updateRegistrationStatus(String id, String status) async {
    PerformanceLogger.start('updateRegistrationStatus');
    try {
      final db = await database;
      await db.update(
        'registrations',
        {'status': status, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      PerformanceLogger.stop('updateRegistrationStatus');
    } catch (e) {
      PerformanceLogger.error('updateRegistrationStatus fallito', error: e);
      rethrow;
    }
  }

  Future<void> deleteRegistration(String id) async {
    PerformanceLogger.start('deleteRegistration');
    try {
      final db = await database;
      await db.delete(
        'registrations',
        where: 'id = ?',
        whereArgs: [id],
      );
      PerformanceLogger.stop('deleteRegistration');
    } catch (e) {
      PerformanceLogger.error('deleteRegistration fallito', error: e);
      rethrow;
    }
  }

  // ========== METODI SYNC REGISTRAZIONI (NUOVI) ==========

  /// Inserisce una registrazione solo se non esiste già (per id).
  /// Ritorna `true` se ha inserito, `false` se esisteva già.
  /// Idempotente: puoi chiamarlo N volte con lo stesso input.
  Future<bool> insertRegistrationIfAbsent(Registration r) async {
    PerformanceLogger.start('insertRegistrationIfAbsent');
    try {
      final db = await database;
      final now = DateTime.now().toUtc().toIso8601String();

      final rowId = await db.rawInsert('''
        INSERT OR IGNORE INTO registrations (
          id, event_id, user_id, status,
          instrument_choice, reading_level, improvisation_level,
          selected_song_ids, notes, admin_notes,
          confirmed_at, cancelled_at,
          created_at, updated_at,
          sync_state, last_pulled_at, remote_updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'clean', ?, ?)
      ''', [
        r.id,
        r.eventId,
        r.userId,
        r.status,
        r.instrumentChoice,
        r.readingLevel,
        r.improvisationLevel,
        r.selectedSongIds,
        r.notes,
        r.adminNotes,
        r.confirmedAt,
        r.cancelledAt,
        r.createdAt,
        r.updatedAt,
        now,          // last_pulled_at
        r.updatedAt,  // remote_updated_at
      ]);

      final inserted = rowId > 0;
      PerformanceLogger.info(
        'insertRegistrationIfAbsent',
        details: inserted ? 'inserito ${r.id}' : 'già presente ${r.id}',
      );
      PerformanceLogger.stop('insertRegistrationIfAbsent');
      return inserted;
    } catch (e) {
      PerformanceLogger.error('insertRegistrationIfAbsent fallito', error: e);
      rethrow;
    }
  }

  /// Ritorna le registrazioni modificate localmente e non ancora pushate.
  Future<List<Registration>> getDirtyRegistrations() async {
    PerformanceLogger.start('getDirtyRegistrations');
    try {
      final db = await database;
      final rows = await db.query(
        'registrations',
        where: "sync_state = 'dirty'",
        orderBy: 'updated_at ASC',
      );
      final result = rows.map((m) => Registration.fromMap(m)).toList();
      PerformanceLogger.info('Dirty registrations', details: '${result.length}');
      PerformanceLogger.stop('getDirtyRegistrations');
      return result;
    } catch (e) {
      PerformanceLogger.error('getDirtyRegistrations fallito', error: e);
      return [];
    }
  }

  /// Marca una registrazione come "clean" (push riuscito).
  Future<void> markRegistrationClean(String id) async {
    try {
      final db = await database;
      await db.update(
        'registrations',
        {
          'sync_state': 'clean',
          'last_pushed_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      PerformanceLogger.error('markRegistrationClean fallito', error: e);
      rethrow;
    }
  }

  /// Marca una registrazione come "dirty" (modifica locale non ancora pushata).
  Future<void> markRegistrationDirty(String id) async {
    try {
      final db = await database;
      await db.update(
        'registrations',
        {'sync_state': 'dirty'},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      PerformanceLogger.error('markRegistrationDirty fallito', error: e);
      rethrow;
    }
  }

  /// Aggiorna lo status locale E marca dirty (per le azioni admin).
  Future<void> setRegistrationStatusLocal(
      String id,
      String status, {
        String? adminNotes,
      }) async {
    PerformanceLogger.start('setRegistrationStatusLocal');
    try {
      final db = await database;
      final values = <String, Object?>{
        'status': status,
        'sync_state': 'dirty',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (adminNotes != null) values['admin_notes'] = adminNotes;

      await db.update(
        'registrations',
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
      PerformanceLogger.info('setRegistrationStatusLocal',
          details: '$id -> $status');
      PerformanceLogger.stop('setRegistrationStatusLocal');
    } catch (e) {
      PerformanceLogger.error('setRegistrationStatusLocal fallito', error: e);
      rethrow;
    }
  }

  /// Aggiorna i timestamp di pull per un batch di id (post mark-exported).
  Future<void> markRegistrationsPulled(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final db = await database;
      final now = DateTime.now().toUtc().toIso8601String();
      await db.transaction((txn) async {
        for (final id in ids) {
          await txn.update(
            'registrations',
            {'last_pulled_at': now},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      });
    } catch (e) {
      PerformanceLogger.error('markRegistrationsPulled fallito', error: e);
      rethrow;
    }
  }

  /// Scrive una riga in `sync_log`. Non solleva mai: il log non deve
  /// bloccare il flusso di sincronizzazione.
  Future<void> logSync({
    required String direction, // 'pull' | 'push'
    required String action,    // 'inserted' | 'skipped' | 'error' | ...
    String? entityId,
    String? detail,
    String entity = 'registrations',
  }) async {
    try {
      final db = await database;
      await db.insert('sync_log', {
        'ts': DateTime.now().toUtc().toIso8601String(),
        'direction': direction,
        'action': action,
        'entity': entity,
        'entity_id': entityId,
        'detail': detail,
      });
    } catch (e) {
      // Non rilanciare: il log non deve rompere la sync.
      print('⚠️ logSync fallito: $e');
    }
  }

  /// Ritorna le ultime N righe del log di sincronizzazione.
  Future<List<Map<String, dynamic>>> getSyncLog({int limit = 100}) async {
    try {
      final db = await database;
      return await db.query('sync_log', orderBy: 'ts DESC', limit: limit);
    } catch (e) {
      PerformanceLogger.error('getSyncLog fallito', error: e);
      return [];
    }
  }

  // ========== METODI UTENTI ==========

  Future<List<User>> getAllUsers() async {
    PerformanceLogger.start('getAllUsers');
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('users');
      final users = List.generate(maps.length, (i) {
        return User.fromMap(maps[i]);
      });
      PerformanceLogger.info('Tutti gli utenti', details: '${users.length} utenti');
      PerformanceLogger.stop('getAllUsers');
      return users;
    } catch (e) {
      PerformanceLogger.error('getAllUsers fallito', error: e);
      return [];
    }
  }

  Future<User?> getUserById(String id) async {
    PerformanceLogger.start('getUserById');
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        PerformanceLogger.stop('getUserById');
        return User.fromMap(maps.first);
      }
      PerformanceLogger.stop('getUserById');
      return null;
    } catch (e) {
      PerformanceLogger.error('getUserById fallito', error: e);
      return null;
    }
  }

  Future<User?> getUserByEmail(String email) async {
    PerformanceLogger.start('getUserByEmail');
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [email],
      );
      if (maps.isNotEmpty) {
        PerformanceLogger.stop('getUserByEmail');
        return User.fromMap(maps.first);
      }
      PerformanceLogger.stop('getUserByEmail');
      return null;
    } catch (e) {
      PerformanceLogger.error('getUserByEmail fallito', error: e);
      return null;
    }
  }

  Future<void> updateUserLastLogin(String userId) async {
    PerformanceLogger.start('updateUserLastLogin');
    try {
      final db = await database;
      await db.update(
        'users',
        {'last_login': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [userId],
      );
      PerformanceLogger.stop('updateUserLastLogin');
    } catch (e) {
      PerformanceLogger.error('updateUserLastLogin fallito', error: e);
      rethrow;
    }
  }
}