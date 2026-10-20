import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/config.dart';
import 'package:gymflow/core/email_config.dart';
import 'package:gymflow/core/errors.dart';
import 'package:gymflow/models/course.dart';
import 'package:gymflow/models/enums.dart';
import 'package:gymflow/services/backend.dart';
import 'package:gymflow/services/email_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

/// Faux serveur EmailJS : enregistre les requêtes.
class FakeEmailJs {
  FakeEmailJs(this.handler);
  Future<http.Response> Function(http.Request) handler;
  final List<http.Request> requests = [];
  late final MockClient client = MockClient((req) {
    requests.add(req);
    return handler(req);
  });

  Map<String, dynamic> body([int i = -1]) =>
      jsonDecode((i < 0 ? requests.last : requests[i]).body)
          as Map<String, dynamic>;

  static Future<http.Response> ok() async => http.Response('OK', 200);
}

const _service = 'service_test42';
const _template = 'template_test42';
const _publicKey = 'pk_TEST_secret_42';

Future<(Backend, FakeEmailJs)> backendWithEmail(
  Future<http.Response> Function(http.Request) handler, {
  bool keys = true,
  String demo = '',
}) async {
  final fake = FakeEmailJs(handler);
  final b = await makeBackend(httpClient: fake.client);
  b.email
    ..serviceId = keys ? _service : ''
    ..templateId = keys ? _template : ''
    ..publicKey = keys ? _publicKey : ''
    ..demoRecipient = demo
    ..retryDelay = Duration.zero;
  return (b, fake);
}

/// Réservation confirmée de Nour sur `c_s1`, email attendu.
Future<Reservation> bookNour(Backend b) async {
  await loginAs(b, 'nour@gymflow.tn');
  final r = await b.reservationService.book('c_s1');
  await b.email.lastSend;
  return b.reservations.byId(r.id)!;
}

void expectNoSecret(String? text) {
  for (final s in [_service, _template, _publicKey]) {
    expect(text ?? '', isNot(contains(s)), reason: text);
  }
}

void main() {
  group('EmailService : envoi EmailJS', () {
    test('succès « OK » : requête conforme, statut enregistré', () async {
      final (b, fake) = await backendWithEmail((_) => FakeEmailJs.ok());
      final r = await bookNour(b);
      expect(fake.requests, hasLength(1));
      final req = fake.requests.single;
      expect(req.method, 'POST');
      expect(req.url.toString(), AppConfig.emailJsUrl);
      expect(req.headers['Content-Type'], startsWith('application/json'));
      final body = fake.body();
      expect(body['service_id'], _service);
      expect(body['template_id'], _template);
      expect(body['user_id'], _publicKey);
      final p = body['template_params'] as Map<String, dynamic>;
      expect(p.keys.toSet(), {
        'to_email',
        'to_name',
        'course_title',
        'course_date',
        'coach_name',
        'booking_code',
        'qr_data',
        'booking_code_text',
      });
      final course = b.courses.byId('c_s1')!;
      expect(p['to_email'], 'nour@gymflow.tn');
      expect(p['to_name'], b.users.byId('u_nour')!.fullName);
      expect(p['course_title'], course.title);
      expect(p['coach_name'], b.users.byId(course.coachId)!.fullName);
      // booking_code = texte du ticket encodé pour l'URL du QR du modèle.
      final qrText = b.reservationService.ticketQrText(r)!;
      expect(p['booking_code'], Uri.encodeComponent(qrText));
      expect(p['qr_data'], p['booking_code']);
      expect(p['booking_code_text'], r.bookingCode);
      expect(qrText, startsWith('GymFlow – Réservation ${r.bookingCode}'));
      expect(qrText, contains(course.title));
      // Aucune donnée de l'abonné dans le QR (api.qrserver.com la verrait).
      expect(qrText, isNot(contains('Nour')));
      expect(qrText, isNot(contains('@')));
      // URL finale du modèle (…?size=200x200&data={{booking_code}}) valide.
      final url = Uri.parse(
        'https://api.qrserver.com/v1/create-qr-code/?size=200x200'
        '&data=${p['booking_code']}',
      );
      expect(url.queryParameters['data'], qrText);
      expect(url.queryParameters['size'], '200x200');
      expect(p['booking_code'], matches(RegExp(r'^[A-Za-z0-9%._~-]+$')));
      expect(p['course_date'], EmailService.formatDate(course.startAt!));

      expect(r.email!.status, EmailStatus.sent);
      expect(r.email!.to, 'nour@gymflow.tn');
      expect(r.email!.sentAt, isNotNull);
      expect(r.email!.error, isNull);
    });

    test('date au format français « mardi 21 octobre à 18h00 »', () async {
      await makeBackend();
      expect(
        EmailService.formatDate(DateTime(2026, 10, 21, 18)),
        'mercredi 21 octobre à 18h00',
      );
      expect(
        EmailService.formatDate(DateTime(2026, 10, 20, 7, 30)),
        'mardi 20 octobre à 07h30',
      );
    });

    test('erreur 4xx : pas de nouvel essai, raison sans clé', () async {
      final (b, fake) = await backendWithEmail(
        (_) async => http.Response(
          'The Public Key is invalid: $_publicKey (service $_service)',
          400,
        ),
      );
      final r = await bookNour(b);
      expect(fake.requests, hasLength(1));
      expect(r.status, ReservationStatus.confirmed);
      expect(r.email!.status, EmailStatus.failed);
      expect(r.email!.error, contains('400'));
      expect(r.email!.error, contains('Public Key is invalid'));
      expectNoSecret(r.email!.error);
      expectNoSecret(jsonEncode(r.toJson()['email']));
    });

    test('5xx puis succès au nouvel essai', () async {
      var n = 0;
      final (b, fake) = await backendWithEmail(
        (_) async => ++n == 1
            ? http.Response('Internal error', 502)
            : http.Response('OK', 200),
      );
      final r = await bookNour(b);
      expect(fake.requests, hasLength(2));
      expect(r.email!.status, EmailStatus.sent);
    });

    test('5xx deux fois : échec après un seul nouvel essai', () async {
      final (b, fake) = await backendWithEmail(
        (_) async => http.Response('down', 503),
      );
      final r = await bookNour(b);
      expect(fake.requests, hasLength(2));
      expect(r.email!.status, EmailStatus.failed);
      expect(r.email!.error, contains('indisponible (503)'));
    });

    test('réseau coupé : la réservation réussit quand même', () async {
      final (b, fake) = await backendWithEmail(
        (_) => throw const SocketException('offline'),
      );
      final r = await bookNour(b);
      expect(r.status, ReservationStatus.confirmed);
      expect(fake.requests, hasLength(2));
      expect(r.email!.status, EmailStatus.failed);
      expect(r.email!.error, 'réseau indisponible');
    });

    testWidgets('délai de 10 s dépassé, nouvel essai, puis échec', (
      tester,
    ) async {
      late Backend b;
      late FakeEmailJs fake;
      await tester.runAsync(() async {
        (b, fake) = await backendWithEmail(
          (_) => Completer<http.Response>().future,
        );
        await loginAs(b, 'nour@gymflow.tn');
      });
      Reservation? booked;
      unawaited(b.reservationService.book('c_s1').then((x) => booked = x));
      await tester.pump();
      final r = booked!;
      // La réservation est déjà confirmée, l'email est en cours.
      expect(r.status, ReservationStatus.confirmed);
      expect(b.email.isSending(r.id), isTrue);
      for (var s = 0; s < 22; s++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(fake.requests, hasLength(2));
      final saved = b.reservations.byId(r.id)!;
      expect(saved.email!.status, EmailStatus.failed);
      expect(saved.email!.error, 'délai de 10 s dépassé');
      expect(b.email.isSending(r.id), isFalse);
    });

    test('destinataire de démo : adresse remplacée, nom conservé', () async {
      final (b, fake) = await backendWithEmail(
        (_) => FakeEmailJs.ok(),
        demo: 'demo.soutenance@example.com',
      );
      final r = await bookNour(b);
      final p = fake.body()['template_params'] as Map<String, dynamic>;
      expect(p['to_email'], 'demo.soutenance@example.com');
      expect(p['to_name'], b.users.byId('u_nour')!.fullName);
      expect(r.email!.to, 'demo.soutenance@example.com');
    });
  });

  group('Quand envoyer', () {
    test('liste d\'attente : aucun email', () async {
      final (b, fake) = await backendWithEmail((_) => FakeEmailJs.ok());
      await loginAs(b, 'nour@gymflow.tn');
      final w = await b.reservationService.book('c_s3', joinWaitlist: true);
      await b.email.lastSend;
      expect(w.status, ReservationStatus.waitlisted);
      expect(fake.requests, isEmpty);
      expect(b.reservations.byId(w.id)!.email, isNull);
    });

    test('promotion depuis la liste d\'attente : email envoyé', () async {
      final (b, fake) = await backendWithEmail((_) => FakeEmailJs.ok());
      await loginAs(b, 'nour@gymflow.tn');
      final w = await b.reservationService.book('c_s3', joinWaitlist: true);
      await b.auth.logout();
      // Une abonnée confirmée libère sa place.
      final leila = b.reservationService.activeFor('c_s3', 'u_leila')!;
      await loginAs(b, 'leila@gymflow.tn');
      await b.reservationService.cancel(leila.id);
      await b.email.lastSend;
      final promoted = b.reservations.byId(w.id)!;
      expect(promoted.status, ReservationStatus.confirmed);
      expect(fake.requests, hasLength(1));
      final p = fake.body()['template_params'] as Map<String, dynamic>;
      expect(p['to_email'], 'nour@gymflow.tn');
      expect(p['booking_code_text'], promoted.bookingCode);
      expect(
        Uri.decodeComponent(p['booking_code'] as String),
        contains(promoted.bookingCode!),
      );
      expect(promoted.email!.status, EmailStatus.sent);
    });

    test('jeu de démo : aucun email, aucun appel', () async {
      final (b, fake) = await backendWithEmail((_) => FakeEmailJs.ok());
      expect(fake.requests, isEmpty);
      expect(b.reservations.all.every((r) => r.email == null), isTrue);
    });
  });

  group('Renvoyer l\'email', () {
    test('limité à une fois par minute', () async {
      final (b, fake) = await backendWithEmail((_) => FakeEmailJs.ok());
      final r = await bookNour(b);
      expect(
        () => b.email.resend(r.id),
        throwsA(
          isA<BusinessRuleException>().having(
            (e) => e.message,
            'message',
            contains('Patientez'),
          ),
        ),
      );
      setNow(testNow.add(const Duration(seconds: 61)));
      final d = await b.email.resend(r.id);
      expect(d!.status, EmailStatus.sent);
      expect(fake.requests, hasLength(2));
    });

    test('réservé à l\'abonné, au coach du cours et à l\'admin', () async {
      final (b, _) = await backendWithEmail((_) => FakeEmailJs.ok());
      final r = await bookNour(b);
      await b.auth.logout();
      setNow(testNow.add(const Duration(minutes: 5)));
      await loginAs(b, 'leila@gymflow.tn');
      expect(
        () => b.email.resend(r.id),
        throwsA(isA<PermissionDeniedException>()),
      );
      await b.auth.logout();
      await loginAs(b, 'amira@gymflow.tn'); // coach de c_s1
      expect((await b.email.resend(r.id))!.status, EmailStatus.sent);
    });
  });

  group('FormSubmit (fournisseur par défaut, sans clé)', () {
    Future<http.Response> fsOk() async => http.Response(
      '{"success":"true","message":"The form was submitted successfully."}',
      200,
      headers: {'content-type': 'text/html; charset=UTF-8'},
    );

    test(
      'sans clés EmailJS : FormSubmit, requête et contenu conformes',
      () async {
        final (b, fake) = await backendWithEmail((_) => fsOk(), keys: false);
        expect(b.email.provider, EmailProvider.formSubmit);
        final r = await bookNour(b);
        expect(fake.requests, hasLength(1));
        final req = fake.requests.single;
        expect(
          req.url.toString(),
          'https://formsubmit.co/ajax/${EmailConfig.formSubmitRecipient}',
        );
        expect(req.method, 'POST');
        expect(req.headers['Content-Type'], startsWith('application/json'));
        expect(req.headers['Accept'], 'application/json');
        // Android / tests (hors web) : origine activée annoncée.
        expect(req.headers['Origin'], 'http://localhost:8080');
        expect(req.headers['Referer'], 'http://localhost:8080/');

        final body = fake.body();
        final c = b.courses.byId('c_s1')!;
        expect(body['_subject'], '✅ Réservation confirmée – ${c.title}');
        expect(body['_template'], 'table');
        expect(body['_captcha'], 'false');
        expect(body['Abonné'], b.users.byId('u_nour')!.fullName);
        expect(body['Cours'], c.title);
        expect(body['Date'], EmailService.formatDate(c.startAt!));
        expect(body['Coach'], b.users.byId(c.coachId)!.fullName);
        expect(body['Salle'], c.room);
        expect(body['Code de réservation'], r.bookingCode);
        final qr = Uri.parse(body['QR code (image)'] as String);
        expect(qr.host, 'api.qrserver.com');
        expect(
          qr.queryParameters['data'],
          b.reservationService.ticketQrText(r),
        );

        expect(r.email!.status, EmailStatus.sent);
        expect(r.email!.to, EmailConfig.formSubmitRecipient);
      },
    );

    test('origine non activée (réponse FormSubmit) : raison claire', () async {
      final (b, fake) = await backendWithEmail(
        (_) async => http.Response(
          '{"success":"false","message":"This form needs Activation. '
          'We\'ve sent you an email containing an \'Activate Form\' link."}',
          200,
        ),
        keys: false,
      );
      final r = await bookNour(b);
      expect(fake.requests, hasLength(1), reason: 'pas de nouvel essai');
      expect(r.status, ReservationStatus.confirmed);
      expect(r.email!.status, EmailStatus.failed);
      expect(r.email!.error, startsWith('FormSubmit : origine non activée'));
    });

    test('web sur une autre origine : aucun appel, raison claire', () async {
      final (b, fake) = await backendWithEmail((_) => fsOk(), keys: false);
      b.email.webOrigin = 'http://localhost:54321';
      final r = await bookNour(b);
      expect(fake.requests, isEmpty);
      expect(r.email!.status, EmailStatus.failed);
      expect(
        r.email!.error,
        EmailService.originNotActivated('http://localhost:54321'),
      );
      expect(r.email!.error, contains('--web-port 8080'));
    });

    test(
      'web sur l\'origine activée : envoi, en-têtes laissés au navigateur',
      () async {
        final (b, fake) = await backendWithEmail((_) => fsOk(), keys: false);
        b.email.webOrigin = 'http://localhost:8080';
        final r = await bookNour(b);
        expect(fake.requests, hasLength(1));
        expect(fake.requests.single.headers.containsKey('Referer'), isFalse);
        expect(r.email!.status, EmailStatus.sent);
      },
    );

    test(
      '5xx puis succès ; réponse illisible = échec sans nouvel essai',
      () async {
        var n = 0;
        final (b, fake) = await backendWithEmail(
          (_) async => ++n == 1 ? http.Response('busy', 502) : fsOk(),
          keys: false,
        );
        final r = await bookNour(b);
        expect(fake.requests, hasLength(2));
        expect(r.email!.status, EmailStatus.sent);

        expect(
          EmailService.parseFormSubmit(200, '<html>oops</html>').error,
          'FormSubmit : réponse illisible',
        );
        expect(
          EmailService.parseFormSubmit(200, '<html>oops</html>').retry,
          isFalse,
        );
        expect(
          EmailService.parseFormSubmit(
            200,
            '{"success":"false","message":"Make sure you open this page '
            'through a web server"}',
          ).error,
          'FormSubmit : origine absente (en-tête Referer manquant)',
        );
        expect(
          EmailService.parseFormSubmit(200, '{"success":true}').error,
          isNull,
        );
      },
    );

    test('clés EmailJS présentes : EmailJS utilisé à la place', () async {
      final (b, fake) = await backendWithEmail((_) => FakeEmailJs.ok());
      expect(b.email.provider, EmailProvider.emailJs);
      await bookNour(b);
      expect(fake.requests.single.url.host, 'api.emailjs.com');
    });

    test('renvoi limité aussi avec FormSubmit', () async {
      final (b, fake) = await backendWithEmail((_) => fsOk(), keys: false);
      final r = await bookNour(b);
      expect(() => b.email.resend(r.id), throwsA(isA<BusinessRuleException>()));
      setNow(testNow.add(const Duration(minutes: 2)));
      final d = await b.email.resend(r.id);
      expect(d!.status, EmailStatus.sent);
      expect(fake.requests, hasLength(2));
    });
  });
}
