import '../core/errors.dart';
import '../models/enums.dart';
import '../models/privacy.dart';
import '../models/session_log.dart';
import '../models/user.dart';
import 'backend.dart';
import 'exercise_service.dart';
import 'progress_service.dart';

/// Profil public d'un membre, limité aux informations qu'il a choisi de
/// montrer. Ne contient jamais : e-mail de connexion, téléphone, âge,
/// poids, taille, abonnement, réservations ou achats.
class PublicProfile {
  const PublicProfile({
    required this.userId,
    required this.fullName,
    required this.avatarPath,
    required this.goal,
    required this.memberSince,
    required this.sharedSessions,
    required this.social,
    required this.activeThisWeek,
  });

  final String userId;
  final String fullName;
  final String? avatarPath;
  final Goal goal;
  final DateTime memberSince;
  final List<SessionLog> sharedSessions;

  /// Vide si le membre n'a pas autorisé l'affichage de ses réseaux.
  final SocialLinks social;
  final bool activeThisWeek;

  String get firstName => fullName.split(' ').first;

  /// Utilisateur réduit aux champs publics (pour l'avatar).
  AppUser asAvatarUser() => AppUser(
    id: userId,
    email: '',
    fullName: fullName,
    role: UserRole.member,
    createdAt: memberSince,
    avatarPath: avatarPath,
  );
}

/// API interne « Communauté » : annuaire des membres qui ont choisi d'être
/// visibles, profils publics et signalements.
class CommunityService {
  CommunityService(this._b);
  final Backend _b;

  /// Un membre apparaît dans la communauté seulement s'il l'a activé,
  /// s'il est majeur, actif et non masqué par la salle.
  bool isVisible(AppUser u) =>
      u.isMember && u.active && u.isAdult && u.privacy.isPubliclyVisible;

  bool _activeThisWeek(String userId) {
    final start = ProgressService.startOfWeek(_b.now());
    return _b.sessions.all.any(
      (s) => s.userId == userId && s.shared && !s.startedAt.isBefore(start),
    );
  }

  /// Annuaire (hors soi-même), trié par activité récente.
  List<PublicProfile> members({String query = '', bool activeOnly = false}) {
    final me = _b.requireUser();
    final q = ExerciseService.normalize(query);
    final list = <PublicProfile>[];
    for (final u in _b.users.all) {
      if (u.id == me.id || !isVisible(u)) continue;
      if (q.isNotEmpty && !ExerciseService.normalize(u.fullName).contains(q)) {
        continue;
      }
      final p = _toPublic(u);
      if (activeOnly && !p.activeThisWeek) continue;
      list.add(p);
    }
    DateTime last(PublicProfile p) => p.sharedSessions.isEmpty
        ? p.memberSince
        : p.sharedSessions.first.startedAt;
    list.sort((a, b) => last(b).compareTo(last(a)));
    return list;
  }

  int visibleCount() => _b.users.all.where(isVisible).length;

  /// Profil public d'un membre (refusé s'il n'est pas visible).
  PublicProfile profile(String userId) {
    final me = _b.requireUser();
    final u = _b.users.byId(userId) ?? (throw const NotFoundException());
    if (u.id != me.id && !isVisible(u)) {
      throw const PermissionDeniedException(
        'Ce membre a choisi de garder son profil privé.',
      );
    }
    return _toPublic(u);
  }

  PublicProfile _toPublic(AppUser u) => PublicProfile(
    userId: u.id,
    fullName: u.fullName,
    avatarPath: u.avatarPath,
    goal: u.goal,
    memberSince: u.createdAt,
    sharedSessions: _b.trainingLog.sharedSessionsOf(u.id),
    social: u.privacy.showSocialLinks ? u.social : const SocialLinks(),
    activeThisWeek: _activeThisWeek(u.id),
  );

  /// Profil d'un auteur de séance consultable depuis le fil ?
  bool canOpenProfile(String userId) {
    final me = _b.auth.currentUser;
    final u = _b.users.byId(userId);
    if (me == null || u == null) return false;
    return u.id == me.id || isVisible(u);
  }

  /// Signalement d'un profil : les administrateurs sont prévenus et
  /// l'action est tracée. Un même profil ne peut être signalé qu'une fois
  /// par jour par la même personne.
  Future<void> report(String userId, String reason) async {
    final me = _b.requireUser();
    final target = _b.users.byId(userId) ?? (throw const NotFoundException());
    if (target.id == me.id) {
      throw const BusinessRuleException('Vous ne pouvez pas vous signaler.');
    }
    final text = reason.trim();
    if (text.length < 5 || text.length > 300) {
      throw const ValidationException('Motif : 5 à 300 caractères.');
    }
    final since = _b.now().subtract(const Duration(days: 1));
    final already = _b.auditRepo.all.any(
      (a) =>
          a.action == 'Signalement' &&
          a.actorId == me.id &&
          a.targetId == userId &&
          a.createdAt.isAfter(since),
    );
    if (already) {
      throw const BusinessRuleException(
        'Signalement déjà envoyé aujourd\'hui. La salle va l\'examiner.',
      );
    }
    await _b.audit.log('Signalement', text, targetId: userId);
    for (final admin in _b.users.where((u) => u.isAdmin && u.active)) {
      await _b.notifications.notify(
        admin.id,
        NotificationType.system,
        'Profil signalé : ${target.fullName}',
        'Motif : $text',
        route: '/admin/user',
        refId: userId,
      );
    }
  }

  /// Modération par la salle : masquer ou réafficher un profil.
  Future<void> setHiddenByAdmin(String userId, bool hidden) async {
    _b.requireRole(Backend.adminOnly);
    final u = _b.users.byId(userId) ?? (throw const NotFoundException());
    await _b.users.save(
      u.copyWith(privacy: u.privacy.copyWith(hiddenByAdmin: hidden)),
    );
    await _b.audit.log(
      hidden ? 'Profil masqué (modération)' : 'Profil réaffiché',
      u.fullName,
      targetId: userId,
    );
    if (hidden) {
      for (final s in _b.sessions.where(
        (s) => s.userId == userId && s.shared,
      )) {
        await _b.sessions.save(s.copyWith(shared: false));
      }
      await _b.notifications.notify(
        userId,
        NotificationType.system,
        'Profil masqué par la salle',
        'Votre profil et vos séances ne sont plus visibles des autres membres. '
            'Contactez l\'accueil pour en savoir plus.',
      );
    }
    _b.bus.emit();
  }
}
