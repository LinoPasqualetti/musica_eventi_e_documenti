// lib/screens/admin/admin_database.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/database_service.dart';

class AdminDatabase extends StatefulWidget {
  const AdminDatabase({Key? key}) : super(key: key);

  @override
  State<AdminDatabase> createState() => _AdminDatabaseState();
}

class _AdminDatabaseState extends State<AdminDatabase> {
  final DatabaseService _db = DatabaseService();
  bool _isLoading = false;
  String _dbInfo = '';

  @override
  void initState() {
    super.initState();
    _loadDbInfo();
  }

  Future<void> _loadDbInfo() async {
    try {
      final events = await _db.getAllEvents();
      final songs = await _db.getAllSongs();
      final users = await _db.getAllUsers();
      final registrations = await _db.getAllRegistrations();
      setState(() {
        _dbInfo = '''
📊 STATO DATABASE
━━━━━━━━━━━━━━━━━━━━━━━━━━
📅 Eventi: ${events.length}
🎵 Brani: ${songs.length}
👥 Utenti: ${users.length}
📝 Iscrizioni: ${registrations.length}
━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 Percorso: ${_db.getDatabasePath()}
''';
      });
    } catch (e) {
      setState(() {
        _dbInfo = '❌ Errore nel caricamento informazioni: $e';
      });
    }
  }

  Future<void> _restoreFromAsset() async {
    // Dialog di conferma
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Ripristino Database'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Stai per sostituire il database corrente con quello presente in:',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              '📁 assets/db/musica_per_tutti.db',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '⚠️ ATTENZIONE:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '• Tutti i dati correnti andranno persi\n'
                  '• Eventi, brani, utenti e iscrizioni saranno sostituiti\n'
                  '• Questa operazione è irreversibile',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sì, Ripristina'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _db.forceCopyFromAsset();
        await _loadDbInfo();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Database ripristinato con successo!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportDatabase() async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Salva database come...',
        fileName: 'musica_per_tutti_backup_${DateTime.now().toIso8601String().split('T').first}.db',
      );

      if (result != null) {
        await _db.exportDatabase(result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Database esportato in: $result'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Errore: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 Gestione Database',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Gestisci il database dell\'applicazione',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Info database
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📋 Informazioni Database',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _dbInfo,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Pulsanti
          Row(
            children: [
              // Ripristina da asset
              Expanded(
                child: Card(
                  elevation: 2,
                  child: InkWell(
                    onTap: _isLoading ? null : _restoreFromAsset,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.restore,
                            size: 40,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Ripristina da Asset',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sostituisci il database con quello in assets/db/',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Esporta database
              Expanded(
                child: Card(
                  elevation: 2,
                  child: InkWell(
                    onTap: _isLoading ? null : _exportDatabase,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.download,
                            size: 40,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Esporta Database',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Salva una copia di backup del database corrente',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Operazione in corso...'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}