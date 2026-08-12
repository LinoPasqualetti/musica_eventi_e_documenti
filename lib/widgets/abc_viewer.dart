import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/song_model.dart';

class AbcViewer extends StatelessWidget {
  final Song song;

  const AbcViewer({Key? key, required this.song}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.music_note, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(child: Text(song.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Text(song.composer, style: TextStyle(color: Colors.grey.shade600)),
            const Divider(),
            const Text('📄 Codice ABC:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  song.abcNotation,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🔜 Prossimamente: visualizzazione pentagramma')),
                      );
                    },
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Vedi pentagramma'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Clipboard.setData(ClipboardData(text: song.abcNotation));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('📄 Copiato negli appunti!')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copia ABC'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
