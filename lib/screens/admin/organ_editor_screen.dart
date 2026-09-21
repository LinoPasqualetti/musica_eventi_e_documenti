// lib/screens/admin/organ_editor_screen.dart
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/organ.dart';
import '../../models/organ_slot.dart';
import 'organ_slot_form.dart';

class OrganEditorScreen extends StatefulWidget {
  final String eventSongId;
  final String songTitle;
  final String eventTitle;

  const OrganEditorScreen({
    Key? key,
    required this.eventSongId,
    required this.songTitle,
    required this.eventTitle,
  }) : super(key: key);

  @override
  State<OrganEditorScreen> createState() => _OrganEditorScreenState();
}

class _OrganEditorScreenState extends State<OrganEditorScreen> {
  final DatabaseService _db = DatabaseService();

  Organ? _organ;
  List<OrganSlot> _slots = [];
  List<String> _knownInstruments = [];
  bool _loading = true;

  final Map<OrganSection, bool> _sectionExpanded = {
    OrganSection.ritmica: true,
    OrganSection.armonica: false,
    OrganSection.solistica: false,
    OrganSection.orchestrale: false,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // 1. Carica organici esistenti per questo event_song
      final organs = await _db.getOrgansByEventSong(widget.eventSongId);

      Organ? organ;
      if (organs.isEmpty) {
        // 2. Se non esiste, creane uno "standard"
        final now = DateTime.now().toUtc().toIso8601String();
        organ = Organ(
          id: _db.generateOrganId(),
          eventSongId: widget.eventSongId,
          name: 'Organico standard',
          createdAt: now,
          updatedAt: now,
        );
        await _db.insertOrgan(organ);
      } else {
        organ = organs.first;
      }

      // 3. Carica slot + strumenti noti
      final slots = await _db.getSlotsByOrgan(organ.id);
      final known = await _db.getKnownInstruments();

      setState(() {
        _organ = organ;
        _slots = slots;
        _knownInstruments = known;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateOrganName(String name) async {
    if (_organ == null) return;
    final updated = _organ!.copyWith(
      name: name,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    try {
      await _db.updateOrgan(updated);
      setState(() => _organ = updated);
    } catch (e) {
      _showError('Errore salvataggio nome: $e');
    }
  }

  Future<void> _updateOrganNotes(String notes) async {
    if (_organ == null) return;
    final updated = _organ!.copyWith(
      notes: notes.isEmpty ? null : notes,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    try {
      await _db.updateOrgan(updated);
      setState(() => _organ = updated);
    } catch (e) {
      _showError('Errore salvataggio note: $e');
    }
  }

  Future<void> _addSlot() async {
    if (_organ == null) return;
    final result = await showOrganSlotForm(
      context: context,
      organId: _organ!.id,
      knownInstruments: _knownInstruments,
    );
    if (result == null) return;

    try {
      await _db.insertOrganSlot(result);
      await _reloadSlots();
    } catch (e) {
      _showError('Errore aggiunta slot: $e');
    }
  }

  Future<void> _editSlot(OrganSlot slot) async {
    final result = await showOrganSlotForm(
      context: context,
      organId: slot.organId,
      knownInstruments: _knownInstruments,
      existing: slot,
    );
    if (result == null) return;

    try {
      await _db.updateOrganSlot(result);
      await _reloadSlots();
    } catch (e) {
      _showError('Errore modifica slot: $e');
    }
  }

  Future<void> _deleteSlot(OrganSlot slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina slot'),
        content: Text(
          'Eliminare "${slot.instrument}" (×${slot.quantity}) '
              'dalla sezione ${slot.section.label}?',
        ),
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
    if (confirmed != true) return;

    try {
      await _db.deleteOrganSlot(slot.id);
      await _reloadSlots();
    } catch (e) {
      _showError('Errore eliminazione slot: $e');
    }
  }

  Future<void> _reloadSlots() async {
    if (_organ == null) return;
    final slots = await _db.getSlotsByOrgan(_organ!.id);
    final known = await _db.getKnownInstruments();
    setState(() {
      _slots = slots;
      _knownInstruments = known;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  List<OrganSlot> _slotsBySection(OrganSection section) {
    return _slots.where((s) => s.section == section).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🎼 ${widget.songTitle}'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.eventTitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _organ == null
          ? const Center(child: Text('Errore: organico non caricato'))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Intestazione organico
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: _organ!.name,
                  decoration: const InputDecoration(
                    labelText: 'Nome organico',
                    border: OutlineInputBorder(),
                  ),
                  onFieldSubmitted: _updateOrganName,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _organ!.notes ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Note (opzionale)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  onFieldSubmitted: _updateOrganNotes,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Le 4 sezioni
        ...OrganSection.values.map(_buildSection),
      ],
    );
  }

  Widget _buildSection(OrganSection section) {
    final sectionSlots = _slotsBySection(section);
    final expanded = _sectionExpanded[section] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        key: PageStorageKey('section_${section.dbValue}'),
        initiallyExpanded: expanded,
        onExpansionChanged: (v) {
          setState(() => _sectionExpanded[section] = v);
        },
        leading: Text(
          section.emoji,
          style: const TextStyle(fontSize: 24),
        ),
        title: Text(
          section.label.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: sectionSlots.isEmpty
                    ? Colors.grey.shade200
                    : Colors.deepPurple.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${sectionSlots.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: sectionSlots.isEmpty
                      ? Colors.grey.shade600
                      : Colors.deepPurple.shade700,
                ),
              ),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          if (sectionSlots.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Nessuno strumento in questa sezione',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...sectionSlots.map((slot) => ListTile(
              dense: true,
              title: Text(slot.instrument),
              subtitle: slot.notes != null && slot.notes!.isNotEmpty
                  ? Text(slot.notes!)
                  : null,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.deepPurple.shade50,
                child: Text(
                  '×${slot.quantity}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    tooltip: 'Modifica',
                    onPressed: () => _editSlot(slot),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'Elimina',
                    color: Colors.red,
                    onPressed: () => _deleteSlot(slot),
                  ),
                ],
              ),
            )),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: Text('Aggiungi a ${section.label}'),
              onPressed: _addSlot,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurple,
              ),
            ),
          ),
        ],
      ),
    );
  }
}