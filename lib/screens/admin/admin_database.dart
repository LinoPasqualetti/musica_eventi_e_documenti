// lib/screens/admin/admin_database.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../services/database_service.dart';
import '../../services/full_push_service.dart';
import '../../services/document_push_service.dart';
import '../../services/pending_uploads_service.dart';
import '../../providers/registration_sync_provider.dart';

class AdminDatabase extends StatefulWidget {
  const AdminDatabase({Key? key}) : super(key: key);

  @override
  State<AdminDatabase> createState() => _AdminDatabaseState();
}

class _AdminDatabaseState extends State<AdminDatabase> {
  final DatabaseService _db = DatabaseService();
  bool _isLoading = false;
  String _dbInfo = '';
  String _lastStatus = '';

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
      final dbPath = await _db.getDatabasePath();
      setState(() {
        _dbInfo =
            'STATO DATABASE\n'
            '---------------------\n'
            'Eventi: ${events.length}\n'
            'Brani: ${songs.length}\n'
            'Utenti: ${users.length}\n'
            'Iscrizioni: ${registrations.length}\n'
            '---------------------\n'
            'Path: $dbPath\n';
      });
    } catch (e) {
      setState(() => _dbInfo = 'Errore: $e');
    }
  }

  Future<void> _pushFull() async {
    setState(() {
      _isLoading = true;
      _lastStatus = 'Push completo in corso...';
    });
    try {
      final report = await FullPushService.pushFull();
      if (!mounted) return;
      setState(() {
        _lastStatus = report.ok
            ? 'Push completo riuscito in ${report.durationMs}ms'
            : 'Push completato con errori';
      });
      await _showReportDialog(report);
      await _loadDbInfo();
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastStatus = 'Push fallito: $e');
      _snack('Errore push completo: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showReportDialog(FullPushReport report) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              report.ok ? Icons.check_circle : Icons.warning_amber,
              color: report.ok ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(report.ok ? 'Push completo' : 'Con errori'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Text(
              report.describe(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _pullRegistrations() async {
    setState(() {
      _isLoading = true;
      _lastStatus = 'Pull candidature dal web...';
    });
    try {
      final provider = context.read<RegistrationSyncProvider>();
      await provider.pullPending();
      if (!mounted) return;
      final err = provider.lastError;
      if (err != null) {
        setState(() => _lastStatus = 'Pull: $err');
        _snack(err, isError: true);
      } else {
        final n = provider.state.lastPulled;
        setState(() => _lastStatus = 'Scaricate $n candidature');
        _snack('Scaricate $n candidature');
      }
      await _loadDbInfo();
    } catch (e) {
      setState(() => _lastStatus = 'Pull fallito: $e');
      _snack('Errore: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pushRegistrations() async {
    setState(() {
      _isLoading = true;
      _lastStatus = 'Push candidature modificate...';
    });
    try {
      final provider = context.read<RegistrationSyncProvider>();
      await provider.pushDirty();
      if (!mounted) return;
      final err = provider.lastError;
      if (err != null) {
        setState(() => _lastStatus = 'Push candidature: $err');
        _snack(err, isError: true);
      } else {
        final n = provider.state.lastPushed;
        setState(() => _lastStatus = 'Pushate $n candidature');
        _snack('Pushate $n candidature');
      }
    } catch (e) {
      setState(() => _lastStatus = 'Push fallito: $e');
      _snack('Errore: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pushPendingBlobs() async {
    setState(() {
      _isLoading = true;
      _lastStatus = 'Push blob pendenti...';
    });
    try {
      final pending = await PendingUploadsService.readAll();
      if (pending.isEmpty) {
        setState(() => _lastStatus = 'Nessun blob pendente');
        _snack('Nessun blob pendente');
        return;
      }

      int ok = 0;
      int fail = 0;

      for (final p in pending) {
        try {
          final docId = p['documentId'] as String?;
          if (docId == null) continue;
          final doc = await _db.getDocumentByIdWithContent(docId);
          if (doc == null || doc.content == null) {
            fail++;
            continue;
          }
          final success = await DocumentPushService.pushDocument(doc);
          if (success) {
            await PendingUploadsService.remove(docId);
            ok++;
          } else {
            fail++;
          }
        } catch (_) {
          fail++;
        }
      }

      setState(() => _lastStatus =
          'Push blob: $ok ok, $fail falliti (su ${pending.length})');
      _snack('Push blob: $ok ok, $fail falliti');
    } catch (e) {
      setState(() => _lastStatus = 'Push blob fallito: $e');
      _snack('Errore: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clearPendingBlobs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulire i pending?'),
        content: const Text(
          'Verranno rimossi dalla coda senza essere pushati al web.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Pulisci'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final pending = await PendingUploadsService.readAll();
    for (final p in pending) {
      final id = p['documentId'] as String?;
      if (id != null) await PendingUploadsService.remove(id);
    }
    _snack('Pending puliti (${pending.length} rimossi)');
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _restoreFromAsset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Ripristino Database'),
          ],
        ),
        content: const Text(
          'Sostituisci il DB corrente con quello in assets/db/.\n\n'
          'Attenzione: tutti i dati correnti andranno persi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ripristina'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _db.forceCopyFromAsset();
        await _loadDbInfo();
        _snack('Database ripristinato');
      } catch (e) {
        _snack('Errore: $e', isError: true);
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportDatabase() async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Salva database come...',
        fileName:
            'musica_per_tutti_backup_${DateTime.now().toIso8601String().split('T').first}.db',
      );
      if (result != null) {
        await _db.exportDatabase(result);
        _snack('Database esportato in: $result');
      }
    } catch (e) {
      _snack('Errore: $e', isError: true);
    }
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 40, color: iconColor),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gestione Database',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Gestisci il database e la sincronizzazione col web',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informazioni Database',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _dbInfo,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Sincronizzazione con Web',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Il Flutter e master del contenuto. Il Web riceve una copia.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: _buildActionCard(
              icon: Icons.cloud_upload,
              iconColor: Colors.deepPurple,
              title: 'Push Completo',
              subtitle:
                  'Sostituisce events/songs/documents/organici e mergia le candidature',
              onTap: _isLoading ? null : _pushFull,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.cloud_download,
                  iconColor: Colors.blue,
                  title: 'Pull candidature',
                  subtitle: 'Scarica nuove dal Web',
                  onTap: _isLoading ? null : _pullRegistrations,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.cloud_sync,
                  iconColor: Colors.teal,
                  title: 'Push candidature',
                  subtitle: 'Invia solo quelle modificate',
                  onTap: _isLoading ? null : _pushRegistrations,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.upload_file,
                  iconColor: Colors.indigo,
                  title: 'Push blob pendenti',
                  subtitle: 'Documenti in coda (retry)',
                  onTap: _isLoading ? null : _pushPendingBlobs,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.clear_all,
                  iconColor: Colors.red,
                  title: 'Pulisci coda blob',
                  subtitle: 'Rimuovi senza pushare',
                  onTap: _isLoading ? null : _clearPendingBlobs,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Push Completo: il Web diventa una copia esatta del Flutter. '
                    'Le candidature del Web NON vengono sovrascritte '
                    '(merge condizionale).',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          if (_lastStatus.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _lastStatus,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],

          const SizedBox(height: 24),

          const Text(
            'Manutenzione',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.restore,
                  iconColor: Colors.orange.shade700,
                  title: 'Ripristina da Asset',
                  subtitle: 'Sostituisci con assets/db/',
                  onTap: _isLoading ? null : _restoreFromAsset,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.download,
                  iconColor: Colors.green.shade700,
                  title: 'Esporta Database',
                  subtitle: 'Salva una copia di backup',
                  onTap: _isLoading ? null : _exportDatabase,
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

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
