// lib/models/user_model.dart
class User {
  final String id;
  final String email;
  final String passwordHash;
  final String fullName;
  final String role;
  final String status;
  final String? profilePicture;
  final String? bio;
  final String createdAt;
  final String? updatedAt;
  final String? lastLogin;
  final int loginAttempts;
  final String? lockedUntil;
  final String? resetToken;
  final String? resetTokenExpiry;

  User({
    required this.id,
    required this.email,
    required this.passwordHash,
    required this.fullName,
    this.role = 'user',
    this.status = 'active',
    this.profilePicture,
    this.bio,
    required this.createdAt,
    this.updatedAt,
    this.lastLogin,
    this.loginAttempts = 0,
    this.lockedUntil,
    this.resetToken,
    this.resetTokenExpiry,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'password_hash': passwordHash,
      'full_name': fullName,
      'role': role,
      'status': status,
      'profile_picture': profilePicture,
      'bio': bio,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_login': lastLogin,
      'login_attempts': loginAttempts,
      'locked_until': lockedUntil,
      'reset_token': resetToken,
      'reset_token_expiry': resetTokenExpiry,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      email: map['email'] as String,
      passwordHash: map['password_hash'] as String,
      fullName: map['full_name'] as String,
      role: map['role'] as String? ?? 'user',
      status: map['status'] as String? ?? 'active',
      profilePicture: map['profile_picture'] as String?,
      bio: map['bio'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
      lastLogin: map['last_login'] as String?,
      loginAttempts: map['login_attempts'] as int? ?? 0,
      lockedUntil: map['locked_until'] as String?,
      resetToken: map['reset_token'] as String?,
      resetTokenExpiry: map['reset_token_expiry'] as String?,
    );
  }
}