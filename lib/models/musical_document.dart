// lib/models/musical_document.dart
class MusicalDocument {
  final String id;
  final String songId;
  final String docType;
  final String fileName;
  final String filePath;
  final int? fileSize;
  final String? mimeType;
  final String? description;
  final bool isPublic;
  final String uploadedBy;
  final String createdAt;
  final String? updatedAt;

  MusicalDocument({
    required this.id,
    required this.songId,
    required this.docType,
    required this.fileName,
    required this.filePath,
    this.fileSize,
    this.mimeType,
    this.description,
    this.isPublic = true,
    required this.uploadedBy,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'song_id': songId,
      'doc_type': docType,
      'file_name': fileName,
      'file_path': filePath,
      'file_size': fileSize,
      'mime_type': mimeType,
      'description': description,
      'is_public': isPublic ? 1 : 0,
      'uploaded_by': uploadedBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory MusicalDocument.fromMap(Map<String, dynamic> map) {
    return MusicalDocument(
      id: map['id'] as String,
      songId: map['song_id'] as String,
      docType: map['doc_type'] as String,
      fileName: map['file_name'] as String,
      filePath: map['file_path'] as String,
      fileSize: map['file_size'] as int?,
      mimeType: map['mime_type'] as String?,
      description: map['description'] as String?,
      isPublic: (map['is_public'] as int? ?? 1) == 1,
      uploadedBy: map['uploaded_by'] as String,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
    );
  }
}