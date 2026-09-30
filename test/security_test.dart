import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/errors.dart';
import 'package:gymflow/core/security.dart';
import 'package:gymflow/models/enums.dart';
import 'package:gymflow/services/auth_service.dart';

import 'helpers.dart';

void main() {
  group('hachage des mots de passe', () {
    final h = PasswordHasher(iterations: 500);

    test(
      'sel aléatoire : deux empreintes différentes pour le même mot de passe',
      () {
        final s1 = h.newSalt();
        final s2 = h.newSalt();
        expect(s1, isNot(s2));
        expect(h.hash('Secret123', s1), isNot(h.hash('Secret123', s2)));
        expect(h.hash('Secret123', s1), isNot(contains('Secret123')));
      },
    );

    test('vérification correcte et incorrecte', () {
      final salt = h.newSalt();
      final hash = h.hash('Secret123', salt);
      expect(h.verify('Secret123', salt, hash, 500), isTrue);
      expect(h.verify('secret123', salt, hash, 500), isFalse);
      expect(PasswordHasher.constantTimeEquals('abc', 'abc'), isTrue);
      expect(PasswordHasher.constantTimeEquals('abc', 'abd'), isFalse);
    });

    test('PBKDF2-HMAC-SHA256 conforme au vecteur RFC 7914', () {
      final key = PasswordHasher.pbkdf2(
        'passwd'.codeUnits,
        'salt'.codeUnits,
        1,
        64,
      );
      final hex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(hex, startsWith('55ac046e56e3089fec1691c22544b605'));
    });
  });

  test(
    'aucun mot de passe ni empreinte dans les données utilisateur',
    () async {
      final b = await makeBackend();
      for (final u in b.users.all) {
        final json = u.toJson().toString().toLowerCase();
        expect(json, isNot(contains('password')));
        expect(json, isNot(contains('hash')));
        expect(json, isNot(contains('salt')));
        expect(json, isNot(contains('2026!')));
      }
      for (final c in b.credentials.all) {
        expect(c.hash, isNot(contains('2026')));
      }
    },
  );

  test('verrouillage temporaire après 5 échecs', () async {
    final b = await makeBackend();
    for (var i = 0; i < 4; i++) {
      await expectLater(
        b.auth.login('ahmed@gymflow.tn', 'mauvais'),
        throwsA(isA<ValidationException>()),
      );
    }
    await expectLater(
      b.auth.login('ahmed@gymflow.tn', 'mauvais'),
      throwsA(
        isA<BusinessRuleException>().having(
          (e) => e.message,
          'm',
          contains('verrouillé'),
        ),
      ),
    );
    // Même le bon mot de passe est refusé pendant le verrouillage.
    await expectLater(
      b.auth.login('ahmed@gymflow.tn', 'Membre2026!'),
      throwsA(isA<BusinessRuleException>()),
    );
    setNow(testNow.add(const Duration(minutes: 16)));
    final u = await b.auth.login('ahmed@gymflow.tn', 'Membre2026!');
    expect(u.id, 'u_ahmed');
  });

  test('compte désactivé : connexion refusée et session invalidée', () async {
    final b = await makeBackend();
    await expectLater(
      b.auth.login('walid@gymflow.tn', 'Membre2026!'),
      throwsA(
        isA<BusinessRuleException>().having(
          (e) => e.message,
          'm',
          contains('désactivé'),
        ),
      ),
    );
    // Session existante d'un compte désactivé ensuite.
    await loginAs(b, 'ahmed@gymflow.tn');
    await b.users.save(b.users.byId('u_ahmed')!.copyWith(active: false));
    expect(() => b.requireUser(), throwsA(isA<NotAuthenticatedException>()));
    final fresh = AuthService(b);
    await fresh.restoreSession();
    expect(fresh.currentUser, isNull);
    expect(fresh.pendingMessage, contains('désactivé'));
  });

  test('session restaurée au relancement pour un compte actif', () async {
    final b = await makeBackend();
    await loginAs(b, 'leila@gymflow.tn');
    final fresh = AuthService(b);
    await fresh.restoreSession();
    expect(fresh.currentUser?.id, 'u_leila');
    await b.auth.logout();
    final afterLogout = AuthService(b);
    await afterLogout.restoreSession();
    expect(afterLogout.currentUser, isNull);
  });

  test('mot de passe oublié : code à usage unique', () async {
    final b = await makeBackend();
    expect(await b.auth.requestPasswordReset('inconnu@gymflow.tn'), isNull);
    final code = await b.auth.requestPasswordReset('nour@gymflow.tn');
    expect(code, matches(RegExp(r'^\d{6}$')));
    await expectLater(
      b.auth.resetPassword('nour@gymflow.tn', '000000', 'Nouveau2026'),
      throwsA(isA<ValidationException>()),
    );
    await b.auth.resetPassword('nour@gymflow.tn', code!, 'Nouveau2026');
    await expectLater(
      b.auth.login('nour@gymflow.tn', 'Membre2026!'),
      throwsA(isA<ValidationException>()),
    );
    expect((await b.auth.login('nour@gymflow.tn', 'Nouveau2026')).id, 'u_nour');
    // Le code ne peut pas être réutilisé.
    await expectLater(
      b.auth.resetPassword('nour@gymflow.tn', code, 'Autre2026x'),
      throwsA(isA<ValidationException>()),
    );
  });

  test('code expiré après 15 minutes', () async {
    final b = await makeBackend();
    final code = await b.auth.requestPasswordReset('nour@gymflow.tn');
    setNow(testNow.add(const Duration(minutes: 16)));
    await expectLater(
      b.auth.resetPassword('nour@gymflow.tn', code!, 'Nouveau2026'),
      throwsA(isA<ValidationException>()),
    );
  });

  test(
    'inscription : validations, e-mail unique, essai gratuit de 7 jours',
    () async {
      final b = await makeBackend();
      await expectLater(
        b.auth.register(
          fullName: 'Test',
          email: 'nour@gymflow.tn',
          password: 'Abcdefg1',
          gender: Gender.female,
          goal: Goal.fitness,
        ),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        b.auth.register(
          fullName: 'Sami Test',
          email: 'sami@test.tn',
          password: 'court',
          gender: Gender.male,
          goal: Goal.fitness,
        ),
        throwsA(isA<ValidationException>()),
      );
      final u = await b.auth.register(
        fullName: 'Sami Test',
        email: 'Sami@Test.tn',
        password: 'Abcdefg1',
        gender: Gender.male,
        goal: Goal.endurance,
      );
      expect(u.role, UserRole.member);
      expect(u.email, 'sami@test.tn');
      expect(u.subscription.type, SubscriptionType.trial);
      expect(u.subscription.daysLeft(testNow), 7);
      expect(b.auth.currentUser?.id, u.id);
    },
  );

  test('changement de mot de passe', () async {
    final b = await makeBackend();
    await loginAs(b, 'ines@gymflow.tn');
    await expectLater(
      b.auth.changePassword('faux', 'Nouveau2026'),
      throwsA(isA<ValidationException>()),
    );
    await b.auth.changePassword('Membre2026!', 'Nouveau2026');
    await b.auth.logout();
    expect((await b.auth.login('ines@gymflow.tn', 'Nouveau2026')).id, 'u_ines');
  });
}
