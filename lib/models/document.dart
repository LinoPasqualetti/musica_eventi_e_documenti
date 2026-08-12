// lib/models/document.dart
class Document {
  final String id;
  final String docType;
  final String fileName;
  final String filePath;
  final int fileSize;
  final String description;
  final bool isPublic;
  final String uploadedBy;
  final String createdAt;
  final String? updatedAt;

  Document({
    required this.id,
    required this.docType,
    required this.fileName,
    required this.filePath,
    this.fileSize = 0,
    this.description = '',
    this.isPublic = true,
    required this.uploadedBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory Document.fromMap(Map<String, dynamic> map) {
    // Gestisci is_public che può essere int (0/1) o bool
    bool isPublicValue;
    final isPublicRaw = map['is_public'];
    if (isPublicRaw is bool) {
      isPublicValue = isPublicRaw;
    } else if (isPublicRaw is int) {
      isPublicValue = isPublicRaw == 1;
    } else if (isPublicRaw is String) {
      isPublicValue = isPublicRaw == '1' || isPublicRaw.toLowerCase() == 'true';
    } else {
      isPublicValue = true; // default
    }

    return Document(
      id: map['id']?.toString() ?? '',
      docType: map['doc_type']?.toString() ?? '',
      fileName: map['file_name']?.toString() ?? '',
      filePath: map['file_path']?.toString() ?? '',
      fileSize: map['file_size'] is int ? map['file_size'] : 0,
      description: map['description']?.toString() ?? '',
      isPublic: isPublicValue,
      uploadedBy: map['uploaded_by']?.toString() ?? '',
      createdAt: map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doc_type': docType,
      'file_name': fileName,
      'file_path': filePath,
      'file_size': fileSize,
      'description': description,
      'is_public': isPublic ? 1 : 0,
      'uploaded_by': uploadedBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Document copyWith({
    String? id,
    String? docType,
    String? fileName,
    String? filePath,
    int? fileSize,
    String? description,
    bool? isPublic,
    String? uploadedBy,
    String? createdAt,
    String? updatedAt,
  }) {
    return Document(
      id: id ?? this.id,
      docType: docType ?? this.docType,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      description: description ?? this.description,
      isPublic: isPublic ?? this.isPublic,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}