import 'dart:convert';

import '../core/errors.dart';
import '../core/legal.dart';
import '../core/security.dart';
import '../core/validators.dart';
import '../models/enums.dart';
import '../models/content.dart';
import '../models/privacy.dart';
import '../models/user.dart';
import 'backend.dart';

/// API interne « vie privée » : réglages de visibilité, réseaux sociaux,
/// consentements, présentation, export des données (droit d'accès et de
/// portabilité) et suppression du compte (droit à l'effacement).
class PrivacyService {
  PrivacyService(this._b);
  final Backend _b;

  /// Ajoute une trace de consentement horodatée au compte connecté.
  Future<AppUser> recordConsent(String type, bool granted) async {
    final me = _b.requireUser();
    final updated = await _b.users.save(
      me.copyWith(
        consents: [
          ...me.consents,
          ConsentRecord(
            type: type,
            granted: granted,
            at: _b.now(),
            version: Legal.version,
          ),
        ],
      ),
    );
    _b.auth.refreshCurrent();
    return updated;
  }

  /// Dernier état connu d'un consentement (null si jamais exprimé).
  bool? consentState(AppUser u, String type) {
    for (final c in u.consents.reversed) {
      if (c.type == type) return c.granted;
    }
    return null;
  }

  /// CGU et politique de la version courante acceptées ?
  bool hasAcceptedTerms(AppUser u) => u.consents.any(
    (c) =>
        c.type == ConsentType.terms && c.granted && c.version == Legal.version,
  );

  /// Met à jour les réglages de l'utilisateur connecté. La modération
  /// (`hiddenByAdmin`) ne peut pas être modifiée par l'utilisateur.
  Future<AppUser> updateSettings(PrivacySettings next) async {
    final me = _b.requireUser();
    if (next.profileVisible && !me.isAdult) {
      throw const BusinessRuleException(
        'Les comptes de mineurs ne peuvent pas être visibles dans la communauté.',
      );
    }
    final previous = me.privacy;
    final settings = next.copyWith(
      hiddenByAdmin: previous.hiddenByAdmin,
      // Sans profil visible, les réseaux ne sont jamais affichés.
      showSocialLinks: next.profileVisible && next.showSocialLinks,
    );
    await _b.users.save(me.copyWith(privacy: settings));
    _b.auth.refreshCurrent();
    if (previous.profileVisible != settings.profileVisible) {
      await recordConsent(ConsentType.profileVisible, settings.profileVisible);
    }
    if (previous.showSocialLinks != settings.showSocialLinks) {
      await recordConsent(ConsentType.socialLinks, settings.showSocialLinks);
    }
    _b.bus.emit();
    return _b.users.byId(me.id)!;
  }

  /// Enregistre les réseaux sociaux après validation et normalisation.
  Future<AppUser> updateSocial(SocialLinks links) async {
    final me = _b.requireUser();
    final clean = SocialLinks(
      instagram: normalizeHandle(links.instagram, 'Instagram'),
      snapchat: normalizeHandle(links.snapchat, 'Snapchat'),
      facebook: normalizeProfileUrl(links.facebook, 'Facebook', const [
        'facebook.com',
        'fb.com',
      ]),
      linkedin: normalizeProfileUrl(links.linkedin, 'LinkedIn', const [
        'linkedin.com',
      ]),
      publicEmail: _email(links.publicEmail),
    );
    final updated = await _b.users.save(me.copyWith(social: clean));
    _b.auth.refreshCurrent();
    _b.bus.emit();
    return updated;
  }

  /// Identifiant de réseau social : lettres, chiffres, point, tiret bas.
  static String? normalizeHandle(String? raw, String network) {
    var v = (raw ?? '').trim();
    if (v.isEmpty) return null;
    v = v.replaceFirst(RegExp(r'^@'), '');
    final fromUrl = RegExp(
      r'^(?:https?://)?(?:www\.)?[a-z.]+\.com/(?:add/)?([A-Za-z0-9._-]+)/?$',
    ).firstMatch(v);
    if (fromUrl != null) v = fromUrl.group(1)!;
    if (!RegExp(r'^[A-Za-z0-9._-]{2,30}$').hasMatch(v)) {
      throw ValidationException('Identifiant $network invalide.');
    }
    return v;
  }

  /// Lien de profil HTTPS limité au domaine officiel du réseau (évite les
  /// liens piégés vers d'autres sites).
  static String? normalizeProfileUrl(
    String? raw,
    String network,
    List<String> domains,
  ) {
    var v = (raw ?? '').trim();
    if (v.isEmpty) return null;
    if (!v.startsWith('http')) v = 'https://$v';
    final uri = Uri.tryParse(v);
    final host = uri?.host.replaceFirst(RegExp(r'^(www\.|m\.)'), '') ?? '';
    if (uri == null ||
        !domains.contains(host) ||
        uri.pathSegments.where((p) => p.isNotEmpty).isEmpty ||
        v.length > 200) {
      throw ValidationException(
        'Lien $network invalide (ex. https://${domains.first}/votre-profil).',
      );
    }
    return Uri(scheme: 'https', host: 'www.$host', path: uri.path).toString();
  }

  static String? _email(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return null;
    final err = Validators.email(v);
    if (err != null) throw ValidationException('E-mail public : $err');
    return v.toLowerCase();
  }

  /// Présentation (tour vertical) terminée.
  Future<void> completeIntro() async {
    final me = _b.requireUser();
    await _b.users.save(me.copyWith(introVersion: Legal.introVersion));
    _b.auth.refreshCurrent();
  }

  bool needsIntro(AppUser u) => u.introVersion < Legal.introVersion;

  /// Export complet des données de l'utilisateur connecté (JSON lisible).
  /// Les secrets d'authentification ne sont jamais exportés.
  String exportMyData() {
    final me = _b.requireUser();
    final reservations = _b.reservations.where((r) => r.userId == me.id);
    final data = {
      'export': {
        'genere_le': _b.now().toIso8601String(),
        'application': 'GymFlow',
        'version_politique': Legal.version,
      },
      'compte': me.toJson(),
      'seances': [
        for (final s in _b.sessions.where((s) => s.userId == me.id)) s.toJson(),
      ],
      'pesees': [
        for (final w in _b.weights.where((w) => w.userId == me.id)) w.toJson(),
      ],
      'reservations': [
        for (final r in reservations)
          {...r.toJson(), 'cours': _b.courses.byId(r.courseId)?.title},
      ],
      'commandes': [
        for (final o in _b.orders.where((o) => o.userId == me.id)) o.toJson(),
      ],
      'notifications': [
        for (final n in _b.notificationsRepo.where((n) => n.userId == me.id))
          n.toJson(),
      ],
      // Créations (exercices, workouts, programmes), quel que soit leur
      // statut de publication.
      'mes_exercices': [
        for (final e in _b.exercises.where((e) => e.authorId == me.id))
          e.toJson(),
      ],
      'mes_workouts': [
        for (final w in _b.workouts.where((w) => w.authorId == me.id))
          w.toJson(),
      ],
      'mes_programmes': [
        for (final p in _b.programs.where((p) => p.authorId == me.id))
          p.toJson(),
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Suppression de son propre compte (abonné), après confirmation par
  /// mot de passe.
  Future<void> deleteMyAccount(String password) async {
    final me = _b.requireRole({UserRole.member});
    final cred = _b.credentials.byId(me.id);
    if (cred == null ||
        !_b.auth.hasher.verify(
          password,
          cred.salt,
          cred.hash,
          cred.iterations,
        )) {
      throw const ValidationException('Mot de passe incorrect.');
    }
    await eraseUser(me);
    await _b.audit.log(
      'Effacement à la demande',
      'Compte supprimé par son titulaire (droit à l\'effacement)',
      targetId: me.id,
    );
    await _b.auth.logout();
    _b.bus.emit();
  }

  /// Efface toutes les données personnelles d'un compte. Les commandes,
  /// soumises à une obligation comptable, sont conservées mais anonymisées.
  Future<void> eraseUser(AppUser u) async {
    final now = _b.now();
    for (final r in _b.reservations.where((r) => r.userId == u.id)) {
      final c = _b.courses.byId(r.courseId);
      await _b.reservations.delete(r.id);
      await _b.notifications.cancelCourseReminders(r.id);
      if (c != null && c.startAt != null && c.startAt!.isAfter(now)) {
        await _b.reservationService.promoteWaitlist(c.id);
      }
    }
    for (final s in _b.sessions.where((s) => s.userId == u.id)) {
      await _b.sessions.delete(s.id);
    }
    for (final s in _b.sessions.where((s) => s.kudos.contains(u.id))) {
      await _b.sessions.save(
        s.copyWith(kudos: s.kudos.where((k) => k != u.id).toList()),
      );
    }
    for (final w in _b.weights.where((w) => w.userId == u.id)) {
      await _b.weights.delete(w.id);
    }
    for (final n in _b.notificationsRepo.where((n) => n.userId == u.id)) {
      await _b.notificationsRepo.delete(n.id);
    }
    // Créations non publiées : supprimées. Créations publiées (cédées à la
    // salle lors de la proposition) : conservées mais anonymisées.
    final heir = u.canManageContent ? '' : 'ancien-membre';
    for (final p in _b.programs.where((p) => p.authorId == u.id)) {
      if (p.isPublished) {
        await _b.programs.save(p.copyWith(authorId: heir));
      } else {
        await _b.programs.delete(p.id);
      }
    }
    for (final w in _b.workouts.where((w) => w.authorId == u.id)) {
      if (w.isPublished) {
        await _b.workouts.save(w.copyWith(authorId: heir));
      } else {
        await _b.workouts.delete(w.id);
      }
    }
    for (final e in _b.exercises.where((e) => e.authorId == u.id)) {
      if (e.isPublished) {
        await _b.exercises.save(e.copyWith(authorId: heir));
      } else {
        await _b.exercises.delete(e.id);
      }
    }
    for (final o in _b.orders.where((o) => o.userId == u.id)) {
      await _b.orders.save(o.anonymized(_anonymousId(u.id)));
    }
    await _b.credentials.delete(u.id);
    await _b.users.delete(u.id);
  }

  /// Identifiant non réversible pour les commandes conservées.
  static String _anonymousId(String userId) =>
      'anonyme-${tokenDigest(userId).substring(0, 12)}';
}
