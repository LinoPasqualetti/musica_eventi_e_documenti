// lib/screens/admin/organ_slot_form.dart
import 'package:flutter/material.dart';
import '../../models/organ_slot.dart';

/// Mostra un bottom sheet per creare o modificare uno slot dell'organico.
/// Ritorna:
///   - OrganSlot (nuovo o modificato) se l'utente conferma
///   - null se l'utente annulla
Future<OrganSlot?> showOrganSlotForm({
  required BuildContext context,
  required String organId,
  required List<String> knownInstruments,
  OrganSlot? existing,
}) async {
  return showModalBottomSheet<OrganSlot>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _OrganSlotFormSheet(
        organId: organId,
        knownInstruments: knownInstruments,
        existing: existing,
      ),
    ),
  );
}

class _OrganSlotFormSheet extends StatefulWidget {
  final String organId;
  final List<String> knownInstruments;
  final OrganSlot? existing;

  const _OrganSlotFormSheet({
    required this.organId,
    required this.knownInstruments,
    this.existing,
  });

  @override
  State<_OrganSlotFormSheet> createState() => _OrganSlotFormSheetState();
}

class _OrganSlotFormSheetState extends State<_OrganSlotFormSheet> {
  late OrganSection _selectedSection;
  late TextEditingController _instrumentController;
  late TextEditingController _notesController;
  late int _quantity;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _selectedSection = e?.section ?? OrganSection.ritmica;
    _instrumentController = TextEditingController(text: e?.instrument ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    _quantity = e?.quantity ?? 1;
  }

  @override
  void dispose() {
    _instrumentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final instrument = _instrumentController.text.trim();
    if (instrument.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lo strumento è obbligatorio'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_quantity < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La quantità deve essere almeno 1'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();

    final result = widget.existing == null
        ? OrganSlot(
      id: 'slot_${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}',
      organId: widget.organId,
      section: _selectedSection,
      instrument: instrument,
      quantity: _quantity,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      orderIndex: 0,
      createdAt: now,
      updatedAt: now,
    )
        : widget.existing!.copyWith(
      section: _selectedSection,
      instrument: instrument,
      quantity: _quantity,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      updatedAt: now,
    );

    Navigator.pop(context, result);
  }

  String _randomSuffix() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = DateTime.now().microsecondsSinceEpoch;
    final buf = StringBuffer();
    for (var i = 0; i < 6; i++) {
      buf.write(chars[(rand + i * 7) % chars.length]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isEdit ? '✎ Modifica slot' : '➕ Nuovo slot',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Sezione
            DropdownButtonFormField<OrganSection>(
              value: _selectedSection,
              decoration: const InputDecoration(
                labelText: 'Sezione',
                border: OutlineInputBorder(),
              ),
              items: OrganSection.values.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text('${s.emoji} ${s.label}'),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedSection = v);
              },
            ),
            const SizedBox(height: 12),

            // Strumento con autocomplete
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue tv) {
                final query = tv.text.trim().toLowerCase();
                if (query.isEmpty) return widget.knownInstruments;
                return widget.knownInstruments
                    .where((s) => s.toLowerCase().contains(query))
                    .toList();
              },
              initialValue: TextEditingValue(
                text: _instrumentController.text,
              ),
              onSelected: (value) {
                _instrumentController.text = value;
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                // Collega il controller di Autocomplete al nostro
                if (controller.text != _instrumentController.text) {
                  _instrumentController.text = controller.text;
                }
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Strumento *',
                    border: OutlineInputBorder(),
                    hintText: 'Es. Basso elettrico, Tromba in Bb, Violini I',
                  ),
                  onChanged: (v) => _instrumentController.text = v,
                );
              },
            ),
            const SizedBox(height: 12),

            // Quantità
            Row(
              children: [
                const Text('Quantità:'),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                ),
                Text(
                  '$_quantity',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _quantity++),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Note
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Note (opzionale)',
                border: OutlineInputBorder(),
                hintText: 'Es. con sordina, solo assolo',
              ),
            ),
            const SizedBox(height: 20),

            // Pulsanti
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annulla'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isEdit ? 'Salva' : 'Aggiungi'),
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