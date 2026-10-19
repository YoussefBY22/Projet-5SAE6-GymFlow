import 'dart:convert';
import 'package:http/http.dart' as http;

class CloudAIService {
  // ⚠️ REMPLACEZ PAR VOTRE CLÉ API (Google AI Studio)
  static const String _apiKey = 'AQ.Ab8RN6LLwizW_Z0eazjTqW24MNcjIJ7PdDXZXpfZQQ9Di9nyNA';

  Future<String> generateText(String prompt) async {
    // On utilise le modèle recommandé par Google dans ses messages d'erreur récents
    // L'URL est celle de l'API REST v1beta, mais avec le bon nom de modèle
  final url = Uri.parse(
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=$_apiKey',
);

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 150,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        return text ?? "Aucune réponse générée.";
      } else {
        // Affiche le code HTTP et le corps de la réponse pour comprendre l'erreur
        return "Erreur HTTP ${response.statusCode}: ${response.body}";
      }
    } catch (e) {
      return "Erreur réseau : $e";
    }
  }
}