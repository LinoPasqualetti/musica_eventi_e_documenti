// C:\musica_eventi_e_documenti\lib\screens\admin\admin_registrations.dart
//
// Vista aggregata Evento â†’ Brano â†’ Strumento â†’ Candidature.
// - Icona evento = immagine dell'evento
// - Tutti i brani mostrati, anche quelli senza candidature
// - Badge inline: Org / Conf / Att / Rif
// - Brani in griglia orizzontale con larghezza DINAMICA
// - Click su un brano â†’ card grande a larghezza piena con strumenti in griglia dinamica
// - Candidature con pulsanti OK/NO
// - 3 filtri: stato, evento, brano

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

// ============================================================
// Modelli locali
// ============================================================
class _RegRow {
  final Registration reg;
  final String name;
  final String? email;
  _RegRow({required this.reg, required this.name, this.email});
}

class _InstrumentGroup {
  final String instrument;
  final String section;
  final int total;
  final List<_RegRow> rows;

  _InstrumentGroup({
    required this.instrument,
    required this.section,
    required this.total,
    required this.rows,
  });

  int get confirmed =>
      rows.where((r) => r.reg.status == 'confirmed').length;
  int get pending => rows
      .where((r) =>
  r.reg.status == 'pending' || r.reg.status == 'waitlist')
      .length;
  int get rejected =>
      rows.where((r) => r.reg.status == 'rejected').length;
  int get cancelled =>
      rows.where((r) => r.reg.status == 'cancelled').length;
}

class _SongGroup {
  final String songId;
  final String songTitle;
  final List<_InstrumentGroup> instruments;

  _SongGroup({
    required this.songId,
    required this.songTitle,
    required this.instruments,
  });

  int get totalOrganico =>
      instruments.fold(0, (s, i) => s + i.total);
  int get confirmed => instruments.fold(0, (s, i) => s + i.confirmed);
  int get pending => instruments.fold(0, (s, i) => s + i.pending);
  int get rejected => instruments.fold(0, (s, i) => s + i.rejected);
}

class _EventGroup {
  final String eventId;
  final String eventTitle;
  final List<_SongGroup> songs;

  _EventGroup({
    required this.eventId,
    required this.eventTitle,
    required this.songs,
  });

  int get totalOrganico =>
      songs.fold(0, (s, e) => s + e.totalOrganico);
  int get confirmed => songs.fold(0, (s, e) => s + e.confirmed);
  int get pending => songs.fold(0, (s, e) => s + e.pending);
  int get rejected => songs.fold(0, (s, e) => s + e.rejected);
}

// ============================================================
// State
// ============================================================
class _AdminRegistrationsState extends State<AdminRegistrations> {
  final DatabaseService _db = DatabaseService();
  List<Registration> _registrations = [];
  List<_EventGroup> _groups = [];

  Map<String, User> _userCache = {};
  Map<String, Event> _eventCache = {};
  Map<String, Song> _songCache = {};
  Map<String, OrganSlot> _organSlotCache = {};

  Map<String, List<OrganSlot>> _organSlotsByEventSong = {};
  Map<String, List<Map<String, dynamic>>> _eventSongsByEvent = {};
  Map<String, String> _eventSongIdMap = {};

  bool _isLoading = true;
  String _filterStatus = 'tutti';
  String _searchEvent = '';
  String _searchSong = '';

  // Quale brano Ã¨ espanso (card grande)
  String? _expandedSongId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ============================================================
  // Layout dinamico
  // ============================================================
  /// Calcola quante colonne e che larghezza usare in base allo spazio.
  ({int columns, double itemWidth}) _layoutFor(double maxWidth) {
    const spacing = 8.0;
    const minWidth = 260.0;
    for (int n = 5; n >= 1; n--) {
      final itemWidth = (maxWidth - spacing * (n - 1)) / n;
      if (itemWidth >= minWidth) {
        return (columns: n, itemWidth: itemWidth);
      }
    }
    return (columns: 1, itemWidth: maxWidth);
  }

  // ============================================================
  // Caricamento
  // ============================================================
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final registrations = await _db.getAllRegistrations();

      _userCache = {};
      _eventCache = {};
      _songCache = {};
      _organSlotCache = {};

      for (var reg in registrations) {
        if (reg.userId.isNotEmpty &&
            !_userCache.containsKey(reg.userId)) {
          final user = await _db.getUserById(reg.userId);
          if (user != null) _userCache[reg.userId] = user;
        }
        if (reg.eventId.isNotEmpty &&
            !_eventCache.containsKey(reg.eventId)) {
          final event = await _db.getEventById(reg.eventId);
          if (event != null) _eventCache[reg.eventId] = event;
        }
        final slotId = reg.organSlotId;
        if (slotId != null &&
            slotId.isNotEmpty &&
            !_organSlotCache.containsKey(slotId)) {
          final slot = await _db.getOrganSlotById(slotId);
          if (slot != null) _organSlotCache[slotId] = slot;
        }
        if (reg.songId != null &&
            reg.songId!.isNotEmpty &&
            !_songCache.containsKey(reg.songId!)) {
          final song = await _db.getSongById(reg.songId!);
          if (song != null) _songCache[reg.songId!] = song;
        }
      }

      _organSlotsByEventSong =
      await _db.getAllOrganSlotsGroupedByEventSong();
      _eventSongIdMap = await _db.getEventSongIdMap();

      final allEvents = await _db.getAllEvents();
      _eventSongsByEvent = {};
      for (final ev in allEvents) {
        _eventCache[ev.id] = ev;
        _eventSongsByEvent[ev.id] =
        await _db.getAllEventSongsWithSongTitle(ev.id);
      }

      setState(() {
        _registrations = registrations;
        _groups = _buildGroups(registrations);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('Errore: $e', isError: true);
    }
  }

  // ============================================================
  // Costruzione gruppi
  // ============================================================
  List<_EventGroup> _buildGroups(List<Registration> regs) {
    final filtered = _filterStatus == 'tutti'
        ? regs.where((r) => r.deletedAt == null).toList()
        : regs
        .where((r) =>
    r.deletedAt == null && r.status == _filterStatus)
        .toList();

    final map = <String, Map<String, Map<String, List<_RegRow>>>>{};
    for (final reg in filtered) {
      final eventId = reg.eventId;
      final songId = reg.songId ?? '';
      final slot = reg.organSlotId != null
          ? _organSlotCache[reg.organSlotId!]
          : null;
      final instrument = slot?.instrument ?? 'N/D';

      map.putIfAbsent(eventId, () => {});
      map[eventId]!.putIfAbsent(songId, () => {});
      map[eventId]![songId]!.putIfAbsent(instrument, () => []);

      final name = _getDisplayName(reg);
      final email = _getDisplayEmail(reg);
      map[eventId]![songId]![instrument]!.add(
        _RegRow(reg: reg, name: name, email: email),
      );
    }

    final events = <_EventGroup>[];
    for (final eventEntry in _eventSongsByEvent.entries) {
      final eventId = eventEntry.key;
      final eventTitle = _eventCache[eventId]?.title ?? eventId;

      final songs = <_SongGroup>[];
      final processedSongIds = <String>{};

      // 1. Brani da event_song
      for (final es in eventEntry.value) {
        final songId = es['song_id'] as String?;
        if (songId == null || songId.isEmpty) continue;
        if (processedSongIds.contains(songId)) continue;
        processedSongIds.add(songId);

        final eventSongId = es['event_song_id'] as String?;
        final songTitle = (es['song_title'] as String?) ??
            _songCache[songId]?.title ??
            songId;

        final allSlots = eventSongId != null
            ? (_organSlotsByEventSong[eventSongId] ?? [])
            : [];

        final totals = <String, int>{};
        for (final s in allSlots) {
          final key = '${s.instrument}::${s.section.dbValue}';
          totals[key] =
              (totals[key] ?? 0) + ((s.quantity ?? 1) as num).toInt();
        }

        final songRegs = map[eventId]?[songId] ?? {};

        final instrumentNames = <String>{};
        for (final s in allSlots) instrumentNames.add(s.instrument);
        for (final inst in songRegs.keys) instrumentNames.add(inst);

        final instruments = <_InstrumentGroup>[];
        for (final instrument in instrumentNames) {
          final rows = songRegs[instrument] ?? [];

          String sectionStr = 'altro';
          for (final s in allSlots) {
            if (s.instrument == instrument) {
              sectionStr = s.section.dbValue;
              break;
            }
          }
          if (sectionStr == 'altro') {
            for (final r in rows) {
              if (r.reg.organSlotId != null) {
                final s = _organSlotCache[r.reg.organSlotId!];
                if (s != null) {
                  sectionStr = s.section.dbValue;
                  break;
                }
              }
            }
          }

          final totalKey = '$instrument::$sectionStr';
          final total = totals[totalKey] ?? 0;

          instruments.add(_InstrumentGroup(
            instrument: instrument,
            section: sectionStr,
            total: total,
            rows: rows,
          ));
        }

        instruments.sort((a, b) {
          final cmp = a.section.compareTo(b.section);
          return cmp != 0 ? cmp : a.instrument.compareTo(b.instrument);
        });

        songs.add(_SongGroup(
          songId: songId,
          songTitle: songTitle,
          instruments: instruments,
        ));
      }

      // 2. Brani orfani
      for (final songId in (map[eventId] ?? {}).keys) {
        if (processedSongIds.contains(songId)) continue;
        processedSongIds.add(songId);

        final songTitle = songId.isEmpty
            ? '(brano non specificato)'
            : (_songCache[songId]?.title ?? songId);

        final songRegs = map[eventId]![songId]!;
        final instruments = <_InstrumentGroup>[];
        for (final instEntry in songRegs.entries) {
          final instrument = instEntry.key;
          final rows = instEntry.value;

          String sectionStr = 'altro';
          for (final r in rows) {
            if (r.reg.organSlotId != null) {
              final s = _organSlotCache[r.reg.organSlotId!];
              if (s != null) {
                sectionStr = s.section.dbValue;
                break;
              }
            }
          }

          instruments.add(_InstrumentGroup(
            instrument: instrument,
            section: sectionStr,
            total: rows.length,
            rows: rows,
          ));
        }

        instruments.sort((a, b) {
          final cmp = a.section.compareTo(b.section);
          return cmp != 0 ? cmp : a.instrument.compareTo(b.instrument);
        });

        songs.add(_SongGroup(
          songId: songId,
          songTitle: songTitle,
          instruments: instruments,
        ));
      }

      songs.sort((a, b) => a.songTitle.compareTo(b.songTitle));
      events.add(_EventGroup(
        eventId: eventId,
        eventTitle: eventTitle,
        songs: songs,
      ));
    }

    events.sort((a, b) => a.eventTitle.compareTo(b.eventTitle));
    return events;
  }

  // ============================================================
  // Filtri
  // ============================================================
  List<_EventGroup> get _filteredGroups {
    if (_searchEvent.isEmpty && _searchSong.isEmpty) return _groups;

    final result = <_EventGroup>[];
    for (final ev in _groups) {
      final eventMatches = _searchEvent.isEmpty ||
          ev.eventTitle.toLowerCase().contains(_searchEvent);
      if (!eventMatches) continue;

      final songsToInclude = _searchSong.isEmpty
          ? ev.songs
          : ev.songs
          .where((s) =>
          s.songTitle.toLowerCase().contains(_searchSong))
          .toList();
      if (songsToInclude.isEmpty) continue;

      result.add(_EventGroup(
        eventId: ev.eventId,
        eventTitle: ev.eventTitle,
        songs: songsToInclude,
      ));
    }
    return result;
  }

  // ============================================================
  // Azioni
  // ============================================================
  Future<void> _updateStatusLocal(Registration reg, String newStatus) async {
    try {
      await _db.setRegistrationStatusLocal(reg.id, newStatus);
      await _loadData();
      _showSnack('âœ… Stato aggiornato a "$newStatus"');
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
      _showSnack('âš ï¸ $err', isError: true);
    } else {
      _showSnack(
          'âœ… Sincronizzate ${provider.state.lastPulled} nuove iscrizioni');
    }
    await _loadData();
  }

  Future<void> _publishToWeb() async {
    final provider = context.read<RegistrationSyncProvider>();
    await provider.pushDirty();
    if (!mounted) return;
    final err = provider.lastError;
    if (err != null) {
      _showSnack('âš ï¸ $err', isError: true);
    } else {
      _showSnack(
          'âœ… Pubblicate ${provider.state.lastPushed} iscrizioni sul web');
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

  // ============================================================
  // Helper
  // ============================================================
  String _getDisplayName(Registration reg) {
    if (reg.candidateName != null &&
        reg.candidateName!.trim().isNotEmpty) {
      return reg.candidateName!;
    }
    final user = _userCache[reg.userId];
    if (user != null && user.fullName.trim().isNotEmpty) {
      return user.fullName;
    }
    return reg.userId;
  }

  String? _getDisplayEmail(Registration reg) {
    if (reg.candidateEmail != null &&
        reg.candidateEmail!.trim().isNotEmpty) {
      return reg.candidateEmail;
    }
    return _userCache[reg.userId]?.email;
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
        return 'â³';
      case 'waitlist':
        return 'âŒ›';
      case 'confirmed':
        return 'âœ…';
      case 'validated':
        return 'âœ…';
      case 'rejected':
        return 'âŒ';
      case 'cancelled':
        return 'ðŸš«';
      case 'published':
        return 'ðŸ“¤';
      case 'exported':
        return 'ðŸ“¤';
      case 'imported':
        return 'ðŸ“¥';
      default:
        return status;
    }
  }

  Widget _statBadgeSmall(String label, int value, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Consumer<RegistrationSyncProvider>(
      builder: (context, syncProvider, _) {
        final isSyncing = syncProvider.isRunning;

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Text(
                    'ðŸ“‹ Gestione Iscrizioni',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: isSyncing ? null : _syncFromWeb,
                    icon: isSyncing
                        ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2))
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
              const SizedBox(height: 6),

              // Filtri
              Row(
                children: [
                  const Text('Stato:'),
                  const SizedBox(width: 6),
                  DropdownButton<String>(
                    value: _filterStatus,
                    items: const [
                      DropdownMenuItem(
                          value: 'tutti', child: Text('ðŸ“‹ Tutti')),
                      DropdownMenuItem(
                          value: 'pending', child: Text('â³ In attesa')),
                      DropdownMenuItem(
                          value: 'confirmed',
                          child: Text('âœ… Confermate')),
                      DropdownMenuItem(
                          value: 'rejected', child: Text('âŒ Rifiutate')),
                      DropdownMenuItem(
                          value: 'cancelled',
                          child: Text('ðŸš« Cancellate')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _filterStatus = v);
                        _loadData();
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Cerca evento...',
                        prefixIcon: Icon(Icons.event, size: 16),
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (v) {
                        setState(
                                () => _searchEvent = v.trim().toLowerCase());
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Cerca brano...',
                        prefixIcon: Icon(Icons.music_note, size: 16),
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (v) {
                        setState(
                                () => _searchSong = v.trim().toLowerCase());
                      },
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_filteredGroups.length} eventi Â· '
                        '${_filteredGroups.fold<int>(0, (s, g) => s + g.songs.length)} brani',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Lista
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredGroups.isEmpty
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
                  itemCount: _filteredGroups.length,
                  itemBuilder: (context, i) =>
                      _buildEventTile(_filteredGroups[i], i),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // Widget: Evento
  // ============================================================
  Widget _buildEventTile(_EventGroup ev, int index) {
    final imageUrl = _eventCache[ev.eventId]?.imageUrl;
    final hasExpandedSong = _expandedSongId != null &&
        ev.songs.any((s) => s.songId == _expandedSongId);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: ExpansionTile(
        key: PageStorageKey('ev-$index'),
        initiallyExpanded: false,
        tilePadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
              ? NetworkImage(imageUrl)
              : null,
          child: (imageUrl == null || imageUrl.isEmpty)
              ? const Icon(Icons.event, color: Colors.deepPurple)
              : null,
        ),
        title: Text(
          ev.eventTitle,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              _statBadgeSmall(
                  'Org', ev.totalOrganico, Colors.blue, Colors.white),
              const SizedBox(width: 4),
              _statBadgeSmall('Con', ev.confirmed, Colors.white,
                  Colors.green.shade800),
              const SizedBox(width: 4),
              _statBadgeSmall('Att', ev.pending, Colors.black,
                  Colors.yellow.shade700),
              const SizedBox(width: 4),
              _statBadgeSmall('Rif', ev.rejected, Colors.white,
                  Colors.red.shade700),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Griglia pillole-brani DINAMICA
                LayoutBuilder(
                  builder: (context, constraints) {
                    final layout = _layoutFor(constraints.maxWidth);
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ev.songs
                          .map((s) =>
                          _buildSongPill(s, layout.itemWidth))
                          .toList(),
                    );
                  },
                ),
                // Card brano espanso
                if (hasExpandedSong)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _buildExpandedSong(
                      ev.songs.firstWhere(
                              (s) => s.songId == _expandedSongId),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Widget: pillola-brano
  // ============================================================
  Widget _buildSongPill(_SongGroup song, double width) {
    final isExpanded = _expandedSongId == song.songId;

    return InkWell(
      onTap: () {
        setState(() {
          _expandedSongId = isExpanded ? null : song.songId;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: width,
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isExpanded
              ? Colors.deepPurple.shade50
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isExpanded
                ? Colors.deepPurple
                : Colors.grey.shade300,
            width: isExpanded ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 14,
              color: isExpanded ? Colors.deepPurple : Colors.grey,
            ),
            const SizedBox(width: 4),
            const Icon(Icons.music_note,
                color: Colors.deepPurple, size: 14),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                song.songTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
            const SizedBox(width: 4),
            _statBadgeSmall('Org', song.totalOrganico, Colors.blue,
                Colors.white),
            const SizedBox(width: 2),
            _statBadgeSmall('Con', song.confirmed, Colors.white,
                Colors.green.shade800),
            const SizedBox(width: 2),
            _statBadgeSmall('Att', song.pending, Colors.black,
                Colors.yellow.shade700),
            const SizedBox(width: 2),
            _statBadgeSmall('Rif', song.rejected, Colors.white,
                Colors.red.shade700),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Widget: brano espanso (card grande)
  // ============================================================
  Widget _buildExpandedSong(_SongGroup song) {
    return Card(
      elevation: 2,
      color: Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.deepPurple.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.music_note,
                    color: Colors.deepPurple, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    song.songTitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                _statBadgeSmall('Org', song.totalOrganico, Colors.blue,
                    Colors.white),
                const SizedBox(width: 4),
                _statBadgeSmall('Con', song.confirmed, Colors.white,
                    Colors.green.shade800),
                const SizedBox(width: 4),
                _statBadgeSmall('Att', song.pending, Colors.black,
                    Colors.yellow.shade700),
                const SizedBox(width: 4),
                _statBadgeSmall('Rif', song.rejected, Colors.white,
                    Colors.red.shade700),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Chiudi',
                  onPressed: () {
                    setState(() => _expandedSongId = null);
                  },
                ),
              ],
            ),
            const Divider(height: 8),
            // Strumenti con larghezza DINAMICA
            LayoutBuilder(
              builder: (context, constraints) {
                final layout = _layoutFor(constraints.maxWidth);
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: song.instruments
                      .map((g) => SizedBox(
                    width: layout.itemWidth,
                    child: _buildInstrumentTile(g),
                  ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Widget: strumento
  // ============================================================
  Widget _buildInstrumentTile(_InstrumentGroup g) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200, width: 0.5),
      ),
      child: ExpansionTile(
        key: PageStorageKey('inst-${g.instrument}-${g.section}'),
        initiallyExpanded: false,
        tilePadding:
        const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        childrenPadding: const EdgeInsets.all(4),
        dense: true,
        title: Row(
          children: [
            const Icon(Icons.piano, size: 12, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                g.instrument,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 4),
            _statBadgeSmall(
                'Org', g.total, Colors.blue, Colors.white),
            const SizedBox(width: 2),
            _statBadgeSmall('Con', g.confirmed, Colors.white,
                Colors.green.shade800),
            const SizedBox(width: 2),
            _statBadgeSmall('Att', g.pending, Colors.black,
                Colors.yellow.shade700),
            const SizedBox(width: 2),
            _statBadgeSmall('Rif', g.rejected, Colors.white,
                Colors.red.shade700),
          ],
        ),
        subtitle: null,
        children: g.rows.map(_buildRegistrationRow).toList(),
      ),
    );
  }

  // ============================================================
  // Widget: candidatura
  // ============================================================
  Widget _buildRegistrationRow(_RegRow row) {
    final reg = row.reg;
    final color = _statusColor(reg.status);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 3)),
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 8,
                backgroundColor: color,
                child: Text(
                  reg.status[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    if (row.email != null && row.email!.isNotEmpty)
                      Text(
                        row.email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
              Text(
                _statusLabel(reg.status),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          if (reg.timeDescription != null &&
              reg.timeDescription!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 22),
              child: Text(
                'â± ${reg.timeDescription}',
                style: const TextStyle(
                    fontSize: 10, color: Colors.grey),
              ),
            ),
          if (reg.notes != null && reg.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 22),
              child: Text(
                'ðŸ“ ${reg.notes}',
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade700),
              ),
            ),
          if (reg.status == 'pending' || reg.status == 'waitlist')
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 22),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 24,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _updateStatusLocal(reg, 'confirmed'),
                        icon: const Icon(Icons.check, size: 12),
                        label: const Text('OK',
                            style: TextStyle(fontSize: 10)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SizedBox(
                      height: 24,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _updateStatusLocal(reg, 'rejected'),
                        icon: const Icon(Icons.close, size: 12),
                        label: const Text('NO',
                            style: TextStyle(fontSize: 10)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
