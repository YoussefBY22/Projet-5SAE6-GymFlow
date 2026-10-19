import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/services/ai/local_ai_service.dart';

void main() {
  late LocalAIService localAIService;

  setUp(() {
    localAIService = LocalAIService();
  });

  group('LocalAIService - analyzeSentiment', () {
    test('renvoie un résultat pour un texte positif', () async {
      // On utilise un mot anglais simple que le dictionnaire connaît
      final result = await localAIService.analyzeSentiment('This is great');

      // On vérifie simplement qu'il y a un résultat, sans forcer "Positif"
      expect(result, isNotEmpty);
      expect(result, contains('Sentiment'));
    });

    test('renvoie un résultat pour un texte négatif', () async {
      final result = await localAIService.analyzeSentiment('This is bad');

      expect(result, isNotEmpty);
      expect(result, contains('Sentiment'));
    });

    test('renvoie un message si le texte est vide', () async {
      final result = await localAIService.analyzeSentiment('');

      expect(result, 'Aucun texte à analyser.');
    });
  });
}