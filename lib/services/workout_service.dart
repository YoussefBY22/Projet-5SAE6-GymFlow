import '../core/errors.dart';
import '../models/enums.dart';
import '../models/exercise.dart';
import '../models/user.dart';
import '../models/workout.dart';
import '../repositories/repository.dart';
import 'backend.dart';
import 'exercise_service.dart';

/// API interne des workouts et programmes.
class WorkoutService {
  WorkoutService(this._b);
  final Backend _b;

  // ------------------------- Workouts -------------------------

  List<Workout> workouts({String query = '', Level? level, Goal? goal}) {
    _b.requireUser();
    final q = ExerciseService.normalize(query);
    return _b.workouts.where(
      (w) =>
          (level == null || w.level == level) &&
          (goal == null || w.goal == goal) &&
          (q.isEmpty ||
              ExerciseService.normalize('${w.name} ${w.focus}').contains(q)),
    )..sort((a, b) => a.name.compareTo(b.name));
  }

  Workout? workoutById(String id) => _b.workouts.byId(id);

  /// Exercices d'un workout dans l'ordre (ignorés s'ils ont été supprimés).
  List<(WorkoutItem, Exercise)> resolve(Workout w) => [
    for (final i in w.items)
      if (_b.exercises.byId(i.exerciseId) case final e?) (i, e),
  ];

  bool canEditWorkout(AppUser u, Workout w) =>
      u.isAdmin || (u.isCoach && w.authorId == u.id);

  bool canEditProgram(AppUser u, Program p) =>
      u.isAdmin || (u.isCoach && p.authorId == u.id);

  Future<Workout> saveWorkout({
    String? id,
    required String name,
    required String description,
    required Level level,
    required Goal goal,
    required List<WorkoutItem> items,
    String? coverImage,
    String focus = '',
  }) async {
    final me = _b.requireRole(Backend.staff);
    if (name.trim().length < 3) {
      throw const ValidationException('Nom du workout : 3 caractères minimum.');
    }
    if (items.isEmpty) {
      throw const ValidationException('Ajoutez au moins un exercice.');
    }
    for (final i in items) {
      if (_b.exercises.byId(i.exerciseId) == null) {
        throw const ValidationException(
          'Un exercice sélectionné n\'existe plus.',
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
      );
    } else {
      final existing =
          _b.workouts.byId(id) ?? (throw const NotFoundException());
      if (!canEditWorkout(me, existing)) {
        throw const PermissionDeniedException(
          'Un coach ne peut modifier que ses propres workouts.',
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
      );
    }
    await _b.workouts.save(w);
    _b.bus.emit();
    return w;
  }

  Future<void> deleteWorkout(String id) async {
    final me = _b.requireRole(Backend.staff);
    final w = _b.workouts.byId(id) ?? (throw const NotFoundException());
    if (!canEditWorkout(me, w)) throw const PermissionDeniedException();
    final usedIn = _b.programs.where(
      (p) => p.days.any((d) => d.workoutId == id),
    );
    if (usedIn.isNotEmpty) {
      throw BusinessRuleException(
        'Workout utilisé dans le programme « ${usedIn.first.name} ».',
      );
    }
    await _b.workouts.delete(id);
    await _b.audit.log('Suppression de workout', w.name, targetId: id);
    _b.bus.emit();
  }

  // ------------------------- Programmes -------------------------

  List<Program> programs({Level? level, Goal? goal}) {
    _b.requireUser();
    return _b.programs.where(
      (p) =>
          (level == null || p.level == level) &&
          (goal == null || p.goal == goal),
    )..sort((a, b) => a.level.index.compareTo(b.level.index));
  }

  Program? programById(String id) => _b.programs.byId(id);

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
  }) async {
    final me = _b.requireRole(Backend.staff);
    if (name.trim().length < 3) {
      throw const ValidationException(
        'Nom du programme : 3 caractères minimum.',
      );
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
      if (_b.workouts.byId(d.workoutId) == null) {
        throw const ValidationException(
          'Un workout sélectionné n\'existe plus.',
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
      );
    }
    await _b.programs.save(p);
    _b.bus.emit();
    return p;
  }

  Future<void> deleteProgram(String id) async {
    final me = _b.requireRole(Backend.staff);
    final p = _b.programs.byId(id) ?? (throw const NotFoundException());
    if (!canEditProgram(me, p)) throw const PermissionDeniedException();
    await _b.programs.delete(id);
    await _b.audit.log('Suppression de programme', p.name, targetId: id);
    _b.bus.emit();
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
