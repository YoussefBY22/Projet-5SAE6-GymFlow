import '../core/errors.dart';
import '../models/content.dart';
import '../models/enums.dart';
import '../models/exercise.dart';
import '../models/user.dart';
import '../models/workout.dart';
import '../repositories/repository.dart';
import 'backend.dart';
import 'library_service.dart';

/// API interne des workouts et programmes.
class WorkoutService {
  WorkoutService(this._b);
  final Backend _b;

  // ------------------------- Workouts -------------------------

  /// Workouts publiés + créations de l'utilisateur connecté (une création
  /// non publiée n'est jamais visible des autres membres).
  List<Workout> workouts({
    String query = '',
    Level? level,
    Goal? goal,
    bool personalOnly = false,
  }) {
    final me = _b.requireUser();
    return _b.library.workouts(
      query: query,
      filters: {
        if (level != null) LibraryFilters.level: {level.name},
        if (goal != null) LibraryFilters.goal: {goal.name},
      },
    )..removeWhere(
      (w) => personalOnly && (w.authorId != me.id || w.isPublished),
    );
  }

  /// Workout consultable par l'utilisateur connecté (null sinon).
  Workout? workoutById(String id) {
    final w = _b.workouts.byId(id);
    if (w == null) return null;
    return _b.library.canSee(_b.auth.currentUser, w) ? w : null;
  }

  /// Exercices d'un workout dans l'ordre (ignorés s'ils ont été supprimés).
  List<(WorkoutItem, Exercise)> resolve(Workout w) => [
    for (final i in w.items)
      if (_b.exercises.byId(i.exerciseId) case final e?) (i, e),
  ];

  bool canEditWorkout(AppUser u, Workout w) => _b.library.canEdit(u, w);

  bool canEditProgram(AppUser u, Program p) => _b.library.canEdit(u, p);

  Future<Workout> saveWorkout({
    String? id,
    required String name,
    required String description,
    required Level level,
    required Goal goal,
    required List<WorkoutItem> items,
    String? coverImage,
    String focus = '',
    String lang = ContentLang.fr,
    String? altName,
    String? altDescription,
  }) async {
    // Abonnés : workouts personnels (privés) ; staff : workouts du club.
    final me = _b.requireUser();
    if (id == null) _b.library.checkPersonalLimit(me, ContentKind.workout);
    if (name.trim().length < 3 || name.trim().length > 80) {
      throw const ValidationException('Nom du workout : 3 à 80 caractères.');
    }
    if (items.isEmpty) {
      throw const ValidationException('Ajoutez au moins un exercice.');
    }
    for (final i in items) {
      final e = _b.exercises.byId(i.exerciseId);
      if (e == null || !_b.library.canSee(me, e)) {
        throw const ValidationException(
          'Un exercice sélectionné n\'existe plus.',
        );
      }
      if (me.canManageContent && !e.isPublished && e.authorId != me.id) {
        throw const ValidationException(
          'Un workout du club ne peut utiliser que des exercices publiés.',
        );
      }
      if (i.sets < 1 || i.sets > 10) {
        throw const ValidationException('Séries : entre 1 et 10.');
      }
      if ((i.reps ?? 0) <= 0 && (i.durationSec ?? 0) <= 0) {
        throw const ValidationException(
          'Chaque exercice doit avoir des répétitions ou une durée.',
        );
      }
      if (i.restSec < 0 || i.restSec > 600) {
        throw const ValidationException('Repos : entre 0 et 600 s.');
      }
    }
    Workout w;
    if (id == null) {
      w = Workout(
        id: IdGen.next('w_'),
        name: name.trim(),
        description: description.trim(),
        level: level,
        goal: goal,
        items: items,
        authorId: me.id,
        createdAt: _b.now(),
        coverImage: coverImage,
        focus: focus.trim(),
        lang: ContentLang.normalize(lang),
        altName: _opt(altName),
        altDescription: _opt(altDescription),
        publication: me.canManageContent
            ? const Publication()
            : Publication.personal,
      );
    } else {
      final existing =
          _b.workouts.byId(id) ?? (throw const NotFoundException());
      if (!canEditWorkout(me, existing)) {
        throw const PermissionDeniedException(
          'Vous ne pouvez modifier que vos propres workouts.',
        );
      }
      w = existing.copyWith(
        name: name.trim(),
        description: description.trim(),
        level: level,
        goal: goal,
        items: items,
        coverImage: coverImage,
        focus: focus.trim(),
        lang: ContentLang.normalize(lang),
        altName: _opt(altName),
        altDescription: _opt(altDescription),
        clearTranslation: true,
      );
    }
    await _b.workouts.save(w);
    _b.bus.emit();
    return w;
  }

  Future<void> deleteWorkout(String id) async {
    final me = _b.requireUser();
    final w = _b.workouts.byId(id) ?? (throw const NotFoundException());
    if (!canEditWorkout(me, w)) throw const PermissionDeniedException();
    final usedIn = _b.programs.where(
      (p) => p.days.any((d) => d.workoutId == id),
    );
    if (usedIn.isNotEmpty) {
      final visible = usedIn.where((p) => _b.library.canSee(me, p));
      throw BusinessRuleException(
        visible.isEmpty
            ? 'Workout utilisé dans un programme.'
            : 'Workout utilisé dans le programme « ${visible.first.name} ».',
      );
    }
    await _b.workouts.delete(id);
    await _b.audit.log('Suppression de workout', w.name, targetId: id);
    _b.bus.emit();
  }

  // ------------------------- Programmes -------------------------

  List<Program> programs({Level? level, Goal? goal}) => _b.library.programs(
    filters: {
      if (level != null) LibraryFilters.level: {level.name},
      if (goal != null) LibraryFilters.goal: {goal.name},
    },
  );

  /// Programme consultable par l'utilisateur connecté (null sinon).
  Program? programById(String id) {
    final p = _b.programs.byId(id);
    if (p == null) return null;
    return _b.library.canSee(_b.auth.currentUser, p) ? p : null;
  }

  Future<Program> saveProgram({
    String? id,
    required String name,
    required String description,
    required Level level,
    required Goal goal,
    required int weeks,
    required List<ProgramDay> days,
    required String equipment,
    String? coverImage,
    String lang = ContentLang.fr,
    String? altName,
    String? altDescription,
  }) async {
    final me = _b.requireUser();
    if (id == null) _b.library.checkPersonalLimit(me, ContentKind.program);
    if (name.trim().length < 3 || name.trim().length > 80) {
      throw const ValidationException('Nom du programme : 3 à 80 caractères.');
    }
    if (days.isEmpty || days.length > 7) {
      throw const ValidationException('Entre 1 et 7 jours d\'entraînement.');
    }
    if (days.map((d) => d.weekday).toSet().length != days.length) {
      throw const ValidationException('Un seul workout par jour.');
    }
    if (weeks < 1 || weeks > 52) {
      throw const ValidationException('Durée : entre 1 et 52 semaines.');
    }
    for (final d in days) {
      final w = _b.workouts.byId(d.workoutId);
      if (w == null || !_b.library.canSee(me, w)) {
        throw const ValidationException(
          'Un workout sélectionné n\'existe plus.',
        );
      }
      if (me.canManageContent && !w.isPublished) {
        throw const ValidationException(
          'Un programme du club ne peut utiliser que des workouts publiés.',
        );
      }
    }
    final sorted = [...days]..sort((a, b) => a.weekday.compareTo(b.weekday));
    Program p;
    if (id == null) {
      p = Program(
        id: IdGen.next('p_'),
        name: name.trim(),
        description: description.trim(),
        level: level,
        goal: goal,
        weeks: weeks,
        days: sorted,
        equipment: equipment.trim(),
        authorId: me.id,
        createdAt: _b.now(),
        coverImage: coverImage,
        lang: ContentLang.normalize(lang),
        altName: _opt(altName),
        altDescription: _opt(altDescription),
        publication: me.canManageContent
            ? const Publication()
            : Publication.personal,
      );
    } else {
      final existing =
          _b.programs.byId(id) ?? (throw const NotFoundException());
      if (!canEditProgram(me, existing)) {
        throw const PermissionDeniedException();
      }
      p = existing.copyWith(
        name: name.trim(),
        description: description.trim(),
        level: level,
        goal: goal,
        weeks: weeks,
        days: sorted,
        equipment: equipment.trim(),
        coverImage: coverImage,
        lang: ContentLang.normalize(lang),
        altName: _opt(altName),
        altDescription: _opt(altDescription),
        clearTranslation: true,
      );
    }
    await _b.programs.save(p);
    _b.bus.emit();
    return p;
  }

  Future<void> deleteProgram(String id) async {
    final me = _b.requireUser();
    final p = _b.programs.byId(id) ?? (throw const NotFoundException());
    if (!canEditProgram(me, p)) throw const PermissionDeniedException();
    await _b.programs.delete(id);
    await _b.audit.log('Suppression de programme', p.name, targetId: id);
    _b.bus.emit();
  }

  static String? _opt(String? s) {
    final v = s?.trim() ?? '';
    return v.isEmpty ? null : v;
  }

  /// Prochain workout du programme suivi, selon le jour de la semaine
  /// (« Reprendre mon programme »).
  (Program, Workout, int)? nextProgramWorkout(AppUser u) {
    final p = u.activeProgramId == null
        ? null
        : _b.programs.byId(u.activeProgramId!);
    if (p == null || p.days.isEmpty) return null;
    final today = _b.now().weekday;
    final next = p.days.firstWhere(
      (d) => d.weekday >= today,
      orElse: () => p.days.first,
    );
    final w = _b.workouts.byId(next.workoutId);
    if (w == null) return null;
    return (p, w, next.weekday);
  }
}
