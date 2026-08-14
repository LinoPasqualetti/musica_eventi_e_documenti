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
  Map<String, int> _documentsCount = {};
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

      final countMap = await _db.getRegistrationsCountBySongForEvent(widget.event.id);
      final instrumentsMap = await _db.getInstrumentsBySongForEvent(widget.event.id);
      final docsCountMap = await _db.getDocumentsCountBySong();

      setState(() {
        _allSongs = allSongs;
        _assignedSongs = assignedSongs;
        _registrationsCount = countMap;
        _instrumentsBySong = instrumentsMap;
        _documentsCount = docsCountMap;
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

  Future<void> _createAndAddSong(String title) async {
    final composerController = TextEditingController();
    final showResult = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎵 Nuovo Brano'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: composerController,
              decoration: const InputDecoration(
                labelText: 'Compositore (opzionale)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Titolo: "$title"',
              style: const TextStyle(fontWeight: FontWeight.bold),
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
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Crea e Aggiungi'),
          ),
        ],
      ),
    );

    if (showResult == true) {
      try {
        final newSong = Song(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          composer: composerController.text.isNotEmpty ? composerController.text : null,
          createdBy: 'admin',
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: null,
          difficulty: null,
          genre: null,
          durationSeconds: null,
          tempo: null,
          keySignature: null,
          timeSignature: null,
          lyrics: null,
        );

        await _db.insertSong(newSong);
        await _loadData();

        final createdSong = _allSongs.firstWhere(
              (s) => s.title == title && s.composer == composerController.text,
          orElse: () => _allSongs.last,
        );

        if (createdSong.id.isNotEmpty) {
          await _addSong(createdSong);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Brano creato e aggiunto alla scaletta!'),
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
  }

  Widget _buildDocumentIndicator(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: count > 0 ? Colors.blue.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.description,
            size: 14,
            color: count > 0 ? Colors.blue.shade700 : Colors.grey.shade500,
          ),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              color: count > 0 ? Colors.blue.shade700 : Colors.grey.shade500,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationIndicator(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: count > 0 ? Colors.green.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '👥 $count',
        style: TextStyle(
          fontSize: 12,
          color: count > 0 ? Colors.green.shade700 : Colors.grey.shade600,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Dialog per aggiungere un brano esistente
  Future<void> _showAddSongDialog() async {
    final TextEditingController _searchController = TextEditingController();
    String searchQuery = '';

    // Filtra i brani disponibili (non ancora assegnati)
    final availableSongs = _allSongs
        .where((song) => !_assignedSongs.any((s) => s.id == song.id))
        .toList();

    // Se non ci sono brani disponibili, suggerisci di crearne uno
    if (availableSongs.isEmpty) {
      final createNew = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('📚 Nessun brano disponibile'),
          content: const Text(
            'Tutti i brani sono già stati assegnati a questo evento.\n'
                'Vuoi crearne uno nuovo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Crea Nuovo Brano'),
            ),
          ],
        ),
      );

      if (createNew == true) {
        _showCreateNewSongDialog('');
      }
      return;
    }

    // Mostra il dialog con la lista filtrata
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final filteredSongs = availableSongs.where((song) {
              if (searchQuery.isEmpty) return true;
              return song.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  (song.composer?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Text(
                        '📚 Aggiungi Brano',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Chiudi'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Barra di ricerca
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cerca brani...',
                      prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setStateModal(() {
                            searchQuery = '';
                          });
                        },
                      )
                          : null,
                    ),
                    onChanged: (value) {
                      setStateModal(() {
                        searchQuery = value;
                      });
                    },
                    onSubmitted: (value) {
                      if (value.isNotEmpty && filteredSongs.isEmpty) {
                        Navigator.pop(context);
                        _showCreateNewSongDialog(value);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  // Pulsante "Crea Nuovo Brano"
                  Row(
                    children: [
                      const Icon(Icons.add_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showCreateNewSongDialog('');
                        },
                        child: const Text(
                          'Crea nuovo brano',
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${filteredSongs.length} brani disponibili',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  const Divider(),
                  // Lista brani
                  Expanded(
                    child: filteredSongs.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            searchQuery.isEmpty
                                ? 'Nessun brano disponibile'
                                : 'Nessun brano trovato per "$searchQuery"',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (searchQuery.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showCreateNewSongDialog(searchQuery);
                              },
                              icon: const Icon(Icons.add_circle),
                              label: Text(
                                'Crea "$searchQuery"',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                        : ListView.builder(
                      itemCount: filteredSongs.length,
                      itemBuilder: (context, index) {
                        final song = filteredSongs[index];
                        final docsCount = _documentsCount[song.id] ?? 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            leading: const Icon(
                              Icons.music_note,
                              color: Colors.deepPurple,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(song.title),
                                ),
                                _buildDocumentIndicator(docsCount),
                              ],
                            ),
                            subtitle: song.composer != null
                                ? Text(song.composer!)
                                : null,
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.add_circle,
                                color: Colors.green,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _addSong(song);
                              },
                              tooltip: 'Aggiungi',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Dialog per creare un nuovo brano
  Future<void> _showCreateNewSongDialog(String title) async {
    if (title.isEmpty) {
      final titleController = TextEditingController();
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('🎵 Nuovo Brano'),
          content: TextField(
            controller: titleController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Titolo del brano',
              border: OutlineInputBorder(),
              hintText: 'Inserisci il titolo...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  Navigator.pop(context, true);
                  _createAndAddSong(titleController.text);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Crea e Aggiungi'),
            ),
          ],
        ),
      );
      return;
    }

    _createAndAddSong(title);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🎵 Brani per: ${widget.event.title}'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _showAddSongDialog,
            tooltip: 'Aggiungi brano',
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
            // Intestazione
            Row(
              children: [
                const Text(
                  '🎵 Brani in scaletta',
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

            // Lista brani assegnati
            if (_assignedSongs.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.music_off,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Nessun brano in scaletta',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Premi il pulsante + per aggiungere brani',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _assignedSongs.length,
                  itemBuilder: (context, index) {
                    final song = _assignedSongs[index];
                    final count = _registrationsCount[song.id] ?? 0;
                    final instruments = _instrumentsBySong[song.id] ?? [];
                    final docsCount = _documentsCount[song.id] ?? 0;

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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            _buildDocumentIndicator(docsCount),
                            const SizedBox(width: 8),
                            _buildRegistrationIndicator(count),
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
                                    materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
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
          ],
        ),
      ),
    );
  }
}