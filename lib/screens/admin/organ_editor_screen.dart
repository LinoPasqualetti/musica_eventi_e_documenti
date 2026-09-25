// lib/screens/admin/organ_editor_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../models/organ.dart';
import '../../models/organ_slot.dart';
import '../../providers/registration_sync_provider.dart';
import 'organ_slot_form.dart';
import 'organ_template_picker_sheet.dart';
import 'organ_wizard_screen.dart';

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

  /// Invia l'organico corrente al backend Web (one-shot push).
  Future<void> _pushToWeb() async {
    if (_organ == null) return;

    if (_slots.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessuno slot da inviare. Aggiungi almeno uno slot.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Chiedi conferma
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invia organico al Web?'),
        content: Text(
          'Verranno inviati ${_slots.length} slot al Web. '
              'Gli slot esistenti sul Web per questo brano verranno sostituiti.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Invia'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (!mounted) return;
    final provider = context.read<RegistrationSyncProvider>();

    // Mostra loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Invio in corso...'),
          ],
        ),
        duration: Duration(minutes: 1),
      ),
    );

    final count = await provider.pushOrganToWeb(
      eventSongId: widget.eventSongId,
      organ: _organ!,
      slots: _slots,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();

    if (count >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Organico inviato: $count slot'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      final err = provider.lastError ?? 'Errore sconosciuto';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $err'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Apre il wizard avanzato di composizione organico (stile Finale).
  Future<void> _openWizard() async {
    if (_organ == null) return;

    // Carica i template disponibili
    final templates = await _db.getAllOrganTemplates();

    if (!mounted) return;

    final result = await showOrganWizard(
      context,
      organId: _organ!.id,
      songTitle: widget.songTitle,
      eventTitle: widget.eventTitle,
      initialSlots: _slots,
      availableTemplates: templates,
    );

    if (result == null) return; // Utente ha annullato

    // Sostituisci gli slot esistenti con quelli del wizard
    try {
      // Elimina i vecchi
      for (final slot in _slots) {
        await _db.deleteOrganSlot(slot.id);
      }
      // Inserisci i nuovi
      for (final slot in result) {
        await _db.insertOrganSlot(slot);
      }
      await _reloadSlots();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Organico aggiornato: ${result.length} slot'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Errore applicazione wizard: $e');
    }
  }

  /// Apre il bottom sheet di selezione template e applica il template scelto.
  Future<void> _applyTemplate() async {
    if (_organ == null) return;

    // Conta slot attuali
    final currentCount = _slots.length;

    final tpl = await showOrganTemplatePicker(
      context,
      organId: _organ!.id,
      currentSlotCount: currentCount,
    );
    if (tpl == null) return;

    // Se ci sono già slot, chiedi conferma
    if (currentCount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sostituire l\'organico?'),
          content: Text(
            'Stai per sostituire i $currentCount slot attuali con quelli '
                'del template "${tpl.name}". L\'operazione non è reversibile.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sostituisci'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    // Applica il template
    try {
      final applied = await _db.applyTemplateToOrgan(
        organId: _organ!.id,
        templateId: tpl.id,
      );
      await _reloadSlots();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Template "${tpl.name}" applicato: $applied slot'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Errore: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Wizard avanzato',
            onPressed: _openWizard,
          ),
          IconButton(
            icon: const Icon(Icons.library_music),
            tooltip: 'Applica template',
            onPressed: _applyTemplate,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            tooltip: 'Invia organico al Web',
            onPressed: _pushToWeb,
          ),
        ],
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