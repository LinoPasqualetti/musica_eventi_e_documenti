// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import '../models/event_model.dart';
import '../widgets/event_card.dart';
import 'event_detail_screen.dart';
import 'admin_screen.dart';
import 'admin_login_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = DatabaseService();
  List<Event> _events = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _errorStackTrace;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();

    // ✅ Carica l'utente dopo la build iniziale
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (!authProvider.isInitialized) {
        authProvider.refreshUser();
      }
      _isInitialized = true;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ NON chiamare refreshUser() qui
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _errorStackTrace = null;
    });

    try {
      print('🔄 Inizio caricamento eventi...');
      final events = await _db.getAllEvents();
      print('✅ Eventi caricati: ${events.length}');

      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('❌ ERRORE: $e');
      print('📚 STACK TRACE: $stackTrace');

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
        _errorStackTrace = stackTrace.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dettagli',
              textColor: Colors.white,
              onPressed: _showErrorDialog,
            ),
          ),
        );
      }
    }
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Dettagli Errore'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Messaggio di errore:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  _errorMessage ?? 'Nessun messaggio',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Stack Trace:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _errorStackTrace ?? 'Nessuno stack trace',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final errorText = '''
Messaggio errore: ${_errorMessage ?? 'Nessun messaggio'}

Stack Trace:
${_errorStackTrace ?? 'Nessuno stack trace'}
''';
                        Clipboard.setData(ClipboardData(text: errorText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Errore copiato negli appunti!'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copia tutto'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Chiudi'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openLogin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
    if (result == true) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.refreshUser();
      setState(() {});
    }
  }

  void _openRegister() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  void _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('👋 Logout effettuato'),
      ),
    );
  }

  // ✅ PULSANTE CREA ADMIN (SOLO PER TEST)
  Future<void> _createAdmin() async {
    try {
      final db = await _db.database;
      final existing = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: ['admin@musicapertutti.it'],
      );

      if (existing.isEmpty) {
        await db.insert('users', {
          'id': 'usr_admin',
          'email': 'admin@musicapertutti.it',
          'password_hash': '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9',
          'full_name': 'Admin Musica per Tutti',
          'role': 'admin',
          'status': 'active',
          'created_at': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Admin creato! Email: admin@musicapertutti.it, Password: admin123'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ℹ️ Admin già esistente'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎵 Musica per Tutti'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Badge utente loggato
          if (user != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: user.role == 'admin'
                    ? Colors.amber.shade700
                    : Colors.green.shade400,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    user.role == 'admin'
                        ? Icons.star
                        : Icons.person,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    user.role == 'admin' ? 'Admin' : user.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // ✅ PULSANTE CREA ADMIN (SOLO PER TEST - RIMUOVI IN PRODUZIONE)
          IconButton(
            icon: const Icon(Icons.admin_panel_settings, color: Colors.green),
            onPressed: _createAdmin,
            tooltip: 'Crea Admin (test)',
          ),

          // Pulsante Test Login (ingranaggio)
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              print('🧪🧪🧪 TEST LOGIN DIRETTO 🧪🧪🧪');
              final authProvider = Provider.of<AuthProvider>(context, listen: false);

              try {
                final success = await authProvider.login(
                  'admin@musicapertutti.it',
                  'admin123',
                );
                print('🧪 Risultato login diretto: $success');
                print('🧪 Utente dopo login: ${authProvider.currentUser?.email}');
                print('🧪 Ruolo: ${authProvider.currentUser?.role}');

                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Login diretto riuscito!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  setState(() {});
                }
              } catch (e) {
                print('🧪 Errore login diretto: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Errore: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            tooltip: 'Test Login',
          ),

          // Pulsante Admin
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () async {
              print('🔑 Pulsante admin premuto');

              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.refreshUser();

              final user = authProvider.currentUser;
              print('👤 Utente corrente: ${user?.email}');
              print('👑 Ruolo: ${user?.role}');

              if (user != null && user.role == 'admin') {
                print('✅ Utente admin, apro dashboard');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminScreen()),
                );
              } else {
                print('❌ Utente non admin, apro login admin');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
                );
              }
            },
            tooltip: 'Area Amministrazione',
          ),

          // Pulsante refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvents,
            tooltip: 'Aggiorna',
          ),

          // Login/Logout
          if (user == null)
            IconButton(
              icon: const Icon(Icons.login),
              onPressed: _openLogin,
              tooltip: 'Login',
            )
          else
            PopupMenuButton<String>(
              icon: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 16,
                child: Text(
                  user.fullName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.deepPurple),
                ),
              ),
              onSelected: (value) {
                if (value == 'logout') _logout();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'profile',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        user.email,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        user.role == 'admin' ? '👑 Admin' : '👤 Utente',
                        style: const TextStyle(fontSize: 12, color: Colors.deepPurple),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadEvents,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        child: const Icon(Icons.sync),
        tooltip: 'Ricarica eventi',
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🎶 Il palco è di tutti!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scegli un evento, scarica gli spartiti e suona con noi',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '📌 ${_events.length} eventi disponibili',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Errore nel caricamento',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _errorMessage!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Errore copiato negli appunti!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copia errore'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _loadEvents,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Riprova'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _showErrorDialog,
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Dettagli'),
                ),
              ],
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
            Icon(Icons.event_busy, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Nessun evento disponibile',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            Text(
              'Torna più tardi!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _events.length,
        itemBuilder: (context, index) {
          return EventCard(
            event: _events[index],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      EventDetailScreen(eventId: _events[index].id),
                ),
              ).then((_) => _loadEvents());
            },
          );
        },
      ),
    );
  }
}