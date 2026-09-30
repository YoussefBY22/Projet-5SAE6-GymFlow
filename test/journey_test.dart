import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/routes.dart';

import 'widget_helpers.dart';

/// Coche la série [s] de l'exercice [e] dans le lecteur de séance.
Future<void> _checkSet(WidgetTester tester, int e, int s) async {
  final row = find.byKey(Key('set_${e}_$s'));
  await tester.ensureVisible(row);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(
    find.descendant(of: row, matching: find.byIcon(Icons.check)),
  );
  await settle(tester, 500);
}

void main() {
  testWidgets('lecteur de séance : séries, minuteur de repos, pause', (
    tester,
  ) async {
    await pumpApp(tester, route: Routes.home, loginEmail: 'nour@gymflow.tn');
    await go(tester, Routes.player, 'w_fb_a');
    expect(find.text('EXERCICE 1 / 6'), findsOneWidget);
    expect(find.text('Squat goblet'), findsOneWidget);

    // Valider une série déclenche le minuteur de repos animé (90 s).
    await _checkSet(tester, 0, 0);
    expect(find.byKey(const Key('rest_timer')), findsOneWidget);
    expect(find.text('01:30'), findsOneWidget);
    await settle(tester, 5000);
    expect(find.textContaining('01:2'), findsOneWidget);

    // Pause : le minuteur s'arrête.
    await tester.tap(find.byKey(const Key('pause_button')));
    await settle(tester, 300);
    final frozen = tester.widget<Text>(find.byKey(const Key('elapsed'))).data;
    await settle(tester, 3000);
    expect(find.text('En pause'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('elapsed'))).data, frozen);
    await tester.tap(find.text('En pause'));
    await settle(tester, 300);

    // « Passer » masque le minuteur.
    await tester.tap(find.byKey(const Key('skip_rest')));
    await settle(tester, 600);
    expect(find.byKey(const Key('rest_timer')), findsNothing);

    // Saisie invalide refusée.
    final loadField = find
        .descendant(
          of: find.byKey(const Key('set_0_1')),
          matching: find.byType(TextField),
        )
        .first;
    await tester.enterText(loadField, '900');
    await _checkSet(tester, 0, 1);
    expect(find.textContaining('Vérifiez les répétitions'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets(
    'parcours complet : connexion abonnée → workout → séance → récapitulatif → fil',
    (tester) async {
      final b = await pumpApp(tester);

      // 1. Connexion de la première abonnée (aucune séance).
      expect(b.sessions.where((s) => s.userId == 'u_nour'), isEmpty);
      await tester.enterText(
        find.byKey(const Key('login_email')),
        'nour@gymflow.tn',
      );
      await tester.enterText(
        find.byKey(const Key('login_password')),
        'Membre2026!',
      );
      await tester.tap(find.byKey(const Key('login_submit')));
      await settle(tester, 2000);
      expect(find.text('Bonjour, Nour !'), findsOneWidget);

      // 2. Onglet Entraînement → Workouts → Full Body A.
      await tester.tap(find.text('Entraînement').last);
      await settle(tester);
      await tester.tap(find.text('Workouts'));
      await settle(tester);
      await tapVisible(tester, find.text('Full Body A — Débutant'));
      await settle(tester);
      expect(find.text('Déroulé de la séance'), findsOneWidget);

      // 3. Lancer la séance.
      await tester.tap(find.byKey(const Key('start_session')));
      await settle(tester);
      expect(find.text('EXERCICE 1 / 6'), findsOneWidget);

      // 4. Réaliser les 3 séries du premier exercice avec une charge.
      for (var s = 0; s < 3; s++) {
        final load = find
            .descendant(
              of: find.byKey(Key('set_0_$s')),
              matching: find.byType(TextField),
            )
            .first;
        await tester.ensureVisible(load);
        await tester.enterText(load, '12');
        await _checkSet(tester, 0, s);
        if (find.byKey(const Key('skip_rest')).evaluate().isNotEmpty) {
          await tester.tap(find.byKey(const Key('skip_rest')));
          await settle(tester, 500);
        }
      }

      // 5. Exercice suivant, une série, puis aller au dernier et terminer.
      await tester.tap(find.byKey(const Key('next_exercise')));
      await settle(tester, 800);
      expect(find.text('EXERCICE 2 / 6'), findsOneWidget);
      await _checkSet(tester, 1, 0);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('next_exercise')));
        await settle(tester, 600);
      }
      expect(find.text('EXERCICE 6 / 6'), findsOneWidget);
      await _checkSet(tester, 5, 0); // gainage (au temps)
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byKey(const Key('finish_session')));
      await settle(tester, 600);
      await tester.tap(find.text('Terminer'));
      await settle(tester, 2500);

      // 6. Récapitulatif avec record battu.
      expect(find.byKey(const Key('summary_title')), findsOneWidget);
      expect(find.text('Nouveaux records personnels'), findsOneWidget);
      final log = b.sessions.where((s) => s.userId == 'u_nour').single;
      expect(log.totalSets, 5);
      expect(
        log.totalVolume,
        3 * 12 * 12 + 10 * b.sessions.byId(log.id)!.sets[3].loadKg,
      );
      expect(log.prCount, greaterThanOrEqualTo(1));

      // 7. Retour à l'accueil : la séance apparaît dans le fil et l'objectif.
      await tapVisible(tester, find.byKey(const Key('summary_home')));
      await settle(tester, 2000);
      expect(find.text('Bonjour, Nour !'), findsOneWidget);
      expect(b.progress.sessionsThisWeek('u_nour'), 1);
      await tapVisible(tester, find.text('Vous'));
      expect(find.text('Détail des séries'), findsOneWidget);
    },
  );
}
