import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/models/content.dart';
import 'package:gymflow/models/enums.dart';

import 'helpers.dart';

void main() {
  test('le jeu de démonstration est complet et cohérent', () async {
    final b = await makeBackend();
    final users = b.users.all;
    expect(users.where((u) => u.isAdmin).length, 1);
    expect(users.where((u) => u.isCoach).length, 3);
    expect(users.where((u) => u.isMember && u.active).length, 8);
    expect(users.where((u) => !u.active).length, 1);
    expect(b.exercises.count, greaterThanOrEqualTo(40));
    expect(b.workouts.count, greaterThanOrEqualTo(8));
    expect(b.programs.count, greaterThanOrEqualTo(5));
    expect(b.courses.count, greaterThanOrEqualTo(15));
    expect(b.products.count, greaterThanOrEqualTo(12));
    expect(b.orders.count, greaterThan(0));

    // Toutes les références des workouts et programmes existent.
    for (final w in b.workouts.all) {
      for (final i in w.items) {
        expect(b.exercises.byId(i.exerciseId), isNotNull, reason: i.exerciseId);
      }
    }
    for (final p in b.programs.all) {
      for (final d in p.days) {
        expect(b.workouts.byId(d.workoutId), isNotNull);
      }
    }

    // Les trois statuts de cours sont représentés.
    final statuses = b.courses.all.map((c) => c.statusAt(testNow)).toSet();
    expect(statuses, containsAll(CourseStatus.values.take(3)));

    // Le premier abonné de démo n'a encore aucune séance.
    expect(b.sessions.where((s) => s.userId == 'u_nour'), isEmpty);
    expect(b.sessions.where((s) => s.userId == 'u_ahmed'), isNotEmpty);

    // Chaque exercice du club a au moins une vidéo (YouTube ou fichier).
    for (final e in b.exercises.all.where((e) => e.isPublished)) {
      expect(e.mainVideo, isNotNull, reason: e.name);
    }
  });

  test('série de 3 jours pour Ahmed et records calculés', () async {
    final b = await makeBackend();
    await loginAs(b, 'ahmed@gymflow.tn');
    expect(b.progress.streakDays('u_ahmed'), greaterThanOrEqualTo(3));
    expect(b.progress.recordsOf('u_ahmed'), isNotEmpty);
  });
}
