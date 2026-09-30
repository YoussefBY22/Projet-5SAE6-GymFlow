import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/errors.dart';
import 'package:gymflow/models/enums.dart';
import 'package:gymflow/models/session_log.dart';
import 'package:gymflow/services/progress_service.dart';

import 'helpers.dart';

SetLog _set(String ex, double load, int reps, [int i = 1]) => SetLog(
  exerciseId: ex,
  exerciseName: ex,
  setIndex: i,
  reps: reps,
  loadKg: load,
);

void main() {
  test('IMC et catégories', () {
    expect(ProgressService.bmi(70, 175)!, closeTo(22.86, 0.01));
    expect(ProgressService.bmi(70, null), isNull);
    expect(ProgressService.bmiCategory(17), 'Insuffisance pondérale');
    expect(ProgressService.bmiCategory(22), 'Corpulence normale');
    expect(ProgressService.bmiCategory(27), 'Surpoids');
    expect(ProgressService.bmiCategory(32), 'Obésité');
  });

  test('métabolisme de base et besoins caloriques', () {
    final bmr = ProgressService.bmr(
      weightKg: 80,
      heightCm: 180,
      age: 30,
      gender: Gender.male,
    );
    expect(bmr, 1780); // 800 + 1125 - 150 + 5
    expect(
      ProgressService.bmr(
        weightKg: 60,
        heightCm: 165,
        age: 30,
        gender: Gender.female,
      ),
      closeTo(1320.25, 0.01),
    );
    expect(
      ProgressService.dailyCalories(
        bmr: 1000,
        activityFactor: 1.5,
        goal: Goal.weightLoss,
      ),
      1100,
    );
    expect(
      ProgressService.dailyCalories(
        bmr: 1000,
        activityFactor: 1.5,
        goal: Goal.muscleGain,
      ),
      1800,
    );
  });

  test('volume, 1RM (Epley) et records', () {
    final sets = [_set('a', 60, 10), _set('a', 70, 5, 2), _set('b', 0, 20)];
    expect(ProgressService.volumeOf(sets), 600 + 350);
    expect(ProgressService.oneRepMax(100, 1), 100);
    expect(ProgressService.oneRepMax(100, 10), closeTo(133.33, 0.01));
  });

  test(
    'séance enregistrée : records battus, historique, fil et progression',
    () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      final w = b.workouts.byId('w_fb_a')!;
      final first = await b.trainingLog.finishSession(
        workout: w,
        startedAt: testNow,
        durationSec: 2400,
        sets: [
          _set('ex_goblet', 12, 12),
          _set('ex_goblet', 14, 10, 2),
          _set('ex_plank', 0, 1),
        ],
      );
      expect(first.records.length, 1); // 1re charge sur le goblet = record
      expect(first.records.first.bestLoadKg, 14);
      expect(first.log.totalVolume, 12 * 12 + 14 * 10);
      expect(b.trainingLog.historyOf('u_nour').length, 1);
      expect(b.trainingLog.feed().first.id, first.log.id);
      expect(b.progress.sessionsThisWeek('u_nour'), 1);
      expect(b.progress.streakDays('u_nour'), 1);

      setNow(testNow.add(const Duration(days: 1)));
      final second = await b.trainingLog.finishSession(
        workout: w,
        startedAt: testNow.add(const Duration(days: 1)),
        durationSec: 2000,
        sets: [_set('ex_goblet', 14, 12), _set('ex_goblet', 16, 8, 2)],
      );
      expect(second.records.single.bestLoadKg, 16);
      expect(b.progress.streakDays('u_nour'), 2);
      expect(b.progress.recordsOf('u_nour').single.bestLoadKg, 16);
      // Badge « Premier pas » débloqué.
      expect(b.progress.badgesOf('u_nour').first.unlocked, isTrue);
    },
  );

  test(
    'séance vide refusée ; bravo sur la séance d\'un autre membre',
    () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      expect(
        () => b.trainingLog.finishSession(
          workout: b.workouts.byId('w_push')!,
          startedAt: testNow,
          durationSec: 60,
          sets: const [],
        ),
        throwsA(isA<BusinessRuleException>()),
      );
      final ahmedSession = b.sessions.where((s) => s.userId == 'u_ahmed').first;
      final liked = await b.trainingLog.toggleKudos(ahmedSession.id);
      expect(liked.kudos, contains('u_nour'));
      expect(
        b.notificationsRepo.all.any(
          (n) => n.userId == 'u_ahmed' && n.title.contains('Bravo'),
        ),
        isTrue,
      );
      final unliked = await b.trainingLog.toggleKudos(ahmedSession.id);
      expect(unliked.kudos, isNot(contains('u_nour')));
    },
  );

  test('pesée : met à jour le poids du profil et la courbe', () async {
    final b = await makeBackend();
    await loginAs(b, 'salma@gymflow.tn');
    final before = b.progress.weightsOf('u_salma').length;
    await b.progress.addWeight(75.4);
    expect(b.progress.weightsOf('u_salma').length, before + 1);
    expect(b.users.byId('u_salma')!.weightKg, 75.4);
    expect(() => b.progress.addWeight(10), throwsA(isA<ValidationException>()));
  });

  test('série de jours : interrompue après un jour sans séance', () async {
    final b = await makeBackend();
    expect(b.progress.streakDays('u_ahmed'), greaterThanOrEqualTo(3));
    setNow(testNow.add(const Duration(days: 2)));
    expect(b.progress.streakDays('u_ahmed'), 0);
  });
}
