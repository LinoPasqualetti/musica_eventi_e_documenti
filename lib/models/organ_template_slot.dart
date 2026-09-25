// lib/models/organ_template_slot.dart
import 'organ_slot.dart';

/// Slot di un template di organico.
/// Stessa struttura di OrganSlot, ma appartiene a un template invece che a un organico.
class OrganTemplateSlot {
  final String id;
  final String templateId;
  final OrganSection section;
  final String instrument;
  final int quantity;
  final String? notes;
  final int orderIndex;
  final String createdAt;
  final String? updatedAt;
  final String? deletedAt;

  OrganTemplateSlot({
    required this.id,
    required this.templateId,
    required this.section,
    required this.instrument,
    this.quantity = 1,
    this.notes,
    this.orderIndex = 0,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'template_id': templateId,
      'section': section.dbValue,
      'instrument': instrument,
      'quantity': quantity,
      'notes': notes,
      'order_index': orderIndex,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
    };
  }

  factory OrganTemplateSlot.fromMap(Map<String, dynamic> map) {
    final section = OrganSection.fromDb(map['section'] as String?);
    if (section == null) {
      throw FormatException(
        'Invalid section: ${map['section']} for template slot ${map['id']}',
      );
    }
    return OrganTemplateSlot(
      id: map['id'] as String,
      templateId: map['template_id'] as String,
      section: section,
      instrument: map['instrument'] as String,
      quantity: (map['quantity'] as int?) ?? 1,
      notes: map['notes'] as String?,
      orderIndex: (map['order_index'] as int?) ?? 0,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
      deletedAt: map['deleted_at'] as String?,
    );
  }

  bool get isDeleted => deletedAt != null;
}
