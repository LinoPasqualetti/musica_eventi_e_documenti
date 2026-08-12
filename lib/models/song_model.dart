// lib/models/song_model.dart - RIMUOVI orderIndex

class Song {
  final String id;
  final String title;
  final String? composer;
  final String? difficulty;
  final String? genre;
  final int? durationSeconds;
  final int? tempo;
  final String? keySignature;
  final String? timeSignature;
  final String? lyrics;
  final String createdBy;
  final String createdAt;
  final String? updatedAt;
  // ❌ RIMUOVI: final int? orderIndex;

  Song({
    required this.id,
    required this.title,
    this.composer,
    this.difficulty,
    this.genre,
    this.durationSeconds,
    this.tempo,
    this.keySignature,
    this.timeSignature,
    this.lyrics,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    // ❌ RIMUOVI: this.orderIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'composer': composer,
      'difficulty': difficulty,
      'genre': genre,
      'duration_seconds': durationSeconds,
      'tempo': tempo,
      'key_signature': keySignature,
      'time_signature': timeSignature,
      'lyrics': lyrics,
      // ❌ RIMUOVI: 'order_index': orderIndex,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id'] as String,
      title: map['title'] as String,
      composer: map['composer'] as String?,
      difficulty: map['difficulty'] as String?,
      genre: map['genre'] as String?,
      durationSeconds: map['duration_seconds'] as int?,
      tempo: map['tempo'] as int?,
      keySignature: map['key_signature'] as String?,
      timeSignature: map['time_signature'] as String?,
      lyrics: map['lyrics'] as String?,
      // ❌ RIMUOVI: orderIndex: map['order_index'] as int?,
      createdBy: map['created_by'] as String,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
    );
  }
}