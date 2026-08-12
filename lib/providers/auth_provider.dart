// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _currentUser;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isNotifying = false;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.role == 'admin';
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  AuthProvider() {
    print('🏗️ AuthProvider creato');
    _loadCurrentUser();
  }

  // ✅ SOVRASCRIVE notifyListeners per evitare chiamate durante il build
  @override
  void notifyListeners() {
    // Evita notifiche durante il build
    if (_isNotifying) return;
    try {
      super.notifyListeners();
    } catch (e) {
      print('⚠️ notifyListeners ignorato: $e');
    }
  }

  Future<void> _loadCurrentUser() async {
    _isLoading = true;
    _isNotifying = true;

    try {
      print('📂 _loadCurrentUser: inizio');
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('user_email');

      print('📂 _loadCurrentUser: savedEmail = "$savedEmail"');

      if (savedEmail != null && savedEmail.isNotEmpty) {
        print('📂 _loadCurrentUser: cerco utente: $savedEmail');
        final user = await _authService.getUserByEmail(savedEmail);
        if (user != null) {
          _currentUser = user;
          _authService.setCurrentUser(user);
          print('✅ _loadCurrentUser: caricato ${user.email} (${user.role})');
        } else {
          print('⚠️ _loadCurrentUser: utente non trovato');
          await prefs.remove('user_email');
        }
      } else {
        print('ℹ️ _loadCurrentUser: nessuna email salvata');
      }
    } catch (e) {
      print('❌ _loadCurrentUser: errore: $e');
    }

    _isLoading = false;
    _isInitialized = true;
    _isNotifying = false;
    print('📂 _loadCurrentUser: fine, isLoggedIn=$isLoggedIn, isAdmin=$isAdmin');
    super.notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    print('🔑🔑🔑 LOGIN CHIAMATO! email=$email 🔑🔑🔑');
    _isLoading = true;
    _isNotifying = true;

    try {
      print('🔑 login: chiamo _authService.login...');
      final user = await _authService.login(email, password);

      if (user != null) {
        print('✅ login: SUCCESSO! ${user.email} (${user.role})');
        _currentUser = user;
        _authService.setCurrentUser(user);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', user.email);
        print('💾 login: salvato in storage: ${user.email}');

        _isLoading = false;
        _isNotifying = false;
        super.notifyListeners();
        print('✅ login: completato, isAdmin=$isAdmin');
        return true;
      } else {
        print('❌ login: user è null');
        _isLoading = false;
        _isNotifying = false;
        super.notifyListeners();
        return false;
      }
    } catch (e) {
      print('❌ login: ECCEZIONE: $e');
      _isLoading = false;
      _isNotifying = false;
      super.notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    print('👋 logout');
    _authService.logout();
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    _isNotifying = true;
    super.notifyListeners();
    _isNotifying = false;
  }

  Future<void> refreshUser() async {
    print('🔄 refreshUser: inizio, currentUser=${_currentUser?.email}');

    // Se è già in caricamento, evita di rifarlo
    if (_isLoading) {
      print('🔄 refreshUser: già in caricamento, salto');
      return;
    }

    if (_currentUser != null) {
      _isLoading = true;
      _isNotifying = true;

      try {
        final user = await _authService.getUserByEmail(_currentUser!.email);
        if (user != null) {
          _currentUser = user;
          _authService.setCurrentUser(user);
          print('✅ refreshUser: ${user.email} (${user.role})');
        }
      } catch (e) {
        print('❌ refreshUser: errore $e');
      }

      _isLoading = false;
      _isNotifying = false;
      super.notifyListeners();
    } else {
      print('🔄 refreshUser: _currentUser null, carico da storage');
      await _loadCurrentUser();
    }
    print('🔄 refreshUser: fine, isAdmin=$isAdmin');
  }

  String get userDisplayName {
    if (_currentUser == null) return '';
    return _currentUser!.fullName;
  }

  String get userEmail {
    if (_currentUser == null) return '';
    return _currentUser!.email;
  }

  bool get isUserAdmin {
    return _currentUser?.role == 'admin';
  }
}