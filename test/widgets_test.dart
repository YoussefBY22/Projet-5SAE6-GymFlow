import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/routes.dart';
import 'package:gymflow/models/enums.dart';

import 'widget_helpers.dart';

/// Tests de widgets des écrans clés : connexion, formulaires, réservation,
/// panier/paiement, garde de rôle.
void main() {
  testWidgets('connexion : validation des champs puis erreur d\'identifiants', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Content de vous revoir'), findsOneWidget);
    await tester.tap(find.byKey(const Key('login_submit')));
    await settle(tester);
    expect(find.text('L\'adresse e-mail est obligatoire.'), findsOneWidget);
    expect(find.text('Le mot de passe est obligatoire.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('login_email')),
      'nour@gymflow.tn',
    );
    await tester.enterText(find.byKey(const Key('login_password')), 'mauvais');
    await tester.tap(find.byKey(const Key('login_submit')));
    await settle(tester);
    expect(
      find.textContaining('E-mail ou mot de passe incorrect'),
      findsOneWidget,
    );
  });

  testWidgets('connexion réussie d\'un abonné → accueil Strava', (
    tester,
  ) async {
    await pumpApp(tester);
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
    await completeIntro(tester);
    expect(find.text('Bonjour, Nour !'), findsOneWidget);
    expect(find.text('Mon prochain cours'), findsOneWidget);
    expect(find.text('Accueil'), findsOneWidget); // BottomNavigationBar
    expect(find.text('Profil'), findsOneWidget);
  });

  testWidgets('compte désactivé : message clair à la connexion', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.enterText(
      find.byKey(const Key('login_email')),
      'walid@gymflow.tn',
    );
    await tester.enterText(
      find.byKey(const Key('login_password')),
      'Membre2026!',
    );
    await tester.tap(find.byKey(const Key('login_submit')));
    await settle(tester);
    expect(find.textContaining('désactivé'), findsOneWidget);
  });

  testWidgets('super admin : navigation dédiée (Dashboard, Utilisateurs…)', (
    tester,
  ) async {
    await pumpApp(tester, route: Routes.home, loginEmail: 'admin@gymflow.tn');
    expect(find.text('Tableau de bord'), findsOneWidget);
    expect(find.text('Utilisateurs'), findsOneWidget);
    expect(find.text('Contenu'), findsOneWidget);
  });

  testWidgets(
    'garde de rôle : un abonné ne peut pas ouvrir la gestion des utilisateurs',
    (tester) async {
      await pumpApp(tester, route: Routes.home, loginEmail: 'nour@gymflow.tn');
      await go(tester, Routes.users);
      expect(find.text('Accès réservé'), findsOneWidget);
    },
  );

  testWidgets('inscription : validations du formulaire', (tester) async {
    await pumpApp(tester, route: Routes.register);
    await tapVisible(tester, find.text('Créer mon compte'));
    expect(find.text('Le nom est obligatoire.'), findsOneWidget);
    expect(find.text('L\'adresse e-mail est obligatoire.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mot de passe'),
      'abc',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmer le mot de passe'),
      'abd',
    );
    await tapVisible(tester, find.text('Créer mon compte'));
    expect(find.text('8 caractères minimum.'), findsOneWidget);
    expect(
      find.text('Les mots de passe ne correspondent pas.'),
      findsOneWidget,
    );
  });

  testWidgets('formulaire d\'exercice : champs obligatoires', (tester) async {
    final b = await pumpApp(
      tester,
      route: Routes.home,
      loginEmail: 'mehdi@gymflow.tn',
    );
    await go(tester, Routes.exerciseForm);
    final count = b.exercises.count;
    await tapVisible(tester, find.text('Enregistrer'));
    // Rien n'est enregistré ; on remonte voir les erreurs des champs.
    expect(b.exercises.count, count);
    expect(find.text('Indiquez au moins une étape.'), findsOneWidget);
    await tester.fling(mainScrollable(tester), const Offset(0, 3000), 3000);
    await settle(tester);
    expect(find.text('Le nom est obligatoire.'), findsOneWidget);
  });

  testWidgets('réservation d\'un cours depuis sa fiche', (tester) async {
    final b = await pumpApp(
      tester,
      route: Routes.home,
      loginEmail: 'nour@gymflow.tn',
    );
    await go(tester, Routes.courseDetail, 'c_s1');
    expect(find.text('Yoga Vinyasa'), findsWidgets);
    await tapVisible(tester, find.byKey(const Key('book_course')));
    expect(
      find.text('Place confirmée. Rappels 24 h et 1 h avant.'),
      findsOneWidget,
    );
    expect(
      b.reservationService.activeFor('c_s1', 'u_nour')?.status,
      ReservationStatus.confirmed,
    );
    expect(find.text('Ajouter à mon agenda'), findsOneWidget);
  });

  testWidgets('cours complet : bouton « liste d\'attente »', (tester) async {
    await pumpApp(tester, route: Routes.home, loginEmail: 'nour@gymflow.tn');
    await go(tester, Routes.courseDetail, 'c_s3');
    expect(find.text('Rejoindre la liste d\'attente'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('book_course')));
    expect(
      find.textContaining('Liste d\'attente : vous êtes n°1'),
      findsOneWidget,
    );
  });

  testWidgets('panier puis paiement test : commande confirmée', (tester) async {
    final b = await pumpApp(
      tester,
      route: Routes.home,
      loginEmail: 'nour@gymflow.tn',
    );
    await go(tester, Routes.product, 'pr_shaker');
    await tapVisible(tester, find.byKey(const Key('add_to_cart')));
    expect(b.cart.count, 1);
    await go(tester, Routes.cart);
    expect(find.textContaining('18,00'), findsWidgets);
    await tester.tap(find.byKey(const Key('checkout_button')));
    await settle(tester);
    expect(find.text('Récapitulatif'), findsOneWidget);
    await tester.tap(find.byKey(const Key('checkout_button')));
    await settle(tester, 2000);
    expect(find.byKey(const Key('order_confirmed')), findsOneWidget);
    expect(b.cart.isEmpty, isTrue);
    expect(b.products.byId('pr_shaker')!.stock, 39);
  });
}
