// lib/screens/admin_screen.dart
import 'package:flutter/material.dart';
import 'admin/admin_events.dart';
import 'admin/admin_songs.dart';
import 'admin/admin_documents.dart';
import 'admin/admin_users.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 0;

  // USA I NOMI CORRETTI DELLE CLASSI (con "Screen")
  final List<Widget> _screens = [
    const AdminEventsScreen(),      // <-- CON "Screen"
    const AdminSongsScreen(),       // <-- CON "Screen"
    const AdminDocumentsScreen(),   // <-- CON "Screen"
    const AdminUsersScreen(),       // <-- CON "Screen"
  ];

  final List<String> _titles = [
    'Eventi',
    'Canzoni',
    'Documenti',
    'Utenti',
  ];

  final List<IconData> _icons = [
    Icons.event,
    Icons.music_note,
    Icons.folder,
    Icons.people,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: List.generate(
          _titles.length,
              (index) => NavigationDestination(
            icon: Icon(_icons[index]),
            label: _titles[index],
          ),
        ),
      ),
    );
  }
}