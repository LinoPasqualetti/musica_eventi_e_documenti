// lib/screens/admin/organ_template_picker_sheet.dart
import 'package:flutter/material.dart';
import '../../models/organ_template.dart';
import '../../models/organ_slot.dart';
import '../../services/database_service.dart';

/// Bottom sheet per selezionare un template di organico.
/// Ritorna:
///   - OrganTemplate se l'utente conferma
///   - null se annulla
Future<OrganTemplate?> showOrganTemplatePicker(
  BuildContext context, {
  required String organId,
  required int currentSlotCount,
}) async {
  // Carica template dal DB
  final db = DatabaseService();
  final templates = await db.getAllOrganTemplates();

  if (templates.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun template disponibile'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    return null;
  }

  // Raggruppa per categoria
  final byCategory = <String, List<OrganTemplate>>{};
  for (final t in templates) {
    final cat = t.category ?? 'Altro';
    byCategory.putIfAbsent(cat, () => []).add(t);
  }

  if (!context.mounted) return null;

  return showModalBottomSheet<OrganTemplate>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) {
          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.library_music, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Applica template',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              if (currentSlotCount > 0)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber,
                          color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'L\'organico attuale ha $currentSlotCount slot. '
                          'Applicando un template verranno tutti sostituiti.',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(12),
                  children: byCategory.entries.expand((entry) {
                    return [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 4),
                        child: Text(
                          entry.key.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      ...entry.value.map((tpl) => _buildTemplateCard(ctx, tpl, db)),
                    ];
                  }).toList(),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _buildTemplateCard(
    BuildContext ctx, OrganTemplate tpl, DatabaseService db) {
  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFEDE7F6),
        child: Icon(Icons.queue_music, color: Colors.deepPurple),
      ),
      title: Text(
        tpl.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(tpl.description ?? ''),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.pop(ctx, tpl),
    ),
  );
}
