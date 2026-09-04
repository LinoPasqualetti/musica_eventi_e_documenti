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
    
    // Crea indici per performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_esd_event_song ON event_song_documents(event_song_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_esd_document ON event_song_documents(document_id)');
    
    print('✅ Tabella event_song_documents creata');
  }

  /// Migra i dati esistenti dalla relazione song_documents a event_song_documents
  static Future<void> _migrateExistingData(Database db) async {
    print('🔄 Migrazione dati esistenti...');
    
    // Verifica se ci sono dati da migrare
    final existingDocs = await db.query('event_song_documents', limit: 1);
    if (existingDocs.isNotEmpty) {
      print('⚠️ Dati già presenti, salto migrazione');
      return;
    }

    // Ottieni tutte le relazioni event_songs
    final eventSongs = await db.query('event_songs');
    if (eventSongs.isEmpty) {
      print('ℹ️ Nessuna relazione event_songs trovata');
      return;
    }

    // Per ogni event_song, trova i documenti associati al brano via song_documents
    int migratedCount = 0;
    for (var es in eventSongs) {
      final eventSongId = es['id'] as String;
      final songId = es['song_id'] as String;
      
      // Trova i documenti per questo brano
      final songDocs = await db.query(
        'song_documents',
        where: 'song_id = ?',
        whereArgs: [songId],
      );
      
      if (songDocs.isEmpty) continue;
      
      // Inserisci ogni documento come evento-specifico
      for (int i = 0; i < songDocs.length; i++) {
        final doc = songDocs[i];
        final newId = DateTime.now().millisecondsSinceEpoch.toString() + '_${migratedCount}';
        
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
  /// e imposta storage_mode/mime_type per le righe esistenti, in base al doc_type.
  /// Il campo `content` resta NULL: va popolato con lo script
  /// lib/scripts/populate_blob_content.dart, eseguito una volta sulla macchina
  /// dove risiedono ancora i file originali.
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

    print('✅ Migrazione storage blob completata (content da popolare con lo script dedicato)');
  }
}