import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../models/json.dart';

/// Réponse de Gemini : le texte généré, ou un message d'erreur lisible.
class GeminiReply {
  const GeminiReply.text(String this.text) : error = null;
  const GeminiReply.error(String this.error) : text = null;

  final String? text;
  final String? error;
  bool get ok => text != null;
}

/// Client commun de l'API externe Google Gemini (point d'accès REST
/// `generateContent`), partagé par le chatbot et la fiche produit.
///
/// Modèle léger et rapide d'abord, second modèle en secours, délai maximum
/// de 25 secondes. La clé est passée au lancement via secrets.json.
class GeminiClient {
  GeminiClient(this._http, {this.apiKey = AppConfig.geminiApiKey});

  final http.Client _http;

  /// Clé injectable (clé factice dans les tests, sans réseau).
  final String apiKey;

  bool get enabled => apiKey.isNotEmpty;

  static const quotaMessage =
      'Le quota gratuit de l\'assistant est atteint pour le moment. '
      'Réessayez dans quelques minutes.';
  static const unreachableMessage =
      'Je n\'arrive pas à joindre l\'assistant (connexion ou service '
      'indisponible). Réessayez dans un instant.';

  /// Envoie la consigne système et les messages ; `json` demande une
  /// réponse au format JSON, `schema` en fixe la structure (sortie
  /// structurée). La réponse reste à valider par l'appelant.
  Future<GeminiReply> generate({
    required String system,
    required List<Json> contents,
    double temperature = 0.4,
    int maxOutputTokens = 400,
    bool json = false,
    Json? schema,
  }) async {
    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': system},
        ],
      },
      'contents': contents,
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxOutputTokens,
        if (json) 'responseMimeType': 'application/json',
        if (json && schema != null) 'responseSchema': schema,
      },
    });
    for (final model in AppConfig.geminiModels) {
      try {
        final res = await _http
            .post(
              Uri.parse(
                'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
              ),
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': apiKey,
              },
              body: body,
            )
            .timeout(const Duration(seconds: 25));
        if (res.statusCode == 429) return const GeminiReply.error(quotaMessage);
        if (res.statusCode != 200) continue;
        final j =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final parts =
            (((j['candidates'] as List?)?.first as Map?)?['content']
                    as Map?)?['parts']
                as List?;
        final text = parts
            ?.map((p) => (p as Map)['text'] ?? '')
            .join()
            .toString()
            .trim();
        if (text != null && text.isNotEmpty) return GeminiReply.text(text);
      } catch (_) {
        // On essaie le modèle suivant.
      }
    }
    return const GeminiReply.error(unreachableMessage);
  }

  /// Schéma d'un objet JSON dont tous les champs sont des textes requis.
  static Json stringFields(List<String> names) => {
    'type': 'OBJECT',
    'properties': {
      for (final n in names) n: {'type': 'STRING'},
    },
    'required': names,
  };

  /// Message utilisateur unique, au format attendu par `contents`.
  static List<Json> userMessage(String text) => [
    {
      'role': 'user',
      'parts': [
        {'text': text},
      ],
    },
  ];
}
