// lib/models/organ_template.dart

/// Template di organico predefinito (catalogo).
/// Non è specifico di un evento: è un modello riutilizzabile.
class OrganTemplate {
  final String id;
  final String name;
  final String? category;
  final String? description;
  final String createdAt;
  final String? updatedAt;
  final String? deletedAt;

  OrganTemplate({
    required this.id,
    required this.name,
    this.category,
    this.description,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'description': description,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
    };
  }

  factory OrganTemplate.fromMap(Map<String, dynamic> map) {
    return OrganTemplate(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String?,
      description: map['description'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
      deletedAt: map['deleted_at'] as String?,
    );
  }

  OrganTemplate copyWith({
    String? name,
    String? category,
    String? description,
    String? updatedAt,
    String? deletedAt,
  }) {
    return OrganTemplate(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  bool get isDeleted => deletedAt != null;
}
