// lib/models/organ_slot.dart

/// Sezioni musicali dell'organico.
/// - ritmica:     percussioni e bassi (batteria, basso elettrico, contrabbasso, ...)
/// - armonica:    strumenti che producono accordi (pianoforte, chitarra, ...)
/// - solistica:   strumenti che espongono il tema melodico
/// - orchestrale: strumenti che sostengono la melodia dei solisti
enum OrganSection {
  ritmica,
  armonica,
  solistica,
  orchestrale;

  /// Valore usato nel DB (minuscolo, come nel CHECK constraint).
  String get dbValue => name;

  /// Etichetta leggibile per la UI.
  String get label {
    switch (this) {
      case OrganSection.ritmica:
        return 'Ritmica';
      case OrganSection.armonica:
        return 'Armonica';
      case OrganSection.solistica:
        return 'Solistica';
      case OrganSection.orchestrale:
        return 'Orchestrale';
    }
  }

  /// Emoji per la UI.
  String get emoji {
    switch (this) {
      case OrganSection.ritmica:
        return '🥁';
      case OrganSection.armonica:
        return '🎹';
      case OrganSection.solistica:
        return '🎺';
      case OrganSection.orchestrale:
        return '🎻';
    }
  }

  /// Parse da stringa DB. Null se non riconosciuta.
  static OrganSection? fromDb(String? value) {
    if (value == null) return null;
    for (final s in OrganSection.values) {
      if (s.dbValue == value) return s;
    }
    return null;
  }
}

/// Slot dell'organico: un tipo di esecutore richiesto in un organico.
/// Es. "Violini I, quantità 8" oppure "Voce, quantità 1".
class OrganSlot {
  final String id;
  final String organId;
  final OrganSection section;
  final String instrument;
  final int quantity;
  final String? notes;
  final int orderIndex;
  final String createdAt;
  final String? updatedAt;
  final String? deletedAt;

  OrganSlot({
    required this.id,
    required this.organId,
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
      'organ_id': organId,
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

  factory OrganSlot.fromMap(Map<String, dynamic> map) {
    final section = OrganSection.fromDb(map['section'] as String?);
    if (section == null) {
      throw FormatException(
        'Invalid section: ${map['section']} for slot ${map['id']}',
      );
    }
    return OrganSlot(
      id: map['id'] as String,
      organId: map['organ_id'] as String,
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

  OrganSlot copyWith({
    OrganSection? section,
    String? instrument,
    int? quantity,
    String? notes,
    int? orderIndex,
    String? updatedAt,
    String? deletedAt,
  }) {
    return OrganSlot(
      id: id,
      organId: organId,
      section: section ?? this.section,
      instrument: instrument ?? this.instrument,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  bool get isDeleted => deletedAt != null;
}