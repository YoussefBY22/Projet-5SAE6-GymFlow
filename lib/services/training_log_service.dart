import '../core/errors.dart';
import '../models/enums.dart';
import '../models/privacy.dart';
import '../models/session_log.dart';
import '../models/workout.dart';
import '../repositories/repository.dart';
import 'backend.dart';

/// Résultat de fin de séance : la séance enregistrée et les records battus.
class SessionResult {
  const SessionResult(this.log, this.records);
  final SessionLog log;
  final List<PersonalRecord> records;
}

/// API interne de l'historique des séances et du fil d'activités.
///
/// Confidentialité : une séance est **privée** à sa création. Elle n'apparaît
/// sur le fil du club que si son auteur la partage explicitement.
class TrainingLogService {
  TrainingLogService(this._b);
  final Backend _b;

  /// Enregistre une séance terminée depuis le lecteur de séance (privée).
  Future<SessionResult> finishSession({
    required Workout workout,
    required DateTime startedAt,
    required int durationSec,
    required List<SetLog> sets,
    String note = '',
    int? caloriesBurned,
    int? averageHeartRate,
    int? maxHeartRate,
    int? stepCount,
    String? smartwatchDevice,
  }) async {
    final me = _b.requireUser();
    if (sets.isEmpty) {
      throw const BusinessRuleException(
        'Validez au moins une série pour enregistrer la séance.',
      );
    }
    if (durationSec <= 0) {
      throw const ValidationException('Durée de séance invalide.');
    }
    final records = _b.progress.detectRecords(me.id, sets, startedAt);
    final log = SessionLog(
      id: IdGen.next('s_'),
      userId: me.id,
      workoutId: workout.id,
      title: workout.name,
      startedAt: startedAt,
      durationSec: durationSec,
      sets: sets,
      exerciseCount: sets.map((s) => s.exerciseId).toSet().length,
      prCount: records.length,
      note: note.trim(),
      caloriesBurned: caloriesBurned,
      averageHeartRate: averageHeartRate,
      maxHeartRate: maxHeartRate,
      stepCount: stepCount,
      smartwatchDevice: smartwatchDevice,
    );
    await _b.sessions.save(log);
    _b.bus.emit();
    return SessionResult(log, records);
  }

  /// Publie ou retire une séance du fil du club (auteur uniquement).
  /// Chaque décision est tracée dans l'historique des consentements.
  Future<SessionLog> setShared(String sessionId, bool shared) async {
    final me = _b.requireUser();
    final s = _b.sessions.byId(sessionId) ?? (throw const NotFoundException());
    if (s.userId != me.id) throw const PermissionDeniedException();
    if (s.shared == shared) return s;
    final updated = await _b.sessions.save(
      s.copyWith(
        shared: shared,
        sharedAt: shared ? _b.now() : null,
        // Retirer une séance efface aussi les « Bravo » reçus.
        kudos: shared ? s.kudos : const [],
      ),
    );
    await _b.privacy.recordConsent(ConsentType.shareSession, shared);
    _b.bus.emit();
    return updated;
  }

  /// Historique : la personne elle-même ou la salle (super admin).
  List<SessionLog> historyOf(String userId) {
    final me = _b.requireUser();
    if (me.id != userId && !me.isAdmin) throw const PermissionDeniedException();
    return _b.sessions.where((s) => s.userId == userId)
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  /// Séance consultable : la sienne, une séance partagée, ou la salle.
  SessionLog? byId(String id) {
    final me = _b.requireUser();
    final s = _b.sessions.byId(id);
    if (s == null) return null;
    if (s.userId == me.id || me.isAdmin) return s;
    if (s.shared && (_b.users.byId(s.userId)?.active ?? false)) return s;
    return null;
  }

  /// Séances partagées d'un membre (profil public).
  List<SessionLog> sharedSessionsOf(String userId) =>
      _b.sessions.where((s) => s.userId == userId && s.shared)
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  /// Fil de l'accueil : ses propres séances (privées comprises, vues par
  /// soi seul) et, si on le souhaite, les séances **partagées** des autres.
  List<SessionLog> feed({int limit = 30, bool includeOthers = true}) {
    final me = _b.requireUser();
    final all =
        _b.sessions.where((s) {
          if (s.userId == me.id) return true;
          if (!includeOthers || !s.shared) return false;
          return _b.users.byId(s.userId)?.active ?? false;
        })..sort(
          (a, b) =>
              (b.sharedAt ?? b.startedAt).compareTo(a.sharedAt ?? a.startedAt),
        );
    return all.take(limit).toList();
  }

  /// « Bravo » (kudos) sur une séance partagée : ajoute ou retire le sien.
  Future<SessionLog> toggleKudos(String sessionId) async {
    final me = _b.requireUser();
    final s = _b.sessions.byId(sessionId) ?? (throw const NotFoundException());
    if (s.userId == me.id) {
      throw const BusinessRuleException(
        'Vous ne pouvez pas vous féliciter vous-même… mais bravo quand même !',
      );
    }
    if (!s.shared) {
      throw const PermissionDeniedException(
        'Cette séance n\'est pas partagée.',
      );
    }
    final kudos = [...s.kudos];
    final adding = !kudos.remove(me.id);
    if (adding) kudos.add(me.id);
    final updated = await _b.sessions.save(s.copyWith(kudos: kudos));
    if (adding) {
      await _b.notifications.notify(
        s.userId,
        NotificationType.kudos,
        '${me.firstName} vous dit Bravo !',
        'Pour votre séance « ${s.title} ».',
        refId: s.id,
      );
    }
    _b.bus.emit();
    return updated;
  }
}
