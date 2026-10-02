import '../core/errors.dart';
import '../core/validators.dart';
import '../models/enums.dart';
import '../models/user.dart';
import '../repositories/repository.dart';
import 'backend.dart';

/// API interne de gestion des utilisateurs (profil + administration).
/// Aucune méthode ne renvoie de mot de passe ni ne permet de se connecter
/// au compte d'un autre utilisateur.
class UserService {
  UserService(this._b);
  final Backend _b;

  AppUser? byId(String id) => _b.users.byId(id);

  List<AppUser> coaches({bool activeOnly = true}) => _b.users.where(
    (u) => u.role == UserRole.coach && (!activeOnly || u.active),
  )..sort((a, b) => a.fullName.compareTo(b.fullName));

  /// Mise à jour du profil par l'utilisateur lui-même.
  Future<AppUser> updateProfile({
    required String fullName,
    int? age,
    double? heightCm,
    double? weightKg,
    required Goal goal,
    required Gender gender,
    String? avatarPath,
    String? phone,
    int? weeklyGoal,
  }) async {
    final me = _b.requireUser();
    final nameError = Validators.name(fullName);
    if (nameError != null) throw ValidationException(nameError);
    if (age != null && (age < 12 || age > 100)) {
      throw const ValidationException('Âge : entre 12 et 100 ans.');
    }
    if (heightCm != null && (heightCm < 100 || heightCm > 230)) {
      throw const ValidationException('Taille : entre 100 et 230 cm.');
    }
    if (weightKg != null && (weightKg < 30 || weightKg > 250)) {
      throw const ValidationException('Poids : entre 30 et 250 kg.');
    }
    final weightChanged = weightKg != null && weightKg != me.weightKg;
    final updated = await _b.users.save(
      me.copyWith(
        fullName: fullName.trim(),
        age: age,
        heightCm: heightCm,
        weightKg: weightKg,
        goal: goal,
        gender: gender,
        avatarPath: avatarPath,
        phone: phone,
        weeklyGoal: weeklyGoal,
      ),
    );
    if (weightChanged) await _b.progress.addWeight(weightKg);
    _b.auth.refreshCurrent();
    _b.bus.emit();
    return updated;
  }

  Future<void> toggleFavorite(String id) async {
    final me = _b.requireUser();
    final favs = {...me.favoriteIds};
    if (!favs.remove(id)) favs.add(id);
    await _b.users.save(me.copyWith(favoriteIds: favs));
    _b.auth.refreshCurrent();
  }

  bool isFavorite(String id) =>
      _b.auth.currentUser?.favoriteIds.contains(id) ?? false;

  Future<void> setActiveProgram(String? programId) async {
    final me = _b.requireUser();
    await _b.users.save(
      programId == null
          ? me.copyWith(clearActiveProgram: true)
          : me.copyWith(activeProgramId: programId),
    );
    _b.auth.refreshCurrent();
    _b.bus.emit();
  }

  // ---------- Administration (super admin uniquement) ----------

  List<AppUser> list({UserRole? role, bool? active, String query = ''}) {
    _b.requireRole(Backend.adminOnly);
    final q = query.trim().toLowerCase();
    return _b.users.where(
      (u) =>
          (role == null || u.role == role) &&
          (active == null || u.active == active) &&
          (q.isEmpty ||
              u.fullName.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q)),
    )..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  Future<AppUser> setActive(String userId, bool active) async {
    final admin = _b.requireRole(Backend.adminOnly);
    if (userId == admin.id) {
      throw const BusinessRuleException(
        'Vous ne pouvez pas désactiver votre propre compte.',
      );
    }
    final u = _b.users.byId(userId) ?? (throw const NotFoundException());
    final updated = await _b.users.save(u.copyWith(active: active));
    if (!active) {
      // Invalide la session en cours du compte désactivé.
      final cred = _b.credentials.byId(userId);
      if (cred != null) {
        await _b.credentials.save(cred.copyWith(clearSession: true));
      }
    }
    await _b.audit.log(
      active ? 'Activation' : 'Désactivation',
      '${u.fullName} (${u.role.label})',
      targetId: userId,
    );
    _b.bus.emit();
    return updated;
  }

  Future<AppUser> changeRole(String userId, UserRole role) async {
    final admin = _b.requireRole(Backend.adminOnly);
    if (userId == admin.id) {
      throw const BusinessRuleException(
        'Vous ne pouvez pas modifier votre propre rôle.',
      );
    }
    final u = _b.users.byId(userId) ?? (throw const NotFoundException());
    final updated = await _b.users.save(u.copyWith(role: role));
    await _b.audit.log(
      'Changement de rôle',
      '${u.fullName} : ${u.role.label} → ${role.label}',
      targetId: userId,
    );
    _b.bus.emit();
    return updated;
  }

  Future<AppUser> updateSubscription(
    String userId,
    SubscriptionType type,
  ) async {
    _b.requireRole(Backend.adminOnly);
    final u = _b.users.byId(userId) ?? (throw const NotFoundException());
    final now = _b.now();
    final sub = type == SubscriptionType.none
        ? Subscription.none
        : Subscription(
            type: type,
            start: now,
            end: type == SubscriptionType.trial
                ? now.add(const Duration(days: 7))
                : DateTime(now.year, now.month + type.months, now.day),
          );
    final updated = await _b.users.save(u.copyWith(subscription: sub));
    await _b.audit.log(
      'Abonnement',
      '${u.fullName} : ${type.label}',
      targetId: userId,
    );
    await _b.notifications.notify(
      userId,
      NotificationType.system,
      'Abonnement mis à jour',
      'Votre abonnement est maintenant : ${type.label}.',
    );
    _b.bus.emit();
    return updated;
  }

  /// Création d'un coach par le super admin (mot de passe provisoire).
  Future<AppUser> createCoach({
    required String fullName,
    required String email,
    required String temporaryPassword,
    required Gender gender,
    String? specialty,
  }) async {
    _b.requireRole(Backend.adminOnly);
    final errors = [
      Validators.name(fullName),
      Validators.email(email),
      Validators.password(temporaryPassword),
    ].whereType<String>();
    if (errors.isNotEmpty) throw ValidationException(errors.first);
    final e = email.trim().toLowerCase();
    if (_b.users.all.any((u) => u.email == e)) {
      throw const ValidationException('Un compte existe déjà avec cet e-mail.');
    }
    final coach = AppUser(
      id: IdGen.next('u_'),
      email: e,
      fullName: fullName.trim(),
      role: UserRole.coach,
      gender: gender,
      specialty: specialty?.trim(),
      createdAt: _b.now(),
    );
    await _b.users.save(coach);
    await _b.auth.setPassword(coach.id, temporaryPassword);
    await _b.audit.log('Création de coach', coach.fullName, targetId: coach.id);
    _b.bus.emit();
    return coach;
  }

  /// Suppression d'un compte (et de ses réservations actives).
  Future<void> deleteUser(String userId) async {
    final admin = _b.requireRole(Backend.adminOnly);
    if (userId == admin.id) {
      throw const BusinessRuleException(
        'Vous ne pouvez pas supprimer votre propre compte.',
      );
    }
    final u = _b.users.byId(userId) ?? (throw const NotFoundException());
    if (u.isCoach &&
        _b.courses.all.any(
          (c) => c.coachId == userId && c.statusAt(_b.now()).index < 2,
        )) {
      throw const BusinessRuleException(
        'Ce coach a encore des cours à venir : réaffectez-les d\'abord.',
      );
    }
    await _b.privacy.eraseUser(u);
    await _b.audit.log(
      'Suppression',
      '${u.fullName} (${u.role.label})',
      targetId: userId,
    );
    _b.bus.emit();
  }
}
