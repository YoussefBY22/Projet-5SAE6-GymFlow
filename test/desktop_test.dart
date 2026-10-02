import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/app.dart';
import 'package:gymflow/core/routes.dart';
import 'package:gymflow/widgets/common.dart';

import 'helpers.dart';
import 'widget_helpers.dart';

/// Version ordinateur : navigation latérale, contenu centré, aucun
/// débordement sur les écrans principaux et les nouveaux écrans.
void main() {
  Future<void> pumpDesktop(
    WidgetTester tester, {
    required String email,
    Size size = const Size(1440, 900),
  }) async {
    NetImage.networkEnabled = false;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final b = await makeBackend();
    await loginAs(b, email);
    await b.privacy.completeIntro();
    await tester.pumpWidget(const GymFlowApp(initialRoute: Routes.home));
    await settle(tester);
  }

  testWidgets('abonné sur ordinateur : barre latérale, accueil 2 colonnes', (
    tester,
  ) async {
    await pumpDesktop(tester, email: 'ahmed@gymflow.tn');
    expect(find.byKey(const Key('side_rail')), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byKey(const Key('community_card')), findsOneWidget);
    expect(find.byKey(const Key('feed_toggle')), findsOneWidget);
    // La carte communauté est dans la colonne de droite.
    final card = tester.getTopLeft(find.byKey(const Key('community_card')));
    expect(card.dx, greaterThan(700));

    for (final tab in ['Entraînement', 'Cours', 'Boutique', 'Profil']) {
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('side_rail')),
          matching: find.text(tab),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull, reason: tab);
    }
    for (final route in [Routes.community, Routes.privacy, Routes.legal]) {
      await go(tester, route);
      expect(tester.takeException(), isNull, reason: route);
      GymFlowApp.navigatorKey.currentState!.pop();
      await settle(tester);
    }
    await go(tester, Routes.member, 'u_ines');
    expect(find.text('Instagram'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablette (1000 px) : barre latérale compacte', (tester) async {
    await pumpDesktop(
      tester,
      email: 'admin@gymflow.tn',
      size: const Size(1000, 760),
    );
    final rail = tester.widget<NavigationRail>(
      find.byKey(const Key('side_rail')),
    );
    expect(rail.extended, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('présentation sur ordinateur : flèche ↓ et bouton Suivant', (
    tester,
  ) async {
    NetImage.networkEnabled = false;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final b = await makeBackend();
    await loginAs(b, 'nour@gymflow.tn');
    await tester.pumpWidget(const GymFlowApp(initialRoute: Routes.intro));
    await settle(tester);
    expect(find.text('Bienvenue dans GymFlow'), findsOneWidget);
    await tester.tap(find.byKey(const Key('intro_next')));
    await settle(tester, 800);
    expect(find.text('Tes séances t\'appartiennent'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester, 800);
    expect(find.text('Crée tes propres workouts'), findsOneWidget);
  });
}
