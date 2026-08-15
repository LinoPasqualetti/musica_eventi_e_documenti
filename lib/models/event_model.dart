// lib/models/event_model.dart
class Event {
  final String id;
  final String title;
  final String theme;
  final String? description;
  final String? imageUrl;
  final String date;
  final String location;
  final String category;
  final String status;
  final int capacity;
  final String? registrationDeadline;
  final String difficulty;
  final String? duration;
  final String? contactEmail;
  final String? contactPhone;
  final String? videoUrl;
  final String createdBy;
  final String createdAt;
  final String? updatedAt;

  Event({
    required this.id,
    required this.title,
    required this.theme,
    this.description,
    this.imageUrl,
    required this.date,
    required this.location,
    this.category = 'concerto',
    this.status = 'published',
    this.capacity = 999,
    this.registrationDeadline,
    this.difficulty = 'intermediate',
    this.duration,
    this.contactEmail,
    this.contactPhone,
    this.videoUrl,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      theme: map['theme'] ?? '',
      description: map['description'],
      imageUrl: map['image_url'],
      date: map['date'] ?? '',
      location: map['location'] ?? '',
      category: map['category'] ?? 'concerto',
      status: map['status'] ?? 'published',
      capacity: map['capacity'] ?? 999,
      registrationDeadline: map['registration_deadline'],
      difficulty: map['difficulty'] ?? 'intermediate',
      duration: map['duration'],
      contactEmail: map['contact_email'],
      contactPhone: map['contact_phone'],
      videoUrl: map['video_url'],
      createdBy: map['created_by'] ?? '',
      createdAt: map['created_at'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'theme': theme,
      'description': description,
      'image_url': imageUrl,
      'date': date,
      'location': location,
      'category': category,
      'status': status,
      'capacity': capacity,
      'registration_deadline': registrationDeadline,
      'difficulty': difficulty,
      'duration': duration,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'video_url': videoUrl,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Event copyWith({
    String? id,
    String? title,
    String? theme,
    String? description,
    String? imageUrl,
    String? date,
    String? location,
    String? category,
    String? status,
    int? capacity,
    String? registrationDeadline,
    String? difficulty,
    String? duration,
    String? contactEmail,
    String? contactPhone,
    String? videoUrl,
    String? createdBy,
    String? createdAt,
    String? updatedAt,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      theme: theme ?? this.theme,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      date: date ?? this.date,
      location: location ?? this.location,
      category: category ?? this.category,
      status: status ?? this.status,
      capacity: capacity ?? this.capacity,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      difficulty: difficulty ?? this.difficulty,
      duration: duration ?? this.duration,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      videoUrl: videoUrl ?? this.videoUrl,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ============================================
// EVENT SONG (Relazione Evento-Brano)
// ============================================

class EventSong {
  final String id;
  final String eventId;
  final String songId;
  final int orderIndex;
  final String? notes;
  final String createdAt;
  final String? updatedAt;

  // Documenti specifici per questo evento-brano
  final List<EventSongDocument>? documents;

  EventSong({
    required this.id,
    required this.eventId,
    required this.songId,
    this.orderIndex = 0,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.documents,
  });

  factory EventSong.fromMap(Map<String, dynamic> map) {
    return EventSong(
      id: map['id'] ?? '',
      eventId: map['event_id'] ?? '',
      songId: map['song_id'] ?? '',
      orderIndex: map['order_index'] ?? 0,
      notes: map['notes'],
      createdAt: map['created_at'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'song_id': songId,
      'order_index': orderIndex,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  EventSong copyWith({
    String? id,
    String? eventId,
    String? songId,
    int? orderIndex,
    String? notes,
    String? createdAt,
    String? updatedAt,
    List<EventSongDocument>? documents,
  }) {
    return EventSong(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      songId: songId ?? this.songId,
      orderIndex: orderIndex ?? this.orderIndex,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      documents: documents ?? this.documents,
    );
  }
}

// ============================================
// EVENT SONG DOCUMENT (Documento specifico per evento-brano)
// ============================================

class EventSongDocument {
  final String id;
  final String eventSongId;
  final String documentId;
  final int orderIndex;
  final String? notes;
  final String createdAt;
  final String? updatedAt;

  EventSongDocument({
    required this.id,
    required this.eventSongId,
    required this.documentId,
    this.orderIndex = 0,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory EventSongDocument.fromMap(Map<String, dynamic> map) {
    return EventSongDocument(
      id: map['id'] ?? '',
      eventSongId: map['event_song_id'] ?? '',
      documentId: map['document_id'] ?? '',
      orderIndex: map['order_index'] ?? 0,
      notes: map['notes'],
      createdAt: map['created_at'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_song_id': eventSongId,
      'document_id': documentId,
      'order_index': orderIndex,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  EventSongDocument copyWith({
    String? id,
    String? eventSongId,
    String? documentId,
    int? orderIndex,
    String? notes,
    String? createdAt,
    String? updatedAt,
  }) {
    return EventSongDocument(
      id: id ?? this.id,
      eventSongId: eventSongId ?? this.eventSongId,
      documentId: documentId ?? this.documentId,
      orderIndex: orderIndex ?? this.orderIndex,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}