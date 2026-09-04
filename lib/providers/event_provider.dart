// lib/providers/event_provider.dart
import 'package:flutter/material.dart';
import 'package:musica_eventi_e_documenti/models/event_model.dart';
import 'package:musica_eventi_e_documenti/services/database_service.dart';

class EventProvider extends ChangeNotifier {
  List<Event> _events = [];
  bool _isLoading = false;
  String? _error;
  final DatabaseService _db = DatabaseService();

  List<Event> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;

  EventProvider() {
    refreshEvents();
  }

  /// Carica tutti gli eventi
  Future<void> refreshEvents() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('📊 EventProvider: inizio caricamento eventi...');

      // Usa il metodo corretto di DatabaseService
      final events = await _db.getAllEvents();

      _events = events;
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

  /// Ottiene un evento per ID
  Event? getEventById(String id) {
    try {
      return _events.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Eventi pubblicati
  List<Event> get publishedEvents {
    return _events.where((e) => e.status == 'published').toList();
  }

  /// Eventi in bozza
  List<Event> get draftEvents {
    return _events.where((e) => e.status == 'draft').toList();
  }
}