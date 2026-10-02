import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/errors.dart';
import 'package:gymflow/core/search.dart';
import 'package:gymflow/models/content.dart';
import 'package:gymflow/models/enums.dart';
import 'package:gymflow/models/exercise.dart';
import 'package:gymflow/models/prefs.dart';
import 'package:gymflow/models/workout.dart';
import 'package:gymflow/services/backend.dart';
import 'package:gymflow/services/library_service.dart';

import 'helpers.dart';

/// Bibliothèque : créations des membres, publication modérée, recherche
/// bilingue, filtres mémorisés et favoris en tête.
void main() {
  Future<Exercise> createExercise(Backend b, String name) =>
      b.exerciseService.create(
        name: name,
        primaryMuscle: Muscle.chest,
        equipment: Equipment.bodyweight,
        level: Level.beginner,
        type: ExerciseType.strength,
        description: 'Une description assez longue pour être publiée.',
        steps: const ['Se placer.', 'Pousser.'],
        media: const [
          MediaItem(kind: MediaKind.youtube, source: 'IODxDxX7oi4'),
        ],
      );

  group('Recherche bilingue', () {
    test('le glossaire relie le français et l\'anglais', () {
      expect(Search.expand('bench press'), contains('developpe couche'));
      expect(Search.expand('pull up'), contains('traction'));
      expect(Search.expand('Développé couché'), contains('bench press'));
      expect(
        Search.matches(Search.expand('pull ups'), 'Tractions pronation'),
        isTrue,
      );
      // Les mots courts ne déclenchent pas de faux positifs.
      expect(Search.matches(Search.expand('run'), 'Crunch'), isFalse);
    });

    test(
      'un anglophone trouve les exercices, workouts et programmes',
      () async {
        final b = await makeBackend();
        await loginAs(b, 'nour@gymflow.tn');
        List<String> ex(String q) =>
            b.library.exercises(query: q).map((e) => e.id).toList();
        expect(ex('bench press').first, 'ex_bench');
        expect(ex('pull-up'), contains('ex_pullup'));
        expect(ex('deadlift'), containsAll(['ex_deadlift', 'ex_rdl']));
        expect(ex('chest'), contains('ex_db_fly'));
        expect(ex('traction'), contains('ex_pullup'));
        // Un workout est trouvé par les exercices qu'il contient.
        expect(
          b.library.workouts(query: 'bench press').map((w) => w.id),
          contains('w_push'),
        );
        expect(
          b.library.programs(query: 'beginner').map((p) => p.id),
          contains('p_fullbody'),
        );
      },
    );

    test('affichage dans la langue choisie, avec repli', () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      final bench = b.exercises.byId('ex_bench')!;
      expect(bench.nameIn(ContentLang.en), 'Barbell bench press');
      expect(bench.nameIn(ContentLang.fr), 'Développé couché à la barre');
      await b.library.setContentLang(ContentLang.en);
      expect(b.library.contentLang, ContentLang.en);
      // Contenu sans traduction : nom d'origine.
      final w = b.workouts.byId('w_leila_cardio')!;
      expect(w.nameIn(ContentLang.en), 'Cardio rapide');
      // Filtre « disponible en anglais ».
      final en = b.library.workouts(
        filters: {
          LibraryFilters.lang: {ContentLang.en},
        },
      );
      expect(en.every((w) => w.availableIn(ContentLang.en)), isTrue);
    });
  });

  group('Créations des membres et publication', () {
    test('un abonné crée un exercice privé, invisible des autres', () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      final e = await createExercise(b, 'Pompes archer');
      expect(e.publication.status, ContentStatus.private);
      expect(b.exerciseService.byId(e.id), isNotNull);
      await loginAs(b, 'omar@gymflow.tn');
      expect(b.exerciseService.byId(e.id), isNull);
      expect(b.library.exercises().map((x) => x.id), isNot(contains(e.id)));
      // Même nom autorisé : son exercice ne lui est pas visible.
      await expectLater(createExercise(b, 'Pompes archer'), completes);
    });

    test('proposer → valider : visible de tous, avec ses exercices', () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      final e = await createExercise(b, 'Pompes archer');
      final w = await b.workoutService.saveWorkout(
        name: 'Mon haut du corps',
        description: 'Une séance courte et efficace pour le haut du corps.',
        level: Level.beginner,
        goal: Goal.fitness,
        items: [
          WorkoutItem(exerciseId: e.id, sets: 3, reps: 10, restSec: 60),
          const WorkoutItem(
            exerciseId: 'ex_pushup',
            sets: 3,
            reps: 12,
            restSec: 60,
          ),
        ],
        lang: ContentLang.fr,
        altName: 'My upper body',
      );
      await b.library.submit(ContentKind.workout, w.id);
      expect(b.workouts.byId(w.id)!.publication.isPending, isTrue);
      expect(b.exercises.byId(e.id)!.publication.isPending, isTrue);
      // Toujours invisible pour les autres membres…
      await loginAs(b, 'omar@gymflow.tn');
      expect(b.workoutService.workoutById(w.id), isNull);
      await expectLater(
        b.library.approve(ContentKind.workout, w.id),
        throwsA(isA<PermissionDeniedException>()),
      );
      // … mais visible du coach qui valide.
      await loginAs(b, 'sarra@gymflow.tn');
      expect(b.library.reviewQueue().map((x) => x.id), contains(w.id));
      expect(b.workoutService.workoutById(w.id), isNotNull);
      await b.library.approve(ContentKind.workout, w.id);
      expect(b.workouts.byId(w.id)!.isPublished, isTrue);
      expect(b.exercises.byId(e.id)!.isPublished, isTrue);
      // Tout le monde le voit, et le trouve en anglais.
      await loginAs(b, 'omar@gymflow.tn');
      expect(
        b.library.workouts(query: 'my upper body').map((x) => x.id),
        contains(w.id),
      );
      expect(
        b.library.authorLabel(b.workouts.byId(w.id)!),
        matches(RegExp(r'^Nour [A-Z]\.$')),
      );
      expect(
        b.library.originOf(b.workouts.byId(w.id)!, b.auth.currentUser),
        LibraryFilters.community,
      );
      // L'auteur est notifié et ne peut plus le modifier seul.
      await loginAs(b, 'nour@gymflow.tn');
      expect(
        b.notificationsRepo.all.any(
          (n) => n.userId == 'u_nour' && n.title.startsWith('Publié'),
        ),
        isTrue,
      );
      expect(
        b.workoutService.canEditWorkout(
          b.auth.currentUser!,
          b.workouts.byId(w.id)!,
        ),
        isFalse,
      );
    });

    test('refus motivé, correction puis nouvelle proposition', () async {
      final b = await makeBackend();
      await loginAs(b, 'mehdi@gymflow.tn');
      await expectLater(
        b.library.reject(ContentKind.workout, 'w_rami_arms', 'non'),
        throwsA(isA<ValidationException>()),
      );
      await b.library.reject(
        ContentKind.workout,
        'w_rami_arms',
        'Précisez les charges conseillées.',
      );
      final w = b.workouts.byId('w_rami_arms')!;
      expect(w.publication.status, ContentStatus.rejected);
      expect(w.publication.note, 'Précisez les charges conseillées.');
      await loginAs(b, 'rami@gymflow.tn');
      expect(b.workoutService.canEditWorkout(b.auth.currentUser!, w), isTrue);
      await b.library.submit(ContentKind.workout, w.id);
      expect(b.workouts.byId(w.id)!.publication.isPending, isTrue);
      await b.library.withdraw(ContentKind.workout, w.id);
      expect(b.workouts.byId(w.id)!.publication.status, ContentStatus.private);
    });

    test('publication refusée sans description suffisante', () async {
      final b = await makeBackend();
      await loginAs(b, 'leila@gymflow.tn');
      await expectLater(
        b.library.submit(ContentKind.workout, 'w_leila_cardio'),
        throwsA(isA<ValidationException>()),
      );
      await loginAs(b, 'nour@gymflow.tn');
      await expectLater(
        b.library.submit(ContentKind.workout, 'w_leila_cardio'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('un abonné crée un programme avec ses propres workouts', () async {
      final b = await makeBackend();
      await loginAs(b, 'ahmed@gymflow.tn');
      final p = await b.workoutService.saveProgram(
        name: 'Mon split maison',
        description: 'Trois séances par semaine à la maison.',
        level: Level.intermediate,
        goal: Goal.muscleGain,
        weeks: 6,
        days: const [
          ProgramDay(weekday: 1, workoutId: 'w_ahmed_home'),
          ProgramDay(weekday: 3, workoutId: 'w_push'),
        ],
        equipment: 'Poids du corps',
      );
      expect(p.isPrivate, isTrue);
      await b.library.submit(ContentKind.program, p.id);
      // Le workout et l'exercice personnels sont proposés avec lui.
      expect(b.workouts.byId('w_ahmed_home')!.publication.isPending, isTrue);
      expect(
        b.exercises.byId('ex_ahmed_diamond')!.publication.isPending,
        isTrue,
      );
      // Un autre membre ne peut pas utiliser un workout privé d'Ahmed.
      await loginAs(b, 'nour@gymflow.tn');
      await expectLater(
        b.workoutService.saveProgram(
          name: 'Copie',
          description: '',
          level: Level.beginner,
          goal: Goal.fitness,
          weeks: 4,
          days: const [ProgramDay(weekday: 1, workoutId: 'w_ahmed_home')],
          equipment: '',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('dupliquer un workout du club pour le personnaliser', () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      final copy = await b.library.duplicate(ContentKind.workout, 'w_push');
      expect(copy.name, 'Push Day (copie)');
      expect(copy.authorId, 'u_nour');
      expect(copy.publication.status, ContentStatus.private);
    });

    test(
      'le staff publie directement ; un coach modère le contenu des membres',
      () async {
        final b = await makeBackend();
        await loginAs(b, 'sarra@gymflow.tn');
        final e = await createExercise(b, 'Planche latérale');
        expect(e.isPublished, isTrue);
        final ines = b.workouts.byId('w_ines_core')!;
        expect(
          b.workoutService.canEditWorkout(b.auth.currentUser!, ines),
          isTrue,
        );
        // Mais jamais les créations privées d'un membre.
        expect(b.workoutService.workoutById('w_ahmed_home'), isNull);
      },
    );
  });

  group('Filtres mémorisés et favoris', () {
    test('les filtres survivent à la déconnexion', () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      final f = <String, Set<String>>{
        LibraryFilters.level: {Level.beginner.name},
      };
      await b.library.saveFilters(LibraryFilters.workoutsList, f);
      await b.auth.logout();
      await loginAs(b, 'nour@gymflow.tn');
      final saved = b.library.savedFilters(LibraryFilters.workoutsList);
      expect(saved.of(LibraryFilters.level), {Level.beginner.name});
      final list = b.library.workouts(filters: saved);
      expect(list, isNotEmpty);
      expect(list.every((w) => w.level == Level.beginner), isTrue);
    });

    test('matériel disponible, durée et origine', () async {
      final b = await makeBackend();
      await loginAs(b, 'ahmed@gymflow.tn');
      final bodyweight = b.library.workouts(
        filters: {
          LibraryFilters.equipment: {
            Equipment.bodyweight.name,
            Equipment.mat.name,
          },
        },
      );
      for (final w in bodyweight) {
        for (final (_, e) in b.workoutService.resolve(w)) {
          expect(
            {Equipment.bodyweight, Equipment.mat}.contains(e.equipment),
            isTrue,
            reason: '${w.name} : ${e.name}',
          );
        }
      }
      final mine = b.library.workouts(
        filters: {
          LibraryFilters.origin: {LibraryFilters.mine},
        },
      );
      expect(mine.map((w) => w.id), ['w_ahmed_home']);
      final short = b.library.workouts(
        filters: {
          LibraryFilters.duration: {'lt30'},
        },
      );
      expect(short.every((w) => w.estimatedMinutes < 30), isTrue);
    });

    test('le dernier favori passe en tête de liste', () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      final before = b.library.workouts();
      final third = before[2];
      await b.userService.toggleFavorite(third.id);
      expect(b.library.workouts().first.id, third.id);
      final fifth = before[4];
      await b.userService.toggleFavorite(fifth.id);
      final after = b.library.workouts();
      expect(after[0].id, fifth.id);
      expect(after[1].id, third.id);
      await b.userService.toggleFavorite(fifth.id);
      expect(b.library.workouts().first.id, third.id);
    });
  });

  test(
    'suppression d\'un compte : créations privées effacées, publiées anonymisées',
    () async {
      final b = await makeBackend();
      await loginAs(b, 'ines@gymflow.tn');
      await b.privacy.deleteMyAccount('Membre2026!');
      expect(b.workouts.byId('w_ines_core')!.authorId, 'ancien-membre');
      await loginAs(b, 'ahmed@gymflow.tn');
      await b.privacy.deleteMyAccount('Membre2026!');
      expect(b.workouts.byId('w_ahmed_home'), isNull);
      expect(b.exercises.byId('ex_ahmed_diamond'), isNull);
    },
  );
}
