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
  bool _isLoading = true;
  bool _isRefreshing = false;

  static const int SCROLL_THRESHOLD = 20;

  // 🔥 RouteObserver per tracciare quando si torna allo schermo
  final RouteObserver<PageRoute> _routeObserver = RouteObserver<PageRoute>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Iscriviti al RouteObserver per ricevere notifiche quando si torna allo schermo
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

  // 🔥 METODO CHIAMATO QUANDO SI TORNA ALLO SCHERMO
  @override
  void didPopNext() {
    // Questo metodo viene chiamato quando si torna a questo schermo
    // dopo averne aperto un altro
    super.didPopNext();
    print('🔄 Rientrato in EventDetailScreen - Ricarico dati...');
    _refreshData();
  }

  // 🔥 METODO PER FORZARE IL REFRESH
  Future<void> _refreshData() async {
    // Se non siamo nella vista attiva, non fare nulla
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

      if (mounted) {
        setState(() {
          _event = event;
          _songs = songs;
          _documentsCountBySong = counts;
          _isLoading = false;
        });
      }

      print('✅ Evento caricato: ${event?.title}');
      print('✅ Canzoni trovate: ${songs.length}');
      print('✅ Conteggio documenti: $counts');
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

      // 🔥 Usa push per permettere il refresh al ritorno
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

      // 🔥 Se i documenti sono stati modificati, ricarica i dati
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

  // 🔥 METODO PER GESTIRE LA SCALETTA CON REFRESH
  void _navigateToSongsAssignment() async {
    // 🔥 Usa push per permettere il refresh al ritorno
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventSongsAssignment(
          event: _event!,
        ),
      ),
    );

    // 🔥 Se la scaletta è stata modificata, ricarica i dati
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

                  // Info evento - in alto
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
                        // 🔥 INTESTAZIONE SCALETTA CON BOTTONI
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Row(
                            children: [
                              // 🔥 BOTTONE GESTISCI SCALETTA (solo admin) - con conteggio brani
                              if (isAdmin)
                                ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.playlist_add,
                                    size: 14,
                                  ),
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
                              // 🔥 BOTTONE GESTISCI DOCUMENTI (solo admin)
                              if (isAdmin)
                                ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.folder,
                                    size: 14,
                                  ),
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

                        // ✅ LISTA BRANI COMPATTA
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
                                runSpacing: 0,
                                children: _songs.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final song = entry.value;
                                  final docCount = _documentsCountBySong[song.id] ?? 0;
                                  return SizedBox(
                                    width: (MediaQuery.of(context).size.width - 36) / 2,
                                    height: 24,
                                    child: Row(
                                      children: [
                                        // 🔥 BOTTONE DOCUMENTI PER SINGOLO BRANO (admin) - primo elemento, icona gialla
                                        if (isAdmin)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.folder_open,
                                              color: Colors.amber,
                                              size: 14,
                                            ),
                                            onPressed: () => _navigateToDocuments(song),
                                            tooltip: 'Documenti del brano',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        SizedBox(
                                          width: 16,
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.25),
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        // 🔥 CONTATORE DOCUMENTI SPECIFICI DI QUESTO EVENTO
                                        if (docCount > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4),
                                            child: Text(
                                              '($docCount)',
                                              style: TextStyle(
                                                color: Colors.amber.withOpacity(0.8),
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(width: 4),

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
          // 🔥 BOTTONE REFRESH
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

  // ✅ Dialog per selezionare il brano e andare ai documenti
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