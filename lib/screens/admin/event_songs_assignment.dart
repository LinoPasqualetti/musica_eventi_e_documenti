// lib/screens/admin/event_songs_assignment.dart
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/event_model.dart';
import '../../models/song_model.dart';
import 'candidature_screen.dart';
import '../../models/registration_model.dart';
import 'song_form_screen.dart';
import 'event_song_documents.dart';
import 'organ_editor_screen.dart';
import '../../services/organ_push_service.dart';
import '../../services/auth_service.dart';
import '../../models/organ_template.dart';
import 'organ_template_picker_sheet.dart';

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
  Map<String, int> _organSlotsCount = {};
  bool _isLoading = true;
  bool _isReordering = false;

  // 🔥 MULTI-SELECT per bulk apply template
  bool _selectionMode = false;
  final Set<String> _selectedSongIds = {};

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
      final organCountMap = await _db.getOrganSlotsCountByEvent(widget.event.id);

      setState(() {
        _allSongs = allSongs;
        _assignedSongs = assignedSongs;
        _registrationsCount = countMap;
        _instrumentsBySong = instrumentsMap;
        _documentsCount = docsCountMap;
        _organSlotsCount = organCountMap;
        _isLoading = false;
        _isReordering = false;
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

  // ============================================
  // MULTI-SELECT HANDLERS
  // ============================================

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedSongIds.clear();
    });
  }

  void _toggleSongSelection(String songId) {
    setState(() {
      if (_selectedSongIds.contains(songId)) {
        _selectedSongIds.remove(songId);
      } else {
        _selectedSongIds.add(songId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedSongIds.clear();
      _selectedSongIds.addAll(_assignedSongs.map((s) => s.id));
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedSongIds.clear();
    });
  }

  // ============================================
  // BULK APPLY TEMPLATE
  // ============================================

  Future<void> _bulkApplyTemplate() async {
    if (_selectedSongIds.isEmpty) return;

    final template = await showOrganTemplatePicker(
      context,
      organId: 'bulk',
      currentSlotCount: 0,
    );
    if (template == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.queue_music, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Conferma bulk apply'),
          ],
        ),
        content: Text(
          'Applicare il template "${template.name}" a '
              '${_selectedSongIds.length} brani?\n\n'
              'Verranno creati/aggiornati gli organici in locale e poi pushati al web.\n'
              'I brani con organico già popolato verranno saltati.',
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
            child: const Text('Applica e pusha'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final eventSongIds = <String>[];
      for (final songId in _selectedSongIds) {
        final esId = await _db.getEventSongId(widget.event.id, songId);
        if (esId != null) eventSongIds.add(esId);
      }

      if (!mounted) return;
      Navigator.pop(context);

      if (eventSongIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nessun event_song_id valido trovato'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final report = await _db.bulkApplyTemplate(
        eventSongIds: eventSongIds,
        template: template,
      );

      if (!mounted) return;
      await _loadData();

      // Push al web
      OrganPushResult? webResult;
      if (report.applied.isNotEmpty) {
        final toPush = <OrganToPush>[];
        for (final item in report.applied) {
          if (item.organId == null) continue;
          final organ = await _db.getOrganById(item.organId!);
          if (organ == null) continue;
          final slots = await _db.getSlotsByOrgan(item.organId!);
          toPush.add(OrganToPush(
            eventSongId: item.eventSongId,
            organ: organ,
            slots: slots,
          ));
        }

        if (toPush.isNotEmpty) {
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );

          webResult = await OrganPushService.pushOrganBulk(organs: toPush);

          if (mounted) Navigator.pop(context);
        }
      }

      if (!mounted) return;
      await _showBulkApplyReport(report, webResult);

      setState(() {
        _selectionMode = false;
        _selectedSongIds.clear();
      });
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore bulk apply: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showBulkApplyReport(
      BulkApplyReport report,
      OrganPushResult? webResult,
      ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📊 Report bulk apply'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📱 LOCALE (Flutter)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (report.applied.isNotEmpty) ...[
                Text('✅ Applicati: ${report.applied.length}',
                    style: const TextStyle(color: Colors.green)),
                ...report.applied.take(5).map((a) => Text(
                  '  • ${a.eventSongId} (${a.slotsCreated} slot)',
                  style: const TextStyle(fontSize: 12),
                )),
              ],
              if (report.skipped.isNotEmpty) ...[
                Text('⚠️ Saltati: ${report.skipped.length}',
                    style: const TextStyle(color: Colors.orange)),
                ...report.skipped.take(3).map((s) => Text(
                  '  • ${s.eventSongId}: ${s.reason ?? ""}',
                  style: const TextStyle(fontSize: 12),
                )),
              ],
              if (report.errors.isNotEmpty) ...[
                Text('❌ Errori: ${report.errors.length}',
                    style: const TextStyle(color: Colors.red)),
                ...report.errors.take(3).map((e) => Text(
                  '  • $e',
                  style: const TextStyle(fontSize: 12),
                )),
              ],

              const Divider(height: 24),

              const Text('🌐 WEB (backend)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (webResult == null)
                const Text('⏸️ Nessun push eseguito',
                    style: TextStyle(color: Colors.grey, fontSize: 12))
              else if (!webResult.success)
                Text('❌ Push fallito: ${webResult.error}',
                    style: const TextStyle(color: Colors.red))
              else ...[
                  if (webResult.applied > 0)
                    Text('✅ Applicati: ${webResult.applied}',
                        style: const TextStyle(color: Colors.green)),
                  if (webResult.blocked > 0)
                    Text('🚫 Bloccati: ${webResult.blocked}',
                        style: const TextStyle(color: Colors.orange)),
                  if (webResult.errored > 0)
                    Text('❌ Errori: ${webResult.errored}',
                        style: const TextStyle(color: Colors.red)),
                  if (webResult.applied == 0 &&
                      webResult.blocked == 0 &&
                      webResult.errored == 0)
                    const Text('Nessuna modifica',
                        style: TextStyle(color: Colors.grey)),
                ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ============================================
  // FINE MULTI-SELECT / BULK APPLY
  // ============================================

  // 🔥 METODO PER RIORDINARE I BRANI
  Future<void> _reorderSongs(int oldIndex, int newIndex) async {
    if (_isReordering) return;
    setState(() => _isReordering = true);

    try {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      final List<Song> reordered = List.from(_assignedSongs);
      final Song item = reordered.removeAt(oldIndex);
      reordered.insert(newIndex, item);

      setState(() {
        _assignedSongs = reordered;
      });

      for (int i = 0; i < reordered.length; i++) {
        await _db.updateSongOrder(
          widget.event.id,
          reordered[i].id,
          i,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Ordine scaletta aggiornato!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
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
        await _loadData();
      }
    } finally {
      if (mounted) {
        setState(() => _isReordering = false);
      }
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

  // 🔥 METODO PER LA RIMOZIONE CON DIALOG DI CONFERMA
  Future<void> _confirmRemoveSong(Song song) async {
    try {
      final events = await _db.getEventsBySong(song.id);
      final otherEvents = events.where((e) => e.id != widget.event.id).toList();
      final hasOtherEvents = otherEvents.isNotEmpty;

      final registrations = await _db.getRegistrationsByEvent(widget.event.id);
      final hasRegistrations = registrations.any((reg) {
        if (reg.selectedSongIds != null && reg.selectedSongIds!.isNotEmpty) {
          final songIds = reg.selectedSongIds!.split(',');
          return songIds.contains(song.id);
        }
        return false;
      });

      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Conferma Rimozione'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rimuovere "${song.title}" dalla scaletta?',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                if (hasOtherEvents)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '⚠️ Canzone presente in altri eventi',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Questa canzone è presente anche in ${otherEvents.length} altro${otherEvents.length > 1 ? 'i' : ''} evento${otherEvents.length > 1 ? '' : 'o'}:',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...otherEvents.map((e) => Padding(
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.event, size: 12, color: Colors.orange),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${e.title} (${e.date})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                        const SizedBox(height: 8),
                        Text(
                          '⚠️ La rimozione da questo evento NON influisce sugli altri eventi.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (hasRegistrations)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_remove, color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '⚠️ Ci sono musicisti iscritti che hanno selezionato questo brano. '
                                'La rimozione potrebbe influire sulle loro iscrizioni.',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),
                Text(
                  'Sei sicuro di voler rimuovere questo brano dalla scaletta?',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
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
              child: const Text('Rimuovi'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _removeSong(song);
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

        Navigator.pop(context, true);
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

  // 🔥 METODO: Modifica brano
  Future<void> _editSong(Song song) async {
    final events = await _db.getEventsBySong(song.id);
    final isMultiEvent = events.length > 1;

    final relations = await _db.getSongRelations(song.id);
    final eventRelations = relations['events'] as List? ?? [];
    final docRelations = relations['documents'] as List? ?? [];

    final titleController = TextEditingController(text: song.title);
    final composerController = TextEditingController(text: song.composer ?? '');
    final difficultyController = TextEditingController(text: song.difficulty ?? '');
    final genreController = TextEditingController(text: song.genre ?? '');
    final tempoController = TextEditingController(text: song.tempo?.toString() ?? '');
    final keyController = TextEditingController(text: song.keySignature ?? '');
    final timeController = TextEditingController(text: song.timeSignature ?? '');

    int? durationSeconds = song.durationSeconds;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.edit, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text('Modifica Brano'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isMultiEvent)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '⚠️ Questa canzone è associata a ${events.length} eventi!\n'
                                  'Le modifiche influenzeranno TUTTI gli eventi.',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Titolo *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: composerController,
                    decoration: const InputDecoration(
                      labelText: 'Compositore',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: difficultyController,
                    decoration: const InputDecoration(
                      labelText: 'Difficoltà',
                      border: OutlineInputBorder(),
                      hintText: 'beginner, intermediate, advanced',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: genreController,
                    decoration: const InputDecoration(
                      labelText: 'Genere',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: tempoController,
                          decoration: const InputDecoration(
                            labelText: 'Tempo (BPM)',
                            border: OutlineInputBorder(),
                            hintText: '120',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: keyController,
                          decoration: const InputDecoration(
                            labelText: 'Tonalità',
                            border: OutlineInputBorder(),
                            hintText: 'Do, Sol, etc.',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: timeController,
                          decoration: const InputDecoration(
                            labelText: 'Tempo in battute',
                            border: OutlineInputBorder(),
                            hintText: '4/4, 3/4, etc.',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(
                            text: durationSeconds?.toString() ?? '',
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Durata (secondi)',
                            border: OutlineInputBorder(),
                            hintText: '180',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            durationSeconds = int.tryParse(value);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📊 Relazioni esistenti',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Eventi: ${eventRelations.length}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Documenti: ${docRelations.length}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Il titolo è obbligatorio'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, true);
                  _saveSongEdit(
                    song: song,
                    title: titleController.text.trim(),
                    composer: composerController.text.trim(),
                    difficulty: difficultyController.text.trim(),
                    genre: genreController.text.trim(),
                    tempo: int.tryParse(tempoController.text.trim()),
                    keySignature: keyController.text.trim(),
                    timeSignature: timeController.text.trim(),
                    durationSeconds: durationSeconds,
                    isMultiEvent: isMultiEvent,
                    events: events,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Salva Modifiche'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 🔥 METODO: Salva modifiche brano
  Future<void> _saveSongEdit({
    required Song song,
    required String title,
    required String composer,
    required String difficulty,
    required String genre,
    required int? tempo,
    required String? keySignature,
    required String? timeSignature,
    required int? durationSeconds,
    required bool isMultiEvent,
    required List<Event> events,
  }) async {
    try {
      final updatedSong = Song(
        id: song.id,
        title: title,
        composer: composer.isNotEmpty ? composer : null,
        difficulty: difficulty.isNotEmpty ? difficulty : null,
        genre: genre.isNotEmpty ? genre : null,
        durationSeconds: durationSeconds,
        tempo: tempo,
        keySignature: keySignature?.isNotEmpty == true ? keySignature : null,
        timeSignature: timeSignature?.isNotEmpty == true ? timeSignature : null,
        createdBy: song.createdBy,
        createdAt: song.createdAt,
        updatedAt: DateTime.now().toIso8601String(),
      );

      await _db.updateSong(updatedSong);
      await _loadData();

      if (mounted) {
        final message = isMultiEvent
            ? '✅ Brano aggiornato su TUTTI gli eventi (${events.length})'
            : '✅ Brano aggiornato con successo!';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isMultiEvent ? Icons.warning : Icons.check_circle,
                  color: isMultiEvent ? Colors.orange : Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: isMultiEvent ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 3),
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

  // ============================================
  // INDICATORI
  // ============================================

  Widget _buildDocumentIndicator(int count, Song song) {
    return GestureDetector(
      onTap: () async {
        final eventSongId = await _db.getEventSongId(widget.event.id, song.id);
        if (eventSongId != null) {
          if (!mounted) return;
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventSongDocumentsScreen(
                eventId: widget.event.id,
                songId: song.id,
                eventSongId: eventSongId,
                songTitle: song.title,
              ),
            ),
          );
          if (result == true && mounted) {
            await _loadData();
          }
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Errore: relazione evento-brano non trovata'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Container(
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
      ),
    );
  }

  Widget _buildOrganIndicator(int count, Song song) {
    return GestureDetector(
      onTap: () => _openOrganEditor(song),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: count > 0 ? Colors.deepPurple.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.queue_music,
              size: 14,
              color: count > 0 ? Colors.deepPurple.shade700 : Colors.grey.shade500,
            ),
            const SizedBox(width: 2),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                color: count > 0 ? Colors.deepPurple.shade700 : Colors.grey.shade500,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidatureIndicator(int count, Song song) {
    return GestureDetector(
      onTap: () => _openCandidature(song),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: count > 0 ? Colors.green.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people,
              size: 14,
              color: count > 0 ? Colors.green.shade700 : Colors.grey.shade500,
            ),
            const SizedBox(width: 2),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                color: count > 0 ? Colors.green.shade700 : Colors.grey.shade500,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // DIALOG PER AGGIUNGARE BRANO
  // ============================================

  Future<void> _showAddSongDialog() async {
    final TextEditingController _searchController = TextEditingController();
    String searchQuery = '';

    final availableSongs = _allSongs
        .where((song) => !_assignedSongs.any((s) => s.id == song.id))
        .toList();

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
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: docsCount > 0 ? Colors.blue.shade100 : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.description,
                                        size: 14,
                                        color: docsCount > 0 ? Colors.blue.shade700 : Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '$docsCount',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: docsCount > 0 ? Colors.blue.shade700 : Colors.grey.shade500,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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

  // ============================================
  // APRI EDITOR ORGANICO (F2)
  // ============================================

  Future<void> _openOrganEditor(Song song) async {
    try {
      final eventSongId = await _db.getEventSongId(widget.event.id, song.id);
      if (eventSongId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore: relazione evento-brano non trovata'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrganEditorScreen(
            eventSongId: eventSongId,
            songTitle: song.title,
            eventTitle: widget.event.title,
          ),
        ),
      );

      await _loadData();
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

  // ============================================
  // APRI GESTIONE CANDIDATURE (F5) - placeholder
  // ============================================

  Future<void> _openCandidature(Song song) async {
    try {
      final eventSongId = await _db.getEventSongId(widget.event.id, song.id);
      if (eventSongId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore: relazione evento-brano non trovata'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CandidatureScreen(
            eventSongId: eventSongId,
            songTitle: song.title,
            eventTitle: widget.event.title,
          ),
        ),
      );

      await _loadData();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectionMode
              ? '${_selectedSongIds.length} selezionati'
              : '🎵 Brani per: ${widget.event.title}',
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        leading: _selectionMode
            ? IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _toggleSelectionMode,
          tooltip: 'Annulla selezione',
        )
            : null,
        actions: _selectionMode
            ? [
          IconButton(
            icon: const Icon(Icons.select_all, color: Colors.white),
            onPressed: _selectAll,
            tooltip: 'Seleziona tutti',
          ),
          IconButton(
            icon: const Icon(Icons.deselect, color: Colors.white),
            onPressed: _deselectAll,
            tooltip: 'Deseleziona tutti',
          ),
          IconButton(
            icon: const Icon(Icons.queue_music, color: Colors.white),
            onPressed: _selectedSongIds.isEmpty
                ? null
                : _bulkApplyTemplate,
            tooltip: 'Applica template ai selezionati',
          ),
        ]
            : [
          IconButton(
            icon: const Icon(Icons.checklist, color: Colors.white),
            onPressed: _assignedSongs.isEmpty
                ? null
                : _toggleSelectionMode,
            tooltip: 'Seleziona brani (bulk apply)',
          ),
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
            Row(
              children: [
                Text(
                  _selectionMode
                      ? '👆 Seleziona i brani'
                      : '🎵 Brani in scaletta',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_assignedSongs.length} brani',
                  style: const TextStyle(color: Colors.grey),
                ),
                if (!_selectionMode && _assignedSongs.length > 1) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.drag_handle,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'trascina per riordinare',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

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
                child: ReorderableListView(
                  onReorder: _selectionMode ? (_, __) {} : _reorderSongs,
                  buildDefaultDragHandles: !_selectionMode,
                  padding: const EdgeInsets.only(bottom: 16),
                  physics: const BouncingScrollPhysics(),
                  children: _assignedSongs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final song = entry.value;
                    final count = _registrationsCount[song.id] ?? 0;
                    final instruments = _instrumentsBySong[song.id] ?? [];
                    final docsCount = _documentsCount[song.id] ?? 0;
                    final organSlotsCount = _organSlotsCount[song.id] ?? 0;
                    final isSelected = _selectedSongIds.contains(song.id);

                    return Card(
                      key: Key(song.id),
                      color: isSelected
                          ? Colors.deepPurple.shade50
                          : null,
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        onTap: _selectionMode
                            ? () => _toggleSongSelection(song.id)
                            : null,
                        leading: _selectionMode
                            ? Checkbox(
                          value: isSelected,
                          onChanged: (_) =>
                              _toggleSongSelection(song.id),
                          activeColor: Colors.deepPurple,
                        )
                            : CircleAvatar(
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
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!_selectionMode) ...[
                              _buildDocumentIndicator(docsCount, song),
                              const SizedBox(width: 6),
                              _buildOrganIndicator(organSlotsCount, song),
                              const SizedBox(width: 6),
                              _buildCandidatureIndicator(count, song),
                              const SizedBox(width: 4),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (value) async {
                                  switch (value) {
                                    case 'modifica':
                                      await _editSong(song);
                                      break;
                                    case 'candidature':
                                      await _openCandidature(song);
                                      break;
                                    case 'rimuovi':
                                      await _confirmRemoveSong(song);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'modifica',
                                    child: ListTile(
                                      leading: Icon(Icons.edit, color: Colors.deepPurple),
                                      title: Text('Modifica brano'),
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'candidature',
                                    child: ListTile(
                                      leading: Icon(Icons.people, color: Colors.green),
                                      title: Text('Gestisci candidature'),
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                  PopupMenuItem(
                                    value: 'rimuovi',
                                    child: ListTile(
                                      leading: const Icon(Icons.delete_outline, color: Colors.red),
                                      title: const Text('Rimuovi dalla scaletta'),
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (song.composer != null) Text('Compositore: ${song.composer}'),
                            if (instruments.isNotEmpty)
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: instruments.map((instrument) {
                                  return Chip(
                                    label: Text(instrument, style: const TextStyle(fontSize: 11)),
                                    backgroundColor: Colors.deepPurple.shade50,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  );
                                }).toList(),
                              ),
                            if (instruments.isEmpty && count > 0)
                              const Text(
                                'Strumenti non specificati',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            FutureBuilder<List<Event>>(
                              future: _db.getEventsBySong(song.id),
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data!.length > 1) {
                                  final otherEvents = snapshot.data!
                                      .where((e) => e.id != widget.event.id)
                                      .length;
                                  return Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '📌 Presente in ${snapshot.data!.length} eventi (${otherEvents} altro${otherEvents > 1 ? 'i' : ''})',
                                      style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}