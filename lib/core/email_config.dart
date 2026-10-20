/// Configuration de l'email de confirmation, **commitée** : aucune clé
/// secrète, l'email fonctionne sans `secrets.json` (PC d'un collègue,
/// nouveau clone).
///
/// Fournisseur par défaut : FormSubmit (`formsubmit.co`), gratuit, sans
/// compte ni clé. Il n'envoie qu'à une adresse fixe, activée une fois par
/// email, **pour une origine donnée** (ici `http://localhost:8080`).
/// Voir DECISIONS.md pour activer une nouvelle origine.
class EmailConfig {
  EmailConfig._();

  /// Destinataire unique de tous les emails de confirmation (démo).
  static const String formSubmitRecipient = 'zouaoui.farah@esprit.tn';

  static const String formSubmitBaseUrl = 'https://formsubmit.co/ajax/';

  /// Port fixe de l'application web : l'activation FormSubmit est liée à
  /// l'origine (`flutter run -d chrome --web-port 8080`).
  static const int webPort = 8080;

  /// Origines activées dans FormSubmit (lien « Activate Form » cliqué).
  static const List<String> activatedOrigins = ['http://localhost:8080'];

  /// Origine envoyée par l'application Android (en-têtes `Origin` et
  /// `Referer`, qu'un client Dart n'envoie pas de lui-même) : la même que
  /// l'origine web activée.
  static const String nativeOrigin = 'http://localhost:8080';
}
