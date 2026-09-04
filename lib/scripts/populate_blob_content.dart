// lib/scripts/populate_blob_content.dart
//
// Legge, per ogni documento con storage_mode='blob' e content ancora NULL,
// il file indicato in file_path e lo carica nella colonna content.
// Va eseguito SULLA MACCHINA dove i file originali sono ancora raggiungibili
// (i percorsi nel DB sono del tipo C:\musica_eventi_e_documenti\assets\...).
//
// Uso:
//   dart run lib/scripts/populate_blob_content.dart <percorso_del_db.db>
//
// Non richiede Flutter in esecuzione: usa sqflite_common_ffi direttamente,
// già una dipendenza del progetto (vedi services/database_service.dart).

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Uso: dart run lib/scripts/populate_blob_content.dart <percorso_del_db.db>');
    exit(1);
  }

  final dbPath = args[0];
  if (!File(dbPath).existsSync()) {
    stderr.writeln('File DB non trovato: $dbPath');
    exit(1);
  }

  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(dbPath);

  final rows = await db.query(
    'documents',
    columns: ['id', 'doc_type', 'file_name', 'file_path'],
    where: "storage_mode = 'blob' AND content IS NULL AND file_path IS NOT NULL",
  );

  print('Trovati ${rows.length} documenti da popolare.');

  var ok = 0;
  final mancanti = <Map<String, Object?>>[];

  for (final row in rows) {
    final id = row['id'] as String;
    final docType = row['doc_type'] as String;
    final fileName = row['file_name'] as String;
    final filePath = row['file_path'] as String;

    final sourceFile = File(filePath);
    if (!sourceFile.existsSync()) {
      mancanti.add(row);
      continue;
    }

    final bytes = await sourceFile.readAsBytes();
    await db.update(
      'documents',
      {'content': bytes, 'file_size': bytes.length},
      where: 'id = ?',
      whereArgs: [id],
    );
    ok++;
    print('  OK  [$docType] $fileName (${bytes.length} byte)');
  }

  await db.close();

  print('\nCompletato: $ok documenti caricati come BLOB.');
  if (mancanti.isNotEmpty) {
    print('\nATTENZIONE: ${mancanti.length} file non trovati sul disco:');
    for (final row in mancanti) {
      print('  - [${row['id']}] ${row['file_name']} -> ${row['file_path']}');
    }
  }
}
