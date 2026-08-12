// lib/screens/admin/admin_suggestions.dart
import 'package:flutter/material.dart';

class AdminSuggestions extends StatefulWidget {
  const AdminSuggestions({Key? key}) : super(key: key);

  @override
  State<AdminSuggestions> createState() => _AdminSuggestionsState();
}

class _AdminSuggestionsState extends State<AdminSuggestions> {
  int _selectedTab = 0;
  final List<String> _tabs = ['Eventi', 'Immagini', 'Feedback'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💡 Gestione Suggerimenti',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Tab selector
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: List.generate(_tabs.length, (index) {
                final isSelected = _selectedTab == index;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTab = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.deepPurple : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _tabs[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey.shade700,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          // Contenuto tab
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildSuggestionsList('suggerimenti eventi');
      case 1:
        return _buildSuggestionsList('suggerimenti immagini');
      case 2:
        return _buildSuggestionsList('feedback utenti');
      default:
        return const SizedBox();
    }
  }

  Widget _buildSuggestionsList(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lightbulb_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Nessun $type',
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'I suggerimenti appariranno qui',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}