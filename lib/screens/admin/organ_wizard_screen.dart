// lib/screens/admin/organ_wizard_screen.dart
import 'package:flutter/material.dart';
import '../../data/instrument_catalog.dart';
import '../../models/organ.dart';
import '../../models/organ_slot.dart';
import '../../models/organ_template.dart';
import '../../services/database_service.dart';
import '../../models/organ_template_slot.dart';

/// Wizard per comporre un organico in stile Finale: 3 colonne
/// (sezioni | strumenti | organico corrente).
///
/// Ritorna una lista di [OrganSlot] se l'utente conferma, altrimenti null.
Future<List<OrganSlot>?> showOrganWizard(
    BuildContext context, {
      required String organId,
      required String songTitle,
      required String eventTitle,
      required List<OrganSlot> initialSlots,
      required List<OrganTemplate> availableTemplates,
    }) {
  return Navigator.push<List<OrganSlot>>(
    context,
    MaterialPageRoute(
      builder: (_) => OrganWizardScreen(
        organId: organId,
        songTitle: songTitle,
        eventTitle: eventTitle,
        initialSlots: initialSlots,
        availableTemplates: availableTemplates,
      ),
    ),
  );
}

class OrganWizardScreen extends StatefulWidget {
  final String organId;
  final String songTitle;
  final String eventTitle;
  final List<OrganSlot> initialSlots;
  final List<OrganTemplate> availableTemplates;

  const OrganWizardScreen({
    Key? key,
    required this.organId,
    required this.songTitle,
    required this.eventTitle,
    required this.initialSlots,
    required this.availableTemplates,
  }) : super(key: key);

  @override
  State<OrganWizardScreen> createState() => _OrganWizardScreenState();
}

class _OrganWizardScreenState extends State<OrganWizardScreen> {
  final DatabaseService _db = DatabaseService();

  // Sezione selezionata nella colonna 1
  OrganSection? _selectedSection;

  // Slot correnti dell'organico (working copy)
  late List<_WizardSlot> _slots;

  // Template selezionato nel dropdown
  OrganTemplate? _selectedTemplate;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Converti gli slot esistenti in working copy
    _slots = widget.initialSlots
        .map((s) => _WizardSlot.fromOrganSlot(s))
        .toList();
    _loading = false;
  }

  // ============================================
  // AZIONI
  // ============================================

  void _addInstrument(String instrument) {
    final section = InstrumentCatalog.findSection(instrument);
    if (section == null) return;

    // Se esiste già, incrementa quantity
    final existingIdx = _slots.indexWhere(
          (s) => s.instrument == instrument && s.section == section,
    );
    setState(() {
      if (existingIdx >= 0) {
        _slots[existingIdx].quantity++;
      } else {
        _slots.add(_WizardSlot(
          section: section,
          instrument: instrument,
          quantity: 1,
          orderIndex: _slots.length,
        ));
      }
    });
  }

  void _removeSlot(int index) {
    setState(() {
      _slots.removeAt(index);
    });
  }

  void _changeQuantity(int index, int delta) {
    setState(() {
      final newQty = _slots[index].quantity + delta;
      if (newQty <= 0) {
        _slots.removeAt(index);
      } else {
        _slots[index].quantity = newQty;
      }
    });
  }

  Future<void> _loadTemplate(OrganTemplate tpl) async {
    try {
      final slots = await _db.getOrganTemplateSlots(tpl.id);
      setState(() {
        _slots = slots
            .map((s) => _WizardSlot(
          section: s.section,
          instrument: s.instrument,
          quantity: s.quantity,
          orderIndex: s.orderIndex,
        ))
            .toList();
        _selectedTemplate = tpl;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template "${tpl.name}" caricato'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      _showError('Errore caricamento template: $e');
    }
  }

  Future<void> _saveAsNewTemplate() async {
    if (_slots.isEmpty) {
      _showError('Aggiungi almeno uno strumento prima di salvare');
      return;
    }

    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salva come nuovo ensemble'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome ensemble *',
                hintText: 'Es. "Combo Jazz Custom"',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descrizione (opzionale)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final tplId = 'tpl_${DateTime.now().millisecondsSinceEpoch}';

      final template = OrganTemplate(
        id: tplId,
        name: name,
        category: 'Personalizzati',
        description: descCtrl.text.trim().isEmpty
            ? 'Ensemble personalizzato'
            : descCtrl.text.trim(),
        createdAt: now,
      );

      await _db.insertOrganTemplate(template);

      // Inserisci gli slot
      for (int i = 0; i < _slots.length; i++) {
        final s = _slots[i];
        final now = DateTime.now().toUtc().toIso8601String();
        await _db.insertOrganTemplateSlot(OrganTemplateSlot(
          id: 'tplslot_${DateTime.now().microsecondsSinceEpoch}_$i',
          templateId: tplId,
          section: s.section,
          instrument: s.instrument,
          quantity: s.quantity,
          orderIndex: i,
          createdAt: now,
        ));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Ensemble "$name" salvato'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Errore salvataggio ensemble: $e');
    }
  }

  void _resetSlots() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Svuotare l\'organico?'),
        content: const Text('Tutti gli strumenti verranno rimossi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _slots.clear());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Svuota'),
          ),
        ],
      ),
    );
  }

  void _confirm() {
    if (_slots.isEmpty) {
      _showError('Aggiungi almeno uno strumento');
      return;
    }

    // Converti in OrganSlot
    final now = DateTime.now().toUtc().toIso8601String();
    final result = <OrganSlot>[];
    for (int i = 0; i < _slots.length; i++) {
      final s = _slots[i];
      result.add(OrganSlot(
        id: _db.generateSlotId(),
        organId: widget.organId,
        section: s.section,
        instrument: s.instrument,
        quantity: s.quantity,
        orderIndex: i,
        createdAt: now,
      ));
    }
    Navigator.pop(context, result);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ============================================
  // BUILD
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎼 Composizione Organico', style: TextStyle(fontSize: 16)),
            Text(
              '${widget.songTitle} — ${widget.eventTitle}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Salva come nuovo ensemble',
            onPressed: _saveAsNewTemplate,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Svuota',
            onPressed: _resetSlots,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildTemplateSelector(),
          const Divider(height: 1),
          Expanded(child: _buildThreeColumnLayout()),
          const Divider(height: 1),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildTemplateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          const Icon(Icons.folder_open, color: Colors.deepPurple, size: 20),
          const SizedBox(width: 12),
          const Text('Carica ensemble:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<OrganTemplate>(
              value: _selectedTemplate,
              isExpanded: true,
              hint: const Text('— Seleziona un ensemble —'),
              items: widget.availableTemplates.map((tpl) {
                return DropdownMenuItem(
                  value: tpl,
                  child: Text('${tpl.name}  ·  ${tpl.description ?? ''}'),
                );
              }).toList(),
              onChanged: (tpl) {
                if (tpl != null) _loadTemplate(tpl);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeColumnLayout() {
    // Su schermi stretti, mostra solo 2 colonne + bottom sheet
    final isWide = MediaQuery.of(context).size.width > 900;

    if (isWide) {
      return Row(
        children: [
          // Colonna 1: Sezioni
          SizedBox(
            width: 180,
            child: _buildSectionColumn(),
          ),
          const VerticalDivider(width: 1),

          // Colonna 2: Strumenti
          Expanded(
            flex: 2,
            child: _buildInstrumentsColumn(),
          ),
          const VerticalDivider(width: 1),

          // Colonna 3: Organico
          Expanded(
            flex: 3,
            child: _buildOrganColumn(),
          ),
        ],
      );
    } else {
      // Schermo stretto: 1 colonna a step
      return Column(
        children: [
          // Sezioni come chip orizzontali
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _sectionChip(null, 'Tutti'),
                ...OrganSection.values.map((s) => _sectionChip(s, s.label)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildInstrumentsColumn()),
          const Divider(height: 1),
          SizedBox(
            height: 250,
            child: _buildOrganColumn(),
          ),
        ],
      );
    }
  }

  Widget _buildSectionColumn() {
    return Container(
      color: Colors.grey.shade50,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _sectionTile(
            section: null,
            label: '📋 Tutti',
            subtitle: '${InstrumentCatalog.totalInstruments} strumenti',
          ),
          const Divider(),
          ...OrganSection.values.map((section) {
            final count = InstrumentCatalog.forSection(section).length;
            final inOrgan = _slots.where((s) => s.section == section).length;
            return _sectionTile(
              section: section,
              label: '${section.emoji} ${section.label}',
              subtitle: '$count disp. · $inOrgan in uso',
            );
          }),
        ],
      ),
    );
  }

  Widget _sectionTile({
    required OrganSection? section,
    required String label,
    required String subtitle,
  }) {
    final isSelected = _selectedSection == section;
    return ListTile(
      dense: true,
      selected: isSelected,
      selectedTileColor: Colors.deepPurple.shade50,
      leading: isSelected
          ? const Icon(Icons.arrow_right, color: Colors.deepPurple)
          : null,
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.deepPurple : null,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      onTap: () => setState(() => _selectedSection = section),
    );
  }

  Widget _sectionChip(OrganSection? section, String label) {
    final isSelected = _selectedSection == section;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedSection = section),
        selectedColor: Colors.deepPurple.shade100,
      ),
    );
  }

  Widget _buildInstrumentsColumn() {
    final sections = _selectedSection != null
        ? [_selectedSection!]
        : OrganSection.values;

    final allInstruments = <MapEntry<OrganSection, String>>[];
    for (final s in sections) {
      for (final inst in InstrumentCatalog.forSection(s)) {
        allInstruments.add(MapEntry(s, inst));
      }
    }

    if (allInstruments.isEmpty) {
      return const Center(child: Text('Nessuno strumento disponibile'));
    }

    return Container(
      color: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: allInstruments.length,
        itemBuilder: (ctx, i) {
          final entry = allInstruments[i];
          final section = entry.key;
          final instrument = entry.value;
          final alreadyIn = _slots.any(
                (s) => s.instrument == instrument && s.section == section,
          );

          return ListTile(
            dense: true,
            leading: Text(section.emoji, style: const TextStyle(fontSize: 20)),
            title: Text(instrument),
            subtitle: Text(
              section.label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            trailing: alreadyIn
                ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                : const Icon(Icons.add_circle_outline,
                color: Colors.deepPurple, size: 20),
            onTap: () => _addInstrument(instrument),
          );
        },
      ),
    );
  }

  Widget _buildOrganColumn() {
    if (_slots.isEmpty) {
      return Container(
        color: Colors.grey.shade50,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.queue_music, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'Nessuno strumento nell\'organico.\n'
                      'Clicca sulla colonna di sinistra per aggiungere.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _slots.length,
              onReorder: (oldI, newI) {
                setState(() {
                  if (newI > oldI) newI--;
                  final item = _slots.removeAt(oldI);
                  _slots.insert(newI, item);
                });
              },
              itemBuilder: (ctx, i) {
                final s = _slots[i];
                return Card(
                  key: ValueKey('${s.instrument}_${s.section.name}_$i'),
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    dense: true,
                    leading: Text(
                      s.section.emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: Text(
                      s.instrument,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      s.section.label,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: s.quantity > 1
                              ? () => _changeQuantity(i, -1)
                              : null,
                          tooltip: 'Diminuisci',
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'x${s.quantity}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple.shade700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          onPressed: () => _changeQuantity(i, 1),
                          tooltip: 'Aumenta',
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          color: Colors.red,
                          onPressed: () => _removeSlot(i),
                          tooltip: 'Rimuovi',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildOrganSummary(),
        ],
      ),
    );
  }

  Widget _buildOrganSummary() {
    final totalSlots = _slots.length;
    final totalMusicians =
    _slots.fold<int>(0, (sum, s) => sum + s.quantity);
    final bySection = <OrganSection, int>{};
    for (final s in _slots) {
      bySection[s.section] = (bySection[s.section] ?? 0) + s.quantity;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                '$totalSlots strumenti · $totalMusicians musicisti',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          if (bySection.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: bySection.entries.map((e) {
                return Text(
                  '${e.key.emoji} ${e.value}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _saveAsNewTemplate,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salva come ensemble'),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Annulla'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _confirm,
            icon: const Icon(Icons.check),
            label: const Text('Applica organico'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// WORKING SLOT (mutable)
// ============================================

class _WizardSlot {
  OrganSection section;
  String instrument;
  int quantity;
  int orderIndex;

  _WizardSlot({
    required this.section,
    required this.instrument,
    required this.quantity,
    required this.orderIndex,
  });

  factory _WizardSlot.fromOrganSlot(OrganSlot slot) {
    return _WizardSlot(
      section: slot.section,
      instrument: slot.instrument,
      quantity: slot.quantity,
      orderIndex: slot.orderIndex,
    );
  }
}