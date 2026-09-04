// lib/providers/event_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:musica_eventi_e_documenti/models/event_model.dart';
import 'package:musica_eventi_e_documenti/services/database_helper.dart';

class EventProvider extends ChangeNotifier {
  List<Event> _events = [];
  bool _isLoading = false;
  String? _error;

  List<Event> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;

  EventProvider() {
    _loadEvents();
  }

  /// Carica tutti gli eventi dal database
  Future<void> _loadEvents() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('📊 EventProvider: inizio caricamento eventi...');
      final db = await DatabaseHelper.instance.database;
      final eventMaps = await db.query('events');

      _events = eventMaps.map((map) => Event.fromMap(map)).toList();
      _events.sort((a, b) {
        if (a.eventDate == null && b.eventDate == null) return 0;
        if (a.eventDate == null) return 1;
        if (b.eventDate == null) return -1;
        return a.eventDate!.compareTo(b.eventDate!);
      });

      _isLoading = false;
      print('✅ EventProvider: caricati ${_events.length} eventi');
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Errore nel caricamento degli eventi: $e';
      print('❌ EventProvider: errore: $e');
      notifyListeners();
    }
  }

  /// Ricarica gli eventi (da chiamare dopo modifiche)
  Future<void> refreshEvents() async {
    await _loadEvents();
  }

  /// Ottiene un evento per ID
  Event? getEventById(String id) {
    try {
      return _events.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Filtra eventi per stato
  List<Event> getEventsByStatus(String status) {
    return _events.where((e) => e.status == status).toList();
  }

  /// Eventi pubblicati
  List<Event> get publishedEvents => getEventsByStatus('published');

  /// Eventi in bozza
  List<Event> get draftEvents => getEventsByStatus('draft');

  /// Eventi futuri
  List<Event> get upcomingEvents {
    final now = DateTime.now();
    return _events.where((e) =>
    e.eventDate != null &&
        e.eventDate!.isAfter(now) &&
        e.status == 'published'
    ).toList();
  }
}
