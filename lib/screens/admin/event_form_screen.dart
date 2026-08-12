// lib/screens/admin/event_form_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../models/event_model.dart';

class EventFormScreen extends StatefulWidget {
  final Event? event;
  const EventFormScreen({Key? key, this.event}) : super(key: key);

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final DatabaseService _db = DatabaseService();
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _themeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _dateController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _capacityController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _durationController = TextEditingController();
  final _videoUrlController = TextEditingController();

  String _selectedCategory = 'concerto';
  String _selectedStatus = 'published';
  String _selectedDifficulty = 'intermediate';

  bool _isLoading = false;
  bool _isEditing = false;

  final List<String> _categories = ['concerto', 'workshop', 'masterclass', 'conferenza', 'altro'];
  final List<String> _statuses = ['published', 'draft', 'cancelled', 'archived'];
  final List<String> _difficulties = ['beginner', 'intermediate', 'advanced', 'professional'];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.event != null;
    if (_isEditing) {
      _loadEventData();
    }
  }

  void _loadEventData() {
    final event = widget.event!;
    _titleController.text = event.title;
    _themeController.text = event.theme;
    _descriptionController.text = event.description ?? '';
    _locationController.text = event.location;
    _dateController.text = event.date;
    _imageUrlController.text = event.imageUrl ?? '';
    _capacityController.text = event.capacity.toString();
    _contactEmailController.text = event.contactEmail ?? '';
    _contactPhoneController.text = event.contactPhone ?? '';
    _durationController.text = event.duration ?? '';
    _videoUrlController.text = event.videoUrl ?? '';
    _selectedCategory = event.category;
    _selectedStatus = event.status;
    _selectedDifficulty = event.difficulty;
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Devi essere loggato'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final now = DateTime.now().toIso8601String();
      final eventId = _isEditing ? widget.event!.id : _db.generateId();

      final event = Event(
        id: eventId,
        title: _titleController.text.trim(),
        theme: _themeController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        imageUrl: _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
        date: _dateController.text.trim(),
        location: _locationController.text.trim(),
        category: _selectedCategory,
        status: _selectedStatus,
        capacity: int.tryParse(_capacityController.text.trim()) ?? 999,
        difficulty: _selectedDifficulty,
        duration: _durationController.text.trim().isEmpty ? null : _durationController.text.trim(),
        contactEmail: _contactEmailController.text.trim().isEmpty ? null : _contactEmailController.text.trim(),
        contactPhone: _contactPhoneController.text.trim().isEmpty ? null : _contactPhoneController.text.trim(),
        videoUrl: _videoUrlController.text.trim().isEmpty ? null : _videoUrlController.text.trim(),
        createdBy: user.id,
        createdAt: _isEditing ? widget.event!.createdAt : now,
        updatedAt: now,
      );

      if (_isEditing) {
        await _db.updateEvent(event);
      } else {
        await _db.insertEvent(event);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? '✅ Evento aggiornato!' : '✅ Evento creato!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Errore: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final initialDate = _dateController.text.isNotEmpty
        ? DateTime.tryParse(_dateController.text) ?? now
        : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _themeController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    _imageUrlController.dispose();
    _capacityController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _durationController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '✏️ Modifica Evento' : '➕ Nuovo Evento'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Titolo *', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty == true ? 'Titolo richiesto' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _themeController,
                decoration: const InputDecoration(labelText: 'Tema *', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty == true ? 'Tema richiesto' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descrizione', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dateController,
                decoration: InputDecoration(
                  labelText: 'Data *',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_month),
                    onPressed: _selectDate,
                  ),
                  border: const OutlineInputBorder(),
                ),
                readOnly: true,
                onTap: _selectDate,
                validator: (v) => v?.isEmpty == true ? 'Data richiesta' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Luogo *', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty == true ? 'Luogo richiesto' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                value: _selectedCategory,
                items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat.toUpperCase()))).toList(),
                onChanged: (value) => setState(() => _selectedCategory = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Difficoltà', border: OutlineInputBorder()),
                value: _selectedDifficulty,
                items: _difficulties.map((diff) => DropdownMenuItem(value: diff, child: Text(diff.toUpperCase()))).toList(),
                onChanged: (value) => setState(() => _selectedDifficulty = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Stato', border: OutlineInputBorder()),
                value: _selectedStatus,
                items: _statuses.map((status) => DropdownMenuItem(value: status, child: Text(status.toUpperCase()))).toList(),
                onChanged: (value) => setState(() => _selectedStatus = value!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _capacityController,
                decoration: const InputDecoration(labelText: 'Capacità massima', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(labelText: 'URL Immagine', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactEmailController,
                decoration: const InputDecoration(labelText: 'Email contatto', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactPhoneController,
                decoration: const InputDecoration(labelText: 'Telefono contatto', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isEditing ? '💾 Aggiorna' : '➕ Crea Evento', style: const TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}