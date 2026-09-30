import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../core/errors.dart';
import '../core/formatters.dart';
import '../core/security.dart';
import '../core/validators.dart';
import '../models/enums.dart';
import '../models/user.dart';
import '../repositories/repository.dart';
import 'backend.dart';

/// API interne d'authentification : inscription, connexion, session,
/// verrouillage après échecs, mot de passe oublié (flux simulé).
class AuthService extends ChangeNotifier {
  AuthService(this._b) : hasher = PasswordHasher(iterations: _b.passwordIterations);

  final Backend _b;
  final PasswordHasher hasher;
  static const _tokenKey = 'gymflow_session_token';
  static const _userKey = 'gymflow_session_user';

  AppUser? _current;

  /// Message à afficher sur l'écran de connexion (ex. compte désactivé).
  String? pendingMessage;

  AppUser? get currentUser => _current;
  bool get isLoggedIn => _current != null;

  /// Restaure la session au lancement ; invalide la session d'un compte
  /// désactivé ou d'un jeton inconnu.
  Future<void> restoreSession() async {
    final token = await _b.sessionStorage.read(_tokenKey);
    final userId = await _b.sessionStorage.read(_userKey);
    if (token == null || userId == null) return;
    final cred = _b.credentials.byId(userId);
    final user = _b.users.byId(userId);
    final valid =
        cred?.sessionDigest != null &&
        PasswordHasher.constantTimeEquals(
          cred!.sessionDigest!,
          tokenDigest(token),
        );
    if (user == null || !valid) {
      await _clearStoredSession();
      return;
    }
    if (!user.active) {
      await _b.credentials.save(cred.copyWith(clearSession: true));
      await _clearStoredSession();
      pendingMessage =
          'Votre compte a été désactivé par la salle. Contactez l\'accueil.';
      return;
    }
    _current = user;
    notifyListeners();
  }

  /// Crée les données d'authentification d'un utilisateur.
  Future<void> setPassword(String userId, String password) async {
    final salt = hasher.newSalt();
    final existing = _b.credentials.byId(userId);
    final cred = Credential(
      userId: userId,
      hash: hasher.hash(password, salt),
      salt: salt,
      iterations: hasher.iterations,
      sessionDigest: existing?.sessionDigest,
    );
    await _b.credentials.save(cred);
  }

  AppUser? _findByEmail(String email) {
    final e = email.trim().toLowerCase();
    for (final u in _b.users.all) {
      if (u.email.toLowerCase() == e) return u;
    }
    return null;
  }

  Future<AppUser> login(String email, String password) async {
    if (Validators.email(email) != null || password.isEmpty) {
      throw const ValidationException('Saisissez votre e-mail et mot de passe.');
    }
    const generic = 'E-mail ou mot de passe incorrect.';
    final user = _findByEmail(email);
    final cred = user == null ? null : _b.credentials.byId(user.id);
    if (user == null || cred == null) throw const ValidationException(generic);

    final now = _b.now();
    if (cred.lockedUntil != null && cred.lockedUntil!.isAfter(now)) {
      final minutes = cred.lockedUntil!.difference(now).inMinutes + 1;
      throw BusinessRuleException(
        'Trop de tentatives. Compte verrouillé, réessayez dans $minutes min.',
      );
    }

    final ok = hasher.verify(password, cred.salt, cred.hash, cred.iterations);
    if (!ok) {
      final attempts = cred.failedAttempts + 1;
      if (attempts >= AppConfig.maxLoginAttempts) {
        await _b.credentials.save(
          cred.copyWith(
            failedAttempts: 0,
            lockedUntil: now.add(AppConfig.lockDuration),
          ),
        );
        throw BusinessRuleException(
          'Trop de tentatives. Compte verrouillé pendant '
          '${AppConfig.lockDuration.inMinutes} min.',
        );
      }
      await _b.credentials.save(
        cred.copyWith(failedAttempts: attempts, clearLock: true),
      );
      final left = AppConfig.maxLoginAttempts - attempts;
      throw ValidationException(
        '$generic Encore ${Fmt.plural(left, 'essai')} avant verrouillage.',
      );
    }

    if (!user.active) {
      throw const BusinessRuleException(
        'Ce compte a été désactivé par la salle. Contactez l\'accueil.',
      );
    }

    final token = newSessionToken();
    await _b.credentials.save(
      cred.copyWith(
        failedAttempts: 0,
        clearLock: true,
        sessionDigest: tokenDigest(token),
      ),
    );
    await _b.sessionStorage.write(_tokenKey, token);
    await _b.sessionStorage.write(_userKey, user.id);
    final updated = await _b.users.save(user.copyWith(lastLoginAt: now));
    _current = updated;
    pendingMessage = null;
    notifyListeners();
    _b.bus.emit();
    return updated;
  }

  Future<AppUser> register({
    required String fullName,
    required String email,
    required String password,
    required Gender gender,
    required Goal goal,
    int? age,
  }) async {
    final errors = [
      Validators.name(fullName),
      Validators.email(email),
      Validators.password(password),
    ].whereType<String>();
    if (errors.isNotEmpty) throw ValidationException(errors.first);
    if (_findByEmail(email) != null) {
      throw const ValidationException('Un compte existe déjà avec cet e-mail.');
    }
    final now = _b.now();
    final user = AppUser(
      id: IdGen.next('u_'),
      email: email.trim().toLowerCase(),
      fullName: fullName.trim(),
      role: UserRole.member,
      gender: gender,
      goal: goal,
      age: age,
      createdAt: now,
      // Essai gratuit de 7 jours pour découvrir la salle.
      subscription: Subscription(
        type: SubscriptionType.trial,
        start: now,
        end: now.add(const Duration(days: 7)),
      ),
    );
    await _b.users.save(user);
    await setPassword(user.id, password);
    await _b.notifications.notify(
      user.id,
      NotificationType.system,
      'Bienvenue chez GymFlow !',
      'Votre essai gratuit de 7 jours commence aujourd\'hui. Réservez votre premier cours.',
    );
    return login(email, password);
  }

  Future<void> logout() async {
    final u = _current;
    if (u != null) {
      final cred = _b.credentials.byId(u.id);
      if (cred != null) {
        await _b.credentials.save(cred.copyWith(clearSession: true));
      }
    }
    await _clearStoredSession();
    _current = null;
    _b.cart.clear();
    notifyListeners();
  }

  Future<void> _clearStoredSession() async {
    await _b.sessionStorage.delete(_tokenKey);
    await _b.sessionStorage.delete(_userKey);
  }

  /// Recharge l'utilisateur courant après une modification de profil.
  void refreshCurrent() {
    final u = _current;
    if (u == null) return;
    _current = _b.users.byId(u.id);
    notifyListeners();
  }

  /// Mot de passe oublié : génère un code à 6 chiffres valable 15 min.
  /// L'envoi d'e-mail est simulé : le code est renvoyé pour être affiché
  /// dans une « boîte de réception » de démonstration.
  Future<String?> requestPasswordReset(String email) async {
    if (Validators.email(email) != null) {
      throw const ValidationException('Adresse e-mail invalide.');
    }
    final user = _findByEmail(email);
    if (user == null) return null;
    final cred = _b.credentials.byId(user.id);
    if (cred == null) return null;
    final code = (Random.secure().nextInt(900000) + 100000).toString();
    await _b.credentials.save(
      cred.copyWith(
        resetCodeHash: tokenDigest(code),
        resetCodeExpires: _b.now().add(AppConfig.resetCodeValidity),
      ),
    );
    return code;
  }

  Future<void> resetPassword(String email, String code, String newPassword) async {
    final pwdError = Validators.password(newPassword);
    if (pwdError != null) throw ValidationException(pwdError);
    final user = _findByEmail(email);
    final cred = user == null ? null : _b.credentials.byId(user.id);
    const invalid = 'Code invalide ou expiré.';
    if (cred == null ||
        cred.resetCodeHash == null ||
        cred.resetCodeExpires == null ||
        cred.resetCodeExpires!.isBefore(_b.now()) ||
        !PasswordHasher.constantTimeEquals(
          cred.resetCodeHash!,
          tokenDigest(code.trim()),
        )) {
      throw const ValidationException(invalid);
    }
    final salt = hasher.newSalt();
    await _b.credentials.save(
      cred.copyWith(
        hash: hasher.hash(newPassword, salt),
        salt: salt,
        iterations: hasher.iterations,
        failedAttempts: 0,
        clearLock: true,
        clearReset: true,
        clearSession: true,
      ),
    );
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    final user = _b.requireUser();
    final cred = _b.credentials.byId(user.id)!;
    if (!hasher.verify(oldPassword, cred.salt, cred.hash, cred.iterations)) {
      throw const ValidationException('Mot de passe actuel incorrect.');
    }
    final pwdError = Validators.password(newPassword);
    if (pwdError != null) throw ValidationException(pwdError);
    final salt = hasher.newSalt();
    await _b.credentials.save(
      cred.copyWith(
        hash: hasher.hash(newPassword, salt),
        salt: salt,
        iterations: hasher.iterations,
      ),
    );
  }
}
