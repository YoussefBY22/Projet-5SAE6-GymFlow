import 'content.dart';
import 'enums.dart';
import 'json.dart';

/// Ligne d'un workout : un exercice avec ses paramètres de travail.
class WorkoutItem {
  const WorkoutItem({
    required this.exerciseId,
    required this.sets,
    this.reps,
    this.durationSec,
    required this.restSec,
    this.tempo = '',
    this.suggestedLoad = '',
    this.notes = '',
  });

  final String exerciseId;
  final int sets;

  /// Répétitions par série (ou `null` si l'exercice est au temps).
  final int? reps;

  /// Durée par série en secondes (gainage, cardio…).
  final int? durationSec;
  final int restSec;

  /// Tempo « 3-1-1 » (excentrique-pause-concentrique).
  final String tempo;
  final String suggestedLoad;
  final String notes;

  bool get isTimed => durationSec != null && (reps == null || reps == 0);

  String get target => isTimed ? '${durationSec}s' : '${reps ?? 0} reps';

  WorkoutItem copyWith({
    int? sets,
    int? reps,
    int? durationSec,
    int? restSec,
    String? tempo,
    String? suggestedLoad,
    String? notes,
  }) => WorkoutItem(
    exerciseId: exerciseId,
    sets: sets ?? this.sets,
    reps: reps ?? this.reps,
    durationSec: durationSec ?? this.durationSec,
    restSec: restSec ?? this.restSec,
    tempo: tempo ?? this.tempo,
    suggestedLoad: suggestedLoad ?? this.suggestedLoad,
    notes: notes ?? this.notes,
  );

  Json toJson() => {
    'exerciseId': exerciseId,
    'sets': sets,
    'reps': reps,
    'durationSec': durationSec,
    'restSec': restSec,
    'tempo': tempo,
    'suggestedLoad': suggestedLoad,
    'notes': notes,
  };

  factory WorkoutItem.fromJson(Json j) => WorkoutItem(
    exerciseId: j['exerciseId'] as String,
    sets: toInt(j['sets'], 3),
    reps: toIntOrNull(j['reps']),
    durationSec: toIntOrNull(j['durationSec']),
    restSec: toInt(j['restSec'], 60),
    tempo: j['tempo'] as String? ?? '',
    suggestedLoad: j['suggestedLoad'] as String? ?? '',
    notes: j['notes'] as String? ?? '',
  );
}

/// Séance type (ex. « Push Day ») : liste ordonnée d'exercices.
class Workout implements LibraryItem {
  const Workout({
    required this.id,
    required this.name,
    required this.description,
    required this.level,
    required this.goal,
    required this.items,
    required this.authorId,
    required this.createdAt,
    this.coverImage,
    this.focus = '',
    this.lang = ContentLang.fr,
    this.altName,
    this.altDescription,
    this.publication = const Publication(),
  });

  @override
  final String id;
  @override
  final String name;
  final String description;
  final Level level;
  final Goal goal;
  final List<WorkoutItem> items;
  @override
  final String authorId;
  @override
  final DateTime createdAt;
  final String? coverImage;

  /// Zones travaillées affichées en sous-titre (« Pectoraux · Épaules »).
  final String focus;
  @override
  final String lang;
  @override
  final String? altName;
  final String? altDescription;
  @override
  final Publication publication;

  @override
  ContentKind get kind => ContentKind.workout;

  /// Workout non publié (personnel, proposé ou refusé) : visible par son
  /// auteur seulement (et par le staff pendant la validation).
  bool get isPrivate => !publication.isPublished;

  String descriptionIn(String language) =>
      language != lang && (altDescription?.isNotEmpty ?? false)
      ? altDescription!
      : description;

  int get totalSets => items.fold(0, (s, i) => s + i.sets);

  /// Durée estimée : travail (~40 s par série ou durée) + repos.
  int get estimatedMinutes {
    var seconds = 0;
    for (final i in items) {
      final work = i.isTimed ? (i.durationSec ?? 30) : 40;
      seconds += i.sets * work + (i.sets - 1) * i.restSec + 60;
    }
    return (seconds / 60).ceil();
  }

  Workout copyWith({
    String? id,
    String? name,
    String? description,
    Level? level,
    Goal? goal,
    List<WorkoutItem>? items,
    String? coverImage,
    String? focus,
    String? lang,
    String? altName,
    String? altDescription,
    bool clearTranslation = false,
    Publication? publication,
    String? authorId,
    DateTime? createdAt,
  }) => Workout(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    level: level ?? this.level,
    goal: goal ?? this.goal,
    items: items ?? this.items,
    authorId: authorId ?? this.authorId,
    createdAt: createdAt ?? this.createdAt,
    coverImage: coverImage ?? this.coverImage,
    focus: focus ?? this.focus,
    lang: lang ?? this.lang,
    altName: clearTranslation ? altName : (altName ?? this.altName),
    altDescription: clearTranslation
        ? altDescription
        : (altDescription ?? this.altDescription),
    publication: publication ?? this.publication,
  );

  Json toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'level': level.name,
    'goal': goal.name,
    'items': items.map((i) => i.toJson()).toList(),
    'authorId': authorId,
    'createdAt': dateToJson(createdAt),
    'coverImage': coverImage,
    'focus': focus,
    'lang': lang,
    'altName': altName,
    'altDescription': altDescription,
    'publication': publication.toJson(),
  };

  factory Workout.fromJson(Json j) => Workout(
    id: j['id'] as String,
    name: j['name'] as String,
    description: j['description'] as String? ?? '',
    level: enumFrom(Level.values, j['level'], Level.beginner),
    goal: enumFrom(Goal.values, j['goal'], Goal.fitness),
    items: jsonList(j['items']).map(WorkoutItem.fromJson).toList(),
    authorId: j['authorId'] as String? ?? '',
    createdAt: dateOr(j['createdAt'], DateTime(2026)),
    coverImage: j['coverImage'] as String?,
    focus: j['focus'] as String? ?? '',
    lang: ContentLang.normalize(j['lang'] as String?),
    altName: j['altName'] as String?,
    altDescription: j['altDescription'] as String?,
    // Ancien format : booléen `isPrivate` (workouts personnels V1).
    publication: Publication.fromJson(
      j['publication'] == null
          ? null
          : Map<String, dynamic>.from(j['publication'] as Map),
      legacyPrivate: j['isPrivate'] as bool? ?? false,
    ),
  );
}

/// Jour d'un programme : jour de semaine (1 = lundi) → workout.
class ProgramDay {
  const ProgramDay({required this.weekday, required this.workoutId});

  final int weekday;
  final String workoutId;

  Json toJson() => {'weekday': weekday, 'workoutId': workoutId};

  factory ProgramDay.fromJson(Json j) => ProgramDay(
    weekday: toInt(j['weekday'], 1),
    workoutId: j['workoutId'] as String,
  );
}

/// Programme : plusieurs workouts répartis sur la semaine.
class Program implements LibraryItem {
  const Program({
    required this.id,
    required this.name,
    required this.description,
    required this.level,
    required this.goal,
    required this.weeks,
    required this.days,
    required this.equipment,
    required this.authorId,
    required this.createdAt,
    this.coverImage,
    this.lang = ContentLang.fr,
    this.altName,
    this.altDescription,
    this.publication = const Publication(),
  });

  @override
  final String id;
  @override
  final String name;
  final String description;
  final Level level;
  final Goal goal;
  final int weeks;
  final List<ProgramDay> days;
  final String equipment;
  @override
  final String authorId;
  @override
  final DateTime createdAt;
  final String? coverImage;
  @override
  final String lang;
  @override
  final String? altName;
  final String? altDescription;
  @override
  final Publication publication;

  @override
  ContentKind get kind => ContentKind.program;

  bool get isPrivate => !publication.isPublished;

  String descriptionIn(String language) =>
      language != lang && (altDescription?.isNotEmpty ?? false)
      ? altDescription!
      : description;

  int get daysPerWeek => days.length;

  Program copyWith({
    String? id,
    String? name,
    String? description,
    Level? level,
    Goal? goal,
    int? weeks,
    List<ProgramDay>? days,
    String? equipment,
    String? coverImage,
    String? lang,
    String? altName,
    String? altDescription,
    bool clearTranslation = false,
    Publication? publication,
    String? authorId,
    DateTime? createdAt,
  }) => Program(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    level: level ?? this.level,
    goal: goal ?? this.goal,
    weeks: weeks ?? this.weeks,
    days: days ?? this.days,
    equipment: equipment ?? this.equipment,
    authorId: authorId ?? this.authorId,
    createdAt: createdAt ?? this.createdAt,
    coverImage: coverImage ?? this.coverImage,
    lang: lang ?? this.lang,
    altName: clearTranslation ? altName : (altName ?? this.altName),
    altDescription: clearTranslation
        ? altDescription
        : (altDescription ?? this.altDescription),
    publication: publication ?? this.publication,
  );

  Json toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'level': level.name,
    'goal': goal.name,
    'weeks': weeks,
    'days': days.map((d) => d.toJson()).toList(),
    'equipment': equipment,
    'authorId': authorId,
    'createdAt': dateToJson(createdAt),
    'coverImage': coverImage,
    'lang': lang,
    'altName': altName,
    'altDescription': altDescription,
    'publication': publication.toJson(),
  };

  factory Program.fromJson(Json j) => Program(
    id: j['id'] as String,
    name: j['name'] as String,
    description: j['description'] as String? ?? '',
    level: enumFrom(Level.values, j['level'], Level.beginner),
    goal: enumFrom(Goal.values, j['goal'], Goal.fitness),
    weeks: toInt(j['weeks'], 4),
    days: jsonList(j['days']).map(ProgramDay.fromJson).toList(),
    equipment: j['equipment'] as String? ?? '',
    authorId: j['authorId'] as String? ?? '',
    createdAt: dateOr(j['createdAt'], DateTime(2026)),
    coverImage: j['coverImage'] as String?,
    lang: ContentLang.normalize(j['lang'] as String?),
    altName: j['altName'] as String?,
    altDescription: j['altDescription'] as String?,
    publication: Publication.fromJson(
      j['publication'] == null
          ? null
          : Map<String, dynamic>.from(j['publication'] as Map),
    ),
  );
}
