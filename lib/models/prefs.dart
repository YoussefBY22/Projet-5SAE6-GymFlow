import 'content.dart';
import 'json.dart';

/// Filtres d'une liste : identifiant du groupe → options cochées.
/// Dans un groupe les options s'additionnent (OU), entre groupes elles se
/// combinent (ET).
typedef FilterValues = Map<String, Set<String>>;

extension FilterValuesX on FilterValues {
  Set<String> of(String group) => this[group] ?? const {};
  bool has(String group, String option) => of(group).contains(option);
  bool isActive(String group) => of(group).isNotEmpty;

  /// Nombre d'options cochées (pastille du bouton « Filtres »).
  int get activeCount => values.fold(0, (n, s) => n + s.length);

  FilterValues toggled(String group, String option, {bool single = false}) {
    final next = {
      for (final e in entries) e.key: {...e.value},
    };
    final set = next[group] ?? <String>{};
    if (!set.remove(option)) {
      if (single) set.clear();
      set.add(option);
    }
    if (set.isEmpty) {
      next.remove(group);
    } else {
      next[group] = set;
    }
    return next;
  }

  Json toJson() => {
    for (final e in entries)
      if (e.value.isNotEmpty) e.key: e.value.toList(),
  };
}

FilterValues filterValuesFromJson(Object? j) {
  if (j is! Map) return {};
  return {
    for (final e in j.entries) e.key.toString(): stringList(e.value).toSet(),
  };
}

/// Préférences d'affichage d'un utilisateur, conservées avec son compte
/// (elles survivent à la déconnexion et suivent l'utilisateur).
class UiPrefs {
  const UiPrefs({this.contentLang = ContentLang.fr, this.filters = const {}});

  /// Langue d'affichage des noms d'exercices, workouts et programmes.
  final String contentLang;

  /// Filtres mémorisés par liste (`workouts`, `programs`, `courses`…).
  final Map<String, FilterValues> filters;

  UiPrefs copyWith({String? contentLang, Map<String, FilterValues>? filters}) =>
      UiPrefs(
        contentLang: contentLang ?? this.contentLang,
        filters: filters ?? this.filters,
      );

  Json toJson() => {
    'contentLang': contentLang,
    'filters': {for (final e in filters.entries) e.key: e.value.toJson()},
  };

  factory UiPrefs.fromJson(Object? j) {
    if (j is! Map) return const UiPrefs();
    final f = j['filters'];
    return UiPrefs(
      contentLang: ContentLang.normalize(j['contentLang'] as String?),
      filters: f is Map
          ? {
              for (final e in f.entries)
                e.key.toString(): filterValuesFromJson(e.value),
            }
          : const {},
    );
  }
}
