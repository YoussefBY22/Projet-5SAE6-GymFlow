import 'dart:convert';

import '../core/config.dart';
import 'backend.dart';

/// Envoi d'e-mails réels via l'API externe EmailJS (pas de serveur :
/// l'appel HTTP part directement de l'application, web ou mobile).
/// Les identifiants sont passés au lancement via secrets.json.
class EmailService {
  EmailService(this._b);
  final Backend _b;

  bool get enabled =>
      AppConfig.emailJsServiceId.isNotEmpty &&
      AppConfig.emailJsTemplateId.isNotEmpty &&
      AppConfig.emailJsPublicKey.isNotEmpty;

  /// Envoie le code de réinitialisation. Renvoie `false` si l'envoi a
  /// échoué (pas de configuration, quota atteint, réseau) : l'application
  /// revient alors à l'affichage du code à l'écran.
  Future<bool> sendResetCode(String email, String code) async {
    if (!enabled) return false;
    final user = _b.users.all
        .where((u) => u.email == email.trim().toLowerCase())
        .firstOrNull;
    try {
      final res = await _b.httpClient
          .post(
            Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'service_id': AppConfig.emailJsServiceId,
              'template_id': AppConfig.emailJsTemplateId,
              'user_id': AppConfig.emailJsPublicKey,
              'template_params': {
                'to_email': email.trim(),
                'name': user?.firstName ?? 'membre GymFlow',
                'code': code,
              },
            }),
          )
          .timeout(const Duration(seconds: 20));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
