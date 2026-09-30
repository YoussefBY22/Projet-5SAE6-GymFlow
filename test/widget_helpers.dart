import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/app.dart';
import 'package:gymflow/core/routes.dart';
import 'package:gymflow/services/backend.dart';
import 'package:gymflow/widgets/common.dart';

import 'helpers.dart';

/// Lance l'application sur un écran de téléphone (360 × 780 dp) avec le
/// backend de démonstration en mémoire.
Future<Backend> pumpApp(
  WidgetTester tester, {
  String route = Routes.login,
  String? loginEmail,
}) async {
  NetImage.networkEnabled = false;
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final b = await makeBackend();
  if (loginEmail != null) await loginAs(b, loginEmail);
  await tester.pumpWidget(GymFlowApp(initialRoute: route));
  await settle(tester);
  return b;
}

/// Laisse passer les animations sans exiger un état totalement stable
/// (les minuteurs périodiques du lecteur empêchent `pumpAndSettle`).
Future<void> settle(WidgetTester tester, [int ms = 1200]) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Navigation par route nommée depuis le test.
Future<void> go(WidgetTester tester, String route, [Object? argument]) async {
  GymFlowApp.navigatorKey.currentState!.pushNamed(route, arguments: argument);
  await settle(tester);
}

/// Liste verticale principale de l'écran affiché (la plus grande zone
/// défilante visible — exclut les champs de texte multi-lignes).
Finder mainScrollable(WidgetTester tester) {
  final candidates = find
      .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      )
      .hitTestable();
  Element? best;
  var bestArea = 0.0;
  for (final e in candidates.evaluate()) {
    final box = e.renderObject as RenderBox?;
    if (box == null || !box.hasSize) continue;
    final area = box.size.width * box.size.height;
    if (area > bestArea) {
      bestArea = area;
      best = e;
    }
  }
  final target = best;
  return find.byElementPredicate((e) => e == target);
}

/// Fait défiler jusqu'à l'élément puis le touche.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    // Liste paresseuse : on fait défiler jusqu'à construire l'élément.
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: mainScrollable(tester),
    );
  }
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder);
  await settle(tester, 600);
}
