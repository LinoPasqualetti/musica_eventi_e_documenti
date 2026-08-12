// lib/models/song_document.dart
class SongDocument {
  final String id;
  final String documentId;
  final String songId;
  final int orderIndex;
  final String? notes;
  final String createdAt;
  final String? updatedAt;

  SongDocument({
    required this.id,
    required this.documentId,
    required this.songId,
    this.orderIndex = 0,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'song_id': songId,
      'order_index': orderIndex,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory SongDocument.fromMap(Map<String, dynamic> map) {
    return SongDocument(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      songId: map['song_id'] as String,
      orderIndex: map['order_index'] as int? ?? 0,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
    );
  }
}