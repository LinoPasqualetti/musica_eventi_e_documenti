// lib/screens/admin/song_form_screen.dart
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../models/song_model.dart';
import '../../models/event_model.dart';

class SongFormScreen extends StatefulWidget {
  final Song? song;
  final List<Event>? events;

  const SongFormScreen({
    Key? key,
    this.song,
    this.events,
  }) : super(key: key);

  @override
  State<SongFormScreen> createState() => _SongFormScreenState();
}

class _SongFormScreenState extends State<SongFormScreen> {
  final DatabaseService _db = DatabaseService();
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _composerController = TextEditingController();
  final _genreController = TextEditingController();
  final _durationController = TextEditingController();
  final _tempoController = TextEditingController();
  final _keySignatureController = TextEditingController();
  final _timeSignatureController = TextEditingController();
  final _lyricsController = TextEditingController();

  bool _isLoading = false;
  bool _isEditing = false;
  String? _selectedDifficulty = 'intermediate';
  String? _selectedGenre;

  final List<String> _difficulties = [
    'beginner',
    'intermediate',
    'advanced',
    'professional'
  ];

  final List<String> _genres = [
    'Classica',
    'Jazz',
    'Pop',
    'Rock',
    'Folk',
    'Elettronica',
    'World',
    'Colonna Sonora',
    'Altro'
  ];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.song != null;
    print('📂 _SongFormScreenState - initState');
    print('📂 _isEditing: $_isEditing');
    if (_isEditing) {
      _loadSongData();
    }
  }

  void _loadSongData() {
    final song = widget.song!;
    print('📂 _loadSongData - caricamento dati brano: ${song.title}');
    _titleController.text = song.title;
    _composerController.text = song.composer ?? '';
    _genreController.text = song.genre ?? '';
    _selectedGenre = song.genre;
    _durationController.text = song.durationSeconds?.toString() ?? '';
    _tempoController.text = song.tempo?.toString() ?? '';
    _keySignatureController.text = song.keySignature ?? '';
    _timeSignatureController.text = song.timeSignature ?? '';
    _lyricsController.text = song.lyrics ?? '';
    _selectedDifficulty = song.difficulty ?? 'intermediate';
  }

  Future<void> _saveSong() async {
    print('🔍🔍🔍 _saveSong() CHIAMATO! 🔍🔍🔍');
    print('🔍 Titolo: "${_titleController.text}"');
    print('🔍 Compositore: "${_composerController.text}"');
    print('🔍 Difficoltà: $_selectedDifficulty');

    if (!_formKey.currentState!.validate()) {
      print('❌ Form non valido - validazione fallita');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Compila tutti i campi obbligatori'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    print('✅ Form valido, procedo con il salvataggio...');

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      print('👤 Utente corrente: ${user?.email}');
      print('👤 Ruolo: ${user?.role}');

      if (user == null) {
        print('❌❌❌ ERRORE: Utente non loggato! ❌❌❌');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Devi essere loggato per creare un brano'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final now = DateTime.now().toIso8601String();
      final songId = _isEditing ? widget.song!.id : _db.generateId();

      print('📝 ID brano: $songId');
      print('📝 Data creazione: $now');

      final song = Song(
        id: songId,
        title: _titleController.text.trim(),
        composer: _composerController.text.trim().isEmpty ? null : _composerController.text.trim(),
        difficulty: _selectedDifficulty,
        genre: _genreController.text.trim().isEmpty ? null : _genreController.text.trim(),
        durationSeconds: _durationController.text.trim().isEmpty ? null : int.tryParse(_durationController.text.trim()),
        tempo: _tempoController.text.trim().isEmpty ? null : int.tryParse(_tempoController.text.trim()),
        keySignature: _keySignatureController.text.trim().isEmpty ? null : _keySignatureController.text.trim(),
        timeSignature: _timeSignatureController.text.trim().isEmpty ? null : _timeSignatureController.text.trim(),
        lyrics: _lyricsController.text.trim().isEmpty ? null : _lyricsController.text.trim(),
        createdBy: user.id,
        createdAt: _isEditing ? widget.song!.createdAt : now,
        updatedAt: now,
      );

      print('📦 Song creato: ${song.title}');

      if (_isEditing) {
        print('💾 Aggiorno brano esistente...');
        await _db.updateSong(song);
        print('✅ Brano aggiornato con successo!');
      } else {
        print('💾 Inserisco nuovo brano...');
        await _db.insertSong(song);
        print('✅ Brano inserito con successo!');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? '✅ Brano aggiornato con successo!' : '✅ Brano creato con successo!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      print('🔚 _saveSong() completato, torno indietro');
      Navigator.pop(context, true);

    } catch (e, stackTrace) {
      print('❌❌❌ ECCEZIONE DURANTE IL SALVATAGGIO ❌❌❌');
      print('❌ Errore: $e');
      print('❌ Stack trace: $stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Errore: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    print('🗑️ _SongFormScreenState - dispose');
    _titleController.dispose();
    _composerController.dispose();
    _genreController.dispose();
    _durationController.dispose();
    _tempoController.dispose();
    _keySignatureController.dispose();
    _timeSignatureController.dispose();
    _lyricsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🔄 _SongFormScreenState - build');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '✏️ Modifica Brano' : '🎵 Nuovo Brano'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titolo
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titolo *',
                  prefixIcon: Icon(Icons.music_note),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Titolo richiesto';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Compositore
              TextFormField(
                controller: _composerController,
                decoration: const InputDecoration(
                  labelText: 'Compositore',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Genere
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Genere',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                value: _selectedGenre,
                items: _genres.map((genre) {
                  return DropdownMenuItem(
                    value: genre,
                    child: Text(genre),
                  );
                }).toList(),
                onChanged: (value) => setState(() {
                  _selectedGenre = value;
                  _genreController.text = value ?? '';
                }),
              ),
              const SizedBox(height: 12),

              // Difficoltà
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Difficoltà',
                  prefixIcon: Icon(Icons.trending_up),
                  border: OutlineInputBorder(),
                ),
                value: _selectedDifficulty,
                items: _difficulties.map((diff) {
                  return DropdownMenuItem(
                    value: diff,
                    child: Text(diff.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedDifficulty = value),
              ),
              const SizedBox(height: 12),

              // Durata
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'Durata (secondi)',
                  prefixIcon: Icon(Icons.timer),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),

              // Tempo
              TextFormField(
                controller: _tempoController,
                decoration: const InputDecoration(
                  labelText: 'Tempo (BPM)',
                  prefixIcon: Icon(Icons.speed),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),

              // Tonalità
              TextFormField(
                controller: _keySignatureController,
                decoration: const InputDecoration(
                  labelText: 'Tonalità (es. C, G, F)',
                  prefixIcon: Icon(Icons.music_note),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Metro
              TextFormField(
                controller: _timeSignatureController,
                decoration: const InputDecoration(
                  labelText: 'Metro (es. 4/4, 3/4)',
                  prefixIcon: Icon(Icons.tune),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Testo
              TextFormField(
                controller: _lyricsController,
                decoration: const InputDecoration(
                  labelText: 'Testo',
                  prefixIcon: Icon(Icons.text_fields),
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 24),

              // Pulsante Salva
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveSong,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text(
                    _isEditing ? '💾 Aggiorna Brano' : '➕ Crea Brano',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}