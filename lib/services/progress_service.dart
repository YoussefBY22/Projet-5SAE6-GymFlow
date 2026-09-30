import 'package:flutter/material.dart';

import '../core/errors.dart';
import '../models/enums.dart';
import '../models/session_log.dart';
import '../repositories/repository.dart';
import 'backend.dart';

/// Badge / succès débloqué par la régularité.
class Badge {
  const Badge({
    required this.title,
    required this.description,
    required this.icon,
    required this.progress,
  });

  final String title;
  final String description;
  final IconData icon;

  /// 0 → 1 ; 1 = débloqué.
  final double progress;
  bool get unlocked => progress >= 1;
}

/// Calculs de progression : IMC, volume, records, série, objectifs.
class ProgressService {
  ProgressService(this._b);
  final Backend _b;

  // ---------------- IMC & calories (fonctions pures) ----------------

  static double? bmi(double? weightKg, double? heightCm) {
    if (weightKg == null || heightCm == null || heightCm <= 0) return null;
    final m = heightCm / 100;
    return weightKg / (m * m);
  }

  static String bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Insuffisance pondérale';
    if (bmi < 25) return 'Corpulence normale';
    if (bmi < 30) return 'Surpoids';
    return 'Obésité';
  }

  /// Métabolisme de base (Mifflin-St Jeor), en kcal/jour.
  static double bmr({
    required double weightKg,
    required double heightCm,
    required int age,
    required Gender gender,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    return gender == Gender.male ? base + 5 : base - 161;
  }

  /// Besoin calorique journalier ajusté à l'objectif.
  static double dailyCalories({
    required double bmr,
    required double activityFactor,
    required Goal goal,
  }) {
    final tdee = bmr * activityFactor;
    return switch (goal) {
      Goal.weightLoss => tdee - 400,
      Goal.muscleGain => tdee + 300,
      Goal.fitness || Goal.endurance => tdee,
    };
  }

  /// 1RM estimé (formule d'Epley).
  static double oneRepMax(double loadKg, int reps) =>
      reps <= 1 ? loadKg : loadKg * (1 + reps / 30);

  static double volumeOf(Iterable<SetLog> sets) =>
      sets.fold(0, (s, x) => s + x.volume);

  // ---------------- Poids ----------------

  List<WeightEntry> weightsOf(String userId) =>
      _b.weights.where((w) => w.userId == userId)
        ..sort((a, b) => a.date.compareTo(b.date));

  Future<void> addWeight(double kg) async {
    final me = _b.requireUser();
    if (kg < 30 || kg > 250) {
      throw const ValidationException('Poids : entre 30 et 250 kg.');
    }
    await _b.weights.save(
      WeightEntry(
        id: IdGen.next('wt_'),
        userId: me.id,
        date: _b.now(),
        weightKg: kg,
      ),
    );
    if (me.weightKg != kg) {
      await _b.users.save(me.copyWith(weightKg: kg));
      _b.auth.refreshCurrent();
    }
    _b.bus.emit();
  }

  // ---------------- Records ----------------

  List<PersonalRecord> recordsOf(String userId, {DateTime? before}) {
    final best = <String, PersonalRecord>{};
    for (final s in _b.sessions.where((s) => s.userId == userId)) {
      if (before != null && !s.startedAt.isBefore(before)) continue;
      for (final set in s.sets) {
        if (set.loadKg <= 0 || set.reps <= 0) continue;
        final current = best[set.exerciseId];
        final better =
            current == null ||
            set.loadKg > current.bestLoadKg ||
            (set.loadKg == current.bestLoadKg && set.reps > current.repsAtBest);
        if (better) {
          best[set.exerciseId] = PersonalRecord(
            exerciseId: set.exerciseId,
            exerciseName: set.exerciseName,
            bestLoadKg: set.loadKg,
            repsAtBest: set.reps,
            estimatedOneRm: oneRepMax(set.loadKg, set.reps),
            date: s.startedAt,
          );
        }
      }
    }
    return best.values.toList()
      ..sort((a, b) => b.estimatedOneRm.compareTo(a.estimatedOneRm));
  }

  /// Records battus par de nouvelles séries (charge supérieure au
  /// meilleur historique de l'exercice).
  List<PersonalRecord> detectRecords(
    String userId,
    List<SetLog> sets,
    DateTime at,
  ) {
    final previous = {
      for (final r in recordsOf(userId, before: at)) r.exerciseId: r,
    };
    final found = <String, PersonalRecord>{};
    for (final set in sets) {
      if (set.loadKg <= 0 || set.reps <= 0) continue;
      final prev = previous[set.exerciseId];
      final bestSoFar =
          found[set.exerciseId]?.bestLoadKg ?? prev?.bestLoadKg ?? 0;
      if (set.loadKg > bestSoFar) {
        found[set.exerciseId] = PersonalRecord(
          exerciseId: set.exerciseId,
          exerciseName: set.exerciseName,
          bestLoadKg: set.loadKg,
          repsAtBest: set.reps,
          estimatedOneRm: oneRepMax(set.loadKg, set.reps),
          date: at,
        );
      }
    }
    return found.values.toList();
  }

  // ---------------- Régularité ----------------

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime startOfWeek(DateTime d) =>
      _day(d).subtract(Duration(days: d.weekday - 1));

  /// Série de jours consécutifs avec au moins une séance (jusqu'à
  /// aujourd'hui, ou hier si aucune séance aujourd'hui).
  int streakDays(String userId) {
    final days = _b.sessions
        .where((s) => s.userId == userId)
        .map((s) => _day(s.startedAt))
        .toSet();
    var cursor = _day(_b.now());
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }

  /// Séances de la semaine en cours (lundi → dimanche).
  int sessionsThisWeek(String userId) {
    final start = startOfWeek(_b.now());
    return _b.sessions
        .where((s) => s.userId == userId && !s.startedAt.isBefore(start))
        .length;
  }

  /// Jours de la semaine en cours où l'utilisateur s'est entraîné.
  Set<int> activeWeekdays(String userId) {
    final start = startOfWeek(_b.now());
    return _b.sessions
        .where((s) => s.userId == userId && !s.startedAt.isBefore(start))
        .map((s) => s.startedAt.weekday)
        .toSet();
  }

  /// Volume (kg) par semaine sur les [weeks] dernières semaines.
  List<(DateTime, double)> weeklyVolume(String userId, {int weeks = 8}) {
    final start = startOfWeek(_b.now());
    return [
      for (var i = weeks - 1; i >= 0; i--)
        () {
          final from = DateTime(start.year, start.month, start.day - 7 * i);
          final to = DateTime(from.year, from.month, from.day + 7);
          final vol = _b.sessions
              .where(
                (s) =>
                    s.userId == userId &&
                    !s.startedAt.isBefore(from) &&
                    s.startedAt.isBefore(to),
              )
              .fold<double>(0, (sum, s) => sum + s.totalVolume);
          return (from, vol);
        }(),
    ];
  }

  // ---------------- Badges ----------------

  List<Badge> badgesOf(String userId) {
    final sessions = _b.sessions.where((s) => s.userId == userId);
    final count = sessions.length;
    final volume = sessions.fold<double>(0, (s, x) => s + x.totalVolume);
    final prs = sessions.fold<int>(0, (s, x) => s + x.prCount);
    final streak = streakDays(userId);
    final courses = _b.reservations
        .where((r) => r.userId == userId && r.attended == true)
        .length;
    double p(num value, num target) => (value / target).clamp(0, 1).toDouble();
    return [
      Badge(
        title: 'Premier pas',
        description: 'Terminer une première séance',
        icon: Icons.flag,
        progress: p(count, 1),
      ),
      Badge(
        title: 'Régulier',
        description: '10 séances enregistrées',
        icon: Icons.event_repeat,
        progress: p(count, 10),
      ),
      Badge(
        title: 'Série de feu',
        description: '3 jours d\'affilée',
        icon: Icons.local_fire_department,
        progress: p(streak, 3),
      ),
      Badge(
        title: 'Chasseur de records',
        description: '5 records personnels',
        icon: Icons.emoji_events,
        progress: p(prs, 5),
      ),
      Badge(
        title: '10 tonnes',
        description: '10 000 kg soulevés au total',
        icon: Icons.fitness_center,
        progress: p(volume, 10000),
      ),
      Badge(
        title: 'Esprit collectif',
        description: 'Participer à 5 cours',
        icon: Icons.groups,
        progress: p(courses, 5),
      ),
    ];
  }
}
