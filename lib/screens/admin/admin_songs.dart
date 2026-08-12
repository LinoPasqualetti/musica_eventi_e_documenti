// lib/screens/admin/admin_songs.dart
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/song_model.dart';
import '../../models/event_model.dart';
import 'song_form_screen.dart';

class AdminSongs extends StatefulWidget {
  const AdminSongs({Key? key}) : super(key: key);

  @override
  State<AdminSongs> createState() => _AdminSongsState();
}

class _AdminSongsState extends State<AdminSongs> {
  final DatabaseService _db = DatabaseService();
  List<Song> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    try {
      final songs = await _db.getAllSongs();
      setState(() {
        _songs = songs;
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

  Future<void> _deleteSong(Song song) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗑️ Elimina Canzone'),
        content: Text('Sei sicuro di voler eliminare "${song.title}"?'),
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
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _db.deleteSong(song.id);
        await _loadSongs();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Canzone "${song.title}" eliminata'),
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
    }
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
                '🎵 Gestione Canzoni',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _loadSongs,
                icon: const Icon(Icons.refresh),
                label: const Text('Aggiorna'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SongFormScreen(),
                    ),
                  );
                  if (result == true) {
                    await _loadSongs();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Nuova Canzone'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _songs.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Nessuna canzone trovata'),
                  Text('Clicca su "Nuova Canzone" per crearne una'),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _songs.length,
              itemBuilder: (context, index) {
                final song = _songs[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.music_note, color: Colors.deepPurple),
                    title: Text(song.title),
                    subtitle: Text(
                      song.composer ?? 'Compositore sconosciuto',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orange),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SongFormScreen(
                                  song: song,
                                ),
                              ),
                            );
                            if (result == true) {
                              await _loadSongs();
                            }
                          },
                          tooltip: 'Modifica',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteSong(song),
                          tooltip: 'Elimina',
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