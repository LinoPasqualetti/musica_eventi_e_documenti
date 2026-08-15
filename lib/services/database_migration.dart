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
}