// [MODIFICA] C:\musica_eventi_e_documenti\lib\screens\admin\admin_registrations.dart

// lib/screens/admin/admin_registrations.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../models/registration_model.dart';
import '../../models/user_model.dart';
import '../../models/event_model.dart';
import '../../models/song_model.dart';
import '../../providers/registration_sync_provider.dart';

class AdminRegistrations extends StatefulWidget {
  const AdminRegistrations({Key? key}) : super(key: key);

  @override
  State<AdminRegistrations> createState() => _AdminRegistrationsState();
}

class _AdminRegistrationsState extends State<AdminRegistrations> {
  final DatabaseService _db = DatabaseService();
  List<Registration> _registrations = [];
  Map<String, User> _userCache = {};
  Map<String, Event> _eventCache = {};
  Map<String, Song> _songCache = {};
  bool _isLoading = true;
  String _filterStatus = 'tutti';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final registrations = await _db.getAllRegistrations();

      _userCache = {};
      _eventCache = {};
      _songCache = {};

      for (var reg in registrations) {
        if (!_userCache.containsKey(reg.userId)) {
          final user = await _db.getUserById(reg.userId);
          if (user != null) _userCache[reg.userId] = user;
        }
        if (!_eventCache.containsKey(reg.eventId)) {
          final event = await _db.getEventById(reg.eventId);
          if (event != null) _eventCache[reg.eventId] = event;
        }
        if (reg.selectedSongIds != null) {
          final songIds = reg.selectedSongIds!.split(',');
          for (var songId in songIds) {
            if (!_songCache.containsKey(songId)) {
              final song = await _db.getSongById(songId);
              if (song != null) _songCache[songId] = song;
            }
          }
        }
      }

      setState(() {
        _registrations = registrations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('Errore: $e', isError: true);
    }
  }

  /// Cambia lo status locale e marca la registrazione come 'dirty'
  /// (verrà pushata al web al prossimo "Pubblica sul web").
  Future<void> _updateStatusLocal(Registration reg, String newStatus) async {
    try {
      await _db.setRegistrationStatusLocal(reg.id, newStatus);
      await _loadData();
      _showSnack('✅ Stato aggiornato a "$newStatus" (in attesa di pubblicazione)');
    } catch (e) {
      _showSnack('Errore: $e', isError: true);
    }
  }

  /// PULL dal web
  Future<void> _syncFromWeb() async {
    final provider = context.read<RegistrationSyncProvider>();
    await provider.pullPending();

    if (!mounted) return;

    final err = provider.lastError;
    if (err != null) {
      _showSnack('⚠️ $err', isError: true);
    } else {
      _showSnack('✅ Sincronizzate ${provider.state.lastPulled} nuove iscrizioni');
    }
    await _loadData();
  }

  /// PUSH al web
  Future<void> _publishToWeb() async {
    final provider = context.read<RegistrationSyncProvider>();
    await provider.pushDirty();

    if (!mounted) return;

    final err = provider.lastError;
    if (err != null) {
      _showSnack('⚠️ $err', isError: true);
    } else {
      _showSnack('✅ Pubblicate ${provider.state.lastPushed} iscrizioni sul web');
    }
    await _loadData();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _getUserFullName(String userId) {
    final user = _userCache[userId];
    return user?.fullName ?? userId;
  }

  String _getEventTitle(String eventId) {
    final event = _eventCache[eventId];
    return event?.title ?? eventId;
  }

  String _getSongTitles(String? songIds) {
    if (songIds == null || songIds.isEmpty) return 'Nessuno';
    final ids = songIds.split(',');
    return ids.map((id) => _songCache[id]?.title ?? id).join(', ');
  }

  List<Registration> get _filteredRegistrations {
    if (_filterStatus == 'tutti') return _registrations;
    return _registrations.where((r) => r.status == _filterStatus).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'exported':
      case 'imported':
        return Colors.blue;
      case 'validated':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'published':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return '⏳ In attesa';
      case 'exported':
        return '📤 Esportata';
      case 'imported':
        return '📥 Importata';
      case 'validated':
        return '✅ Validata';
      case 'rejected':
        return '❌ Rifiutata';
      case 'published':
        return '🌐 Pubblicata';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationSyncProvider>(
      builder: (context, syncProvider, _) {
        final isSyncing = syncProvider.isRunning;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── HEADER ──────────────────────────────
              Row(
                children: [
                  const Text(
                    '📝 Gestione Iscrizioni',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),

                  // Bottone "Sincronizza dal web" (PULL)
                  ElevatedButton.icon(
                    onPressed: isSyncing ? null : _syncFromWeb,
                    icon: isSyncing
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.cloud_download),
                    label: const Text('Sincronizza dal web'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Bottone "Pubblica sul web" (PUSH)
                  ElevatedButton.icon(
                    onPressed: isSyncing ? null : _publishToWeb,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Pubblica sul web'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Bottone "Aggiorna"
                  IconButton(
                    onPressed: isSyncing ? null : _loadData,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Ricarica dal DB locale',
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Filtri
              Row(
                children: [
                  const Text('Filtra:'),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _filterStatus,
                    items: const [
                      DropdownMenuItem(value: 'tutti', child: Text('📋 Tutti')),
                      DropdownMenuItem(value: 'pending', child: Text('⏳ In attesa')),
                      DropdownMenuItem(value: 'exported', child: Text('📤 Esportate')),
                      DropdownMenuItem(value: 'imported', child: Text('📥 Importate')),
                      DropdownMenuItem(value: 'validated', child: Text('✅ Validate')),
                      DropdownMenuItem(value: 'rejected', child: Text('❌ Rifiutate')),
                      DropdownMenuItem(value: 'published', child: Text('🌐 Pubblicate')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _filterStatus = value);
                    },
                  ),
                  const Spacer(),
                  Text(
                    '${_filteredRegistrations.length} iscrizioni',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ─── LISTA ──────────────────────────────
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredRegistrations.isEmpty
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Nessuna iscrizione trovata'),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: _filteredRegistrations.length,
                  itemBuilder: (context, index) {
                    final reg = _filteredRegistrations[index];
                    return _buildRegistrationCard(reg);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRegistrationCard(Registration reg) {
    final userName = _getUserFullName(reg.userId);
    final eventTitle = _getEventTitle(reg.eventId);
    final songTitles = _getSongTitles(reg.selectedSongIds);

    // Estrai lo stato di sync dalla mappa
    // (il campo non è nel model Registration, lo leggiamo direttamente dal DB)
    // Per ora mostriamo solo lo status; il sync_state lo vedremo in una seconda iterazione.

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _statusColor(reg.status),
                  radius: 14,
                  child: Text(
                    reg.status[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '🎵 $eventTitle',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(reg.status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusLabel(reg.status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _statusColor(reg.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.music_note, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Strumento: ${reg.instrumentChoice ?? 'N/D'}',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.library_music, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Brani: $songTitles',
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Lettura: ${reg.readingLevel}/5  •  Improvvisazione: ${reg.improvisationLevel}/5',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            if (reg.notes != null && reg.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '📝 ${reg.notes}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 8),

            // ─── AZIONI ─────────────────────────────
            // In base allo status, mostra bottoni diversi
            Row(
              children: [
                if (reg.status == 'pending' || reg.status == 'exported' || reg.status == 'imported') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatusLocal(reg, 'validated'),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Valida'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatusLocal(reg, 'rejected'),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Rifiuta'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ] else if (reg.status == 'validated' || reg.status == 'rejected') ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'In attesa di "Pubblica sul web"',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (reg.status == 'published') ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: Colors.purple.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pubblicata sul web',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.purple.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}