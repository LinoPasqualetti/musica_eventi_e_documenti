// lib/screens/admin_login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/auth_provider.dart';
import 'admin_screen.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({Key? key}) : super(key: key);

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  static const String ADMIN_ACCESS_PASSWORD = 'admin123';

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginAsAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      print('🔐🔐🔐 LOGIN ADMIN DIRETTO 🔐🔐🔐');
      print('🔑 Password inserita: ${_passwordController.text}');

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Verifica se l'utente è già loggato come admin
      if (authProvider.currentUser != null && authProvider.currentUser!.role == 'admin') {
        print('✅ Utente già loggato come admin');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Sei già autenticato come amministratore'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AdminScreen()),
                (route) => false,
          );
        }
        return;
      }

      // Controlla la password
      if (_passwordController.text == ADMIN_ACCESS_PASSWORD) {
        print('✅ Password admin corretta!');

        // Tentativo di login con credenziali admin
        final success = await authProvider.login(
          'admin@musicapertutti.it',
          'admin123',
        );

        print('📊 Risultato login: $success');
        print('👤 Utente: ${authProvider.currentUser?.email}');
        print('👑 Ruolo: ${authProvider.currentUser?.role}');

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Accesso amministrazione consentito'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            // Login fallito ma password corretta: vai comunque alla admin
            print('⚠️ Login fallito ma password corretta, vado alla admin screen');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Accesso amministrazione consentito'),
                backgroundColor: Colors.green,
              ),
            );
          }

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AdminScreen()),
                (route) => false,
          );
        }
        return;
      } else {
        print('❌ Password errata!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Password errata!'),
              backgroundColor: Colors.red,
            ),
          );
          _passwordController.clear();
        }
      }
    } catch (e) {
      print('❌ Errore login admin: $e');
      // Fallback: se la password è corretta ma c'è un errore, vai comunque
      if (_passwordController.text == ADMIN_ACCESS_PASSWORD && mounted) {
        print('🔄 Fallback: password corretta, vado alla admin screen');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Accesso amministrazione consentito'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AdminScreen()),
              (route) => false,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loginWithCredentials() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
    if (result == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser != null && authProvider.currentUser!.role == 'admin') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AdminScreen()),
              (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Non hai i permessi di amministratore'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔐 Accesso Amministrazione'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // Icona
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    size: 64,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Area Amministratore',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 8),

                const Text(
                  'Inserisci la password per accedere al pannello di controllo',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),

                // Campo password
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password Amministratore *',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: const OutlineInputBorder(),
                    hintText: 'Inserisci la password',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  obscureText: _obscurePassword,
                  onFieldSubmitted: (_) => _loginAsAdmin(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Inserisci la password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Pulsante login
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _loginAsAdmin,
                    icon: _isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.login),
                    label: const Text(
                      'Accedi come Amministratore',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Separatore
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'oppure',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 16),

                // Pulsante login normale
                TextButton.icon(
                  onPressed: _loginWithCredentials,
                  icon: const Icon(Icons.person),
                  label: const Text('Accedi con le tue credenziali'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                  ),
                ),

                const SizedBox(height: 24),

                // Info box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Informazioni di accesso',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Password admin: admin123\n'
                            '• Usa le credenziali admin per accesso completo\n'
                            '• Contatta l\'amministratore per assistenza',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('← Torna alla home'),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}