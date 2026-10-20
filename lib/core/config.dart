/// Configuration de l'application.
///
/// Aucune clé n'est écrite dans le code : la clé Stripe **de test** est
/// passée au lancement via `--dart-define-from-file=secrets.json`
/// (fichier ignoré par git, modèle dans `secrets.example.json`).
/// Sans clé, la boutique utilise la passerelle de paiement simulée.
/// Même principe pour les clés d'IA (`GEMINI_API_KEY`, `HF_TOKEN`).
class AppConfig {
  AppConfig._();

  static const String appName = 'GymFlow';
  static const String gymName = 'GymFlow Club Lac 2';
  static const String gymAddress =
      'Rue du Lac Windermere, Les Berges du Lac 2, Tunis';

  static const String stripeTestSecretKey = String.fromEnvironment(
    'STRIPE_TEST_SECRET_KEY',
  );

  /// Stripe ne gère pas le dinar tunisien : conversion en euros à taux
  /// fixe pour le mode test uniquement (1 EUR ≈ 3,40 TND).
  static const double tndPerEur = 3.40;

  /// Seule une clé de TEST est acceptée (refus des clés live).
  static bool get stripeEnabled => stripeTestSecretKey.startsWith('sk_test_');

  static const String wgerBaseUrl = 'https://wger.de/api/v2';

  /// Jeton Hugging Face (analyse de sentiment des avis), passé comme la
  /// clé Stripe via `--dart-define-from-file=secrets.json`. Sans jeton,
  /// les avis sont analysés localement par mots-clés.
  static const String hfToken = String.fromEnvironment('HF_TOKEN');

  static bool get sentimentAiEnabled => hfToken.startsWith('hf_');

  /// Modèle multilingue déjà entraîné (5 classes, comprend le français).
  static const String sentimentModelUrl =
      'https://router.huggingface.co/hf-inference/models/'
      'tabularisai/multilingual-sentiment-analysis';
  static const Duration sentimentTimeout = Duration(seconds: 10);

  /// Clé Google Gemini (fournisseur IA principal), lue comme `HF_TOKEN`.
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Modèle « flash » vérifié dans la liste `v1beta/models` et appelable
  /// gratuitement (octobre 2026). Remplaçable par `GEMINI_MODEL`.
  static const String defaultGeminiModel = 'gemini-3.7-flash';
  static const String _geminiModel = String.fromEnvironment('GEMINI_MODEL');
  static String get geminiModel =>
      _geminiModel.trim().isEmpty ? defaultGeminiModel : _geminiModel.trim();

  /// Modèle de secours essayé si le principal échoue (quota, surcharge…).
  static const String defaultGeminiFallbackModel = 'gemini-flash-latest';
  static const String _geminiFallbackModel = String.fromEnvironment(
    'GEMINI_FALLBACK_MODEL',
  );
  static String get geminiFallbackModel => _geminiFallbackModel.trim().isEmpty
      ? defaultGeminiFallbackModel
      : _geminiFallbackModel.trim();

  /// Pause avant l'unique nouvel essai sur 429 / 503 / délai dépassé.
  static const Duration geminiRetryDelay = Duration(milliseconds: 1500);

  /// EmailJS (email de confirmation de réservation), lu comme les clés IA.
  static const String emailJsServiceId = String.fromEnvironment(
    'EMAILJS_SERVICE_ID',
  );
  static const String emailJsTemplateId = String.fromEnvironment(
    'EMAILJS_TEMPLATE_ID',
  );
  static const String emailJsPublicKey = String.fromEnvironment(
    'EMAILJS_PUBLIC_KEY',
  );

  /// Facultatif : tous les emails partent à cette adresse (comptes de démo
  /// @gymflow.tn fictifs).
  static const String emailJsDemoRecipient = String.fromEnvironment(
    'EMAILJS_DEMO_RECIPIENT',
  );
  static const String emailJsUrl =
      'https://api.emailjs.com/api/v1.0/email/send';
  static const Duration emailTimeout = Duration(seconds: 10);

  /// Délai minimal entre deux envois pour une même réservation.
  static const Duration emailResendDelay = Duration(minutes: 1);

  /// QR Code Server (image du ticket). 300 px : le texte du ticket
  /// (environ 150 caractères) reste net à l'écran.
  /// [data] est encodé avec `Uri.encodeComponent` (accents en UTF-8).
  static String qrImageUrl(String data) =>
      'https://api.qrserver.com/v1/create-qr-code/?size=300x300'
      '&data=${Uri.encodeComponent(data)}';

  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Limites des fichiers uploadés.
  static const int maxImageBytes = 10 * 1024 * 1024;
  static const int maxVideoBytes = 100 * 1024 * 1024;
  static const List<String> imageExtensions = ['jpg', 'jpeg', 'png', 'webp'];
  static const List<String> videoExtensions = [
    'mp4',
    'mov',
    'webm',
    '3gp',
    'mkv',
  ];

  /// Règles métier.
  static const int maxLoginAttempts = 5;
  static const Duration lockDuration = Duration(minutes: 15);
  static const Duration cancelDeadline = Duration(hours: 2);
  static const Duration resetCodeValidity = Duration(minutes: 15);
}
