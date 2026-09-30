import '../core/errors.dart';
import '../models/enums.dart';
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
class TrainingLogService {
  TrainingLogService(this._b);
  final Backend _b;

  /// Enregistre une séance terminée depuis le lecteur de séance.
  Future<SessionResult> finishSession({
    required Workout workout,
    required DateTime startedAt,
    required int durationSec,
    required List<SetLog> sets,
    String note = '',
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
    );
    await _b.sessions.save(log);
    _b.bus.emit();
    return SessionResult(log, records);
  }

  List<SessionLog> historyOf(String userId) {
    final me = _b.requireUser();
    if (me.id != userId && me.isMember) throw const PermissionDeniedException();
    return _b.sessions.where((s) => s.userId == userId)
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  SessionLog? byId(String id) => _b.sessions.byId(id);

  /// Fil d'activités du club (toutes les séances, les plus récentes d'abord).
  List<SessionLog> feed({int limit = 30}) {
    _b.requireUser();
    final all = _b.sessions.all.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return all.take(limit).toList();
  }

  /// « Bravo » (kudos) : ajoute ou retire le sien, notifie l'auteur.
  Future<SessionLog> toggleKudos(String sessionId) async {
    final me = _b.requireUser();
    final s = _b.sessions.byId(sessionId) ?? (throw const NotFoundException());
    if (s.userId == me.id) {
      throw const BusinessRuleException(
        'Vous ne pouvez pas vous féliciter vous-même… mais bravo quand même !',
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
