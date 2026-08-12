// lib/screens/admin/admin_registrations.dart
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/registration_model.dart';
import '../../models/user_model.dart';
import '../../models/event_model.dart';
import '../../models/song_model.dart';

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

      // Carica utenti, eventi e canzoni in cache
      _userCache = {};
      _eventCache = {};
      _songCache = {};

      for (var reg in registrations) {
        // Carica utente se non in cache
        if (!_userCache.containsKey(reg.userId)) {
          final user = await _db.getUserById(reg.userId);
          if (user != null) {
            _userCache[reg.userId] = user;
          }
        }

        // Carica evento se non in cache
        if (!_eventCache.containsKey(reg.eventId)) {
          final event = await _db.getEventById(reg.eventId);
          if (event != null) {
            _eventCache[reg.eventId] = event;
          }
        }

        // Carica canzoni selezionate
        if (reg.selectedSongIds != null) {
          final songIds = reg.selectedSongIds!.split(',');
          for (var songId in songIds) {
            if (!_songCache.containsKey(songId)) {
              final song = await _db.getSongById(songId);
              if (song != null) {
                _songCache[songId] = song;
              }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateStatus(Registration reg, String status) async {
    try {
      await _db.updateRegistrationStatus(reg.id, status);
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Stato aggiornato a $status'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
    final titles = ids
        .map((id) => _songCache[id]?.title ?? id)
        .join(', ');
    return titles;
  }

  List<Registration> get _filteredRegistrations {
    if (_filterStatus == 'tutti') return _registrations;
    return _registrations.where((r) => r.status == _filterStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '📝 Gestione Iscrizioni',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // Filtri
              DropdownButton<String>(
                value: _filterStatus,
                items: const [
                  DropdownMenuItem(value: 'tutti', child: Text('📋 Tutti')),
                  DropdownMenuItem(value: 'pending', child: Text('⏳ In attesa')),
                  DropdownMenuItem(value: 'confirmed', child: Text('✅ Confermate')),
                  DropdownMenuItem(value: 'rejected', child: Text('❌ Rifiutate')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _filterStatus = value);
                  }
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Aggiorna'),
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
                final userName = _getUserFullName(reg.userId);
                final eventTitle = _getEventTitle(reg.eventId);
                final songTitles = _getSongTitles(reg.selectedSongIds);

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
                              backgroundColor: reg.status == 'confirmed'
                                  ? Colors.green
                                  : reg.status == 'rejected'
                                  ? Colors.red
                                  : Colors.orange,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: reg.status == 'confirmed'
                                    ? Colors.green.shade100
                                    : reg.status == 'rejected'
                                    ? Colors.red.shade100
                                    : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                reg.status,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: reg.status == 'confirmed'
                                      ? Colors.green.shade700
                                      : reg.status == 'rejected'
                                      ? Colors.red.shade700
                                      : Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.music_note,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Strumento: ${reg.instrumentChoice ?? 'N/D'}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.library_music,
                              size: 14,
                              color: Colors.grey,
                            ),
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
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.grey,
                            ),
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
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (reg.status == 'pending')
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _updateStatus(reg, 'confirmed'),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Approva'),
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
                                  onPressed: () => _updateStatus(reg, 'rejected'),
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('Rifiuta'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}