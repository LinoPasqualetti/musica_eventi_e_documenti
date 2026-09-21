// lib/models/organ.dart

/// Organico di un brano eseguito in un evento specifico.
/// Contiene più slot (OrganSlot), uno per ogni tipo di esecutore richiesto.
class Organ {
  final String id;
  final String eventSongId;
  final String name;
  final String? notes;
  final String createdAt;
  final String? updatedAt;
  final String? deletedAt;

  Organ({
    required this.id,
    required this.eventSongId,
    required this.name,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_song_id': eventSongId,
      'name': name,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
    };
  }

  factory Organ.fromMap(Map<String, dynamic> map) {
    return Organ(
      id: map['id'] as String,
      eventSongId: map['event_song_id'] as String,
      name: (map['name'] as String?) ?? 'Organico standard',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
      deletedAt: map['deleted_at'] as String?,
    );
  }

  Organ copyWith({
    String? name,
    String? notes,
    String? updatedAt,
    String? deletedAt,
  }) {
    return Organ(
      id: id,
      eventSongId: eventSongId,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  bool get isDeleted => deletedAt != null;
}