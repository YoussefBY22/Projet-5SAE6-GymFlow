import '../core/ticket_qr.dart';
import '../core/errors.dart';
import '../core/formatters.dart';
import '../models/course.dart';
import '../models/enums.dart';
import '../models/user.dart';
import 'backend.dart';

/// Résultat d'une validation de présence.
class CheckInResult {
  const CheckInResult({
    required this.reservation,
    required this.member,
    required this.course,
    required this.alreadyDone,
  });

  final Reservation reservation;
  final AppUser? member;
  final Course course;

  /// Le ticket avait déjà été validé (pas une erreur).
  final bool alreadyDone;

  String get message => alreadyDone
      ? 'Présence déjà validée à ${Fmt.time(reservation.checkedInAt!)}'
      : 'Présence validée : ${member?.fullName ?? 'abonné'}';
}

/// Validation de présence par code de réservation (ticket QR).
///
/// Une seule entrée, [validate], qui reçoit le texte du code : saisie
/// manuelle aujourd'hui, et demain la valeur lue par un scanner (caméra),
/// sans rien changer aux règles. Tous les contrôles sont faits ici.
class CheckInService {
  CheckInService(this._b);
  final Backend _b;

  /// Fenêtre de validation : de 30 min avant le début à 30 min après la fin.
  static const before = Duration(minutes: 30);
  static const after = Duration(minutes: 30);

  static const auditAction = 'Présence validée par QR';

  Future<CheckInResult> validate(String input) async {
    final me = _b.requireRole(Backend.staff);
    final code = TicketQr.extractCode(input);
    if (code == null) {
      throw const ValidationException(
        'Aucun code de réservation trouvé (format GF-XXXX-XXXX).',
      );
    }
    Reservation? r;
    for (final x in _b.reservations.all) {
      if (x.bookingCode == code) {
        r = x;
        break;
      }
    }
    if (r == null) throw const NotFoundException('Code inconnu.');
    final c = _b.courses.byId(r.courseId) ?? (throw const NotFoundException());
    if (!_b.courseService.canManage(me, c)) {
      throw const PermissionDeniedException('Ce cours n\'est pas le vôtre.');
    }
    if (r.status == ReservationStatus.cancelled) {
      throw const BusinessRuleException('Réservation annulée.');
    }
    if (r.status != ReservationStatus.confirmed) {
      throw const BusinessRuleException(
        'Réservation en liste d\'attente : aucune place confirmée.',
      );
    }
    if (c.cancelled) {
      throw const BusinessRuleException('Ce cours a été annulé.');
    }
    final member = _b.users.byId(r.userId);
    if (r.checkedInAt != null) {
      return CheckInResult(
        reservation: r,
        member: member,
        course: c,
        alreadyDone: true,
      );
    }
    final now = _b.now();
    if (c.startAt == null ||
        now.isBefore(c.startAt!.subtract(before)) ||
        now.isAfter(c.endAt!.add(after))) {
      throw BusinessRuleException(
        c.startAt == null
            ? 'Ce cours n\'a pas lieu maintenant (date à venir).'
            : 'Ce cours n\'a pas lieu maintenant '
                  '(${Fmt.dateTime(c.startAt!)}).',
      );
    }
    final saved = await _b.reservationService.applyAttendance(
      r,
      true,
      checkedInAt: now,
      checkedInBy: me.id,
    );
    await _b.audit.log(
      auditAction,
      '${member?.fullName ?? 'Abonné'} · ${c.title} · $code',
      targetId: r.id,
    );
    return CheckInResult(
      reservation: saved,
      member: member,
      course: c,
      alreadyDone: false,
    );
  }
}
