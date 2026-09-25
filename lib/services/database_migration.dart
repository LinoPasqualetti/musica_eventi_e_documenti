// lib/services/database_migration.dart
import 'package:sqflite/sqflite.dart';

class DatabaseMigration {
  /// Esegue tutte le migrazioni necessarie
  static Future<void> runMigrations(Database db) async {
    print('🔄 Avvio migrazioni database...');

    try {
      await _createEventSongDocumentsTable(db);
      await _migrateExistingData(db);
      print('✅ Migrazioni completate con successo!');
    } catch (e) {
      print('❌ Errore durante la migrazione: $e');
      rethrow;
    }
  }

  /// Crea la tabella event_song_documents
  static Future<void> _createEventSongDocumentsTable(Database db) async {
    print('📋 Creazione tabella event_song_documents...');

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

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_esd_event_song ON event_song_documents(event_song_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_esd_document ON event_song_documents(document_id)',
    );

    print('✅ Tabella event_song_documents creata');
  }

  /// Migra i dati esistenti dalla relazione song_documents a event_song_documents
  static Future<void> _migrateExistingData(Database db) async {
    print('🔄 Migrazione dati esistenti...');

    final existingDocs = await db.query('event_song_documents', limit: 1);
    if (existingDocs.isNotEmpty) {
      print('⚠️ Dati già presenti, salto migrazione');
      return;
    }

    final eventSongs = await db.query('event_songs');
    if (eventSongs.isEmpty) {
      print('ℹ️ Nessuna relazione event_songs trovata');
      return;
    }

    int migratedCount = 0;
    for (var es in eventSongs) {
      final eventSongId = es['id'] as String;
      final songId = es['song_id'] as String;

      final songDocs = await db.query(
        'song_documents',
        where: 'song_id = ?',
        whereArgs: [songId],
      );

      if (songDocs.isEmpty) continue;

      for (int i = 0; i < songDocs.length; i++) {
        final doc = songDocs[i];
        final newId =
            DateTime.now().millisecondsSinceEpoch.toString() + '_${migratedCount}';

        await db.insert('event_song_documents', {
          'id': newId,
          'event_song_id': eventSongId,
          'document_id': doc['document_id'],
          'order_index': i + 1,
          'notes': 'Migrato da song_documents',
          'created_at': DateTime.now().toIso8601String(),
        });
        migratedCount++;
      }
    }

    print('✅ Migrati $migratedCount documenti su ${eventSongs.length} relazioni');
  }

  /// Aggiunge le colonne storage_mode/content/mime_type a `documents` (se mancanti)
  static Future<void> runBlobStorageMigration(Database db) async {
    print('🔄 Migrazione storage blob per documents...');

    final columns = await db.rawQuery('PRAGMA table_info(documents)');
    final existingColumns = columns.map((c) => c['name'] as String).toSet();

    if (!existingColumns.contains('storage_mode')) {
      await db.execute(
        "ALTER TABLE documents ADD COLUMN storage_mode TEXT NOT NULL DEFAULT 'filesystem'",
      );
    }
    if (!existingColumns.contains('content')) {
      await db.execute('ALTER TABLE documents ADD COLUMN content BLOB');
    }
    if (!existingColumns.contains('mime_type')) {
      await db.execute('ALTER TABLE documents ADD COLUMN mime_type TEXT');
    }

    const blobTypes = ['mxl', 'abc', 'mid', 'kar'];
    const mimeByType = {
      'mxl': 'application/vnd.recordare.musicxml+xml',
      'abc': 'text/vnd.abc',
      'mid': 'audio/midi',
      'kar': 'audio/midi',
      'pdf': 'application/pdf',
      'audio_mp3': 'audio/mpeg',
      'audio_wav': 'audio/wav',
    };

    for (final type in blobTypes) {
      await db.update(
        'documents',
        {'storage_mode': 'blob'},
        where: 'doc_type = ?',
        whereArgs: [type],
      );
    }

    for (final entry in mimeByType.entries) {
      await db.update(
        'documents',
        {'mime_type': entry.value},
        where: "doc_type = ? AND (mime_type IS NULL OR mime_type = '')",
        whereArgs: [entry.key],
      );
    }

    print('✅ Migrazione storage blob completata');
  }

  /// Aggiunge le colonne di sincronizzazione a `registrations`
  static Future<void> runRegistrationsSyncMigration(Database db) async {
    print('🔄 Migrazione sync registrazioni...');

    final cols = await db.rawQuery('PRAGMA table_info(registrations)');
    final existing = cols.map((c) => c['name'] as String).toSet();

    if (!existing.contains('sync_state')) {
      await db.execute(
        "ALTER TABLE registrations ADD COLUMN sync_state TEXT NOT NULL DEFAULT 'clean'",
      );
    }
    if (!existing.contains('last_pulled_at')) {
      await db.execute('ALTER TABLE registrations ADD COLUMN last_pulled_at TEXT');
    }
    if (!existing.contains('last_pushed_at')) {
      await db.execute('ALTER TABLE registrations ADD COLUMN last_pushed_at TEXT');
    }
    if (!existing.contains('remote_updated_at')) {
      await db.execute('ALTER TABLE registrations ADD COLUMN remote_updated_at TEXT');
    }

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reg_status     ON registrations(status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reg_sync_state ON registrations(sync_state)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_log (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        ts        TEXT NOT NULL,
        direction TEXT NOT NULL,
        action    TEXT NOT NULL,
        entity    TEXT NOT NULL DEFAULT 'registrations',
        entity_id TEXT,
        detail    TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_log_ts ON sync_log(ts)',
    );

    print('✅ Migrazione sync registrazioni completata');
  }

  /// Crea le tabelle `organs` e `organ_slots` per la gestione
  /// dell'organico dei brani.
  static Future<void> runOrgansMigration(Database db) async {
    print('🔄 Migrazione organici (organs + organ_slots)...');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS organs (
        id             TEXT PRIMARY KEY,
        event_song_id  TEXT NOT NULL,
        name           TEXT NOT NULL DEFAULT 'Organico standard',
        notes          TEXT,
        created_at     TEXT NOT NULL,
        updated_at     TEXT,
        deleted_at     TEXT,
        FOREIGN KEY (event_song_id) REFERENCES event_songs(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_organs_event_song_id ON organs(event_song_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_organs_deleted_at ON organs(deleted_at)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS organ_slots (
        id           TEXT PRIMARY KEY,
        organ_id     TEXT NOT NULL,
        section      TEXT NOT NULL CHECK (section IN ('ritmica','armonica','solistica','orchestrale')),
        instrument   TEXT NOT NULL,
        quantity     INTEGER NOT NULL DEFAULT 1,
        notes        TEXT,
        order_index  INTEGER NOT NULL DEFAULT 0,
        created_at   TEXT NOT NULL,
        updated_at   TEXT,
        deleted_at   TEXT,
        FOREIGN KEY (organ_id) REFERENCES organs(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_organ_slots_organ_id   ON organ_slots(organ_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_organ_slots_section    ON organ_slots(section)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_organ_slots_deleted_at ON organ_slots(deleted_at)',
    );

    print('✅ Migrazione organici completata');
  }

  /// Aggiunge le colonne per il collegamento all'organico su `registrations`:
  /// - song_id           → brano di riferimento della candidatura
  /// - organ_slot_id     → slot di organico scelto dall'utente
  /// - time_description  → intervallo temporale in cui l'utente suonerà
  /// - deleted_at        → soft delete
  /// Idempotente: si può rieseguire senza danni.
  static Future<void> runRegistrationsOrgansMigration(Database db) async {
    print('🔄 Migrazione registrations per organico...');

    final cols = await db.rawQuery('PRAGMA table_info(registrations)');
    final existing = cols.map((c) => c['name'] as String).toSet();

    if (!existing.contains('song_id')) {
      await db.execute('ALTER TABLE registrations ADD COLUMN song_id TEXT');
    }
    if (!existing.contains('organ_slot_id')) {
      await db.execute('ALTER TABLE registrations ADD COLUMN organ_slot_id TEXT');
    }
    if (!existing.contains('time_description')) {
      await db.execute('ALTER TABLE registrations ADD COLUMN time_description TEXT');
    }
    if (!existing.contains('deleted_at')) {
      await db.execute('ALTER TABLE registrations ADD COLUMN deleted_at TEXT');
    }

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reg_song_id ON registrations(song_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reg_organ_slot_id ON registrations(organ_slot_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reg_deleted_at ON registrations(deleted_at)',
    );

    print('✅ Migrazione registrations per organico completata');
  }

  /// Aggiunge le colonne candidate_name e candidate_email a `registrations`
  /// per supportare candidature per conto terzi (scuole di musica, insegnanti).
  /// Crea anche l'indice univoco (candidate_name, organ_slot_id).
  /// Idempotente: si può rieseguire senza danni.
  static Future<void> runRegistrationsCandidatesMigration(Database db) async {
    print('🔄 Migrazione registrations per candidati...');

    final cols = await db.rawQuery('PRAGMA table_info(registrations)');
    final existing = cols.map((c) => c['name'] as String).toSet();

    if (!existing.contains('candidate_name')) {
      await db.execute('ALTER TABLE registrations ADD COLUMN candidate_name TEXT');
    }
    if (!existing.contains('candidate_email')) {
      await db.execute('ALTER TABLE registrations ADD COLUMN candidate_email TEXT');
    }

    // Indice univoco: una persona non può candidarsi due volte allo stesso slot.
    // Partial index: solo per record non cancellati.
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS uq_reg_candidate_slot '
          'ON registrations(candidate_name, organ_slot_id) '
          'WHERE deleted_at IS NULL',
    );

    print('✅ Migrazione registrations per candidati completata');
  }
  /// Crea le tabelle per i template di organico predefiniti
  /// e aggiunge il campo `template_id` a `organs`.
  /// Idempotente.
  static Future<void> runOrganTemplatesMigration(Database db) async {
    print('🔄 Migrazione template organici...');

    // 1. Tabella organ_templates
    await db.execute('''
      CREATE TABLE IF NOT EXISTS organ_templates (
        id             TEXT PRIMARY KEY,
        name           TEXT NOT NULL,
        category       TEXT,
        description    TEXT,
        created_at     TEXT NOT NULL,
        updated_at     TEXT,
        deleted_at     TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_organ_templates_category '
          'ON organ_templates(category)',
    );

    // 2. Tabella organ_template_slots
    await db.execute('''
      CREATE TABLE IF NOT EXISTS organ_template_slots (
        id           TEXT PRIMARY KEY,
        template_id  TEXT NOT NULL,
        section      TEXT NOT NULL CHECK (section IN ('ritmica','armonica','solistica','orchestrale')),
        instrument   TEXT NOT NULL,
        quantity     INTEGER NOT NULL DEFAULT 1,
        notes        TEXT,
        order_index  INTEGER NOT NULL DEFAULT 0,
        created_at   TEXT NOT NULL,
        updated_at   TEXT,
        deleted_at   TEXT,
        FOREIGN KEY (template_id) REFERENCES organ_templates(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_organ_template_slots_template_id '
          'ON organ_template_slots(template_id)',
    );

    // 3. Aggiungi colonna template_id a organs
    final cols = await db.rawQuery('PRAGMA table_info(organs)');
    final existing = cols.map((c) => c['name'] as String).toSet();
    if (!existing.contains('template_id')) {
      await db.execute('ALTER TABLE organs ADD COLUMN template_id TEXT');
    }

    print('✅ Migrazione template organici completata');
  }
}