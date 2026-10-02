import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/errors.dart';
import 'package:gymflow/core/routes.dart';
import 'package:gymflow/models/content.dart';
import 'package:gymflow/models/enums.dart';

import 'helpers.dart';

/// Droits par rôle appliqués aux routes et aux services.
void main() {
  test('garde des routes nommées', () {
    expect(Routes.rolesFor(Routes.users), {UserRole.superAdmin});
    expect(Routes.rolesFor(Routes.audit), {UserRole.superAdmin});
    expect(Routes.rolesFor(Routes.productForm), {UserRole.superAdmin});
    expect(Routes.rolesFor(Routes.courseForm), {
      UserRole.superAdmin,
      UserRole.coach,
    });
    // Création ouverte à tous (contenu privé pour un abonné) ; la
    // validation des propositions est réservée au staff.
    expect(Routes.rolesFor(Routes.exerciseForm), isNull);
    expect(Routes.rolesFor(Routes.review), {
      UserRole.superAdmin,
      UserRole.coach,
    });
    expect(Routes.rolesFor(Routes.progress), {UserRole.member});
    expect(Routes.rolesFor(Routes.home), isNull); // tout utilisateur connecté
  });

  test('un abonné n\'accède à aucune API d\'administration', () async {
    final b = await makeBackend();
    await loginAs(b, 'nour@gymflow.tn');
    expect(
      () => b.userService.list(),
      throwsA(isA<PermissionDeniedException>()),
    );
    expect(() => b.audit.entries(), throwsA(isA<PermissionDeniedException>()));
    expect(
      () => b.dashboard.adminStats(),
      throwsA(isA<PermissionDeniedException>()),
    );
    expect(
      () => b.userService.setActive('u_ahmed', false),
      throwsA(isA<PermissionDeniedException>()),
    );
    // Un abonné peut créer un exercice, mais il reste privé (jamais
    // publié sans validation d'un coach ou de l'admin).
    final own = await b.exerciseService.create(
      name: 'Test',
      primaryMuscle: Muscle.abs,
      equipment: Equipment.mat,
      level: Level.beginner,
      type: ExerciseType.strength,
      description: 'Description de test.',
    );
    expect(own.publication.status, ContentStatus.private);
    expect(
      () => b.library.approve(ContentKind.exercise, own.id),
      throwsA(isA<PermissionDeniedException>()),
    );
    expect(
      () => b.wger.browse(categoryId: 11),
      throwsA(isA<PermissionDeniedException>()),
    );
  });

  test('sans session, les API refusent l\'accès', () async {
    final b = await makeBackend();
    expect(
      () => b.exerciseService.list(),
      throwsA(isA<NotAuthenticatedException>()),
    );
    expect(
      () => b.reservationService.book('c_s1'),
      throwsA(isA<NotAuthenticatedException>()),
    );
  });

  test(
    'un coach ne modifie que ses propres exercices, workouts et programmes',
    () async {
      final b = await makeBackend();
      await loginAs(b, 'sarra@gymflow.tn');
      final bench = b.exercises.byId('ex_bench')!; // exercice de Mehdi
      expect(
        () => b.exerciseService.update(bench.copyWith(name: 'Hack')),
        throwsA(isA<PermissionDeniedException>()),
      );
      final pushup = b.exercises.byId('ex_pushup')!; // exercice de Sarra
      final updated = await b.exerciseService.update(
        pushup.copyWith(breathing: 'Expirez en poussant.'),
      );
      expect(updated.breathing, 'Expirez en poussant.');
      expect(
        () => b.workoutService.deleteWorkout('w_push'),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(
        () => b.workoutService.deleteProgram('p_ppl'),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(() => b.dashboard.coachStats(), returnsNormally);
    },
  );

  test('suppression d\'un exercice utilisé dans un workout refusée', () async {
    final b = await makeBackend();
    await loginAs(b, 'admin@gymflow.tn');
    expect(
      () => b.exerciseService.delete('ex_bench'),
      throwsA(isA<BusinessRuleException>()),
    );
  });

  test(
    'super admin : activation, rôle, audit, pas d\'auto-désactivation',
    () async {
      final b = await makeBackend();
      await loginAs(b, 'admin@gymflow.tn');
      expect(
        () => b.userService.setActive('u_admin', false),
        throwsA(isA<BusinessRuleException>()),
      );
      // Session d'Ahmed ouverte ailleurs puis compte désactivé.
      await b.auth.logout();
      await loginAs(b, 'ahmed@gymflow.tn');
      expect(b.credentials.byId('u_ahmed')!.sessionDigest, isNotNull);
      await b.auth.logout();
      await loginAs(b, 'admin@gymflow.tn');
      await b.userService.setActive('u_ahmed', false);
      expect(b.users.byId('u_ahmed')!.active, isFalse);
      expect(b.credentials.byId('u_ahmed')!.sessionDigest, isNull);
      await b.userService.changeRole('u_ines', UserRole.coach);
      final actions = b.audit.entries().map((e) => e.action).toList();
      expect(actions, containsAll(['Désactivation', 'Changement de rôle']));
    },
  );

  test(
    'création de coach par l\'admin : connexion avec le mot de passe provisoire',
    () async {
      final b = await makeBackend();
      await loginAs(b, 'admin@gymflow.tn');
      await b.userService.createCoach(
        fullName: 'Yasmine Kefi',
        email: 'yasmine@gymflow.tn',
        temporaryPassword: 'Provisoire1',
        gender: Gender.female,
        specialty: 'Pilates',
      );
      await b.auth.logout();
      final coach = await b.auth.login('yasmine@gymflow.tn', 'Provisoire1');
      expect(coach.role, UserRole.coach);
    },
  );

  test(
    'abonnement mis à jour par l\'admin : l\'abonné expiré peut réserver',
    () async {
      final b = await makeBackend();
      await loginAs(b, 'admin@gymflow.tn');
      await b.userService.updateSubscription(
        'u_hedi',
        SubscriptionType.monthly,
      );
      await b.auth.logout();
      await loginAs(b, 'hedi@gymflow.tn');
      final r = await b.reservationService.book('c_s1');
      expect(r.status, ReservationStatus.confirmed);
    },
  );

  test('un abonné ne consulte pas l\'historique d\'un autre abonné', () async {
    final b = await makeBackend();
    await loginAs(b, 'nour@gymflow.tn');
    expect(
      () => b.trainingLog.historyOf('u_ahmed'),
      throwsA(isA<PermissionDeniedException>()),
    );
  });
}
