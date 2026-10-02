import 'json.dart';

/// Série réalisée pendant une séance.
class SetLog {
  const SetLog({
    required this.exerciseId,
    required this.exerciseName,
    required this.setIndex,
    required this.reps,
    required this.loadKg,
    this.durationSec,
  });

  final String exerciseId;
  final String exerciseName;
  final int setIndex;
  final int reps;
  final double loadKg;
  final int? durationSec;

  /// Volume de la série = charge × répétitions.
  double get volume => loadKg * reps;

  Json toJson() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'setIndex': setIndex,
    'reps': reps,
    'loadKg': loadKg,
    'durationSec': durationSec,
  };

  factory SetLog.fromJson(Json j) => SetLog(
    exerciseId: j['exerciseId'] as String,
    exerciseName: j['exerciseName'] as String? ?? '',
    setIndex: toInt(j['setIndex']),
    reps: toInt(j['reps']),
    loadKg: toDouble(j['loadKg']),
    durationSec: toIntOrNull(j['durationSec']),
  );
}

/// Séance terminée (historique + carte « activité » du fil).
class SessionLog {
  const SessionLog({
    required this.id,
    required this.userId,
    required this.workoutId,
    required this.title,
    required this.startedAt,
    required this.durationSec,
    required this.sets,
    this.exerciseCount = 0,
    this.prCount = 0,
    this.kudos = const [],
    this.note = '',
    this.shared = false,
    this.sharedAt,
  });

  final String id;
  final String userId;
  final String? workoutId;
  final String title;
  final DateTime startedAt;
  final int durationSec;
  final List<SetLog> sets;
  final int exerciseCount;

  /// Nombre de records personnels battus pendant la séance.
  final int prCount;

  /// Identifiants des utilisateurs qui ont donné « Bravo ».
  final List<String> kudos;
  final String note;

  /// Séance publiée sur le fil du club par son auteur (jamais par défaut).
  final bool shared;
  final DateTime? sharedAt;

  double get totalVolume => sets.fold(0, (s, x) => s + x.volume);
  int get totalSets => sets.length;
  int get totalReps => sets.fold(0, (s, x) => s + x.reps);
  DateTime get endedAt => startedAt.add(Duration(seconds: durationSec));

  SessionLog copyWith({
    List<String>? kudos,
    int? prCount,
    bool? shared,
    DateTime? sharedAt,
  }) => SessionLog(
    id: id,
    userId: userId,
    workoutId: workoutId,
    title: title,
    startedAt: startedAt,
    durationSec: durationSec,
    sets: sets,
    exerciseCount: exerciseCount,
    prCount: prCount ?? this.prCount,
    kudos: kudos ?? this.kudos,
    note: note,
    shared: shared ?? this.shared,
    sharedAt: shared == false ? null : (sharedAt ?? this.sharedAt),
  );

  Json toJson() => {
    'id': id,
    'userId': userId,
    'workoutId': workoutId,
    'title': title,
    'startedAt': dateToJson(startedAt),
    'durationSec': durationSec,
    'sets': sets.map((s) => s.toJson()).toList(),
    'exerciseCount': exerciseCount,
    'prCount': prCount,
    'kudos': kudos,
    'note': note,
    'shared': shared,
    'sharedAt': dateToJson(sharedAt),
  };

  factory SessionLog.fromJson(Json j) => SessionLog(
    id: j['id'] as String,
    userId: j['userId'] as String,
    workoutId: j['workoutId'] as String?,
    title: j['title'] as String? ?? 'Séance',
    startedAt: dateOr(j['startedAt'], DateTime(2026)),
    durationSec: toInt(j['durationSec']),
    sets: jsonList(j['sets']).map(SetLog.fromJson).toList(),
    exerciseCount: toInt(j['exerciseCount']),
    prCount: toInt(j['prCount']),
    kudos: stringList(j['kudos']),
    note: j['note'] as String? ?? '',
    shared: j['shared'] as bool? ?? false,
    sharedAt: dateFromJson(j['sharedAt']),
  );
}

/// Pesée pour la courbe de progression.
class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.userId,
    required this.date,
    required this.weightKg,
  });

  final String id;
  final String userId;
  final DateTime date;
  final double weightKg;

  Json toJson() => {
    'id': id,
    'userId': userId,
    'date': dateToJson(date),
    'weightKg': weightKg,
  };

  factory WeightEntry.fromJson(Json j) => WeightEntry(
    id: j['id'] as String,
    userId: j['userId'] as String,
    date: dateOr(j['date'], DateTime(2026)),
    weightKg: toDouble(j['weightKg']),
  );
}

/// Record personnel sur un exercice (meilleure charge + 1RM estimé).
class PersonalRecord {
  const PersonalRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.bestLoadKg,
    required this.repsAtBest,
    required this.estimatedOneRm,
    required this.date,
  });

  final String exerciseId;
  final String exerciseName;
  final double bestLoadKg;
  final int repsAtBest;
  final double estimatedOneRm;
  final DateTime date;
}
