// [MODIFICA 2026-09-24] C:\musica_eventi_e_documenti\lib\screens\admin\admin_registrations.dart
//
// Fix:
//  - Mostra candidate_name (guest) con fallback su user.fullName
//  - Carica organSlot per mostrare strumento e brano corretti
//  - Fix status: 'confirmed' invece di 'validated'

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../models/registration_model.dart';
import '../../models/user_model.dart';
import '../../models/event_model.dart';
import '../../models/song_model.dart';
import '../../models/organ_slot.dart';
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
  Map<String, OrganSlot> _organSlotCache = {};
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
      _organSlotCache = {};

      for (var reg in registrations) {
        // Carica utente
        if (reg.userId.isNotEmpty && !_userCache.containsKey(reg.userId)) {
          final user = await _db.getUserById(reg.userId);
          if (user != null) _userCache[reg.userId] = user;
        }

        // Carica evento
        if (reg.eventId.isNotEmpty && !_eventCache.containsKey(reg.eventId)) {
          final event = await _db.getEventById(reg.eventId);
          if (event != null) _eventCache[reg.eventId] = event;
        }

        // Carica organSlot (per strumento)
        final slotId = reg.organSlotId;
        if (slotId != null &&
            slotId.isNotEmpty &&
            !_organSlotCache.containsKey(slotId)) {
          final slot = await _db.getOrganSlotById(slotId);
          if (slot != null) _organSlotCache[slotId] = slot;
        }

        // Carica brano (nuovo schema: songId singolo)
        if (reg.songId != null &&
            reg.songId!.isNotEmpty &&
            !_songCache.containsKey(reg.songId!)) {
          final song = await _db.getSongById(reg.songId!);
          if (song != null) _songCache[reg.songId!] = song;
        }

        // Carica brani (legacy: selectedSongIds CSV)
        if (reg.selectedSongIds != null && reg.selectedSongIds!.isNotEmpty) {
          final songIds = reg.selectedSongIds!.split(',');
          for (var songId in songIds) {
            final trimmed = songId.trim();
            if (trimmed.isNotEmpty && !_songCache.containsKey(trimmed)) {
              final song = await _db.getSongById(trimmed);
              if (song != null) _songCache[trimmed] = song;
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

  Future<void> _updateStatusLocal(Registration reg, String newStatus) async {
    try {
      await _db.setRegistrationStatusLocal(reg.id, newStatus);
      await _loadData();
      _showSnack('✅ Stato aggiornato a "$newStatus" (in attesa di pubblicazione)');
    } catch (e) {
      _showSnack('Errore: $e', isError: true);
    }
  }

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

  /// Nome da mostrare:
  /// 1. candidateName (candidatura guest) — priorità
  /// 2. user.fullName (utente registrato)
  /// 3. userId (ultimo fallback)
  String _getDisplayName(Registration reg) {
    if (reg.candidateName != null && reg.candidateName!.trim().isNotEmpty) {
      return reg.candidateName!;
    }
    final user = _userCache[reg.userId];
    if (user != null && user.fullName.trim().isNotEmpty) {
      return user.fullName;
    }
    return reg.userId;
  }

  String? _getDisplayEmail(Registration reg) {
    if (reg.candidateEmail != null && reg.candidateEmail!.trim().isNotEmpty) {
      return reg.candidateEmail;
    }
    final user = _userCache[reg.userId];
    return user?.email;
  }

  String _getEventTitle(String eventId) {
    final event = _eventCache[eventId];
    return event?.title ?? eventId;
  }

  /// Strumento:
  /// 1. organSlot.instrument (nuovo schema)
  /// 2. reg.instrumentChoice (legacy)
  /// 3. 'N/D'
  String _getInstrument(Registration reg) {
    final slotId = reg.organSlotId;
    if (slotId != null && slotId.isNotEmpty) {
      final slot = _organSlotCache[slotId];
      if (slot != null && slot.instrument.isNotEmpty) {
        return slot.instrument;
      }
    }
    if (reg.instrumentChoice != null && reg.instrumentChoice!.isNotEmpty) {
      return reg.instrumentChoice!;
    }
    return 'N/D';
  }

  /// Brano/i:
  /// 1. reg.songId singolo (nuovo schema)
  /// 2. reg.selectedSongIds (legacy, CSV)
  /// 3. 'Nessuno'
  String _getSongTitles(Registration reg) {
    if (reg.songId != null && reg.songId!.isNotEmpty) {
      final song = _songCache[reg.songId!];
      return song?.title ?? reg.songId!;
    }
    if (reg.selectedSongIds != null && reg.selectedSongIds!.isNotEmpty) {
      final ids = reg.selectedSongIds!
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);
      if (ids.isEmpty) return 'Nessuno';
      return ids.map((id) => _songCache[id]?.title ?? id).join(', ');
    }
    return 'Nessuno';
  }

  List<Registration> get _filteredRegistrations {
    if (_filterStatus == 'tutti') {
      return _registrations.where((r) => r.deletedAt == null).toList();
    }
    return _registrations
        .where((r) => r.deletedAt == null && r.status == _filterStatus)
        .toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'waitlist':
        return Colors.amber;
      case 'confirmed':
      case 'validated':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      case 'published':
        return Colors.purple;
      case 'exported':
      case 'imported':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return '⏳ In attesa';
      case 'waitlist':
        return '⌛ Lista attesa';
      case 'confirmed':
        return '✅ Confermata';
      case 'validated':
        return '✅ Validata (legacy)';
      case 'rejected':
        return '❌ Rifiutata';
      case 'cancelled':
        return '🚫 Cancellata';
      case 'published':
        return '📤 Pubblicata';
      case 'exported':
        return '📤 Esportata';
      case 'imported':
        return '📥 Importata';
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
              Row(
                children: [
                  const Text(
                    '📋 Gestione Iscrizioni',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
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
                  IconButton(
                    onPressed: isSyncing ? null : _loadData,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Ricarica dal DB locale',
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  const Text('Filtra:'),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _filterStatus,
                    items: const [
                      DropdownMenuItem(value: 'tutti', child: Text('📋 Tutti')),
                      DropdownMenuItem(value: 'pending', child: Text('⏳ In attesa')),
                      DropdownMenuItem(value: 'confirmed', child: Text('✅ Confermate')),
                      DropdownMenuItem(value: 'rejected', child: Text('❌ Rifiutate')),
                      DropdownMenuItem(value: 'cancelled', child: Text('🚫 Cancellate')),
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

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredRegistrations.isEmpty
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 64, color: Colors.grey),
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
    final displayName = _getDisplayName(reg);
    final displayEmail = _getDisplayEmail(reg);
    final eventTitle = _getEventTitle(reg.eventId);
    final instrument = _getInstrument(reg);
    final songTitles = _getSongTitles(reg);

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
                        displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (displayEmail != null && displayEmail.isNotEmpty)
                        Text(
                          '📧 $displayEmail',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                  'Strumento: $instrument',
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
            if (reg.timeDescription != null &&
                reg.timeDescription!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.timer, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Momento: ${reg.timeDescription}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ],
            if (reg.notes != null && reg.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '📝 ${reg.notes}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
            if (reg.adminNotes != null && reg.adminNotes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '🔒 Admin: ${reg.adminNotes}',
                style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (reg.status == 'pending' || reg.status == 'waitlist') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatusLocal(reg, 'confirmed'),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Conferma'),
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
                ] else if (reg.status == 'confirmed' ||
                    reg.status == 'rejected') ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Colors.amber.shade800),
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
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              size: 16, color: Colors.purple.shade700),
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