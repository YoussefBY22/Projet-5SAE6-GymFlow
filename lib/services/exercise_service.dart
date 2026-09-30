import '../core/errors.dart';
import '../models/enums.dart';
import '../models/exercise.dart';
import '../models/user.dart';
import '../repositories/repository.dart';
import 'backend.dart';

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
/// Admin : tout ; coach : crée et modifie ses exercices ; abonné : lecture.
class ExerciseService {
  ExerciseService(this._b);
  final Backend _b;

  List<Exercise> list([ExerciseFilter f = const ExerciseFilter()]) {
    final me = _b.requireUser();
    final q = normalize(f.query);
    return _b.exercises.where((e) {
      if (f.muscle != null &&
          e.primaryMuscle != f.muscle &&
          !e.secondaryMuscles.contains(f.muscle)) {
        return false;
      }
      if (f.level != null && e.level != f.level) return false;
      if (f.equipment != null && e.equipment != f.equipment) return false;
      if (f.favoritesOnly && !me.favoriteIds.contains(e.id)) return false;
      if (q.isNotEmpty &&
          !normalize(
            '${e.name} ${e.primaryMuscle.label} ${e.equipment.label}',
          ).contains(q)) {
        return false;
      }
      return true;
    })..sort((a, b) => a.name.compareTo(b.name));
  }

  Exercise? byId(String id) => _b.exercises.byId(id);

  bool canEdit(AppUser user, Exercise e) =>
      user.isAdmin || (user.isCoach && e.authorId == user.id);

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
  }) async {
    final me = _b.requireRole(Backend.staff);
    _validate(name, description);
    if (_b.exercises.all.any(
      (e) => e.name.toLowerCase() == name.trim().toLowerCase(),
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
    );
    await _b.exercises.save(e);
    _b.bus.emit();
    return e;
  }

  Future<Exercise> update(Exercise updated) async {
    final me = _b.requireRole(Backend.staff);
    final existing =
        _b.exercises.byId(updated.id) ?? (throw const NotFoundException());
    if (!canEdit(me, existing)) {
      throw const PermissionDeniedException(
        'Un coach ne peut modifier que ses propres exercices.',
      );
    }
    _validate(updated.name, updated.description);
    final saved = await _b.exercises.save(
      updated.copyWith(
        steps: _clean(updated.steps),
        mistakes: _clean(updated.mistakes),
      ),
    );
    _b.bus.emit();
    return saved;
  }

  Future<void> delete(String id) async {
    final me = _b.requireRole(Backend.staff);
    final e = _b.exercises.byId(id) ?? (throw const NotFoundException());
    if (!canEdit(me, e)) throw const PermissionDeniedException();
    final usedIn = _b.workouts.where(
      (w) => w.items.any((i) => i.exerciseId == id),
    );
    if (usedIn.isNotEmpty) {
      throw BusinessRuleException(
        'Exercice utilisé dans ${usedIn.length} workout(s) : '
        '${usedIn.map((w) => w.name).join(', ')}.',
      );
    }
    await _b.exercises.delete(id);
    await _b.audit.log('Suppression d\'exercice', e.name, targetId: id);
    _b.bus.emit();
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
  static String normalize(String s) {
    const from = 'àâäáãéèêëíìîïóòôöõúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    final lower = s.toLowerCase().trim();
    final buf = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      buf.write(i >= 0 ? to[i] : ch);
    }
    return buf.toString();
  }
}
