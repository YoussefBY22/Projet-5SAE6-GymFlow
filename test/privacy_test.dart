import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/errors.dart';
import 'package:gymflow/models/enums.dart';
import 'package:gymflow/models/privacy.dart';
import 'package:gymflow/models/workout.dart';
import 'package:gymflow/services/privacy_service.dart';

import 'helpers.dart';

/// Confidentialité, consentements et communauté : tout est privé par
/// défaut, chaque partage est un choix explicite et traçable.
void main() {
  group('Réglages par défaut et consentements', () {
    test('un compte est privé par défaut, rien n\'est pré-coché', () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      final nour = b.auth.currentUser!;
      expect(nour.privacy.profileVisible, isFalse);
      expect(nour.privacy.showSocialLinks, isFalse);
      expect(nour.privacy.isPubliclyVisible, isFalse);
      // Les autres ne la voient pas.
      await loginAs(b, 'ahmed@gymflow.tn');
      expect(
        b.community.members().map((p) => p.userId),
        isNot(contains('u_nour')),
      );
      expect(
        () => b.community.profile('u_nour'),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(b.community.canOpenProfile('u_nour'), isFalse);
    });

    test('rendre son profil visible est horodaté dans l\'historique', () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      final me = b.auth.currentUser!;
      await b.privacy.updateSettings(me.privacy.copyWith(profileVisible: true));
      var u = b.users.byId('u_nour')!;
      expect(u.privacy.profileVisible, isTrue);
      expect(b.privacy.consentState(u, ConsentType.profileVisible), isTrue);
      expect(u.consents.last.at, testNow, reason: 'le consentement est daté');

      // Réseaux impossibles sans profil visible.
      await b.privacy.updateSettings(
        u.privacy.copyWith(profileVisible: false, showSocialLinks: true),
      );
      u = b.users.byId('u_nour')!;
      expect(u.privacy.showSocialLinks, isFalse);
      expect(b.privacy.consentState(u, ConsentType.profileVisible), isFalse);
    });

    test('un mineur ne peut jamais être visible', () async {
      final b = await makeBackend();
      final nour = b.users.byId('u_nour')!;
      await b.users.save(nour.copyWith(age: 16));
      await loginAs(b, 'nour@gymflow.tn');
      final me = b.auth.currentUser!;
      expect(me.isAdult, isFalse);
      await expectLater(
        b.privacy.updateSettings(me.privacy.copyWith(profileVisible: true)),
        throwsA(isA<BusinessRuleException>()),
      );
    });

    test('l\'inscription exige 18 ans et l\'acceptation des CGU', () async {
      final b = await makeBackend();
      Future<void> reg({required int age, required bool terms}) =>
          b.auth.register(
            fullName: 'Yasmine Test',
            email: 'yasmine$age$terms@test.tn',
            password: 'Abcdefg1',
            gender: Gender.female,
            goal: Goal.fitness,
            age: age,
            acceptTerms: terms,
          );
      await expectLater(
        reg(age: 16, terms: true),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        reg(age: 25, terms: false),
        throwsA(isA<ValidationException>()),
      );
      await reg(age: 25, terms: true);
      final u = b.auth.currentUser!;
      expect(b.privacy.hasAcceptedTerms(u), isTrue);
      expect(b.privacy.needsIntro(u), isTrue);
      await b.privacy.completeIntro();
      expect(b.privacy.needsIntro(b.auth.currentUser!), isFalse);
    });

    test('la modération n\'est pas modifiable par le membre', () async {
      final b = await makeBackend();
      await loginAs(b, 'admin@gymflow.tn');
      await b.community.setHiddenByAdmin('u_ahmed', true);
      await loginAs(b, 'ahmed@gymflow.tn');
      final me = b.auth.currentUser!;
      await b.privacy.updateSettings(
        me.privacy.copyWith(hiddenByAdmin: false, profileVisible: true),
      );
      expect(b.users.byId('u_ahmed')!.privacy.hiddenByAdmin, isTrue);
      await loginAs(b, 'nour@gymflow.tn');
      expect(
        b.community.members().map((p) => p.userId),
        isNot(contains('u_ahmed')),
      );
    });
  });

  group('Réseaux sociaux', () {
    test('identifiants et liens normalisés, domaines officiels seulement', () {
      expect(
        PrivacyService.normalizeHandle('@ma.page', 'Instagram'),
        'ma.page',
      );
      expect(
        PrivacyService.normalizeHandle(
          'https://www.instagram.com/ma.page/',
          'Instagram',
        ),
        'ma.page',
      );
      expect(PrivacyService.normalizeHandle('  ', 'Snapchat'), isNull);
      expect(
        () => PrivacyService.normalizeHandle('pas un id !', 'Snapchat'),
        throwsA(isA<ValidationException>()),
      );
      expect(
        PrivacyService.normalizeProfileUrl('facebook.com/moi', 'Facebook', [
          'facebook.com',
        ]),
        'https://www.facebook.com/moi',
      );
      // Lien piégé vers un autre site : refusé.
      for (final bad in [
        'https://evil.example/facebook.com/moi',
        'https://facebook.com.evil.example/moi',
        'https://www.facebook.com/',
      ]) {
        expect(
          () => PrivacyService.normalizeProfileUrl(bad, 'Facebook', [
            'facebook.com',
          ]),
          throwsA(isA<ValidationException>()),
          reason: bad,
        );
      }
    });

    test('les réseaux ne sont visibles que si le membre l\'a choisi', () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      // Ahmed : visible avec réseaux. Leila : visible sans réseaux.
      expect(b.community.profile('u_ahmed').social.isEmpty, isFalse);
      expect(b.users.byId('u_leila')!.privacy.profileVisible, isTrue);
      expect(b.community.profile('u_leila').social.isEmpty, isTrue);

      await b.privacy.updateSocial(
        const SocialLinks(instagram: '@nour.fit', publicEmail: 'Nour@Mail.tn'),
      );
      final u = b.users.byId('u_nour')!;
      expect(u.social.instagram, 'nour.fit');
      expect(u.social.publicEmail, 'nour@mail.tn');
      // Saisis mais pas affichés : le profil est privé.
      await loginAs(b, 'ahmed@gymflow.tn');
      expect(
        () => b.community.profile('u_nour'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('Partage des séances', () {
    test('une séance non partagée n\'est visible que par son auteur', () async {
      final b = await makeBackend();
      final private = b.sessions.all.firstWhere(
        (s) => s.userId == 'u_ahmed' && !s.shared,
      );
      final shared = b.sessions.all.firstWhere(
        (s) => s.userId == 'u_ahmed' && s.shared,
      );
      await loginAs(b, 'nour@gymflow.tn');
      final feed = b.trainingLog.feed(limit: 500);
      expect(feed.map((s) => s.id), isNot(contains(private.id)));
      expect(feed.map((s) => s.id), contains(shared.id));
      expect(b.trainingLog.byId(private.id), isNull);
      expect(
        () => b.trainingLog.historyOf('u_ahmed'),
        throwsA(isA<PermissionDeniedException>()),
      );
      await expectLater(
        b.trainingLog.toggleKudos(private.id),
        throwsA(isA<PermissionDeniedException>()),
      );
      await expectLater(
        b.trainingLog.setShared(private.id, true),
        throwsA(isA<PermissionDeniedException>()),
      );
      // Masquer l'activité des autres : seul son propre fil reste.
      expect(
        b.trainingLog
            .feed(limit: 500, includeOthers: false)
            .every((s) => s.userId == 'u_nour'),
        isTrue,
      );
    });

    test('l\'auteur partage puis retire : les Bravo sont effacés', () async {
      final b = await makeBackend();
      final s = b.sessions.all.firstWhere(
        (s) => s.userId == 'u_ahmed' && !s.shared,
      );
      await loginAs(b, 'ahmed@gymflow.tn');
      await b.trainingLog.setShared(s.id, true);
      expect(b.sessions.byId(s.id)!.sharedAt, testNow);
      await loginAs(b, 'nour@gymflow.tn');
      await b.trainingLog.toggleKudos(s.id);
      expect(b.sessions.byId(s.id)!.kudos, contains('u_nour'));
      await loginAs(b, 'ahmed@gymflow.tn');
      await b.trainingLog.setShared(s.id, false);
      expect(b.sessions.byId(s.id)!.shared, isFalse);
      expect(b.sessions.byId(s.id)!.kudos, isEmpty);
      expect(
        b.privacy.consentState(b.auth.currentUser!, ConsentType.shareSession),
        isFalse,
      );
    });

    test('la modération retire les séances partagées du fil', () async {
      final b = await makeBackend();
      await loginAs(b, 'admin@gymflow.tn');
      await b.community.setHiddenByAdmin('u_rami', true);
      expect(
        b.sessions.all.where((s) => s.userId == 'u_rami' && s.shared),
        isEmpty,
      );
      expect(
        b.auditRepo.all.any((a) => a.action == 'Profil masqué (modération)'),
        isTrue,
      );
    });
  });

  group('Communauté et signalement', () {
    test('le profil public ne contient aucune donnée sensible', () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      final members = b.community.members();
      expect(members, isNotEmpty);
      expect(members.every((p) => p.userId != 'u_nour'), isTrue);
      for (final p in members) {
        final u = b.users.byId(p.userId)!;
        expect(u.privacy.isPubliclyVisible, isTrue);
        expect(u.isAdult, isTrue);
        expect(p.sharedSessions.every((s) => s.shared), isTrue);
      }
      // Les coachs et l'admin ne sont pas dans l'annuaire des membres.
      expect(members.any((p) => b.users.byId(p.userId)!.isMember), isTrue);
      expect(members.every((p) => b.users.byId(p.userId)!.isMember), isTrue);
    });

    test(
      'signalement : motif obligatoire, une fois par jour, admins prévenus',
      () async {
        final b = await makeBackend();
        await loginAs(b, 'nour@gymflow.tn');
        await expectLater(
          b.community.report('u_ahmed', 'bof'),
          throwsA(isA<ValidationException>()),
        );
        await b.community.report('u_ahmed', 'Photo de profil inappropriée');
        await expectLater(
          b.community.report('u_ahmed', 'Encore une fois'),
          throwsA(isA<BusinessRuleException>()),
        );
        expect(
          b.notificationsRepo.all.any(
            (n) => n.userId == 'u_admin' && n.title.contains('Ahmed'),
          ),
          isTrue,
        );
      },
    );
  });

  group('Workouts personnels', () {
    test('un abonné crée un workout privé, invisible des autres', () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      final ex = b.exercises.all.first;
      final w = await b.workoutService.saveWorkout(
        name: 'Mon circuit maison',
        description: 'Rapide',
        level: Level.beginner,
        goal: Goal.fitness,
        items: [WorkoutItem(exerciseId: ex.id, sets: 3, reps: 12, restSec: 45)],
      );
      expect(w.isPrivate, isTrue);
      expect(w.authorId, 'u_nour');
      expect(b.workoutService.workouts(personalOnly: true).map((x) => x.id), [
        w.id,
      ]);
      await loginAs(b, 'ahmed@gymflow.tn');
      expect(b.workoutService.workoutById(w.id), isNull);
      expect(
        b.workoutService.workouts().map((x) => x.id),
        isNot(contains(w.id)),
      );
      await expectLater(
        b.workoutService.deleteWorkout(w.id),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Droits sur les données', () {
    test('export JSON complet, sans aucun secret', () async {
      final b = await makeBackend();
      await loginAs(b, 'ahmed@gymflow.tn');
      final json = b.privacy.exportMyData();
      final data = jsonDecode(json) as Map<String, dynamic>;
      expect(data['compte']['email'], 'ahmed@gymflow.tn');
      expect((data['seances'] as List), isNotEmpty);
      for (final secret in ['hash', 'salt', 'Membre2026']) {
        expect(json.contains(secret), isFalse, reason: secret);
      }
    });

    test(
      'suppression de son compte : mot de passe exigé, données effacées',
      () async {
        final b = await makeBackend();
        await loginAs(b, 'ahmed@gymflow.tn');
        final orders = b.orders.all.where((o) => o.userId == 'u_ahmed').length;
        await expectLater(
          b.privacy.deleteMyAccount('mauvais'),
          throwsA(isA<ValidationException>()),
        );
        await b.privacy.deleteMyAccount('Membre2026!');
        expect(b.users.byId('u_ahmed'), isNull);
        expect(b.credentials.byId('u_ahmed'), isNull);
        expect(b.sessions.all.where((s) => s.userId == 'u_ahmed'), isEmpty);
        expect(b.sessions.all.any((s) => s.kudos.contains('u_ahmed')), isFalse);
        expect(b.reservations.all.where((r) => r.userId == 'u_ahmed'), isEmpty);
        // Commandes conservées (obligation comptable) mais anonymisées.
        expect(b.orders.all.where((o) => o.userId == 'u_ahmed'), isEmpty);
        expect(
          b.orders.all.where((o) => o.userId.startsWith('anonyme-')).length,
          greaterThanOrEqualTo(orders),
        );
        expect(b.auth.currentUser, isNull);
      },
    );
  });
}
