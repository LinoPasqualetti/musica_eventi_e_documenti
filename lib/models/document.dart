// lib/models/document.dart

import 'dart:typed_data';

class Document {
  final String id;
  final String docType;
  final String fileName;
  final String? filePath;
  final int? fileSize;
  final String? mimeType;
  final String description;
  final Uint8List? content;  // BLOB per MXL/ABC/MIDI/KAR
  final String storageMode;
  final bool isPublic;
  final String uploadedBy;
  final String createdAt;
  final String? updatedAt;
  final String? songId;

  Document({
    required this.id,
    required this.docType,
    required this.fileName,
    this.filePath,
    this.fileSize,
    this.mimeType,
    this.description = '',
    this.content,
    this.storageMode = 'filesystem',
    this.isPublic = true,
    required this.uploadedBy,
    required this.createdAt,
    this.updatedAt,
    this.songId,
  });

  bool get isBlob => storageMode == 'blob' && content != null;

  bool get isStructuredData =>
      ['mxl', 'abc', 'mid', 'kar'].contains(docType);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doc_type': docType,
      'file_name': fileName,
      'file_path': filePath,
      'file_size': fileSize,
      'mime_type': mimeType,
      'description': description,
      'content': content,
      'storage_mode': storageMode,
      'is_public': isPublic ? 1 : 0,
      'uploaded_by': uploadedBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'song_id': songId,
    };
  }

  factory Document.fromMap(Map<String, dynamic> map) {
    return Document(
      id: map['id'] ?? '',
      docType: map['doc_type'] ?? '',
      fileName: map['file_name'] ?? '',
      filePath: map['file_path'],
      fileSize: map['file_size'],
      mimeType: map['mime_type'],
      description: map['description'] ?? '',
      content: map['content'] as Uint8List?,
      storageMode: map['storage_mode'] ?? 'filesystem',
      isPublic: (map['is_public'] ?? 1) == 1,
      uploadedBy: map['uploaded_by'] ?? '',
      createdAt: map['created_at'] ?? '',
      updatedAt: map['updated_at'],
      songId: map['song_id'],
    );
  }

  Document copyWith({
    String? id,
    String? docType,
    String? fileName,
    String? filePath,
    int? fileSize,
    String? mimeType,
    String? description,
    Uint8List? content,
    String? storageMode,
    bool? isPublic,
    String? uploadedBy,
    String? createdAt,
    String? updatedAt,
    String? songId,
  }) {
    return Document(
      id: id ?? this.id,
      docType: docType ?? this.docType,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      description: description ?? this.description,
      content: content ?? this.content,
      storageMode: storageMode ?? this.storageMode,
      isPublic: isPublic ?? this.isPublic,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      songId: songId ?? this.songId,
    );
  }
}