// lib/widgets/song_tile.dart
import 'package:flutter/material.dart';
import '../models/song_model.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final int? orderIndex;

  const SongTile({
    Key? key,
    required this.song,
    this.orderIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple.shade100,
          child: Text(
            '${orderIndex ?? 0}',
            style: TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          song.title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: song.composer != null ? Text(song.composer!) : null,
        trailing: IconButton(
          icon: const Icon(Icons.music_note, color: Colors.deepPurple),
          onPressed: () {
            // TODO: Mostra i documenti della canzone
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(song.title),
                content: const Text('Documenti disponibili...'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Chiudi'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}