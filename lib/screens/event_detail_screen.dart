// lib/screens/event_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../models/event_model.dart';
import '../models/song_model.dart';
import '../providers/auth_provider.dart';
import 'registration_form_screen.dart';
import 'admin/event_songs_assignment.dart';
import 'admin/event_song_documents.dart';
import 'admin/organ_editor_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  const EventDetailScreen({Key? key, required this.eventId}) : super(key: key);

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> with RouteAware {
  final DatabaseService _db = DatabaseService();
  Event? _event;
  List<Song> _songs = [];
  Map<String, int> _documentsCountBySong = {};
  Map<String, int> _organSlotsCountBySong = {};
  Map<String, int> _candidatureCountBySong = {};
  bool _isLoading = true;
  bool _isRefreshing = false;

  static const int SCROLL_THRESHOLD = 20;

  final RouteObserver<PageRoute> _routeObserver = RouteObserver<PageRoute>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      _routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    print('🔄 Rientrato in EventDetailScreen - Ricarico dati...');
    _refreshData();
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    print('🔄 Ricaricamento dati evento...');
    await _loadData(showLoading: false);
    print('✅ Dati evento ricaricati');
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final event = await _db.getEventById(widget.eventId);
      final songs = await _db.getSongsByEvent(widget.eventId);
      final counts = await _db.getEventSongDocumentsCountForEvent(widget.eventId);
      final organCounts = await _db.getOrganSlotsCountByEvent(widget.eventId);
      final candCounts = await _db.getRegistrationsCountBySongForEvent(widget.eventId);

      if (mounted) {
        setState(() {
          _event = event;
          _songs = songs;
          _documentsCountBySong = counts;
          _organSlotsCountBySong = organCounts;
          _candidatureCountBySong = candCounts;
          _isLoading = false;
        });
      }

      print('✅ Evento caricato: ${event?.title}');
      print('✅ Canzoni trovate: ${songs.length}');
      print('✅ Conteggio documenti: $counts');
      print('✅ Conteggio organico: $organCounts');
      print('✅ Conteggio candidature: $candCounts');
    } catch (e, stackTrace) {
      print('❌ ERRORE in _loadData: $e');
      print('📚 STACK: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _navigateToDocuments(Song song) async {
    try {
      final eventSongId = await _db.getEventSongId(widget.eventId, song.id);

      if (eventSongId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore: brano non associato a questo evento'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EventSongDocumentsScreen(
            eventId: widget.eventId,
            songId: song.id,
            eventSongId: eventSongId,
            songTitle: song.title,
          ),
        ),
      );

      if (result == true && mounted) {
        await _refreshData();
      }
    } catch (e) {
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

  Future<void> _openOrganEditor(Song song) async {
    try {
      final eventSongId = await _db.getEventSongId(widget.eventId, song.id);
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
            eventTitle: _event!.title,
          ),
        ),
      );

      await _refreshData();
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

  Future<void> _openCandidature(Song song) async {
    // TODO: implementare F5 (gestione candidature)
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎼 Gestione candidature in arrivo'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _navigateToSongsAssignment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventSongsAssignment(
          event: _event!,
        ),
      ),
    );

    if (result == true && mounted) {
      await _refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_event == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Evento non trovato'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Evento non disponibile'),
            ],
          ),
        ),
      );
    }

    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.isAdmin;
    final hasImage = _event!.imageUrl != null && _event!.imageUrl!.isNotEmpty;
    final bool needsScroll = _songs.length > SCROLL_THRESHOLD;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Container(
          decoration: BoxDecoration(
            image: hasImage
                ? DecorationImage(
              image: NetworkImage(_event!.imageUrl!),
              fit: BoxFit.cover,
            )
                : null,
            gradient: hasImage
                ? null
                : LinearGradient(
              colors: [
                Colors.deepPurple.shade400,
                Colors.deepPurple.shade700,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildAppBar(isAdmin, context),

                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            _event!.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  blurRadius: 10,
                                  color: Colors.black54,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _event!.theme,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: Colors.white60,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _event!.date,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.white60,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _event!.location,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (_event!.description != null &&
                              _event!.description!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                _event!.description!,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ✅ SEZIONE SCALETTA CON BOTTONI
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.85),
                        ],
                        stops: const [0.0, 0.06],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Row(
                            children: [
                              if (isAdmin)
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.playlist_add, size: 14),
                                  label: Text(
                                    'Gestisci Scaletta (${_songs.length})',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onPressed: _navigateToSongsAssignment,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.15),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: const Size(0, 28),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              const SizedBox(width: 8),
                              if (isAdmin)
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.folder, size: 14),
                                  label: const Text(
                                    'Gestisci Documenti',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  onPressed: _showSongSelectionDialog,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.15),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: const Size(0, 28),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              const Spacer(),
                            ],
                          ),
                        ),

                        // ✅ LISTA BRANI IN 2 COLONNE
                        if (_songs.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Center(
                              child: Text(
                                'Nessun brano in scaletta',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          )
                        else
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: needsScroll
                                  ? MediaQuery.of(context).size.height * 0.25
                                  : double.infinity,
                            ),
                            child: SingleChildScrollView(
                              physics: needsScroll
                                  ? const BouncingScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 1,
                                children: _songs.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final song = entry.value;
                                  final docCount = _documentsCountBySong[song.id] ?? 0;
                                  final organCount = _organSlotsCountBySong[song.id] ?? 0;
                                  final candCount = _candidatureCountBySong[song.id] ?? 0;

                                  return SizedBox(
                                    width: (MediaQuery.of(context).size.width - 36) / 2,
                                    height: 24,
                                    child: Row(
                                      children: [
                                        // 📁 Documenti
                                        if (isAdmin)
                                          GestureDetector(
                                            onTap: () => _navigateToDocuments(song),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.folder_open,
                                                  color: Colors.amber,
                                                  size: 12,
                                                ),
                                                if (docCount > 0) ...[
                                                  const SizedBox(width: 1),
                                                  Text(
                                                    '$docCount',
                                                    style: TextStyle(
                                                      color: Colors.amber.withOpacity(0.85),
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        const SizedBox(width: 4),

                                        // 🎼 Organico
                                        if (isAdmin)
                                          GestureDetector(
                                            onTap: () => _openOrganEditor(song),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.queue_music,
                                                  size: 12,
                                                  color: organCount > 0
                                                      ? Colors.deepPurple.shade200
                                                      : Colors.white.withOpacity(0.3),
                                                ),
                                                const SizedBox(width: 1),
                                                Text(
                                                  '$organCount',
                                                  style: TextStyle(
                                                    color: organCount > 0
                                                        ? Colors.deepPurple.shade200
                                                        : Colors.white.withOpacity(0.3),
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        const SizedBox(width: 4),

                                        // 👥 Candidature
                                        if (isAdmin)
                                          GestureDetector(
                                            onTap: () => _openCandidature(song),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.people,
                                                  size: 12,
                                                  color: candCount > 0
                                                      ? Colors.green.shade200
                                                      : Colors.white.withOpacity(0.3),
                                                ),
                                                const SizedBox(width: 1),
                                                Text(
                                                  '$candCount',
                                                  style: TextStyle(
                                                    color: candCount > 0
                                                        ? Colors.green.shade200
                                                        : Colors.white.withOpacity(0.3),
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        const SizedBox(width: 6),

                                        // Numero d'ordine
                                        SizedBox(
                                          width: 12,
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.3),
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 2),

                                        // Titolo
                                        Expanded(
                                          child: Text(
                                            song.title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w400,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),

                        // Pulsante iscrizione
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 2, 0, 6),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final now = DateTime.now();
                                final eventDate = DateTime.tryParse(_event!.date);
                                final isPast = eventDate != null && eventDate.isBefore(now);
                                final isPublished = _event!.status == 'published';

                                if (isPast) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('⚠️ Questo evento è già passato'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }

                                if (!isPublished) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('🔒 Questo evento non è ancora pubblicato'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RegistrationFormScreen(
                                      event: _event!,
                                      songs: _songs,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.music_note, size: 14),
                              label: const Text(
                                '🎸 Voglio Suonare sul Palco!',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                minimumSize: const Size(double.infinity, 30),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isAdmin, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Torna indietro',
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(
              Icons.refresh,
              color: Colors.white,
            ),
            onPressed: _refreshData,
            tooltip: 'Aggiorna dati',
          ),
          IconButton(
            icon: const Icon(
              Icons.share,
              color: Colors.white,
            ),
            onPressed: () {
              // TODO: Condividi evento
            },
            tooltip: 'Condividi',
          ),
        ],
      ),
    );
  }

  void _showSongSelectionDialog() {
    if (_songs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun brano in scaletta'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📄 Seleziona Brano per i Documenti'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: _songs.length,
            itemBuilder: (context, index) {
              final song = _songs[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade100,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Colors.deepPurple.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(song.title),
                subtitle: song.composer != null
                    ? Text('Compositore: ${song.composer}')
                    : null,
                trailing: const Icon(Icons.folder_open, color: Colors.deepPurple),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToDocuments(song);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
        ],
      ),
    );
  }
}