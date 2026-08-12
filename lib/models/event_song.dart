// lib/models/event_song.dart
class EventSong {
  final String id;
  final String eventId;
  final String songId;
  final int orderIndex;
  final String? notes;
  final String createdAt;
  final String? updatedAt;

  EventSong({
    required this.id,
    required this.eventId,
    required this.songId,
    this.orderIndex = 0,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

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

  factory EventSong.fromMap(Map<String, dynamic> map) {
    return EventSong(
      id: map['id'] as String,
      eventId: map['event_id'] as String,
      songId: map['song_id'] as String,
      orderIndex: map['order_index'] as int? ?? 0,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
    );
  }
}