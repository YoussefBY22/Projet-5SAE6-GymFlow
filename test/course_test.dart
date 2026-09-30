import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/errors.dart';
import 'package:gymflow/models/enums.dart';

import 'helpers.dart';

Future<dynamic> _create(
  dynamic b, {
  required String coachId,
  DateTime? start,
  int capacity = 10,
}) => b.courseService.save(
  title: 'Circuit training',
  description: 'Circuit complet en petit groupe.',
  category: CourseCategory.hiit,
  level: Level.intermediate,
  coachId: coachId,
  room: 'Salle Énergie',
  capacity: capacity,
  durationMin: 45,
  startAt: start,
);

void main() {
  test('un coach crée ses propres cours (coach imposé)', () async {
    final b = await makeBackend();
    await loginAs(b, 'sarra@gymflow.tn');
    final c = await _create(
      b,
      coachId: 'u_amira',
      start: testNow.add(const Duration(days: 3)),
    );
    expect(c.coachId, 'u_sarra');
  });

  test('un coach ne modifie pas le cours d\'un autre coach', () async {
    final b = await makeBackend();
    await loginAs(b, 'sarra@gymflow.tn');
    final s1 = b.courses.byId('c_s1')!; // cours d'Amira
    expect(
      () => b.courseService.save(
        id: s1.id,
        title: 'Modifié',
        description: s1.description,
        category: s1.category,
        level: s1.level,
        coachId: s1.coachId,
        room: s1.room,
        capacity: s1.capacity,
        durationMin: s1.durationMin,
        startAt: s1.startAt,
      ),
      throwsA(isA<PermissionDeniedException>()),
    );
  });

  test(
    'le super admin affecte un coach, qui est notifié ; cours « à planifier »',
    () async {
      final b = await makeBackend();
      await loginAs(b, 'admin@gymflow.tn');
      final c = await _create(b, coachId: 'u_mehdi');
      expect(c.coachId, 'u_mehdi');
      expect(b.courseService.statusOf(c), CourseStatus.toPlan);
      expect(
        b.notificationsRepo.all.any(
          (n) => n.userId == 'u_mehdi' && n.refId == c.id,
        ),
        isTrue,
      );
    },
  );

  test('date passée, capacité invalide et abonné refusés', () async {
    final b = await makeBackend();
    await loginAs(b, 'admin@gymflow.tn');
    expect(
      () => _create(
        b,
        coachId: 'u_mehdi',
        start: testNow.subtract(const Duration(hours: 1)),
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => _create(b, coachId: 'u_mehdi', capacity: 0),
      throwsA(isA<ValidationException>()),
    );
    await b.auth.logout();
    await loginAs(b, 'nour@gymflow.tn');
    expect(
      () => _create(b, coachId: 'u_mehdi'),
      throwsA(isA<PermissionDeniedException>()),
    );
  });

  test(
    'capacité inférieure aux inscrits refusée ; hausse → promotion de la liste d\'attente',
    () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      final w = await b.reservationService.book('c_s3', joinWaitlist: true);
      await b.auth.logout();
      await loginAs(b, 'admin@gymflow.tn');
      final s3 = b.courses.byId('c_s3')!;
      Future<dynamic> withCapacity(int cap) => b.courseService.save(
        id: s3.id,
        title: s3.title,
        description: s3.description,
        category: s3.category,
        level: s3.level,
        coachId: s3.coachId,
        room: s3.room,
        capacity: cap,
        durationMin: s3.durationMin,
        startAt: s3.startAt,
      );
      expect(() => withCapacity(3), throwsA(isA<ValidationException>()));
      await withCapacity(8);
      expect(b.reservations.byId(w.id)!.status, ReservationStatus.confirmed);
    },
  );

  test(
    'annulation d\'un cours : réservations annulées et inscrits prévenus',
    () async {
      final b = await makeBackend();
      await loginAs(b, 'sarra@gymflow.tn');
      await b.courseService.cancel('c_s3', 'Vélo en maintenance');
      expect(
        b.courseService.statusOf(b.courses.byId('c_s3')!),
        CourseStatus.cancelled,
      );
      expect(
        b.reservations.where((r) => r.courseId == 'c_s3' && r.isActive),
        isEmpty,
      );
      expect(
        b.notificationsRepo.all
            .where((n) => n.title.startsWith('Cours annulé'))
            .length,
        6,
      );
      expect(
        b.auditRepo.all.any((a) => a.action == 'Annulation de cours'),
        isTrue,
      );
    },
  );

  test('modification d\'horaire : inscrits prévenus', () async {
    final b = await makeBackend();
    await loginAs(b, 'amira@gymflow.tn');
    final s1 = b.courses.byId('c_s1')!;
    await b.courseService.save(
      id: s1.id,
      title: s1.title,
      description: s1.description,
      category: s1.category,
      level: s1.level,
      coachId: s1.coachId,
      room: s1.room,
      capacity: s1.capacity,
      durationMin: s1.durationMin,
      startAt: s1.startAt!.add(const Duration(hours: 1)),
    );
    final notified = b.notificationsRepo.all
        .where((n) => n.title.startsWith('Horaire modifié'))
        .map((n) => n.userId)
        .toSet();
    expect(notified, {'u_leila', 'u_ines'});
  });
}
