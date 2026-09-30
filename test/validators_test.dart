import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/errors.dart';
import 'package:gymflow/core/validators.dart';
import 'package:gymflow/models/enums.dart';
import 'package:gymflow/models/workout.dart';
import 'package:gymflow/services/media_storage.dart';
import 'package:gymflow/services/wger_api.dart';
import 'package:gymflow/widgets/media.dart';

void main() {
  test('validateurs des formulaires', () {
    expect(Validators.email('nour@gymflow.tn'), isNull);
    expect(Validators.email('nour@'), isNotNull);
    expect(Validators.email(''), isNotNull);
    expect(Validators.password('Abcdefg1'), isNull);
    expect(Validators.password('abcdefgh'), isNotNull);
    expect(Validators.password('1234567'), isNotNull);
    expect(Validators.name('A'), isNotNull);
    expect(Validators.name('<script>'), isNotNull);
    expect(Validators.intRange(field: 'X', min: 1, max: 10)('11'), isNotNull);
    expect(Validators.intRange(field: 'X', min: 1, max: 10)('5'), isNull);
    expect(
      Validators.decimalRange(field: 'X', min: 30, max: 250)('72,5'),
      isNull,
    );
    expect(Validators.url('ftp://x'), isNotNull);
    expect(Validators.url('https://wger.de'), isNull);
    expect(Validators.parseDecimal('72,5'), 72.5);
  });

  test('extraction de l\'identifiant YouTube', () {
    const id = 'hWbUlkb5Ms4';
    expect(youtubeId(id), id);
    expect(youtubeId('https://www.youtube.com/watch?v=$id&t=10s'), id);
    expect(youtubeId('https://youtu.be/$id'), id);
    expect(youtubeId('https://www.youtube.com/shorts/$id'), id);
    expect(youtubeId('https://m.youtube.com/embed/$id'), id);
    expect(youtubeId('https://vimeo.com/123'), isNull);
    expect(youtubeId('pas un lien'), isNull);
  });

  test('contrôle du type et de la taille des fichiers uploadés', () {
    expect(
      () => MediaStorage.validate('photo.jpg', 2000, MediaKind.image),
      returnsNormally,
    );
    expect(
      () => MediaStorage.validate('photo.exe', 2000, MediaKind.image),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () =>
          MediaStorage.validate('photo.png', 11 * 1024 * 1024, MediaKind.image),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () =>
          MediaStorage.validate('clip.mp4', 50 * 1024 * 1024, MediaKind.video),
      returnsNormally,
    );
    expect(
      () => MediaStorage.validate('clip.avi', 1000, MediaKind.video),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => MediaStorage.validate('clip.mp4', 0, MediaKind.video),
      throwsA(isA<ValidationException>()),
    );
  });

  test('conversion d\'une réponse wger', () {
    final w = WgerExercise.fromApi({
      'id': 73,
      'category': {'id': 11, 'name': 'Chest'},
      'muscles': [
        {'name': 'Pectoralis major', 'name_en': 'Chest'},
      ],
      'equipment': [
        {'id': 1, 'name': 'Barbell'},
      ],
      'images': [
        {
          'image':
              'https://wger.de/media/exercise-images/192/Bench-press-1.png',
        },
      ],
      'license': {'short_name': 'CC-BY-SA 3'},
      'translations': [
        {
          'language': 2,
          'name': 'Bench Press',
          'description': '<p>Lie down.</p>',
        },
        {
          'language': 12,
          'name': 'Développé couché',
          'description': '<p>Allongez-vous&nbsp;sur le banc.</p>',
        },
      ],
    });
    expect(w.name, 'Développé couché');
    expect(w.description, 'Allongez-vous sur le banc.');
    expect(w.mappedMuscle, Muscle.chest);
    expect(w.mappedEquipment, Equipment.barbell);
    expect(w.images.single, endsWith('Bench-press-1.png'));
  });

  test('durée estimée d\'un workout', () {
    final w = Workout(
      id: 'w',
      name: 'Test',
      description: '',
      level: Level.beginner,
      goal: Goal.fitness,
      authorId: 'a',
      createdAt: DateTime(2026),
      items: const [
        WorkoutItem(exerciseId: 'e', sets: 3, reps: 10, restSec: 60),
      ],
    );
    // 3 × 40 s + 2 × 60 s + 60 s de transition = 300 s.
    expect(w.estimatedMinutes, 5);
    expect(w.totalSets, 3);
  });
}
