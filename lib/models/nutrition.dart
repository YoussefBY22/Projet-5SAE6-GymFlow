import 'json.dart';

/// Valeurs nutritionnelles d'un produit (pour 100 g), importées depuis
/// Open Food Facts ou saisies à la main par l'admin.
///
/// Les calculs (protéines par portion, prix par gramme de protéine) sont
/// faits ici, par le code : l'IA ne fait que les commenter.
class Nutrition {
  const Nutrition({
    this.proteins,
    this.carbs,
    this.sugars,
    this.fat,
    this.kcal,
    this.servingG,
    this.netWeightG,
    this.nutriScore,
    this.allergens = const [],
    this.source,
  });

  /// Pour 100 g.
  final double? proteins;
  final double? carbs;
  final double? sugars;
  final double? fat;
  final double? kcal;

  /// Taille d'une portion et poids net du produit vendu, en grammes.
  final double? servingG;
  final double? netWeightG;

  /// « a » à « e », « not-applicable » (compléments), ou null si inconnu.
  final String? nutriScore;

  /// Libellés en français (« Lait », « Soja »…).
  final List<String> allergens;

  /// « Open Food Facts », ou null pour une saisie manuelle.
  final String? source;

  static const offSource = 'Open Food Facts';

  bool get isEmpty =>
      proteins == null &&
      carbs == null &&
      sugars == null &&
      fat == null &&
      kcal == null &&
      servingG == null &&
      netWeightG == null &&
      nutriScore == null &&
      allergens.isEmpty;

  /// Assez de données pour un résumé utile (protéines et énergie).
  bool get enoughForSummary => proteins != null && kcal != null;

  /// Protéines dans une portion, en grammes.
  double? get proteinPerServing =>
      proteins == null || servingG == null ? null : proteins! * servingG! / 100;

  /// Protéines contenues dans tout le produit, en grammes.
  double? get totalProtein => proteins == null || netWeightG == null
      ? null
      : proteins! * netWeightG! / 100;

  /// Prix d'un gramme de protéine (TND/g) pour le prix de vente donné.
  double? pricePerProteinGram(double price) {
    final total = totalProtein;
    if (total == null || total <= 0 || price <= 0) return null;
    return price / total;
  }

  /// Niveau de sucres pour 100 g, seuils usuels de l'étiquetage
  /// nutritionnel (FSA, Royaume-Uni) : faible ≤ 5 g, élevé > 22,5 g.
  String? get sugarLevel => sugars == null
      ? null
      : (sugars! <= 5 ? 'faible' : (sugars! > 22.5 ? 'élevé' : 'modéré'));

  /// Nutri-Score affichable (« A » à « E »), ou null.
  String? get nutriScoreLetter {
    final s = nutriScore?.toLowerCase();
    return s != null && RegExp(r'^[a-e]$').hasMatch(s) ? s.toUpperCase() : null;
  }

  String get nutriScoreLabel =>
      nutriScoreLetter ??
      (nutriScore == 'not-applicable' ? 'Non applicable' : 'Inconnu');

  Nutrition copyWith({double? netWeightG, double? servingG, String? source}) =>
      Nutrition(
        proteins: proteins,
        carbs: carbs,
        sugars: sugars,
        fat: fat,
        kcal: kcal,
        servingG: servingG ?? this.servingG,
        netWeightG: netWeightG ?? this.netWeightG,
        nutriScore: nutriScore,
        allergens: allergens,
        source: source ?? this.source,
      );

  Json toJson() => {
    'proteins': proteins,
    'carbs': carbs,
    'sugars': sugars,
    'fat': fat,
    'kcal': kcal,
    'servingG': servingG,
    'netWeightG': netWeightG,
    'nutriScore': nutriScore,
    'allergens': allergens,
    'source': source,
  };

  factory Nutrition.fromJson(Json j) => Nutrition(
    proteins: toDoubleOrNull(j['proteins']),
    carbs: toDoubleOrNull(j['carbs']),
    sugars: toDoubleOrNull(j['sugars']),
    fat: toDoubleOrNull(j['fat']),
    kcal: toDoubleOrNull(j['kcal']),
    servingG: toDoubleOrNull(j['servingG']),
    netWeightG: toDoubleOrNull(j['netWeightG']),
    nutriScore: j['nutriScore'] as String?,
    allergens: stringList(j['allergens']),
    source: j['source'] as String?,
  );

  /// Libellé français d'une étiquette d'allergène Open Food Facts
  /// (« en:milk » → « Lait »).
  static String allergenLabel(String tag) {
    final key = tag.contains(':') ? tag.split(':').last : tag;
    final k = key.trim().toLowerCase();
    const labels = {
      'milk': 'Lait',
      'lait': 'Lait',
      'eggs': 'Œufs',
      'oeufs': 'Œufs',
      'gluten': 'Gluten',
      'soybeans': 'Soja',
      'soja': 'Soja',
      'peanuts': 'Arachides',
      'arachides': 'Arachides',
      'nuts': 'Fruits à coque',
      'sesame-seeds': 'Sésame',
      'fish': 'Poisson',
      'crustaceans': 'Crustacés',
      'molluscs': 'Mollusques',
      'celery': 'Céleri',
      'mustard': 'Moutarde',
      'lupin': 'Lupin',
      'sulphur-dioxide-and-sulphites': 'Sulfites',
    };
    final label = labels[k];
    if (label != null) return label;
    final plain = k.replaceAll('-', ' ');
    return plain.isEmpty ? plain : plain[0].toUpperCase() + plain.substring(1);
  }
}
