// lib/services/database_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/document.dart';
import '../models/song_document.dart';

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

class DatabaseService {
  static Database? _database;
  static bool _initialized = false;
  static bool _isWeb = kIsWeb;
  static bool _forceCopyFromAsset = false;

  // Versione del database - AUMENTATA A 2 PER LA MIGRAZIONE
  static const int DB_VERSION = 2;

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

    return await openDatabase(
      path,
      version: DB_VERSION,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) {
        print('✅ Database aperto con successo');
      },
    );
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

  // ============================================
  // CREAZIONE TABELLE
  // ============================================

  Future<void> _onCreate(Database db, int version) async {
    print('🔄 Creazione tabelle versione $version');
    await _createTables(db);
    await _createViews(db);
    print('✅ Tabelle e viste create');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 Aggiornamento database da versione $oldVersion a $newVersion');

    if (oldVersion < 2) {
      // Esegui la migrazione per la nuova tabella event_song_documents
      await DatabaseMigration.runMigrations(db);
      // Crea le viste dopo la migrazione
      await _createViews(db);
    }
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
        file_path TEXT NOT NULL,
        file_size INTEGER,
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
        updated_at TEXT
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
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT * FROM v_event_documents
      WHERE event_id = ?
      ORDER BY song_order ASC, document_order ASC
    ''', [eventId]);
    return result;
  }

  /// Ottiene il riepilogo dei documenti per evento
  Future<List<Map<String, dynamic>>> getEventDocumentsSummary(String eventId) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT * FROM v_event_documents_summary
      WHERE event_id = ?
      ORDER BY song_order ASC
    ''', [eventId]);
    return result;
  }

  /// Ottiene tutti i documenti di un evento (raggruppati per brano)
  Future<Map<String, List<Map<String, dynamic>>>> getEventDocumentsGrouped(String eventId) async {
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
    return grouped;
  }

  // ========== METODI EVENTI ==========

  Future<List<Event>> getAllEvents() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'events',
        orderBy: 'date DESC',
      );
      print('📊 Trovati ${maps.length} eventi');
      return List.generate(maps.length, (i) {
        return Event.fromMap(maps[i]);
      });
    } catch (e) {
      print('❌ Errore in getAllEvents: $e');
      return [];
    }
  }

  Future<Event?> getEventById(String id) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'events',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return Event.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('❌ Errore in getEventById: $e');
      return null;
    }
  }

  Future<void> insertEvent(Event event) async {
    final db = await database;
    await db.insert(
      'events',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('✅ Evento inserito: ${event.title}');
  }

  Future<void> updateEvent(Event event) async {
    final db = await database;
    await db.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
    print('✅ Evento aggiornato: ${event.title}');
  }

  Future<void> deleteEvent(String id) async {
    final db = await database;
    await db.delete(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    );
    print('🗑️ Evento eliminato: $id');
  }

  // ========== METODI CANZONI ==========

  Future<List<Song>> getAllSongs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'songs',
      orderBy: 'title ASC',
    );
    return List.generate(maps.length, (i) {
      return Song.fromMap(maps[i]);
    });
  }

  Future<void> insertSong(Song song) async {
    final db = await database;
    await db.insert('songs', song.toMap());
    print('✅ Brano inserito: ${song.title}');
  }

  Future<void> updateSong(Song song) async {
    final db = await database;
    await db.update(
      'songs',
      song.toMap(),
      where: 'id = ?',
      whereArgs: [song.id],
    );
    print('✅ Brano aggiornato: ${song.title}');
  }

  Future<void> deleteSong(String id) async {
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
  }

  // ========== METODI SONG EVENTI ==========

  Future<void> addSongToEvent(String eventId, String songId, {int orderIndex = 0}) async {
    final db = await database;

    final existing = await db.query(
      'event_songs',
      where: 'event_id = ? AND song_id = ?',
      whereArgs: [eventId, songId],
    );

    if (existing.isNotEmpty) {
      print('ℹ️ Canzone già associata all\'evento');
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
  }

  Future<void> removeSongFromEvent(String eventId, String songId) async {
    final db = await database;
    await db.delete(
      'event_songs',
      where: 'event_id = ? AND song_id = ?',
      whereArgs: [eventId, songId],
    );
    print('🗑️ Canzone rimossa dall\'evento');
  }

  Future<List<Song>> getSongsByEvent(String eventId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
    SELECT s.* 
    FROM songs s
    INNER JOIN event_songs es ON s.id = es.song_id
    WHERE es.event_id = ?
    ORDER BY es.order_index ASC, s.title ASC
  ''', [eventId]);

    return List.generate(maps.length, (i) {
      return Song.fromMap(maps[i]);
    });
  }

  Future<List<Event>> getEventsBySong(String songId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
    SELECT e.* 
    FROM events e
    INNER JOIN event_songs es ON e.id = es.event_id
    WHERE es.song_id = ?
    ORDER BY e.date DESC
  ''', [songId]);

    return List.generate(maps.length, (i) {
      return Event.fromMap(maps[i]);
    });
  }

  Future<void> updateSongOrder(String eventId, String songId, int orderIndex) async {
    final db = await database;
    await db.update(
      'event_songs',
      {'order_index': orderIndex, 'updated_at': DateTime.now().toIso8601String()},
      where: 'event_id = ? AND song_id = ?',
      whereArgs: [eventId, songId],
    );
  }

  Future<Song?> getSongById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'songs',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Song.fromMap(maps.first);
    }
    return null;
  }

  // ========== METODI ISCRIZIONE ==========

  Future<List<Registration>> getRegistrationsByEvent(String eventId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'registrations',
      where: 'event_id = ?',
      whereArgs: [eventId],
    );
    return List.generate(maps.length, (i) {
      return Registration.fromMap(maps[i]);
    });
  }

  Future<Map<String, int>> getDocumentsCountBySong() async {
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
    return countMap;
  }

  Future<Map<String, List<String>>> getInstrumentsBySongForEvent(String eventId) async {
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

    return result;
  }

  Future<Map<String, int>> getRegistrationsCountBySongForEvent(String eventId) async {
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

    return result;
  }

  // ========== METODI DOCUMENTI ==========

  Future<List<Document>> getAllDocuments() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('documents');
    return List.generate(maps.length, (i) {
      return Document.fromMap(maps[i]);
    });
  }

  Future<Document?> getDocumentById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Document.fromMap(maps.first);
    }
    return null;
  }

  Future<void> insertDocument(Document document) async {
    final db = await database;
    await db.insert('documents', document.toMap());
    print('✅ Documento inserito: ${document.fileName}');
  }

  Future<void> updateDocument(Document document) async {
    final db = await database;
    await db.update(
      'documents',
      document.toMap(),
      where: 'id = ?',
      whereArgs: [document.id],
    );
    print('✅ Documento aggiornato: ${document.fileName}');
  }

  Future<void> deleteDocument(String id) async {
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
  }

  // ========== METODI RELAZIONE DOCUMENTO-BRANO ==========

  Future<void> addDocumentToSong(String documentId, String songId, {int orderIndex = 0}) async {
    final db = await database;
    final existing = await db.query(
      'song_documents',
      where: 'document_id = ? AND song_id = ?',
      whereArgs: [documentId, songId],
    );
    if (existing.isNotEmpty) {
      print('ℹ️ Documento già associato al brano');
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
  }

  Future<void> removeDocumentFromSong(String documentId, String songId) async {
    final db = await database;
    await db.delete(
      'song_documents',
      where: 'document_id = ? AND song_id = ?',
      whereArgs: [documentId, songId],
    );
    print('🗑️ Documento rimosso dal brano');
  }

  Future<List<Document>> getDocumentsBySong(String songId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
    SELECT d.* 
    FROM documents d
    INNER JOIN song_documents sd ON d.id = sd.document_id
    WHERE sd.song_id = ?
    ORDER BY sd.order_index ASC, d.file_name ASC
  ''', [songId]);
    return List.generate(maps.length, (i) {
      return Document.fromMap(maps[i]);
    });
  }

  Future<List<Document>> getDocumentsByType(String docType) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'documents',
      where: 'doc_type = ?',
      whereArgs: [docType],
      orderBy: 'file_name ASC',
    );
    return List.generate(maps.length, (i) {
      return Document.fromMap(maps[i]);
    });
  }

  // ========== METODI EVENT_SONG_DOCUMENTS (NUOVI) ==========

  /// Ottiene l'event_song_id per un evento e un brano
  Future<String?> getEventSongId(String eventId, String songId) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'event_songs',
      where: 'event_id = ? AND song_id = ?',
      whereArgs: [eventId, songId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return result.first['id'] as String;
  }

  /// Ottiene i documenti specifici per un evento-brano
  Future<List<EventSongDocument>> getDocumentsForEventSong(String eventSongId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'event_song_documents',
      where: 'event_song_id = ?',
      whereArgs: [eventSongId],
      orderBy: 'order_index ASC',
    );
    return List.generate(maps.length, (i) {
      return EventSongDocument.fromMap(maps[i]);
    });
  }

  /// Aggiunge un documento a un evento-brano
  Future<void> addDocumentToEventSong(String eventSongId, String documentId, {int orderIndex = 0, String? notes}) async {
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
  }

  /// Rimuove un documento da un evento-brano
  Future<void> removeDocumentFromEventSong(String eventSongId, String documentId) async {
    final db = await database;
    await db.delete(
      'event_song_documents',
      where: 'event_song_id = ? AND document_id = ?',
      whereArgs: [eventSongId, documentId],
    );
    print('🗑️ Documento rimosso da evento-brano');
  }

  /// Ottiene i documenti di un evento-brano con i dettagli del documento
  Future<List<Map<String, dynamic>>> getEventSongDocumentsWithDetails(String eventSongId) async {
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

    return result;
  }

  /// Ottiene tutti i documenti di un evento (raggruppati per brano) - usa la vista
  Future<Map<String, List<Map<String, dynamic>>>> getDocumentsByEvent(String eventId) async {
    return getEventDocumentsGrouped(eventId);
  }

  /// Ottiene i documenti di un evento per un brano specifico
  Future<List<Map<String, dynamic>>> getDocumentsForEventAndSong(String eventId, String songId) async {
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

    return result;
  }

  /// Aggiorna l'ordine di un documento in un evento-brano
  Future<void> updateEventSongDocumentOrder(String eventSongDocumentId, int orderIndex) async {
    final db = await database;
    await db.update(
      'event_song_documents',
      {'order_index': orderIndex, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [eventSongDocumentId],
    );
  }

  /// Elimina tutti i documenti di un evento-brano
  Future<void> clearDocumentsFromEventSong(String eventSongId) async {
    final db = await database;
    await db.delete(
      'event_song_documents',
      where: 'event_song_id = ?',
      whereArgs: [eventSongId],
    );
    print('🗑️ Tutti i documenti rimossi da evento-brano');
  }

  // ========== METODI REGISTRAZIONI ==========

  Future<List<Registration>> getAllRegistrations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'registrations',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) {
      return Registration.fromMap(maps[i]);
    });
  }

  Future<int> countRegistrationsByEvent(String eventId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM registrations WHERE event_id = ?',
      [eventId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<bool> isAlreadyRegistered(String eventId, String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'registrations',
      where: 'event_id = ? AND user_id = ?',
      whereArgs: [eventId, userId],
    );
    return maps.isNotEmpty;
  }

  Future<void> insertRegistration(Registration registration) async {
    final db = await database;
    await db.insert(
      'registrations',
      registration.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateRegistrationStatus(String id, String status) async {
    final db = await database;
    await db.update(
      'registrations',
      {'status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteRegistration(String id) async {
    final db = await database;
    await db.delete(
      'registrations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== METODI UTENTI ==========

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users');
    return List.generate(maps.length, (i) {
      return User.fromMap(maps[i]);
    });
  }

  Future<User?> getUserById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateUserLastLogin(String userId) async {
    final db = await database;
    await db.update(
      'users',
      {'last_login': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
}