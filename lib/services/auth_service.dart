// lib/services/auth_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../services/database_service.dart';
import '../models/user_model.dart';

class AuthService {
  final DatabaseService _db = DatabaseService();
  static User? _currentUser;

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<User?> getUserByEmail(String email) async {
    try {
      final db = await _db.database;
      final result = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [email],
      );
      if (result.isNotEmpty) {
        print('📊 Utente trovato: ${result.first['email']} (${result.first['role']})');
        return User.fromMap(result.first);
      }
      print('⚠️ Utente non trovato: $email');
      return null;
    } catch (e) {
      print('❌ Errore getUserByEmail: $e');
      return null;
    }
  }

  void setCurrentUser(User? user) {
    _currentUser = user;
  }

  Future<User?> login(String email, String password) async {
    try {
      final db = await _db.database;
      final hashedPassword = _hashPassword(password);

      print('🔍 Login: $email');
      print('🔑 Hash password: $hashedPassword');

      // ✅ VERIFICA CHE LA TABELLA ESISTA
      final tableCheck = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='users'"
      );
      print('📊 Tabella users esiste? ${tableCheck.isNotEmpty}');

      if (tableCheck.isEmpty) {
        print('❌ Tabella users non esiste!');
        throw Exception('Database non configurato');
      }

      // ✅ CERCA L'UTENTE
      final result = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [email],
      );

      print('📊 Numero di utenti trovati: ${result.length}');

      if (result.isEmpty) {
        // 🔍 DEBUG: Mostra tutti gli utenti
        final allUsers = await db.query('users');
        print('📊 Tutti gli utenti nel database:');
        for (var user in allUsers) {
          print('   - ${user['email']}');
        }
        throw Exception('Email o password errati');
      }

      print('✅ Utente trovato: ${result.first['email']}');
      print('📊 Hash nel DB: ${result.first['password_hash']}');
      print('📊 Hash calcolato: $hashedPassword');

      // ✅ VERIFICA LA PASSWORD
      if (result.first['password_hash'] != hashedPassword) {
        print('❌ Password errata');
        throw Exception('Email o password errati');
      }

      final user = User.fromMap(result.first);
      _currentUser = user;

      await db.update(
        'users',
        {'last_login': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [user.id],
      );

      print('✅ Login OK: ${user.email} (${user.role})');
      return user;
    } catch (e) {
      print('❌ Errore login: $e');
      rethrow;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final db = await _db.database;

      final existing = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [email],
      );

      if (existing.isNotEmpty) {
        throw Exception('Email già registrata');
      }

      final user = User(
        id: _db.generateId(),
        email: email,
        passwordHash: _hashPassword(password),
        fullName: fullName,
        role: 'user',
        createdAt: DateTime.now().toIso8601String(),
      );

      await db.insert('users', user.toMap());
      print('✅ Registrato: $email');
      return true;
    } catch (e) {
      print('❌ Errore registrazione: $e');
      rethrow;
    }
  }

  void logout() {
    _currentUser = null;
    print('👋 Logout');
  }

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.role == 'admin';
}