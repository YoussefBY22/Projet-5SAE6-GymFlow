import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/email_config.dart';
import 'package:gymflow/core/routes.dart';
import 'package:gymflow/screens/courses/ticket_screen.dart';
import 'package:gymflow/services/seed/seed_service.dart';
import 'package:gymflow/widgets/common.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';
import 'widget_helpers.dart';

void main() {
  testWidgets('ticket : détails et code en secours sans image QR', (
    tester,
  ) async {
    final b = await pumpApp(
      tester,
      route: Routes.home,
      loginEmail: 'ines@gymflow.tn',
    );
    final r = b.reservationService.activeFor(
      SeedService.demoCourseId,
      'u_ines',
    )!;
    await go(tester, Routes.ticket, r.id);
    // Le QR encode le texte lisible du ticket (pas le code seul).
    final qr = tester.widget<QrTicketImage>(find.byType(QrTicketImage));
    expect(qr.data, startsWith('GymFlow – Réservation ${r.bookingCode}'));
    expect(qr.data, contains('Présentez ce code au coach.'));
    expect(qr.code, r.bookingCode);
    // Le code reste affiché en grand sous le QR.
    expect(find.byKey(const ValueKey('ticket_code')), findsOneWidget);
    // Réseau désactivé dans les tests : le code s'affiche en grand.
    expect(find.byKey(const ValueKey('qr_fallback')), findsOneWidget);
    expect(find.text('QR indisponible'), findsOneWidget);
    expect(find.text(r.bookingCode!), findsWidgets);
    expect(find.text(SeedService.demoCourseTitle), findsOneWidget);
    expect(find.textContaining('Studio Zen'), findsOneWidget);
    expect(find.textContaining('Amira'), findsWidgets);
    expect(find.textContaining('Abonné : '), findsOneWidget);
    expect(find.byKey(const ValueKey('ticket_resend')), findsOneWidget);

    // Après validation par le coach : « ✅ Présence validée ».
    await b.auth.logout();
    await loginAs(b, 'amira@gymflow.tn');
    await b.checkIn.validate(r.bookingCode!);
    await b.auth.logout();
    await loginAs(b, 'ines@gymflow.tn');
    await go(tester, Routes.ticket, r.id);
    expect(find.textContaining('✅ Présence validée à'), findsOneWidget);
  });

  testWidgets('image QR en erreur : le code remplace le QR', (tester) async {
    NetImage.networkEnabled = true;
    addTearDown(() => NetImage.networkEnabled = false);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: QrTicketImage(code: 'GF-7K4M-2QXP')),
      ),
    );
    // Le moteur de test répond 400 à toute image réseau.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('qr_fallback')), findsOneWidget);
    expect(find.text('GF-7K4M-2QXP'), findsOneWidget);
  });

  testWidgets('coach : validation par code, confirmation puis suivant', (
    tester,
  ) async {
    final b = await pumpApp(
      tester,
      route: Routes.home,
      loginEmail: 'amira@gymflow.tn',
    );
    final r = b.reservationService.activeFor(
      SeedService.demoCourseId,
      'u_ines',
    )!;
    await go(tester, Routes.attendance, SeedService.demoCourseId);
    await tester.tap(find.byKey(const Key('open_checkin')));
    await settle(tester);

    // Code inconnu : message clair.
    await tester.enterText(
      find.byKey(const ValueKey('checkin_code')),
      'GF-ZZZZ-ZZZZ',
    );
    await tester.tap(find.byKey(const ValueKey('checkin_submit')));
    await settle(tester, 400);
    expect(find.text('Code inconnu.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('checkin_code')),
      r.bookingCode!.toLowerCase(),
    );
    await tester.tap(find.byKey(const ValueKey('checkin_submit')));
    await settle(tester, 400);
    expect(find.byKey(const ValueKey('checkin_confirmation')), findsOneWidget);
    expect(find.text(b.users.byId('u_ines')!.fullName), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('checkin_next')));
    await settle(tester, 400);
    expect(find.byKey(const ValueKey('checkin_code')), findsOneWidget);
    expect(b.reservations.byId(r.id)!.attended, isTrue);
  });

  testWidgets('abonné : réservation puis message sur l\'email', (tester) async {
    final b = await pumpApp(
      tester,
      route: Routes.home,
      loginEmail: 'nour@gymflow.tn',
      httpClient: MockClient((_) async => http.Response('OK', 200)),
    );
    b.email
      ..serviceId = 'service_x'
      ..templateId = 'template_x'
      ..publicKey = 'pk_x'
      ..demoRecipient = 'demo@example.com';
    await go(tester, Routes.courseDetail, 'c_s1');
    await tapVisible(tester, find.byKey(const Key('book_course')));
    await settle(tester, 600);
    expect(
      find.text('📧 Email de confirmation envoyé à demo@example.com'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('open_ticket')), findsOneWidget);
  });

  testWidgets('sans secrets.json : email envoyé via FormSubmit (message et '
      'ticket)', (tester) async {
    final calls = <http.Request>[];
    final b = await pumpApp(
      tester,
      route: Routes.home,
      loginEmail: 'nour@gymflow.tn',
      httpClient: MockClient((req) async {
        calls.add(req);
        return http.Response(
          '{"success":"true","message":"The form was submitted successfully."}',
          200,
        );
      }),
    );
    expect(b.email.emailJsConfigured, isFalse);
    await go(tester, Routes.courseDetail, 'c_s1');
    await tapVisible(tester, find.byKey(const Key('book_course')));
    await settle(tester, 600);
    expect(
      find.text(
        '📧 Email de confirmation envoyé à ${EmailConfig.formSubmitRecipient}',
      ),
      findsOneWidget,
    );
    expect(calls.single.url.host, 'formsubmit.co');
    // La place est bien confirmée (pas une liste d'attente).
    final r = b.reservationService.activeFor('c_s1', 'u_nour')!;
    expect(r.status.name, 'confirmed');
    await go(tester, Routes.ticket, r.id);
    final status = tester.widget<Text>(
      find.byKey(const ValueKey('ticket_email_status')),
    );
    expect(status.data, contains(EmailConfig.formSubmitRecipient));
  });

  testWidgets(
    'web sur une origine non activée : raison claire dans le ticket',
    (tester) async {
      final b = await pumpApp(
        tester,
        route: Routes.home,
        loginEmail: 'nour@gymflow.tn',
      );
      b.email.webOrigin = 'https://youssefby22.github.io';
      await go(tester, Routes.courseDetail, 'c_s1');
      await tapVisible(tester, find.byKey(const Key('book_course')));
      await settle(tester, 600);
      expect(
        find.textContaining('FormSubmit : origine non activée'),
        findsOneWidget,
      );
      final r = b.reservationService.activeFor('c_s1', 'u_nour')!;
      await go(tester, Routes.ticket, r.id);
      final status = tester.widget<Text>(
        find.byKey(const ValueKey('ticket_email_status')),
      );
      expect(status.data, contains('origine non activée'));
      expect(status.data, contains('--web-port 8080'));
    },
  );

  testWidgets('EmailJS refuse (403) : raison lisible dans le ticket', (
    tester,
  ) async {
    final b = await pumpApp(
      tester,
      route: Routes.home,
      loginEmail: 'nour@gymflow.tn',
      httpClient: MockClient(
        (_) async => http.Response(
          'API calls are disabled for non-browser applications',
          403,
        ),
      ),
    );
    b.email
      ..serviceId = 'service_x'
      ..templateId = 'template_x'
      ..publicKey = 'pk_secret_x';
    await go(tester, Routes.courseDetail, 'c_s1');
    await tapVisible(tester, find.byKey(const Key('book_course')));
    await settle(tester, 600);
    expect(
      find.textContaining('Email non envoyé : accès refusé par EmailJS (403)'),
      findsOneWidget,
    );
    final r = b.reservationService.activeFor('c_s1', 'u_nour')!;
    await go(tester, Routes.ticket, r.id);
    final status = tester.widget<Text>(
      find.byKey(const ValueKey('ticket_email_status')),
    );
    expect(status.data, contains('non-browser applications'));
    expect(status.data, isNot(contains('pk_secret_x')));
  });
}
