// lib/screens/admin_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import '../models/registration_model.dart';
import 'admin/admin_events.dart';
import 'admin/admin_songs.dart';
import 'admin/admin_registrations.dart';
import 'admin/admin_users.dart';
import 'admin/admin_suggestions.dart';
import 'admin/admin_documents.dart';
import 'home_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const AdminEvents(),
    const AdminSongs(),
    const AdminRegistrations(),
    const AdminUsers(),
    const AdminSuggestions(),
    const AdminDocuments(),
  ];

  final List<String> _titles = [
    '📅 Eventi',
    '🎵 Pezzi',
    '📝 Iscrizioni',
    '👥 Utenti',
    '💡 Suggerimenti',
    '📄 Documenti',
  ];

  final List<IconData> _icons = [
    Icons.event,
    Icons.music_note,
    Icons.people,
    Icons.person,
    Icons.lightbulb,
    Icons.folder,
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

          // Pulsante refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
            tooltip: 'Aggiorna',
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
          Container(
            width: 80,
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              border: Border(
                right: BorderSide(
                  color: Colors.deepPurple.shade200,
                  width: 1,
                ),
              ),
            ),
            child: NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              labelType: NavigationRailLabelType.selected,
              backgroundColor: Colors.transparent,
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
                  selectedIcon: Icon(_icons[0], color: Colors.deepPurple),
                  label: Text(_titles[0]),
                ),
                NavigationRailDestination(
                  icon: Icon(_icons[1]),
                  selectedIcon: Icon(_icons[1], color: Colors.deepPurple),
                  label: Text(_titles[1]),
                ),
                NavigationRailDestination(
                  icon: Icon(_icons[2]),
                  selectedIcon: Icon(_icons[2], color: Colors.deepPurple),
                  label: Text(_titles[2]),
                ),
                NavigationRailDestination(
                  icon: Icon(_icons[3]),
                  selectedIcon: Icon(_icons[3], color: Colors.deepPurple),
                  label: Text(_titles[3]),
                ),
                NavigationRailDestination(
                  icon: Icon(_icons[4]),
                  selectedIcon: Icon(_icons[4], color: Colors.deepPurple),
                  label: Text(_titles[4]),
                ),
                NavigationRailDestination(
                  icon: Icon(_icons[5]),
                  selectedIcon: Icon(_icons[5], color: Colors.deepPurple),
                  label: Text(_titles[5]),
                ),
              ],
            ),
          ),

          // Contenuto
          Expanded(
            child: _screens[_selectedIndex],
          ),
        ],
      ),
    );
  }
}