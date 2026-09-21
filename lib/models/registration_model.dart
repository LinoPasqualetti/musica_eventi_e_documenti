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

  // ─── Campi organico ─────────────────────────────────────────────
  final String? songId;
  final String? organSlotId;
  final String? timeDescription;
  final String? deletedAt;

  // ─── Campi candidato (per conto terzi) ──────────────────────────
  final String? candidateName;
  final String? candidateEmail;

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
    // organico
    this.songId,
    this.organSlotId,
    this.timeDescription,
    this.deletedAt,
    // candidato
    this.candidateName,
    this.candidateEmail,
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
      // organico
      'song_id': songId,
      'organ_slot_id': organSlotId,
      'time_description': timeDescription,
      'deleted_at': deletedAt,
      // candidato
      'candidate_name': candidateName,
      'candidate_email': candidateEmail,
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
      // organico
      songId: map['song_id'] as String?,
      organSlotId: map['organ_slot_id'] as String?,
      timeDescription: map['time_description'] as String?,
      deletedAt: map['deleted_at'] as String?,
      // candidato
      candidateName: map['candidate_name'] as String?,
      candidateEmail: map['candidate_email'] as String?,
    );
  }

  Registration copyWith({
    String? status,
    String? adminNotes,
    String? songId,
    String? organSlotId,
    String? timeDescription,
    String? deletedAt,
    String? candidateName,
    String? candidateEmail,
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
      songId: songId ?? this.songId,
      organSlotId: organSlotId ?? this.organSlotId,
      timeDescription: timeDescription ?? this.timeDescription,
      deletedAt: deletedAt ?? this.deletedAt,
      candidateName: candidateName ?? this.candidateName,
      candidateEmail: candidateEmail ?? this.candidateEmail,
    );
  }
}