# -*- coding: utf-8 -*-
import sys
import io

target = r'C:\musica_eventi_e_documenti\lib\screens\admin\document_form_screen.dart'
anchor = 'await _db.insertDocument(document);'

insert_before = '''      // --- CHECK DUPLICATI ---
      final duplicate = await _db.findDuplicateDocument(document);

      if (duplicate != null) {
        final choice = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Possibile duplicato'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Esiste gia un documento con lo stesso nome e tipo:'),
                const SizedBox(height: 8),
                Text('Nome: ${duplicate.fileName}'),
                Text('ID: ${duplicate.id}'),
                Text('Creato: ${duplicate.createdAt}'),
                const SizedBox(height: 12),
                const Text('Cosa vuoi fare?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: const Text('Annulla'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'new'),
                child: const Text('Salva come nuovo'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'merge'),
                child: const Text('Unisci'),
              ),
            ],
          ),
        );

        if (choice == null || choice == 'cancel') return;

        if (choice == 'merge') {
          final keepExisting = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Unisci documenti'),
              content: const Text(
                'Quale documento vuoi mantenere?\\n\\n'
                '- Tieni esistente: mantiene l ID corrente, aggiorna il contenuto col nuovo\\n'
                '- Tieni nuovo: mantiene il nuovo ID, sposta le relazioni del vecchio',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Tieni esistente'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Tieni nuovo'),
                ),
              ],
            ),
          );

          if (keepExisting == null) return;

          await _db.mergeDocument(
            existingId: duplicate.id,
            newDoc: document,
            keepExisting: keepExisting,
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Documenti uniti con successo'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
          return;
        }
      }

'''

with io.open(target, 'r', encoding='utf-8') as f:
    content = f.read()

if anchor not in content:
    print('ERRORE: anchor non trovato nel file')
    sys.exit(1)

if 'findDuplicateDocument' in content:
    print('ATTENZIONE: la patch sembra gia applicata')
    sys.exit(2)

new_content = content.replace(anchor, insert_before + anchor, 1)

with io.open(target, 'w', encoding='utf-8', newline='') as f:
    f.write(new_content)

print('OK: patch applicata a document_form_screen.dart')