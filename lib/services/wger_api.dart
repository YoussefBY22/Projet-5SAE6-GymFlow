import 'dart:convert';

import '../core/config.dart';
import '../core/errors.dart';
import '../models/enums.dart';
import '../models/exercise.dart';
import '../repositories/data_store.dart';
import 'backend.dart';

/// Exercice tel que renvoyé par l'API publique wger.de.
class WgerExercise {
  const WgerExercise({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.muscles,
    required this.equipment,
    required this.images,
    required this.license,
  });

  final int id;
  final String name;
  final String description;
  final String category;
  final List<String> muscles;
  final List<String> equipment;
  final List<String> images;
  final String license;

  /// Conversion d'une réponse `exerciseinfo` (langue : français, sinon
  /// anglais).
  factory WgerExercise.fromApi(Map<String, dynamic> j) {
    final translations = (j['translations'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    Map<String, dynamic>? pick(int lang) {
      for (final t in translations) {
        if (t['language'] == lang) return t;
      }
      return null;
    }

    final t = pick(12) ?? pick(2) ?? (translations.isEmpty ? null : translations.first);
    return WgerExercise(
      id: j['id'] as int,
      name: (t?['name'] as String? ?? 'Exercice ${j['id']}').trim(),
      description: stripHtml(t?['description'] as String? ?? ''),
      category: ((j['category'] as Map?)?['name'] as String?) ?? '',
      muscles: [
        for (final m in (j['muscles'] as List? ?? const []))
          ((m as Map)['name_en'] as String?)?.isNotEmpty == true
              ? m['name_en'] as String
              : m['name'] as String,
      ],
      equipment: [
        for (final e in (j['equipment'] as List? ?? const []))
          (e as Map)['name'] as String,
      ],
      images: [
        for (final i in (j['images'] as List? ?? const []))
          (i as Map)['image'] as String,
      ],
      license: ((j['license'] as Map?)?['short_name'] as String?) ?? 'CC-BY-SA',
    );
  }

  static String stripHtml(String html) => html
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Groupe musculaire principal déduit de la catégorie wger.
  Muscle get mappedMuscle => switch (category) {
    'Abs' => Muscle.abs,
    'Arms' =>
      muscles.any((m) => m.toLowerCase().contains('tricep'))
          ? Muscle.triceps
          : Muscle.biceps,
    'Back' => Muscle.back,
    'Calves' => Muscle.calves,
    'Cardio' => Muscle.cardio,
    'Chest' => Muscle.chest,
    'Legs' =>
      muscles.any((m) => m.toLowerCase().contains('glute'))
          ? Muscle.glutes
          : muscles.any((m) => m.toLowerCase().contains('hamstring'))
          ? Muscle.hamstrings
          : Muscle.quads,
    'Shoulders' => Muscle.shoulders,
    _ => Muscle.fullBody,
  };

  Equipment get mappedEquipment {
    final e = equipment.join(' ').toLowerCase();
    if (e.contains('dumbbell')) return Equipment.dumbbell;
    if (e.contains('barbell') || e.contains('sz-bar')) return Equipment.barbell;
    if (e.contains('kettlebell')) return Equipment.kettlebell;
    if (e.contains('band')) return Equipment.band;
    if (e.contains('mat')) return Equipment.mat;
    if (e.contains('cable')) return Equipment.cable;
    if (e.contains('bench') || e.contains('machine')) return Equipment.machine;
    return Equipment.bodyweight;
  }

  ExerciseType get mappedType =>
      category == 'Cardio' ? ExerciseType.cardio : ExerciseType.strength;
}

/// Catégories wger (identifiants de l'API) proposées dans l'import.
const wgerCategories = <int, String>{
  11: 'Pectoraux',
  12: 'Dos',
  13: 'Épaules',
  8: 'Bras',
  9: 'Jambes',
  14: 'Mollets',
  10: 'Abdominaux',
  15: 'Cardio',
};

/// Client de l'API externe wger (https://wger.de/api/v2/) avec cache local
/// SQLite et repli hors-ligne.
class WgerApi {
  WgerApi(this._b);
  final Backend _b;
  Map<String, String>? _cache;

  Future<Map<String, String>> _loadCache() async {
    final c = _cache;
    if (c != null) return c;
    final rows = await _b.store.loadAll(Collections.wgerCache);
    return _cache = {
      for (final r in rows) r['id'] as String: r['body'] as String,
    };
  }

  /// Page d'exercices d'une catégorie (20 par page).
  /// En cas d'erreur réseau, renvoie la version en cache si elle existe.
  Future<(List<WgerExercise>, bool fromCache)> browse({
    required int categoryId,
    int offset = 0,
  }) async {
    _b.requireRole(Backend.staff);
    final url =
        '${AppConfig.wgerBaseUrl}/exerciseinfo/?category=$categoryId&limit=20&offset=$offset';
    final cache = await _loadCache();
    String body;
    var fromCache = false;
    try {
      final res = await _b.httpClient
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) throw const NetworkException();
      body = utf8.decode(res.bodyBytes);
      cache[url] = body;
      await _b.store.put(Collections.wgerCache, url, {
        'id': url,
        'body': body,
        'at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {
      final cached = cache[url];
      if (cached == null) {
        throw const NetworkException(
          'API wger injoignable et aucune donnée en cache. Vérifiez votre connexion.',
        );
      }
      body = cached;
      fromCache = true;
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    final results = (json['results'] as List)
        .cast<Map<String, dynamic>>()
        .map(WgerExercise.fromApi)
        .where((e) => e.name.isNotEmpty)
        .toList();
    return (results, fromCache);
  }

  bool alreadyImported(int wgerId) =>
      _b.exercises.all.any((e) => e.wgerId == wgerId);

  /// Importe un exercice wger dans la bibliothèque GymFlow.
  Future<Exercise> import(WgerExercise w) async {
    if (alreadyImported(w.id)) {
      throw const BusinessRuleException('Exercice déjà importé.');
    }
    final description = w.description.length >= 10
        ? w.description
        : 'Exercice importé depuis wger.de (${w.category}).';
    return _b.exerciseService.create(
      name: w.name.length > 80 ? w.name.substring(0, 80) : w.name,
      primaryMuscle: w.mappedMuscle,
      equipment: w.mappedEquipment,
      level: Level.intermediate,
      type: w.mappedType,
      description: description,
      media: [
        for (final i in w.images.take(3))
          MediaItem(kind: MediaKind.image, source: i, caption: 'wger.de · ${w.license}'),
      ],
      wgerId: w.id,
    );
  }
}
