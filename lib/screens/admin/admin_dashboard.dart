// lib/screens/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../home_screen.dart';
import 'admin_events.dart';
import 'admin_songs.dart';
import 'admin_registrations.dart';
import 'admin_users.dart';
import 'admin_suggestions.dart';
import 'admin_documents.dart';
import 'admin_database.dart';  // ✅ NUOVA IMPORT

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  // ✅ AGGIUNTA LA NUOVA SCHERMATA
  final List<Widget> _screens = [
    const AdminEvents(),
    const AdminSongs(),
    const AdminRegistrations(),
    const AdminUsers(),
    const AdminSuggestions(),
    const AdminDocuments(),
    const AdminDatabase(),  // ✅ NUOVA SEZIONE
  ];

  // ✅ AGGIUNTO IL NUOVO TITOLO
  final List<String> _titles = [
    '📅 Eventi',
    '🎵 Pezzi',
    '📝 Iscrizioni',
    '👥 Utenti',
    '💡 Suggerimenti',
    '📄 Documenti',
    '📊 Database',  // ✅ NUOVA SEZIONE
  ];

  // ✅ AGGIUNTA LA NUOVA ICONA
  final List<IconData> _icons = [
    Icons.event,
    Icons.music_note,
    Icons.people,
    Icons.person,
    Icons.lightbulb,
    Icons.folder,
    Icons.storage,  // ✅ NUOVA SEZIONE
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Se l'utente non è admin, torna alla home
    if (!authProvider.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      });
      return const Scaffold(
        body: Center(
          child: Text('Accesso non autorizzato'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Badge admin
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.shade700,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  'Admin: ${authProvider.currentUser?.fullName ?? ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Pulsante logout
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authProvider.logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Row(
        children: [
          // Navigation Rail (menu laterale)
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.deepPurple.shade50,
            selectedIconTheme: const IconThemeData(
              color: Colors.deepPurple,
            ),
            unselectedIconTheme: const IconThemeData(
              color: Colors.grey,
            ),
            selectedLabelTextStyle: const TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelTextStyle: const TextStyle(
              color: Colors.grey,
            ),
            destinations: [
              NavigationRailDestination(
                icon: Icon(_icons[0]),
                label: Text(_titles[0]),
              ),
              NavigationRailDestination(
                icon: Icon(_icons[1]),
                label: Text(_titles[1]),
              ),
              NavigationRailDestination(
                icon: Icon(_icons[2]),
                label: Text(_titles[2]),
              ),
              NavigationRailDestination(
                icon: Icon(_icons[3]),
                label: Text(_titles[3]),
              ),
              NavigationRailDestination(
                icon: Icon(_icons[4]),
                label: Text(_titles[4]),
              ),
              NavigationRailDestination(
                icon: Icon(_icons[5]),
                label: Text(_titles[5]),
              ),
              NavigationRailDestination(
                icon: Icon(_icons[6]),
                label: Text(_titles[6]),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _screens[_selectedIndex],
          ),
        ],
      ),
    );
  }
}