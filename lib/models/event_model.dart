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

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'] as String,
      title: map['title'] as String,
      theme: map['theme'] as String,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      date: map['date'] as String,
      location: map['location'] as String,
      category: map['category'] as String? ?? 'concerto',
      status: map['status'] as String? ?? 'published',
      capacity: map['capacity'] as int? ?? 999,
      registrationDeadline: map['registration_deadline'] as String?,
      difficulty: map['difficulty'] as String? ?? 'intermediate',
      duration: map['duration'] as String?,
      contactEmail: map['contact_email'] as String?,
      contactPhone: map['contact_phone'] as String?,
      videoUrl: map['video_url'] as String?,
      createdBy: map['created_by'] as String,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
    );
  }
}