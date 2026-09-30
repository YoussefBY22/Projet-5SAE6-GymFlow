import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/widget_helpers.dart';

/// Test d'intégration sur téléphone Android (USB) :
/// `flutter test integration_test/app_test.dart -d <id_appareil>`
/// Parcours : connexion abonnée → workout → séance → récapitulatif.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('parcours abonnée de bout en bout', (tester) async {
    final b = await pumpApp(tester);
    await tester.enterText(
      find.byKey(const Key('login_email')),
      'nour@gymflow.tn',
    );
    await tester.enterText(
      find.byKey(const Key('login_password')),
      'Membre2026!',
    );
    await tester.tap(find.byKey(const Key('login_submit')));
    await settle(tester, 2500);
    await tester.tap(find.text('Entraînement').last);
    await settle(tester);
    await tester.tap(find.text('Workouts'));
    await settle(tester);
    await tapVisible(tester, find.text('Full Body A — Débutant'));
    await tester.tap(find.byKey(const Key('start_session')));
    await settle(tester);
    final row = find.byKey(const Key('set_0_0'));
    await tester.ensureVisible(row);
    await tester.tap(
      find.descendant(of: row, matching: find.byIcon(Icons.check)),
    );
    await settle(tester, 800);
    await tester.tap(find.byKey(const Key('skip_rest')));
    await settle(tester, 800);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const Key('next_exercise')));
      await settle(tester, 600);
    }
    await tester.tap(find.byKey(const Key('finish_session')));
    await settle(tester, 600);
    await tester.tap(find.text('Terminer'));
    await settle(tester, 2500);
    expect(find.byKey(const Key('summary_title')), findsOneWidget);
    expect(b.sessions.where((s) => s.userId == 'u_nour').length, 1);
  });
}
