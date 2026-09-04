// lib/screens/admin/events_list_screen.dart

import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/event_model.dart';
import '../../utils/performance_logger.dart';
import '../../utils/ui_performance.dart';  // 🔥 AGGIUNGI

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({Key? key}) : super(key: key);

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  final DatabaseService _db = DatabaseService();
  List<Event> _events = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    UIPerformance.pageLoad('EventsListScreen');  // 🔥 AGGIUNGI
    _loadEvents();
  }

  @override
  void dispose() {
    UIPerformance.pageLoadComplete('EventsListScreen');  // 🔥 AGGIUNGI
    super.dispose();
  }

  Future<void> _loadEvents() async {
    UIPerformance.refresh('EventsListScreen');  // 🔥 AGGIUNGI

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stopwatch = Stopwatch()..start();
      final events = await _db.getAllEvents();
      stopwatch.stop();

      UIPerformance.pageRender('EventsListScreen_Load', stopwatch.elapsedMilliseconds);

      setState(() {
        _events = events;
        _isLoading = false;
      });

      UIPerformance.listRender('EventsList', events.length);
      UIPerformance.userAction('Eventi admin caricati', details: '${events.length} eventi');

    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      UIPerformance.uiError('EventsListScreen', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Eventi'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              UIPerformance.userAction('Refresh EventsList');  // 🔥 AGGIUNGI
              _loadEvents();
            },
            tooltip: 'Ricarica',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              UIPerformance.navigation('EventsListScreen', 'EventFormScreen');  // 🔥 AGGIUNGI
              UIPerformance.userAction('Nuovo evento');
              // Naviga a creazione evento
            },
            tooltip: 'Nuovo Evento',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Errore: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEvents,
              child: const Text('Riprova'),
            ),
          ],
        ),
      );
    }

    if (_events.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Nessun evento trovato'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
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
            title: Text(event.title),
            subtitle: Text(
              '${event.date ?? 'Data non specificata'} • ${event.location ?? 'Luogo non specificato'}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    UIPerformance.userAction('Modifica evento', details: event.title);  // 🔥 AGGIUNGI
                    // Naviga a modifica evento
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    UIPerformance.userAction('Elimina evento', details: event.title);  // 🔥 AGGIUNGI
                    _confirmDelete(event);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Text('Sei sicuro di voler eliminare "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              UIPerformance.userAction('Conferma eliminazione evento', details: event.title);  // 🔥 AGGIUNGI
              await _db.deleteEvent(event.id);
              UIPerformance.userAction('Evento eliminato', details: event.title);
              await _loadEvents();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}