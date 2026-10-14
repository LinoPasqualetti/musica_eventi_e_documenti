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
import 'admin_database.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  // 🔧 CAMBIATO: Database ora è in 6ª posizione (penultima)
  final List<Widget> _screens = [
    const AdminEvents(),        // 0
    const AdminSongs(),         // 1
    const AdminRegistrations(), // 2
    const AdminUsers(),         // 3
    const AdminSuggestions(),   // 4
    const AdminDatabase(),      // 5 ← SPOSTATO QUI (era 6)
    const AdminDocuments(),     // 6 ← SPOSTATO QUI (era 5)
  ];

  final List<String> _titles = [
    '📅 Eventi',        // 0
    '🎵 Pezzi',         // 1
    '📝 Iscrizioni',    // 2
    '👥 Utenti',        // 3
    '💡 Suggerimenti',  // 4
    '📊 Database',      // 5 ← SPOSTATO
    '📄 Documenti',     // 6 ← SPOSTATO
  ];

  final List<IconData> _icons = [
    Icons.event,       // 0
    Icons.music_note,  // 1
    Icons.people,      // 2
    Icons.person,      // 3
    Icons.lightbulb,   // 4
    Icons.storage,     // 5 ← SPOSTATO
    Icons.folder,      // 6 ← SPOSTATO
  ];

  @override
  Widget build(BuildContext context) {
    // 🔍 DEBUG: verifica che le liste siano allineate
    final screenSize = MediaQuery.of(context).size;
    print('🔍 DEBUG NavigationRail:');
    print('   Schermo: ${screenSize.width} x ${screenSize.height}');
    print('   _titles.length: ${_titles.length}');
    print('   _icons.length: ${_icons.length}');
    print('   _screens.length: ${_screens.length}');
    print('   Destinations hardcoded: 7');
    print('   _selectedIndex attuale: $_selectedIndex');

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
            child: const Row(
              children: [
                Icon(Icons.star, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Admin',
                  style: TextStyle(
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
              Provider.of<AuthProvider>(context, listen: false).logout();
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
          // Navigation Rail
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              print('🔍 Click su index: $index (${_titles[index]})');
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
            // 🔧 CAMBIATO: Database ora è in 6ª posizione (penultima)
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.event),
                label: Text('📅 Eventi'),         // 0
              ),
              NavigationRailDestination(
                icon: Icon(Icons.music_note),
                label: Text('🎵 Pezzi'),           // 1
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('📝 Iscrizioni'),      // 2
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person),
                label: Text('👥 Utenti'),          // 3
              ),
              NavigationRailDestination(
                icon: Icon(Icons.lightbulb),
                label: Text('💡 Suggerimenti'),    // 4
              ),
              NavigationRailDestination(
                icon: Icon(Icons.storage),
                label: Text('📊 Database'),        // 5 ← SPOSTATO QUI
              ),
              NavigationRailDestination(
                icon: Icon(Icons.folder),
                label: Text('📄 Documenti'),       // 6 ← SPOSTATO QUI
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