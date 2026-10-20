import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gymflow/core/booking_code.dart';
import 'package:gymflow/core/errors.dart';
import 'package:gymflow/models/course.dart';
import 'package:gymflow/models/enums.dart';
import 'package:gymflow/repositories/data_store.dart';
import 'package:gymflow/services/backend.dart';
import 'package:gymflow/services/checkin_service.dart';
import 'package:gymflow/services/payment/payment_gateway.dart';
import 'package:gymflow/services/platform/platform_services.dart';
import 'package:gymflow/services/seed/seed_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// Réservation d'Ines sur le cours de démo du jour (coach : Amira).
Reservation inesToday(Backend b) =>
    b.reservationService.activeFor(SeedService.demoCourseId, 'u_ines')!;

Matcher throwsMessage<T>(String text) => throwsA(
  isA<T>().having((e) => (e as AppException).message, 'message', text),
);

void main() {
  group('Code de réservation', () {
    test('format GF-XXXX-XXXX, alphabet sans caractère ambigu, unique', () {
      final codes = <String>{};
      for (var i = 0; i < 2000; i++) {
        final c = BookingCode.generate(codes);
        expect(BookingCode.isValidFormat(c), isTrue, reason: c);
        expect(c, matches(RegExp(r'^GF-[A-Z2-9]{4}-[A-Z2-9]{4}$')));
        expect(c.substring(3), isNot(matches(RegExp('[01OIL]'))));
        expect(codes.add(c), isTrue, reason: 'doublon $c');
      }
    });

    test('saisie tolérante', () {
      expect(BookingCode.normalize(' gf-7k4m-2qxp '), 'GF-7K4M-2QXP');
      expect(BookingCode.normalize('GF7K4M2QXP'), 'GF-7K4M-2QXP');
      expect(BookingCode.normalize('7K4M 2QXP'), 'GF-7K4M-2QXP');
      expect(BookingCode.normalize('GF-7K4M-2QX'), isNull);
      expect(BookingCode.normalize('GF-0K4M-2QXP'), isNull, reason: '0');
    });

    test(
      'jeu de démo : chaque réservation a un code valide et unique',
      () async {
        final b = await makeBackend();
        final codes = b.reservations.all.map((r) => r.bookingCode).toList();
        expect(
          codes.every((c) => c != null && BookingCode.isValidFormat(c)),
          isTrue,
        );
        expect(codes.toSet().length, codes.length);
      },
    );

    test('nouvelle réservation : code attribué', () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      final r = await b.reservationService.book('c_s1');
      expect(BookingCode.isValidFormat(r.bookingCode!), isTrue);
    });

    test('anciennes réservations : codes générés sans appel HTTP', () async {
      GoogleFonts.config.allowRuntimeFetching = false;
      SharedPreferences.setMockInitialValues({});
      await initializeDateFormatting('fr_FR');
      final calls = <http.Request>[];
      final client = MockClient((req) async {
        calls.add(req);
        return http.Response('OK', 200);
      });
      Future<Backend> init(DataStore store) => Backend.init(
        store: store,
        sessionStorage: MemorySessionStorage(),
        notifier: RecordingNotifier(),
        calendar: NoopCalendar(),
        clock: () => testNow,
        passwordIterations: 60,
        payment: SimulatedPaymentGateway(latency: Duration.zero),
        httpClient: client,
        emailJsServiceId: 'service_x',
        emailJsTemplateId: 'template_x',
        emailJsPublicKey: 'pk_x',
      );
      final store = MemoryDataStore();
      var b = await init(store);
      for (final r in b.reservations.all) {
        final json = r.toJson()..remove('bookingCode');
        await store.put(Collections.reservations, r.id, json);
      }
      await store.setMeta('booking_codes', '0');
      b = await init(store);
      expect(calls, isEmpty);
      final codes = b.reservations.all.map((r) => r.bookingCode).toList();
      expect(
        codes.every((c) => c != null && BookingCode.isValidFormat(c)),
        isTrue,
      );
      expect(codes.toSet().length, codes.length);
    });
  });

  group('Cours de démo du jour', () {
    test(
      'aujourd\'hui, ~20 min après le lancement, Amira, Ines confirmée',
      () async {
        final b = await makeBackend();
        final c = b.courses.byId(SeedService.demoCourseId)!;
        expect(c.coachId, 'u_amira');
        expect(c.durationMin, 60);
        expect(
          c.startAt,
          DateTime(2026, 9, 30, 10, 30),
          reason: '10:20 → 10:30',
        );
        expect(c.startAt!.minute % 15, 0);
        expect(inesToday(b).status, ReservationStatus.confirmed);
        // Cours à venir avec Ines confirmée (démo du lendemain).
        final s1 = b.reservationService.activeFor('c_s1', 'u_ines')!;
        expect(s1.status, ReservationStatus.confirmed);
        expect(b.courses.byId('c_s1')!.coachId, 'u_amira');
      },
    );

    test('arrondi au quart d\'heure supérieur', () {
      expect(
        SeedService.demoStart(DateTime(2026, 10, 21, 14, 2)),
        DateTime(2026, 10, 21, 14, 30),
      );
      expect(
        SeedService.demoStart(DateTime(2026, 10, 21, 14, 10)),
        DateTime(2026, 10, 21, 14, 30),
      );
      expect(
        SeedService.demoStart(DateTime(2026, 10, 21, 14, 41)),
        DateTime(2026, 10, 21, 15, 15),
      );
    });

    test('base conservée (Android) : recalé au jour du lancement', () async {
      final b = await makeBackend();
      await loginAs(b, 'amira@gymflow.tn');
      await b.checkIn.validate(inesToday(b).bookingCode!);
      expect(inesToday(b).checkedInAt, isNotNull);
      // Lendemain, 9 h : le cours d'hier est replacé aujourd'hui.
      final tomorrow = DateTime(2026, 10, 1, 9);
      setNow(tomorrow);
      await SeedService(b).refreshDemoCourse();
      final c = b.courses.byId(SeedService.demoCourseId)!;
      expect(c.startAt, DateTime(2026, 10, 1, 9, 30));
      final r = inesToday(b);
      expect(r.status, ReservationStatus.confirmed);
      expect(r.checkedInAt, isNull);
      expect(r.attended, isNull);
      // Toujours valable : rien ne change au lancement suivant.
      await SeedService(b).refreshDemoCourse();
      expect(b.courses.byId(SeedService.demoCourseId)!.startAt, c.startAt);
    });
  });

  group('Validation de présence par code', () {
    test('bon code : présence enregistrée, horodatée et tracée', () async {
      final b = await makeBackend();
      final code = inesToday(b).bookingCode!;
      await loginAs(b, 'amira@gymflow.tn');
      final res = await b.checkIn.validate(code.toLowerCase());
      expect(res.alreadyDone, isFalse);
      expect(res.member!.id, 'u_ines');
      expect(res.message, contains('Présence validée'));
      final r = inesToday(b);
      expect(r.attended, isTrue);
      expect(r.checkedInAt, testNow);
      expect(r.checkedInBy, 'u_amira');
      final audit = b.auditRepo.where(
        (a) => a.action == CheckInService.auditAction && a.targetId == r.id,
      );
      expect(audit, hasLength(1));
      expect(audit.single.actorId, 'u_amira');
    });

    test('texte complet du QR collé : code extrait', () async {
      final b = await makeBackend();
      final r = inesToday(b);
      final text = b.reservationService.ticketQrText(r)!;
      expect(text, contains(r.bookingCode!));
      await loginAs(b, 'amira@gymflow.tn');
      // Collé dans un champ d'une ligne : les retours à la ligne disparaissent.
      final res = await b.checkIn.validate(text.replaceAll('\n', ''));
      expect(res.reservation.id, r.id);
      expect(res.alreadyDone, isFalse);
      final again = await b.checkIn.validate(text);
      expect(again.alreadyDone, isTrue);
    });

    test('déjà validé : message informatif, pas d\'erreur', () async {
      final b = await makeBackend();
      final code = inesToday(b).bookingCode!;
      await loginAs(b, 'amira@gymflow.tn');
      await b.checkIn.validate(code);
      setNow(testNow.add(const Duration(minutes: 7)));
      final again = await b.checkIn.validate(code);
      expect(again.alreadyDone, isTrue);
      expect(again.message, 'Présence déjà validée à 10:00');
      expect(
        b.auditRepo.where((a) => a.action == CheckInService.auditAction),
        hasLength(1),
      );
    });

    test('code inconnu ou illisible', () async {
      final b = await makeBackend();
      await loginAs(b, 'amira@gymflow.tn');
      expect(
        () => b.checkIn.validate('GF-ZZZZ-ZZZZ'),
        throwsMessage<NotFoundException>('Code inconnu.'),
      );
      expect(
        () => b.checkIn.validate('bonjour'),
        throwsMessage<ValidationException>(
          'Aucun code de réservation trouvé (format GF-XXXX-XXXX).',
        ),
      );
    });

    test('mauvais coach refusé, admin autorisé', () async {
      final b = await makeBackend();
      final code = inesToday(b).bookingCode!;
      await loginAs(b, 'sarra@gymflow.tn');
      expect(
        () => b.checkIn.validate(code),
        throwsMessage<PermissionDeniedException>(
          'Ce cours n\'est pas le vôtre.',
        ),
      );
      await b.auth.logout();
      await loginAs(b, 'admin@gymflow.tn');
      final res = await b.checkIn.validate(code);
      expect(res.alreadyDone, isFalse);
      expect(inesToday(b).checkedInBy, isNot('u_amira'));
    });

    test('un abonné ne peut pas valider', () async {
      final b = await makeBackend();
      final code = inesToday(b).bookingCode!;
      await loginAs(b, 'ines@gymflow.tn');
      expect(
        () => b.checkIn.validate(code),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('mauvais jour : « Ce cours n\'a pas lieu maintenant »', () async {
      final b = await makeBackend();
      final s1 = b.reservationService.activeFor('c_s1', 'u_ines')!;
      await loginAs(b, 'amira@gymflow.tn');
      expect(
        () => b.checkIn.validate(s1.bookingCode!),
        throwsA(
          isA<BusinessRuleException>().having(
            (e) => e.message,
            'message',
            startsWith('Ce cours n\'a pas lieu maintenant'),
          ),
        ),
      );
    });

    test('fenêtre : de 30 min avant le début à 30 min après la fin', () async {
      final b = await makeBackend();
      final code = inesToday(b).bookingCode!;
      final c = b.courses.byId(SeedService.demoCourseId)!;
      await loginAs(b, 'amira@gymflow.tn');
      setNow(c.startAt!.subtract(const Duration(minutes: 31)));
      expect(
        () => b.checkIn.validate(code),
        throwsA(isA<BusinessRuleException>()),
      );
      setNow(c.endAt!.add(const Duration(minutes: 31)));
      expect(
        () => b.checkIn.validate(code),
        throwsA(isA<BusinessRuleException>()),
      );
      setNow(c.endAt!.add(const Duration(minutes: 30)));
      expect((await b.checkIn.validate(code)).alreadyDone, isFalse);
    });

    test('réservation annulée : code invalide', () async {
      final b = await makeBackend();
      final s1 = b.reservationService.activeFor('c_s1', 'u_ines')!;
      await loginAs(b, 'ines@gymflow.tn');
      await b.reservationService.cancel(s1.id);
      await b.auth.logout();
      setNow(b.courses.byId('c_s1')!.startAt!);
      await loginAs(b, 'amira@gymflow.tn');
      expect(
        () => b.checkIn.validate(s1.bookingCode!),
        throwsMessage<BusinessRuleException>('Réservation annulée.'),
      );
    });

    test('liste d\'attente : refusé', () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      final w = await b.reservationService.book('c_s3', joinWaitlist: true);
      await b.auth.logout();
      setNow(b.courses.byId('c_s3')!.startAt!);
      await loginAs(b, 'sarra@gymflow.tn');
      expect(
        () => b.checkIn.validate(w.bookingCode!),
        throwsA(isA<BusinessRuleException>()),
      );
    });

    test('pointage manuel inchangé : toujours 15 min avant', () async {
      final b = await makeBackend();
      final r = inesToday(b);
      await loginAs(b, 'amira@gymflow.tn');
      // 10 h : début à 10 h 30. Le QR est accepté (fenêtre de 30 min) ...
      expect(
        () => b.reservationService.markAttendance(r.id, true),
        throwsMessage<BusinessRuleException>(
          'La présence se marque à partir de 15 min avant le cours.',
        ),
      );
      final res = await b.checkIn.validate(r.bookingCode!);
      expect(res.reservation.attended, isTrue);
    });
  });
}
