import '../core/errors.dart';
import '../core/search.dart';
import '../models/content.dart';
import '../models/enums.dart';
import '../models/exercise.dart';
import '../models/user.dart';
import '../repositories/repository.dart';
import 'backend.dart';
import 'library_service.dart';

/// Filtres de la bibliothèque d'exercices.
class ExerciseFilter {
  const ExerciseFilter({
    this.query = '',
    this.muscle,
    this.level,
    this.equipment,
    this.favoritesOnly = false,
  });

  final String query;
  final Muscle? muscle;
  final Level? level;
  final Equipment? equipment;
  final bool favoritesOnly;
}

/// API interne des exercices (CRUD + recherche).
/// Admin : tout ; coach : ses exercices et la modération du contenu publié
/// par les abonnés ; abonné : ses exercices personnels (privés, publiables
/// après validation).
class ExerciseService {
  ExerciseService(this._b);
  final Backend _b;

  List<Exercise> list([ExerciseFilter f = const ExerciseFilter()]) {
    final me = _b.requireUser();
    return _b.library.exercises(
      query: f.query,
      filters: {
        if (f.muscle != null) LibraryFilters.muscle: {f.muscle!.name},
        if (f.level != null) LibraryFilters.level: {f.level!.name},
        if (f.equipment != null) LibraryFilters.equipment: {f.equipment!.name},
        if (f.favoritesOnly) LibraryFilters.favorites: {'only'},
      },
    )..removeWhere((e) => !_b.library.canSee(me, e));
  }

  /// Exercice consultable par l'utilisateur connecté (null sinon).
  Exercise? byId(String id) {
    final e = _b.exercises.byId(id);
    if (e == null) return null;
    return _b.library.canSee(_b.auth.currentUser, e) ? e : null;
  }

  bool canEdit(AppUser user, Exercise e) => _b.library.canEdit(user, e);

  Future<Exercise> create({
    required String name,
    required Muscle primaryMuscle,
    List<Muscle> secondaryMuscles = const [],
    required Equipment equipment,
    required Level level,
    required ExerciseType type,
    required String description,
    List<String> steps = const [],
    List<String> mistakes = const [],
    String breathing = '',
    List<MediaItem> media = const [],
    int? wgerId,
    String lang = ContentLang.fr,
    String? altName,
    String? altDescription,
    List<String> aliases = const [],
  }) async {
    final me = _b.requireUser();
    _b.library.checkPersonalLimit(me, ContentKind.exercise);
    _validate(name, description);
    final key = Search.normalize(name);
    if (_b.exercises.all.any(
      (e) => _b.library.canSee(me, e) && Search.normalize(e.name) == key,
    )) {
      throw const ValidationException('Un exercice porte déjà ce nom.');
    }
    final e = Exercise(
      id: IdGen.next('ex_'),
      name: name.trim(),
      primaryMuscle: primaryMuscle,
      secondaryMuscles: secondaryMuscles,
      equipment: equipment,
      level: level,
      type: type,
      description: description.trim(),
      steps: _clean(steps),
      mistakes: _clean(mistakes),
      breathing: breathing.trim(),
      media: media,
      authorId: me.id,
      createdAt: _b.now(),
      wgerId: wgerId,
      lang: ContentLang.normalize(lang),
      altName: _opt(altName),
      altDescription: _opt(altDescription),
      aliases: _clean(aliases),
      // Staff : publié directement. Abonné : privé jusqu'à validation.
      publication: me.canManageContent
          ? const Publication()
          : Publication.personal,
    );
    await _b.exercises.save(e);
    _b.bus.emit();
    return e;
  }

  Future<Exercise> update(Exercise updated) async {
    final me = _b.requireUser();
    final existing =
        _b.exercises.byId(updated.id) ?? (throw const NotFoundException());
    if (!canEdit(me, existing)) {
      throw const PermissionDeniedException(
        'Vous ne pouvez modifier que vos propres exercices.',
      );
    }
    _validate(updated.name, updated.description);
    final saved = await _b.exercises.save(
      updated.copyWith(
        steps: _clean(updated.steps),
        mistakes: _clean(updated.mistakes),
        aliases: _clean(updated.aliases),
        altName: _opt(updated.altName),
        altDescription: _opt(updated.altDescription),
        clearTranslation: true,
        // Le statut de publication ne se change pas par une modification.
        publication: existing.publication,
        authorId: existing.authorId,
      ),
    );
    _b.bus.emit();
    return saved;
  }

  Future<void> delete(String id) async {
    final me = _b.requireUser();
    final e = _b.exercises.byId(id) ?? (throw const NotFoundException());
    if (!canEdit(me, e)) throw const PermissionDeniedException();
    final usedIn = _b.workouts.where(
      (w) => w.items.any((i) => i.exerciseId == id),
    );
    if (usedIn.isNotEmpty) {
      final visible = usedIn.where((w) => _b.library.canSee(me, w)).toList();
      throw BusinessRuleException(
        'Exercice utilisé dans ${usedIn.length} workout(s)'
        '${visible.isEmpty ? '' : ' : ${visible.map((w) => w.name).join(', ')}'}.',
      );
    }
    await _b.exercises.delete(id);
    await _b.audit.log('Suppression d\'exercice', e.name, targetId: id);
    _b.bus.emit();
  }

  static String? _opt(String? s) {
    final v = s?.trim() ?? '';
    return v.isEmpty ? null : v;
  }

  void _validate(String name, String description) {
    if (name.trim().length < 3 || name.trim().length > 80) {
      throw const ValidationException('Nom : 3 à 80 caractères.');
    }
    if (description.trim().length < 10) {
      throw const ValidationException('Description : 10 caractères minimum.');
    }
  }

  static List<String> _clean(List<String> list) =>
      list.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  /// Minuscule sans accents pour une recherche tolérante.
  static String normalize(String s) => Search.normalize(s);
}
