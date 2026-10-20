import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/routes.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'widget_helpers.dart';

/// Parcours de démo : l'abonné note un cours avec un commentaire et voit
/// tout de suite le ton détecté ; le coach le retrouve sur le cours.
void main() {
  testWidgets('abonné : badge de sentiment sur son avis après l\'envoi', (
    tester,
  ) async {
    await pumpApp(tester, route: Routes.home, loginEmail: 'ines@gymflow.tn');
    await go(tester, Routes.courseDetail, 'c_d1');
    final edit = find.byTooltip('Modifier');
    await tester.scrollUntilVisible(
      edit,
      200,
      scrollable: mainScrollable(tester),
    );
    await tester.tap(edit);
    await settle(tester, 600);
    await tester.enterText(
      find.widgetWithText(TextField, 'Commentaire (facultatif)'),
      'Cours génial, super ambiance !',
    );
    await tester.tap(find.text('Envoyer'));
    await settle(tester);
    expect(find.text('« Cours génial, super ambiance ! »'), findsOneWidget);
    expect(find.text('Positif · local'), findsOneWidget);
    expect(find.text('😊'), findsOneWidget);
  });

  testWidgets('coach : avis du cours avec leur ton', (tester) async {
    await pumpApp(tester, route: Routes.home, loginEmail: 'amira@gymflow.tn');
    await go(tester, Routes.courseDetail, 'c_d1');
    final header = find.textContaining('Avis des participants');
    await tester.scrollUntilVisible(
      header,
      300,
      scrollable: mainScrollable(tester),
    );
    expect(header, findsOneWidget);
    expect(find.textContaining('Positif'), findsWidgets);
  });

  // Tableau de bord ouvert pendant qu'une analyse se termine en
  // arrière-plan : la carte doit se recalculer sans recharger la page.
  for (final (email, coachView) in [
    ('admin@gymflow.tn', false),
    ('sarra@gymflow.tn', true),
  ]) {
    testWidgets('score de satisfaction mis à jour en direct ($email)', (
      tester,
    ) async {
      final answer = Completer<http.Response>();
      final b = await pumpApp(
        tester,
        route: Routes.home,
        loginEmail: email,
        httpClient: MockClient((_) => answer.future),
      );
      b.sentiment
        ..geminiKey = 'k'
        ..retryDelay = Duration.zero;
      final spinning = find.textContaining('Spinning Endurance ·');
      await tester.scrollUntilVisible(
        spinning,
        300,
        scrollable: mainScrollable(tester),
      );
      expect(find.textContaining('100 % (1 avis)'), findsWidgets);
      expect(find.textContaining('Boxe Cardio ·'), findsNothing);

      // Avis d'Ines sur Spinning (Sarra) et Boxe Cardio, analysés en
      // arrière-plan pendant que l'écran est affiché.
      final ids = <String>[];
      for (final c in ['c_d3', 'c_d6']) {
        final r = b.reservationService.latestFor(c, 'u_ines')!;
        await b.reservations.save(r.copyWith(comment: 'Bof $c'));
        ids.add(r.id);
      }
      final runs = [for (final id in ids) b.sentiment.analyzeReview(id)];
      answer.complete(
        http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '{"label":"Negative","score":0.8}'},
                  ],
                },
              },
            ],
          }),
          200,
        ),
      );
      await tester.runAsync(() => Future.wait(runs));
      await settle(tester, 600);
      expect(find.textContaining('Spinning Endurance ·'), findsOneWidget);
      expect(find.textContaining('50 % (2 avis)'), findsWidgets);
      expect(find.textContaining('Boxe Cardio ·'), findsOneWidget);
      if (coachView) {
        expect(find.text('Par coach'), findsNothing);
      }

      final refresh = find.byKey(const ValueKey('satisfaction_refresh'));
      await tapVisible(tester, refresh);
      expect(find.text('Score de satisfaction actualisé.'), findsOneWidget);
    });
  }

  testWidgets('avis analysé localement : bouton « Réanalyser avec l\'IA »', (
    tester,
  ) async {
    var aiUp = false;
    final b = await pumpApp(
      tester,
      route: Routes.home,
      loginEmail: 'ines@gymflow.tn',
      httpClient: MockClient(
        (_) async => aiUp
            ? http.Response(
                jsonEncode({
                  'candidates': [
                    {
                      'content': {
                        'parts': [
                          {'text': '{"label":"Neutral","score":0.7}'},
                        ],
                      },
                    },
                  ],
                }),
                200,
              )
            : http.Response('{"error":"quota"}', 429),
      ),
    );
    b.sentiment
      ..geminiKey = 'k'
      ..retryDelay = Duration.zero;
    final r = b.reservationService.latestFor('c_d1', 'u_ines')!;
    await tester.runAsync(() async {
      await b.reservationService.rate(
        r.id,
        3,
        comment: 'cv mais manque de dynamisme dans le cours',
      );
      await b.reservationService.lastAnalysis;
    });
    await go(tester, Routes.courseDetail, 'c_d1');
    final button = find.byKey(ValueKey('reanalyze_${r.id}'));
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: mainScrollable(tester),
    );
    expect(find.textContaining('· local'), findsOneWidget);
    final badge = tester.widget<Tooltip>(
      find.ancestor(
        of: find.textContaining('· local'),
        matching: find.byType(Tooltip),
      ),
    );
    expect(badge.message, contains('quota dépassé (429)'));

    aiUp = true;
    await tapVisible(tester, button);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settle(tester, 600);
    expect(find.text('Neutre · IA'), findsOneWidget);
    expect(button, findsNothing);
    expect(find.text('Analyse IA : Neutre.'), findsOneWidget);
  });
}
