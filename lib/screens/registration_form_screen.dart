// lib/screens/registration_form_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/event_model.dart';
import '../models/song_model.dart';
import '../models/registration_model.dart';
import '../services/database_service.dart';
import '../providers/auth_provider.dart';

class RegistrationFormScreen extends StatefulWidget {
  final Event event;
  final List<Song> songs;

  const RegistrationFormScreen({
    Key? key,
    required this.event,
    required this.songs,
  }) : super(key: key);

  @override
  State<RegistrationFormScreen> createState() => _RegistrationFormScreenState();
}

class _RegistrationFormScreenState extends State<RegistrationFormScreen> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  final _notesController = TextEditingController();
  String? _selectedInstrument;
  int _readingLevel = 1;
  int _improvisationLevel = 1;
  List<String> _selectedSongIds = [];

  bool _isSubmitting = false;
  bool _isEventValid = true;
  String? _validationMessage;

  final List<String> _instruments = [
    'Pianoforte',
    'Chitarra',
    'Basso',
    'Batteria',
    'Violino',
    'Flauto',
    'Saxofono',
    'Voce',
    'Altro',
  ];

  @override
  void initState() {
    super.initState();
    _validateEvent();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _validateEvent() {
    // ✅ Controllo 1: Evento già passato
    try {
      final eventDate = DateTime.parse(widget.event.date);
      final now = DateTime.now();

      if (eventDate.isBefore(now)) {
        setState(() {
          _isEventValid = false;
          _validationMessage = '⚠️ Questo evento è già passato.\n'
              'Non è più possibile iscriversi.';
        });
        return;
      }
    } catch (e) {
      // Se la data non è parsabile, ignora il controllo
      print('⚠️ Data non parsabile: ${widget.event.date}');
    }

    // ✅ Controllo 2: Evento non pubblicato
    if (widget.event.status != 'published') {
      setState(() {
        _isEventValid = false;
        _validationMessage = '🔒 Questo evento non è ancora disponibile per le iscrizioni.\n'
            'Riprova più tardi quando l\'evento sarà pubblicato.';
      });
      return;
    }

    // ✅ Controllo 3: Capacità massima raggiunta
    // Nota: questo richiede un metodo per contare le iscrizioni confermate
    // _checkCapacity();

    setState(() {
      _isEventValid = true;
      _validationMessage = null;
    });
  }

  Future<bool> _checkCapacity() async {
    try {
      final registrations = await _db.getRegistrationsByEvent(widget.event.id);
      final confirmedCount = registrations.where((r) => r.status == 'confirmed').length;

      if (confirmedCount >= widget.event.capacity) {
        setState(() {
          _isEventValid = false;
          _validationMessage = '⚠️ L\'evento ha raggiunto il numero massimo di partecipanti (${widget.event.capacity}).';
        });
        return false;
      }
      return true;
    } catch (e) {
      print('❌ Errore controllo capacità: $e');
      return true;
    }
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    // ✅ RICONTROLLA LA VALIDITÀ DELL'EVENTO
    _validateEvent();
    if (!_isEventValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_validationMessage ?? 'Evento non disponibile'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // ✅ CONTROLLA LA CAPACITÀ
    final hasCapacity = await _checkCapacity();
    if (!hasCapacity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_validationMessage ?? 'Capacità massima raggiunta'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Devi essere loggato per iscriverti'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = authProvider.currentUser!.id;

      // Verifica se già registrato
      final alreadyRegistered = await _db.isAlreadyRegistered(
        widget.event.id,
        userId,
      );

      if (alreadyRegistered) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Sei già registrato a questo evento!'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      // Crea registrazione
      final registration = Registration(
        id: _db.generateId(),
        eventId: widget.event.id,
        userId: userId,
        instrumentChoice: _selectedInstrument,
        readingLevel: _readingLevel,
        improvisationLevel: _improvisationLevel,
        selectedSongIds: _selectedSongIds.isEmpty ? null : _selectedSongIds.join(','),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: DateTime.now().toIso8601String(),
        status: 'pending',
      );

      await _db.insertRegistration(registration);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Iscrizione completata! In attesa di conferma.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      print('❌ Errore iscrizione: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Errore: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎸 Iscrizione all\'Evento'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ✅ MESSAGGIO DI VALIDAZIONE
            if (!_isEventValid && _validationMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _validationMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Info evento
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.event.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('📅 ${widget.event.date}'),
                    Text('📍 ${widget.event.location}'),
                    if (widget.event.status == 'published')
                      const Chip(
                        label: Text('📢 Pubblicato'),
                        backgroundColor: Colors.green,
                        labelStyle: TextStyle(color: Colors.white),
                      )
                    else
                      Chip(
                        label: Text('🔒 ${widget.event.status}'),
                        backgroundColor: Colors.orange,
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                    Text('👥 Capacità: ${widget.event.capacity} partecipanti'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_isEventValid) ...[
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Strumento
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Strumento *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.music_note),
                      ),
                      value: _selectedInstrument,
                      items: _instruments.map((instrument) {
                        return DropdownMenuItem(
                          value: instrument,
                          child: Text(instrument),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedInstrument = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Seleziona uno strumento';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Livelli
                    const Text(
                      '🎯 Livelli di competenza',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Lettura'),
                              Slider(
                                value: _readingLevel.toDouble(),
                                min: 1,
                                max: 5,
                                divisions: 4,
                                label: _readingLevel.toString(),
                                onChanged: (value) {
                                  setState(() {
                                    _readingLevel = value.round();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Improvvisazione'),
                              Slider(
                                value: _improvisationLevel.toDouble(),
                                min: 1,
                                max: 5,
                                divisions: 4,
                                label: _improvisationLevel.toString(),
                                onChanged: (value) {
                                  setState(() {
                                    _improvisationLevel = value.round();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Canzoni selezionabili
                    if (widget.songs.isNotEmpty) ...[
                      const Text(
                        '🎵 Seleziona i brani che vuoi suonare',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...widget.songs.map((song) {
                        return CheckboxListTile(
                          title: Text(song.title),
                          subtitle: song.composer != null ? Text(song.composer!) : null,
                          value: _selectedSongIds.contains(song.id),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedSongIds.add(song.id);
                              } else {
                                _selectedSongIds.remove(song.id);
                              }
                            });
                          },
                        );
                      }),
                      const SizedBox(height: 8),
                    ],

                    // Note
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Note aggiuntive',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // Pulsante invio
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitRegistration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text(
                          '📝 Registrati',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}