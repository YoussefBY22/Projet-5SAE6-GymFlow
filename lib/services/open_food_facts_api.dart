import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/errors.dart';
import '../models/json.dart';
import '../models/nutrition.dart';
import 'backend.dart';

/// Fiche importée depuis Open Food Facts, à relire par l'admin.
class OffProduct {
  const OffProduct({
    required this.barcode,
    required this.nutrition,
    this.name,
    this.brand,
    this.imageUrl,
    this.missing = const [],
  });

  final String barcode;
  final String? name;
  final String? brand;
  final String? imageUrl;
  final Nutrition nutrition;

  /// Valeurs nutritionnelles absentes de la base (« protéines »…).
  final List<String> missing;

  bool get complete => missing.isEmpty;
}

/// API externe Open Food Facts (base collaborative et ouverte de produits
/// alimentaires, sans clé). Seul le point d'accès « produit » est utilisé,
/// avec la liste des champs utiles (paramètre `fields`).
///
/// Aucun en-tête personnalisé n'est envoyé : la requête reste « simple »
/// et passe dans le navigateur (CORS) sans requête préalable.
class OpenFoodFactsApi {
  OpenFoodFactsApi(this._b);
  final Backend _b;

  static const _fields =
      'code,product_name,product_name_fr,brands,image_front_url,nutriments,'
      'serving_quantity,product_quantity,nutriscore_grade,allergens_tags';
  static const timeout = Duration(seconds: 15);
  static const _manual = 'Vous pouvez remplir la fiche à la main.';

  /// Récupère la fiche d'un code-barres (super admin uniquement).
  Future<OffProduct> fetch(String rawCode) async {
    _b.requireRole(Backend.adminOnly);
    final code = rawCode.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{8,14}$').hasMatch(code)) {
      throw const ValidationException('Code-barres : 8 à 14 chiffres.');
    }
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$code.json?fields=$_fields',
    );
    final http.Response res;
    try {
      res = await _b.httpClient.get(uri).timeout(timeout);
    } on TimeoutException {
      throw const NetworkException(
        'Open Food Facts ne répond pas (délai dépassé). Réessayez. $_manual',
      );
    } catch (_) {
      throw const NetworkException(
        'Impossible de joindre Open Food Facts (pas de réseau ?). $_manual',
      );
    }
    if (res.statusCode == 404) {
      throw const NotFoundException(
        'Code-barres inconnu dans Open Food Facts. $_manual',
      );
    }
    if (res.statusCode != 200) {
      throw NetworkException(
        'Open Food Facts est indisponible (erreur ${res.statusCode}). $_manual',
      );
    }
    final Object? data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw const NetworkException(
        'Réponse illisible d\'Open Food Facts. $_manual',
      );
    }
    if (data is! Map || data['status'] != 1 || data['product'] is! Map) {
      throw const NotFoundException(
        'Code-barres inconnu dans Open Food Facts. $_manual',
      );
    }
    return parse(code, Map<String, dynamic>.from(data['product'] as Map));
  }

  /// Transforme la fiche brute en données de l'application. Les valeurs
  /// hors limites (ex. 150 g de protéines pour 100 g) sont ignorées.
  static OffProduct parse(String code, Json p) {
    final n = p['nutriments'] is Map
        ? Map<String, dynamic>.from(p['nutriments'] as Map)
        : <String, dynamic>{};
    double? per100(String key) => _bounded(n['${key}_100g'], 100);
    final nutrition = Nutrition(
      proteins: per100('proteins'),
      carbs: per100('carbohydrates'),
      sugars: per100('sugars'),
      fat: per100('fat'),
      kcal: _bounded(n['energy-kcal_100g'], 900),
      servingG: _bounded(p['serving_quantity'], 2000),
      netWeightG: _bounded(p['product_quantity'], 50000),
      nutriScore: switch (p['nutriscore_grade']) {
        final String s when RegExp(r'^[a-e]$').hasMatch(s) => s,
        'not-applicable' => 'not-applicable',
        _ => null,
      },
      allergens: {
        for (final t in stringList(
          p['allergens_tags'] is List ? p['allergens_tags'] : null,
        ))
          Nutrition.allergenLabel(t),
      }.where((a) => a.isNotEmpty).toList(),
      source: Nutrition.offSource,
    );
    final image = _text(p['image_front_url'], 500);
    return OffProduct(
      barcode: code,
      name: _text(p['product_name_fr'], 80) ?? _text(p['product_name'], 80),
      brand: _text(_text(p['brands'], 200)?.split(',').first, 40),
      imageUrl: image != null && image.startsWith('https://') ? image : null,
      nutrition: nutrition,
      missing: [
        if (nutrition.proteins == null) 'protéines',
        if (nutrition.carbs == null) 'glucides',
        if (nutrition.sugars == null) 'sucres',
        if (nutrition.fat == null) 'lipides',
        if (nutrition.kcal == null) 'kcal',
      ],
    );
  }

  /// Nombre (ou texte numérique) compris entre 0 et `max`, sinon null.
  static double? _bounded(Object? v, double max) {
    final d = v is num
        ? v.toDouble()
        : (v is String ? double.tryParse(v.replaceAll(',', '.')) : null);
    if (d == null || d.isNaN || d < 0 || d > max) return null;
    return double.parse(d.toStringAsFixed(1));
  }

  /// Texte externe nettoyé (caractères de contrôle retirés) et tronqué.
  static String? _text(Object? v, int max) {
    if (v is! String) return null;
    final t = v.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ').trim();
    if (t.isEmpty) return null;
    return t.length > max ? t.substring(0, max).trim() : t;
  }
}
