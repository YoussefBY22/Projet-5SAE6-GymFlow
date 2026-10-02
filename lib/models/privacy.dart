import 'json.dart';

/// Réglages de confidentialité d'un membre.
///
/// Principe de **protection des données par défaut** : tout ce qui expose
/// la personne aux autres membres est désactivé tant qu'elle ne l'a pas
/// activé elle-même (profil visible, réseaux sociaux, partage de séances).
class PrivacySettings {
  const PrivacySettings({
    this.profileVisible = false,
    this.showSocialLinks = false,
    this.showClubFeed = true,
    this.askToShareSessions = true,
    this.hiddenByAdmin = false,
  });

  /// Profil visible des autres membres dans « Communauté ».
  final bool profileVisible;

  /// Réseaux sociaux affichés sur le profil public (si profil visible).
  final bool showSocialLinks;

  /// Préférence d'affichage : voir l'activité partagée des autres membres
  /// sur son propre accueil (ne publie rien).
  final bool showClubFeed;

  /// Proposer de partager chaque séance terminée (sinon tout reste privé).
  final bool askToShareSessions;

  /// Profil masqué de la communauté par la salle (modération).
  final bool hiddenByAdmin;

  /// Visible pour les autres membres, en tenant compte de la modération.
  bool get isPubliclyVisible => profileVisible && !hiddenByAdmin;

  PrivacySettings copyWith({
    bool? profileVisible,
    bool? showSocialLinks,
    bool? showClubFeed,
    bool? askToShareSessions,
    bool? hiddenByAdmin,
  }) => PrivacySettings(
    profileVisible: profileVisible ?? this.profileVisible,
    showSocialLinks: showSocialLinks ?? this.showSocialLinks,
    showClubFeed: showClubFeed ?? this.showClubFeed,
    askToShareSessions: askToShareSessions ?? this.askToShareSessions,
    hiddenByAdmin: hiddenByAdmin ?? this.hiddenByAdmin,
  );

  Json toJson() => {
    'profileVisible': profileVisible,
    'showSocialLinks': showSocialLinks,
    'showClubFeed': showClubFeed,
    'askToShareSessions': askToShareSessions,
    'hiddenByAdmin': hiddenByAdmin,
  };

  factory PrivacySettings.fromJson(Json? j) {
    if (j == null) return const PrivacySettings();
    return PrivacySettings(
      profileVisible: j['profileVisible'] as bool? ?? false,
      showSocialLinks: j['showSocialLinks'] as bool? ?? false,
      showClubFeed: j['showClubFeed'] as bool? ?? true,
      askToShareSessions: j['askToShareSessions'] as bool? ?? true,
      hiddenByAdmin: j['hiddenByAdmin'] as bool? ?? false,
    );
  }
}

/// Réseaux sociaux qu'un membre choisit de montrer (tous facultatifs).
class SocialLinks {
  const SocialLinks({
    this.instagram,
    this.facebook,
    this.linkedin,
    this.snapchat,
    this.publicEmail,
  });

  /// Identifiant Instagram (sans @).
  final String? instagram;

  /// Lien de profil Facebook (https://facebook.com/…).
  final String? facebook;

  /// Lien de profil LinkedIn (https://linkedin.com/in/…).
  final String? linkedin;

  /// Identifiant Snapchat.
  final String? snapchat;

  /// Adresse e-mail de contact publique (distincte de l'e-mail de connexion).
  final String? publicEmail;

  bool get isEmpty => [
    instagram,
    facebook,
    linkedin,
    snapchat,
    publicEmail,
  ].every((v) => v == null || v.isEmpty);

  Json toJson() => {
    'instagram': instagram,
    'facebook': facebook,
    'linkedin': linkedin,
    'snapchat': snapchat,
    'publicEmail': publicEmail,
  };

  factory SocialLinks.fromJson(Json? j) {
    if (j == null) return const SocialLinks();
    return SocialLinks(
      instagram: j['instagram'] as String?,
      facebook: j['facebook'] as String?,
      linkedin: j['linkedin'] as String?,
      snapchat: j['snapchat'] as String?,
      publicEmail: j['publicEmail'] as String?,
    );
  }
}

/// Trace horodatée d'un consentement donné ou retiré (preuve de
/// consentement exigée par la loi tunisienne n° 2004-63 et le RGPD).
class ConsentRecord {
  const ConsentRecord({
    required this.type,
    required this.granted,
    required this.at,
    required this.version,
  });

  /// Objet du consentement (voir [ConsentType]).
  final String type;
  final bool granted;
  final DateTime at;

  /// Version des conditions / de la politique acceptée.
  final String version;

  Json toJson() => {
    'type': type,
    'granted': granted,
    'at': dateToJson(at),
    'version': version,
  };

  factory ConsentRecord.fromJson(Json j) => ConsentRecord(
    type: j['type'] as String,
    granted: j['granted'] as bool? ?? false,
    at: dateOr(j['at'], DateTime(2026)),
    version: j['version'] as String? ?? '',
  );
}

/// Objets de consentement tracés.
class ConsentType {
  ConsentType._();
  static const terms = 'cgu_politique';
  static const profileVisible = 'profil_visible';
  static const socialLinks = 'reseaux_sociaux';
  static const shareSession = 'partage_seance';

  static String label(String type) => switch (type) {
    terms => 'Conditions d\'utilisation et politique de confidentialité',
    profileVisible => 'Profil visible dans la communauté',
    socialLinks => 'Affichage des réseaux sociaux',
    shareSession => 'Partage d\'une séance sur le fil du club',
    _ => type,
  };
}
