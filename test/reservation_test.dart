import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/errors.dart';
import 'package:gymflow/models/enums.dart';
import 'package:gymflow/services/course_service.dart';
import 'package:gymflow/services/notification_service.dart';
import 'package:gymflow/services/platform/platform_services.dart';

import 'helpers.dart';

/// Règles de réservation : complet, liste d'attente, abonnement expiré,
/// chevauchement, annulation 2 h, présence, notation, statuts.
void main() {
  test('réservation confirmée + rappels 24 h / 1 h + notification', () async {
    final b = await makeBackend();
    await loginAs(b, 'nour@gymflow.tn');
    final r = await b.reservationService.book('c_s1');
    expect(r.status, ReservationStatus.confirmed);
    final notifier = b.notifier as RecordingNotifier;
    final course = b.courses.byId('c_s1')!;
    expect(
      notifier.scheduled.values,
      containsAll([
        course.startAt!.subtract(const Duration(hours: 24)),
        course.startAt!.subtract(const Duration(hours: 1)),
      ]),
    );
    expect(b.notifications.mine().first.title, 'Réservation confirmée');
    // La réservation apparaît dans « Mes réservations » et sur l'accueil.
    expect(
      b.courseService.list(view: CourseView.myBookings).map((c) => c.id),
      contains('c_s1'),
    );
    expect(b.reservationService.nextBooking('u_nour')?.$2.id, 'c_s1');
  });

  test('double réservation refusée', () async {
    final b = await makeBackend();
    await loginAs(b, 'nour@gymflow.tn');
    await b.reservationService.book('c_s1');
    expect(
      () => b.reservationService.book('c_s1'),
      throwsA(isA<BusinessRuleException>()),
    );
  });

  test(
    'cours complet : refus, puis liste d\'attente et promotion automatique',
    () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      expect(b.courseService.confirmedCount('c_s3'), 6);
      await expectLater(
        b.reservationService.book('c_s3'),
        throwsA(
          isA<BusinessRuleException>().having(
            (e) => e.message,
            'message',
            contains('complet'),
          ),
        ),
      );
      final waiting = await b.reservationService.book(
        'c_s3',
        joinWaitlist: true,
      );
      expect(waiting.status, ReservationStatus.waitlisted);
      expect(b.reservationService.waitlistPosition(waiting), 1);

      // Ahmed libère sa place : Nour est promue automatiquement.
      await b.auth.logout();
      await loginAs(b, 'ahmed@gymflow.tn');
      final ahmed = b.reservationService.activeFor('c_s3', 'u_ahmed')!;
      await b.reservationService.cancel(ahmed.id);
      expect(
        b.reservations.byId(waiting.id)!.status,
        ReservationStatus.confirmed,
      );
      expect(
        b.notificationsRepo.all.any(
          (n) =>
              n.userId == 'u_nour' && n.title.contains('place s\'est libérée'),
        ),
        isTrue,
      );
    },
  );

  test('abonnement expiré : réservation refusée', () async {
    final b = await makeBackend();
    await loginAs(b, 'hedi@gymflow.tn');
    expect(
      () => b.reservationService.book('c_s1'),
      throwsA(
        isA<BusinessRuleException>().having(
          (e) => e.message,
          'm',
          contains('abonnement'),
        ),
      ),
    );
  });

  test('chevauchement avec une autre réservation refusé', () async {
    final b = await makeBackend();
    await loginAs(b, 'admin@gymflow.tn');
    final s2 = b.courses.byId('c_s2')!; // HIIT Express 12:30-13:00
    final overlapping = await b.courseService.save(
      title: 'Abdos express',
      description: 'Gainage et abdominaux en 30 minutes.',
      category: CourseCategory.hiit,
      level: Level.beginner,
      coachId: 'u_sarra',
      room: 'Studio 2',
      capacity: 10,
      durationMin: 30,
      startAt: s2.startAt!.add(const Duration(minutes: 15)),
    );
    await b.auth.logout();
    await loginAs(b, 'nour@gymflow.tn');
    await b.reservationService.book('c_s2');
    expect(
      () => b.reservationService.book(overlapping.id),
      throwsA(
        isA<BusinessRuleException>().having(
          (e) => e.message,
          'm',
          contains('Chevauchement'),
        ),
      ),
    );
  });

  test('annulation libre jusqu\'à 2 h avant, refusée ensuite', () async {
    final b = await makeBackend();
    await loginAs(b, 'nour@gymflow.tn');
    final start = b.courses.byId('c_s1')!.startAt!;
    final r1 = await b.reservationService.book('c_s1');
    setNow(start.subtract(const Duration(hours: 1)));
    expect(
      () => b.reservationService.cancel(r1.id),
      throwsA(
        isA<BusinessRuleException>().having(
          (e) => e.message,
          'm',
          contains('2 h'),
        ),
      ),
    );
    setNow(start.subtract(const Duration(hours: 3)));
    await b.reservationService.cancel(r1.id);
    expect(b.reservations.byId(r1.id)!.status, ReservationStatus.cancelled);
    final keys = (b.notifier as RecordingNotifier).scheduled.keys;
    expect(keys, isNot(contains(NotificationService.reminderId(r1.id, 24))));
    expect(keys, isNot(contains(NotificationService.reminderId(r1.id, 1))));
  });

  test('cours « à planifier » non réservable, coach ne réserve pas', () async {
    final b = await makeBackend();
    await loginAs(b, 'nour@gymflow.tn');
    expect(
      () => b.reservationService.book('c_p1'),
      throwsA(isA<BusinessRuleException>()),
    );
    await b.auth.logout();
    await loginAs(b, 'sarra@gymflow.tn');
    expect(
      () => b.reservationService.book('c_s1'),
      throwsA(isA<PermissionDeniedException>()),
    );
  });

  test('transition automatique Programmé → Terminé', () async {
    final b = await makeBackend();
    await loginAs(b, 'nour@gymflow.tn');
    final c = b.courses.byId('c_s1')!;
    expect(b.courseService.statusOf(c), CourseStatus.scheduled);
    setNow(c.endAt!.add(const Duration(minutes: 1)));
    expect(b.courseService.statusOf(c), CourseStatus.done);
    expect(
      b.courseService.list(view: CourseView.done).map((x) => x.id),
      contains('c_s1'),
    );
    expect(b.courseService.list().map((x) => x.id), isNot(contains('c_s1')));
  });

  test(
    'présence : coach du cours à partir de 15 min avant ; notation après le cours',
    () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      final r = await b.reservationService.book('c_s1');
      final c = b.courses.byId('c_s1')!;
      expect(
        () => b.reservationService.rate(r.id, 5),
        throwsA(isA<BusinessRuleException>()),
      );

      await b.auth.logout();
      await loginAs(b, 'mehdi@gymflow.tn');
      expect(
        () => b.reservationService.markAttendance(r.id, true),
        throwsA(isA<PermissionDeniedException>()),
      );
      await b.auth.logout();
      await loginAs(b, 'amira@gymflow.tn');
      expect(
        () => b.reservationService.markAttendance(r.id, true),
        throwsA(isA<BusinessRuleException>()),
      );
      setNow(c.startAt!.subtract(const Duration(minutes: 10)));
      await b.reservationService.markAttendance(r.id, true);
      expect(b.reservations.byId(r.id)!.attended, isTrue);

      await b.auth.logout();
      setNow(c.endAt!.add(const Duration(hours: 1)));
      await loginAs(b, 'nour@gymflow.tn');
      expect(
        () => b.reservationService.rate(r.id, 6),
        throwsA(isA<ValidationException>()),
      );
      await b.reservationService.rate(r.id, 5, comment: 'Top !');
      expect(b.reservations.byId(r.id)!.rating, 5);
      expect(b.courseService.averageRating('c_s1'), 5);
    },
  );

  test('un absent ne peut pas noter', () async {
    final b = await makeBackend();
    await loginAs(b, 'salma@gymflow.tn');
    final r = b.reservationService.latestFor('c_d1', 'u_salma')!;
    expect(r.attended, isFalse);
    expect(
      () => b.reservationService.rate(r.id, 4),
      throwsA(isA<BusinessRuleException>()),
    );
  });
}
