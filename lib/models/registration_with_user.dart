// lib/models/registration_with_user.dart
import 'registration_model.dart';

/// Modello che unisce una Registration ai dati dell'utente collegato.
/// Usato in F5 (gestione candidature) per mostrare nome/email del candidato.
class RegistrationWithUser {
  final Registration registration;
  final String? userName;
  final String? userEmail;

  RegistrationWithUser({
    required this.registration,
    this.userName,
    this.userEmail,
  });

  /// Nome da mostrare.
  /// - Se è una candidatura per conto terzi: "Nome Candidato (da Referente)"
  /// - Se è per sé: mostra nome o email dell'utente
  /// - Fallback: user_id
  String get displayName {
    final candName = registration.candidateName;
    final hasCandidate = candName != null && candName.isNotEmpty;
    final hasReferente = userName != null && userName!.isNotEmpty;

    if (hasCandidate && hasReferente && candName != userName) {
      return '$candName (da $userName)';
    }
    if (hasCandidate) return candName;
    if (hasReferente) return userName!;
    if (userEmail != null && userEmail!.isNotEmpty) return userEmail!;
    return 'Utente ${registration.userId}';
  }

  /// Nome del candidato "pulito", senza referente.
  String get candidateOnly {
    final candName = registration.candidateName;
    if (candName != null && candName.isNotEmpty) return candName;
    if (userName != null && userName!.isNotEmpty) return userName!;
    if (userEmail != null && userEmail!.isNotEmpty) return userEmail!;
    return 'Utente ${registration.userId}';
  }

  /// True se la candidatura è per conto terzi (referente != candidato).
  bool get isForThirdParty {
    final candName = registration.candidateName;
    if (candName == null || candName.isEmpty) return false;
    if (userName == null || userName!.isEmpty) return false;
    return candName != userName;
  }

  factory RegistrationWithUser.fromMap(Map<String, dynamic> map) {
    final reg = Registration.fromMap(map);

    return RegistrationWithUser(
      registration: reg,
      userName: map['user_full_name'] as String?,
      userEmail: map['user_email'] as String?,
    );
  }
}