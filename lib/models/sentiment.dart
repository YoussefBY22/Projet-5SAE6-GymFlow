import 'json.dart';

/// Les 5 classes du modèle `tabularisai/multilingual-sentiment-analysis`.
enum SentimentLabel {
  veryNegative('Very Negative'),
  negative('Negative'),
  neutral('Neutral'),
  positive('Positive'),
  veryPositive('Very Positive');

  const SentimentLabel(this.apiName);

  /// Libellé renvoyé par l'API Hugging Face.
  final String apiName;

  /// Regroupement en 3 tons pour l'affichage et le score de satisfaction.
  SentimentTone get tone => switch (this) {
    veryNegative || negative => SentimentTone.negative,
    neutral => SentimentTone.neutral,
    positive || veryPositive => SentimentTone.positive,
  };

  static SentimentLabel? fromApi(Object? name) {
    final n = name?.toString().trim().toLowerCase();
    for (final l in values) {
      if (l.apiName.toLowerCase() == n) return l;
    }
    return null;
  }
}

/// Ton affiché sur un avis.
enum SentimentTone {
  positive('Positif', '😊'),
  neutral('Neutre', '😐'),
  negative('Négatif', '😞');

  const SentimentTone(this.label, this.emoji);
  final String label;
  final String emoji;
}

/// Origine de l'analyse : modèle IA distant ou mots-clés locaux (secours).
enum SentimentSource {
  ia('IA'),
  local('Analyse locale');

  const SentimentSource(this.label);
  final String label;
}

/// Fournisseur du modèle IA utilisé (le badge affiche simplement « IA »).
enum AiProvider {
  gemini('Gemini'),
  huggingface('Hugging Face');

  const AiProvider(this.label);
  final String label;

  static AiProvider? fromJson(Object? v) {
    for (final p in values) {
      if (p.name == v) return p;
    }
    return null;
  }
}

/// Résultat enregistré avec l'avis (aucun nouvel appel à l'API ensuite).
class SentimentResult {
  const SentimentResult({
    required this.label,
    required this.score,
    required this.source,
    required this.analyzedAt,
    this.provider,
    this.fallbackReason,
  });

  final SentimentLabel label;

  /// Confiance de 0 à 1.
  final double score;
  final SentimentSource source;
  final DateTime analyzedAt;

  /// Modèle IA qui a répondu (`null` pour l'analyse locale).
  final AiProvider? provider;

  /// Pourquoi l'IA n'a pas répondu (analyse locale), sans aucune clé :
  /// affiché dans l'infobulle du badge, y compris en release.
  final String? fallbackReason;

  SentimentTone get tone => label.tone;

  Json toJson() => {
    'label': label.apiName,
    'score': score,
    'source': source.name,
    'analyzedAt': dateToJson(analyzedAt),
    'provider': provider?.name,
    'fallbackReason': fallbackReason,
  };

  /// `null` si la donnée est absente ou illisible (anciens avis).
  static SentimentResult? fromJson(Object? v) {
    if (v is! Map) return null;
    final label = SentimentLabel.fromApi(v['label']);
    if (label == null) return null;
    return SentimentResult(
      label: label,
      score: toDouble(v['score']).clamp(0, 1).toDouble(),
      source: v['source'] == SentimentSource.ia.name
          ? SentimentSource.ia
          : SentimentSource.local,
      analyzedAt: dateOr(v['analyzedAt'], DateTime(2026)),
      provider: AiProvider.fromJson(v['provider']),
      fallbackReason: v['fallbackReason'] as String?,
    );
  }
}
