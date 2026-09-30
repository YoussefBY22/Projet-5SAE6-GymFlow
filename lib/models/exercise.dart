import 'enums.dart';
import 'json.dart';

/// Média attaché à un exercice : image (URL ou fichier), vidéo (URL ou
/// fichier uploadé) ou lien YouTube lu dans l'application.
class MediaItem {
  const MediaItem({required this.kind, required this.source, this.caption});

  final MediaKind kind;

  /// URL http(s), chemin de fichier local, ou identifiant/URL YouTube.
  final String source;
  final String? caption;

  bool get isLocalFile => !source.startsWith('http');

  Json toJson() => {'kind': kind.name, 'source': source, 'caption': caption};

  factory MediaItem.fromJson(Json j) => MediaItem(
    kind: enumFrom(MediaKind.values, j['kind'], MediaKind.image),
    source: j['source'] as String,
    caption: j['caption'] as String?,
  );
}

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.primaryMuscle,
    required this.equipment,
    required this.level,
    required this.type,
    required this.description,
    required this.authorId,
    required this.createdAt,
    this.secondaryMuscles = const [],
    this.steps = const [],
    this.mistakes = const [],
    this.breathing = '',
    this.media = const [],
    this.wgerId,
  });

  final String id;
  final String name;
  final Muscle primaryMuscle;
  final List<Muscle> secondaryMuscles;
  final Equipment equipment;
  final Level level;
  final ExerciseType type;
  final String description;
  final List<String> steps;
  final List<String> mistakes;
  final String breathing;
  final List<MediaItem> media;
  final String authorId;
  final DateTime createdAt;

  /// Identifiant wger si l'exercice a été importé depuis l'API.
  final int? wgerId;

  List<MediaItem> get images =>
      media.where((m) => m.kind == MediaKind.image).toList();

  /// Premier média vidéo (YouTube ou fichier) pour le lecteur de séance.
  MediaItem? get mainVideo {
    for (final m in media) {
      if (m.kind != MediaKind.image) return m;
    }
    return null;
  }

  Exercise copyWith({
    String? name,
    Muscle? primaryMuscle,
    List<Muscle>? secondaryMuscles,
    Equipment? equipment,
    Level? level,
    ExerciseType? type,
    String? description,
    List<String>? steps,
    List<String>? mistakes,
    String? breathing,
    List<MediaItem>? media,
  }) {
    return Exercise(
      id: id,
      name: name ?? this.name,
      primaryMuscle: primaryMuscle ?? this.primaryMuscle,
      secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
      equipment: equipment ?? this.equipment,
      level: level ?? this.level,
      type: type ?? this.type,
      description: description ?? this.description,
      steps: steps ?? this.steps,
      mistakes: mistakes ?? this.mistakes,
      breathing: breathing ?? this.breathing,
      media: media ?? this.media,
      authorId: authorId,
      createdAt: createdAt,
      wgerId: wgerId,
    );
  }

  Json toJson() => {
    'id': id,
    'name': name,
    'primaryMuscle': primaryMuscle.name,
    'secondaryMuscles': secondaryMuscles.map((m) => m.name).toList(),
    'equipment': equipment.name,
    'level': level.name,
    'type': type.name,
    'description': description,
    'steps': steps,
    'mistakes': mistakes,
    'breathing': breathing,
    'media': media.map((m) => m.toJson()).toList(),
    'authorId': authorId,
    'createdAt': dateToJson(createdAt),
    'wgerId': wgerId,
  };

  factory Exercise.fromJson(Json j) => Exercise(
    id: j['id'] as String,
    name: j['name'] as String,
    primaryMuscle: enumFrom(Muscle.values, j['primaryMuscle'], Muscle.fullBody),
    secondaryMuscles: stringList(
      j['secondaryMuscles'],
    ).map((n) => enumFrom(Muscle.values, n, Muscle.fullBody)).toList(),
    equipment: enumFrom(Equipment.values, j['equipment'], Equipment.bodyweight),
    level: enumFrom(Level.values, j['level'], Level.beginner),
    type: enumFrom(ExerciseType.values, j['type'], ExerciseType.strength),
    description: j['description'] as String? ?? '',
    steps: stringList(j['steps']),
    mistakes: stringList(j['mistakes']),
    breathing: j['breathing'] as String? ?? '',
    media: jsonList(j['media']).map(MediaItem.fromJson).toList(),
    authorId: j['authorId'] as String? ?? '',
    createdAt: dateOr(j['createdAt'], DateTime(2026)),
    wgerId: toIntOrNull(j['wgerId']),
  );
}
