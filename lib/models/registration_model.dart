// lib/models/registration_model.dart
class Registration {
  final String id;
  final String eventId;
  final String userId;
  final String status;
  final String? instrumentChoice;
  final int readingLevel;
  final int improvisationLevel;
  final String? selectedSongIds;
  final String? notes;
  final String? adminNotes;
  final String? confirmedAt;
  final String? cancelledAt;
  final String createdAt;
  final String? updatedAt;

  // Campi per compatibilità con il vecchio codice
  String? get fullName => null;
  String? get email => null;
  String? get phone => null;
  String? get instrument => instrumentChoice;
  String? get userEmail => null;

  Registration({
    required this.id,
    required this.eventId,
    required this.userId,
    this.status = 'pending',
    this.instrumentChoice,
    this.readingLevel = 1,
    this.improvisationLevel = 1,
    this.selectedSongIds,
    this.notes,
    this.adminNotes,
    this.confirmedAt,
    this.cancelledAt,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'status': status,
      'instrument_choice': instrumentChoice,
      'reading_level': readingLevel,
      'improvisation_level': improvisationLevel,
      'selected_song_ids': selectedSongIds,
      'notes': notes,
      'admin_notes': adminNotes,
      'confirmed_at': confirmedAt,
      'cancelled_at': cancelledAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Registration.fromMap(Map<String, dynamic> map) {
    return Registration(
      id: map['id'] as String,
      eventId: map['event_id'] as String,
      userId: map['user_id'] as String,
      status: map['status'] as String? ?? 'pending',
      instrumentChoice: map['instrument_choice'] as String?,
      readingLevel: map['reading_level'] as int? ?? 1,
      improvisationLevel: map['improvisation_level'] as int? ?? 1,
      selectedSongIds: map['selected_song_ids'] as String?,
      notes: map['notes'] as String?,
      adminNotes: map['admin_notes'] as String?,
      confirmedAt: map['confirmed_at'] as String?,
      cancelledAt: map['cancelled_at'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
    );
  }

  Registration copyWith({
    String? status,
    String? adminNotes,
  }) {
    return Registration(
      id: id,
      eventId: eventId,
      userId: userId,
      status: status ?? this.status,
      instrumentChoice: instrumentChoice,
      readingLevel: readingLevel,
      improvisationLevel: improvisationLevel,
      selectedSongIds: selectedSongIds,
      notes: notes,
      adminNotes: adminNotes ?? this.adminNotes,
      confirmedAt: confirmedAt,
      cancelledAt: cancelledAt,
      createdAt: createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }
}