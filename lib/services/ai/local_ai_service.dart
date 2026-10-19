import 'package:sentiment_dart/sentiment_dart.dart';

class LocalAIService {
  /// Analyse le sentiment d'un texte EN LOCAL (sans API, fonctionne sur Desktop)
  Future<String> analyzeSentiment(String text) async {
    if (text.trim().isEmpty) {
      return "Aucun texte à analyser.";
    }

    try {
      // Utilisation de la méthode statique directement (sans 'new Sentiment()')
      final sentiment = Sentiment.analysis(text);
      
      if (sentiment.score > 0) {
        return "Sentiment : Positif (Score: ${sentiment.score})";
      } else if (sentiment.score < 0) {
        return "Sentiment : Négatif (Score: ${sentiment.score})";
      } else {
        return "Sentiment : Neutre (Score: ${sentiment.score})";
      }
    } catch (e) {
      return "Erreur lors de l'analyse locale : $e";
    }
  }

  void dispose() {}
}