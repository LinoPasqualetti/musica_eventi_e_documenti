// lib/screens/admin/candidature_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../providers/registration_sync_provider.dart';
import '../../models/organ_slot.dart';
import '../../models/registration_with_user.dart';

class CandidatureScreen extends StatefulWidget {
  final String eventSongId;
  final String songTitle;
  final String eventTitle;

  const CandidatureScreen({
    Key? key,
    required this.eventSongId,
    required this.songTitle,
    required this.eventTitle,
  }) : super(key: key);

  @override
  State<CandidatureScreen> createState() => _CandidatureScreenState();
}

class _CandidatureScreenState extends State<CandidatureScreen> {
  final DatabaseService _db = DatabaseService();

  List<OrganSlot> _slots = [];
  List<RegistrationWithUser> _candidature = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final organs = await _db.getOrgansByEventSong(widget.eventSongId);
      List<OrganSlot> slots = [];
      if (organs.isNotEmpty) {
        slots = await _db.getSlotsByOrgan(organs.first.id);
      }

      final candidature =
      await _db.getRegistrationsWithUserByEventSong(widget.eventSongId);

      setState(() {
        _slots = slots;
        _candidature = candidature;
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

  /// Esegue sync completo (pull + push) e ricarica la UI.
  Future<void> _runSync(RegistrationSyncProvider provider) async {
    await provider.syncAll();

    if (!mounted) return;

    final err = provider.lastError;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ $err'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Sync: ${provider.state.lastPulled} nuove, '
                '${provider.state.lastPushed} inviate',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }

    await _load();
  }

  List<RegistrationWithUser> _filtered() {
    if (_filter == 'all') return _candidature;
    return _candidature
        .where((c) => c.registration.status == _filter)
        .toList();
  }

  List<RegistrationWithUser> _forSlot(OrganSlot slot) {
    return _filtered()
        .where((c) => c.registration.organSlotId == slot.id)
        .toList();
  }

  List<OrganSlot> _slotsBySection(OrganSection section) {
    return _slots.where((s) => s.section == section).toList();
  }

  Future<void> _updateStatus(
      RegistrationWithUser c,
      String newStatus,
      ) async {
    try {
      await _db.setRegistrationStatusLocal(
        c.registration.id,
        newStatus,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stato aggiornato: $newStatus'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int _countByStatus(String status) {
    return _candidature
        .where((c) => c.registration.status == status)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Candidature: ${widget.songTitle}'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.eventTitle,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        ),
        actions: [
          // Pulsante sync (pull + push)
          Consumer<RegistrationSyncProvider>(
            builder: (context, syncProvider, _) {
              if (syncProvider.isRunning) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.cloud_sync),
                onPressed: () => _runSync(syncProvider),
                tooltip: 'Sincronizza col Web',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Ricarica',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildSummary(),
        _buildFilters(),
        const Divider(height: 1),
        Expanded(
          child: _slots.isEmpty
              ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Nessun organico definito per questo brano.\n'
                    'Definisci l organico in F2 prima di gestire le candidature.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
              : ListView(
            padding: const EdgeInsets.all(12),
            children: [
              ...OrganSection.values.expand((section) {
                final sectionSlots = _slotsBySection(section);
                if (sectionSlots.isEmpty) return <Widget>[];

                return [
                  _buildSectionHeader(section),
                  ...sectionSlots.map(_buildSlotCard),
                  const SizedBox(height: 16),
                ];
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final total = _candidature.length;
    final pending = _countByStatus('pending');
    final waitlist = _countByStatus('waitlist');
    final confirmed = _countByStatus('confirmed');
    final rejected = _countByStatus('rejected');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey.shade100,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'Totale: $total',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            if (pending > 0) _chip('$pending pending', Colors.orange),
            if (waitlist > 0) _chip('$waitlist waitlist', Colors.blue),
            if (confirmed > 0) _chip('$confirmed confermati', Colors.green),
            if (rejected > 0) _chip('$rejected rifiutati', Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, MaterialColor color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color.shade800),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('all', 'Tutte'),
            const SizedBox(width: 6),
            _filterChip('pending', 'Pending'),
            const SizedBox(width: 6),
            _filterChip('waitlist', 'Waitlist'),
            const SizedBox(width: 6),
            _filterChip('confirmed', 'Confermati'),
            const SizedBox(width: 6),
            _filterChip('rejected', 'Rifiutati'),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: Colors.deepPurple.shade100,
    );
  }

  Widget _buildSectionHeader(OrganSection section) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(section.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 6),
          Text(
            section.label.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard(OrganSlot slot) {
    final candidates = _forSlot(slot);
    final confirmed =
        candidates.where((c) => c.registration.status == 'confirmed').length;
    final pending =
        candidates.where((c) => c.registration.status == 'pending').length;
    final waitlist =
        candidates.where((c) => c.registration.status == 'waitlist').length;
    final isFull = confirmed >= slot.quantity;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    slot.instrument,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _statusBadge(
                  '$confirmed/${slot.quantity}',
                  isFull ? Colors.green : Colors.orange,
                ),
                if (pending > 0) ...[
                  const SizedBox(width: 6),
                  _statusBadge('$pending pending', Colors.orange),
                ],
                if (waitlist > 0) ...[
                  const SizedBox(width: 6),
                  _statusBadge('$waitlist waitlist', Colors.blue),
                ],
              ],
            ),
            if (slot.notes != null && slot.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  slot.notes!,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Nessuna candidatura',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              )
            else
              ...candidates.map(_buildCandidateRow),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color.shade800),
      ),
    );
  }

  Widget _buildCandidateRow(RegistrationWithUser c) {
    final status = c.registration.status;
    final statusColor = _colorForStatus(status);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                c.isForThirdParty ? Icons.school : Icons.person,
                size: 14,
                color: statusColor.shade700,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: statusColor.shade900,
                      ),
                    ),
                    if (c.isForThirdParty && c.userEmail != null)
                      Text(
                        c.userEmail!,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (c.registration.timeDescription != null &&
              c.registration.timeDescription!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 2),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      c.registration.timeDescription!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 4),
            child: Wrap(
              spacing: 4,
              children: [
                if (status != 'confirmed')
                  _actionBtn(
                    'Approva',
                    Icons.check,
                    Colors.green,
                        () => _updateStatus(c, 'confirmed'),
                  ),
                if (status != 'waitlist')
                  _actionBtn(
                    'Waitlist',
                    Icons.pause,
                    Colors.blue,
                        () => _updateStatus(c, 'waitlist'),
                  ),
                if (status != 'rejected')
                  _actionBtn(
                    'Rifiuta',
                    Icons.close,
                    Colors.red,
                        () => _updateStatus(c, 'rejected'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
      String label,
      IconData icon,
      MaterialColor color,
      VoidCallback onPressed,
      ) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14, color: color.shade700),
      label: Text(
        label,
        style: TextStyle(fontSize: 11, color: color.shade700),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        minimumSize: const Size(0, 26),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  MaterialColor _colorForStatus(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'waitlist':
        return Colors.blue;
      case 'rejected':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}