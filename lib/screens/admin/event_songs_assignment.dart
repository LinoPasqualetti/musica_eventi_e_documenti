// lib/screens/admin/event_songs_assignment.dart
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/event_model.dart';
import '../../models/song_model.dart';
import '../../models/registration_model.dart';
import 'song_form_screen.dart';

class EventSongsAssignment extends StatefulWidget {
  final Event event;
  const EventSongsAssignment({Key? key, required this.event}) : super(key: key);

  @override
  State<EventSongsAssignment> createState() => _EventSongsAssignmentState();
}

class _EventSongsAssignmentState extends State<EventSongsAssignment> {
  final DatabaseService _db = DatabaseService();
  List<Song> _allSongs = [];
  List<Song> _assignedSongs = [];
  Map<String, int> _registrationsCount = {};
  Map<String, List<String>> _instrumentsBySong = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final allSongs = await _db.getAllSongs();
      final assignedSongs = await _db.getSongsByEvent(widget.event.id);

      // Ottieni conteggio iscritti per brano
      final countMap = await _db.getRegistrationsCountBySongForEvent(widget.event.id);

      // Ottieni strumenti per brano
      final instrumentsMap = await _db.getInstrumentsBySongForEvent(widget.event.id);

      setState(() {
        _allSongs = allSongs;
        _assignedSongs = assignedSongs;
        _registrationsCount = countMap;
        _instrumentsBySong = instrumentsMap;
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

  Future<void> _addSong(Song song) async {
    try {
      final maxOrder = _assignedSongs.isEmpty ? 0 : _assignedSongs.length;

      await _db.addSongToEvent(widget.event.id, song.id, orderIndex: maxOrder + 1);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "${song.title}" aggiunto all\'evento'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeSong(Song song) async {
    try {
      await _db.removeSongFromEvent(widget.event.id, song.id);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ "${song.title}" rimosso dall\'evento'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createNewSong() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongFormScreen(
          events: [widget.event],
        ),
      ),
    );

    if (result == true) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Brano creato! Aggiungilo alla lista usando il pulsante verde.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableSongs = _allSongs
        .where((song) => !_assignedSongs.any((s) => s.id == song.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('🎵 Brani per: ${widget.event.title}'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _createNewSong,
            tooltip: 'Nuovo Brano',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
            tooltip: 'Aggiorna',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brani assegnati
            Row(
              children: [
                const Text(
                  '🎵 Brani assegnati',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_assignedSongs.length} brani',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_assignedSongs.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('Nessun brano assegnato a questo evento'),
                ),
              )
            else
              Expanded(
                flex: 1,
                child: ListView.builder(
                  itemCount: _assignedSongs.length,
                  itemBuilder: (context, index) {
                    final song = _assignedSongs[index];
                    final count = _registrationsCount[song.id] ?? 0;
                    final instruments = _instrumentsBySong[song.id] ?? [];

                    return Card(
                      key: Key(song.id),
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple.shade100,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                song.title,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: count > 0
                                    ? Colors.green.shade100
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '👥 $count',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: count > 0
                                      ? Colors.green.shade700
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle,
                                color: Colors.red,
                              ),
                              onPressed: () => _removeSong(song),
                              tooltip: 'Rimuovi',
                              iconSize: 20,
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (song.composer != null)
                              Text('Compositore: ${song.composer}'),
                            if (instruments.isNotEmpty)
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: instruments.map((instrument) {
                                  return Chip(
                                    label: Text(
                                      instrument,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    backgroundColor: Colors.deepPurple.shade50,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  );
                                }).toList(),
                              ),
                            if (instruments.isEmpty && count > 0)
                              const Text(
                                'Strumenti non specificati',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const Divider(height: 32),

            // Brani disponibili
            Row(
              children: [
                const Text(
                  '📚 Brani disponibili',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${availableSongs.length} brani',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 1,
              child: availableSongs.isEmpty
                  ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('Tutti i brani sono già assegnati'),
                ),
              )
                  : ListView.builder(
                itemCount: availableSongs.length,
                itemBuilder: (context, index) {
                  final song = availableSongs[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      leading: const Icon(
                        Icons.music_note,
                        color: Colors.deepPurple,
                      ),
                      title: Text(song.title),
                      subtitle: song.composer != null
                          ? Text(song.composer!)
                          : null,
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.add_circle,
                          color: Colors.green,
                        ),
                        onPressed: () => _addSong(song),
                        tooltip: 'Aggiungi',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}