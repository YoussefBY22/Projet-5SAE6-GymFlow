import '../core/config.dart';
import '../core/errors.dart';
import '../core/formatters.dart';
import '../models/course.dart';
import '../models/enums.dart';
import '../models/user.dart';
import '../repositories/repository.dart';
import 'backend.dart';

/// API interne des réservations : règles de réservation, liste d'attente,
/// annulation, présence et notation.
class ReservationService {
  ReservationService(this._b);
  final Backend _b;

  /// Réservation active (confirmée ou en attente) de l'utilisateur.
  Reservation? activeFor(String courseId, String userId) {
    for (final r in _b.reservations.all) {
      if (r.courseId == courseId && r.userId == userId && r.isActive) return r;
    }
    return null;
  }

  /// Réservation (même annulée) la plus récente, pour la notation.
  Reservation? latestFor(String courseId, String userId) {
    final list = _b.reservations.where(
      (r) => r.courseId == courseId && r.userId == userId,
    )..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.isEmpty ? null : list.first;
  }

  /// Rang dans la liste d'attente (1 = prochain promu).
  int waitlistPosition(Reservation r) {
    final queue = _waitlist(r.courseId);
    return queue.indexWhere((x) => x.id == r.id) + 1;
  }

  List<Reservation> _waitlist(String courseId) => _b.reservations.where(
    (r) => r.courseId == courseId && r.status == ReservationStatus.waitlisted,
  )..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// Réserve une place. Refus si : cours non programmé, abonnement expiré,
  /// déjà inscrit, chevauchement avec une autre réservation, ou cours
  /// complet (sauf si [joinWaitlist] : inscription en liste d'attente).
  Future<Reservation> book(String courseId, {bool joinWaitlist = false}) async {
    final me = _b.requireRole({UserRole.member});
    final c = _b.courses.byId(courseId) ?? (throw const NotFoundException());
    final now = _b.now();
    final status = c.statusAt(now);
    if (status != CourseStatus.scheduled) {
      throw BusinessRuleException(switch (status) {
        CourseStatus.toPlan => 'Ce cours n\'a pas encore de date.',
        CourseStatus.done => 'Ce cours est terminé.',
        _ => 'Ce cours a été annulé.',
      });
    }
    if (!me.subscription.isActiveAt(c.startAt!)) {
      throw const BusinessRuleException(
        'Votre abonnement a expiré (ou expire avant ce cours). '
        'Renouvelez-le à l\'accueil pour réserver.',
      );
    }
    if (activeFor(courseId, me.id) != null) {
      throw const BusinessRuleException('Vous êtes déjà inscrit à ce cours.');
    }
    for (final r in _b.reservations.where(
      (r) => r.userId == me.id && r.isActive,
    )) {
      final other = _b.courses.byId(r.courseId);
      if (other != null &&
          other.statusAt(now) == CourseStatus.scheduled &&
          other.overlaps(c)) {
        throw BusinessRuleException(
          'Chevauchement avec « ${other.title} » '
          '(${Fmt.time(other.startAt!)}–${Fmt.time(other.endAt!)}).',
        );
      }
    }
    final full = _b.courseService.confirmedCount(courseId) >= c.capacity;
    if (full && !joinWaitlist) {
      throw const BusinessRuleException(
        'Cours complet. Rejoignez la liste d\'attente pour être prévenu.',
      );
    }
    final r = Reservation(
      id: IdGen.next('r_'),
      courseId: courseId,
      userId: me.id,
      status: full ? ReservationStatus.waitlisted : ReservationStatus.confirmed,
      createdAt: now,
    );
    await _b.reservations.save(r);
    if (full) {
      await _b.notifications.notify(
        me.id,
        NotificationType.waitlist,
        'Liste d\'attente : ${c.title}',
        'Vous êtes n°${waitlistPosition(r)}. Nous vous prévenons dès qu\'une place se libère.',
        route: '/courses/detail',
        refId: c.id,
      );
    } else {
      await _confirmSideEffects(r, c);
    }
    _b.bus.emit();
    return r;
  }

  Future<void> _confirmSideEffects(Reservation r, Course c) async {
    await _b.notifications.scheduleCourseReminders(r, c);
    await _b.notifications.notify(
      r.userId,
      NotificationType.reservation,
      'Réservation confirmée',
      '${c.title} · ${Fmt.dateTime(c.startAt!)} · ${c.room}',
      route: '/courses/detail',
      refId: c.id,
    );
  }

  /// Annulation par l'abonné : libre jusqu'à 2 h avant le début.
  Future<void> cancel(String reservationId) async {
    final me = _b.requireUser();
    final r =
        _b.reservations.byId(reservationId) ??
        (throw const NotFoundException());
    if (r.userId != me.id) throw const PermissionDeniedException();
    if (!r.isActive) {
      throw const BusinessRuleException('Réservation déjà annulée.');
    }
    final c = _b.courses.byId(r.courseId) ?? (throw const NotFoundException());
    final now = _b.now();
    if (r.status == ReservationStatus.confirmed) {
      if (c.statusAt(now) == CourseStatus.done) {
        throw const BusinessRuleException('Ce cours est terminé.');
      }
      if (c.startAt != null &&
          c.startAt!.difference(now) < AppConfig.cancelDeadline) {
        throw const BusinessRuleException(
          'Annulation impossible moins de 2 h avant le début du cours.',
        );
      }
    }
    final wasConfirmed = r.status == ReservationStatus.confirmed;
    await _b.reservations.save(r.copyWith(status: ReservationStatus.cancelled));
    await _b.notifications.cancelCourseReminders(r.id);
    if (wasConfirmed) await promoteWaitlist(c.id);
    _b.bus.emit();
  }

  /// Promotion automatique de la liste d'attente quand des places se libèrent.
  Future<void> promoteWaitlist(String courseId) async {
    final c = _b.courses.byId(courseId);
    if (c == null || c.statusAt(_b.now()) != CourseStatus.scheduled) return;
    var free = c.capacity - _b.courseService.confirmedCount(courseId);
    for (final next in _waitlist(courseId)) {
      if (free <= 0) break;
      final promoted = next.copyWith(status: ReservationStatus.confirmed);
      await _b.reservations.save(promoted);
      await _b.notifications.scheduleCourseReminders(promoted, c);
      await _b.notifications.notify(
        next.userId,
        NotificationType.waitlist,
        'Bonne nouvelle : une place s\'est libérée !',
        'Votre réservation pour « ${c.title} » est confirmée '
            '(${Fmt.dateTime(c.startAt!)}).',
        route: '/courses/detail',
        refId: c.id,
      );
      free--;
    }
  }

  /// Inscrits d'un cours (coach du cours ou admin).
  List<(Reservation, AppUser)> participants(String courseId) {
    final me = _b.requireRole(Backend.staff);
    final c = _b.courses.byId(courseId) ?? (throw const NotFoundException());
    if (!_b.courseService.canManage(me, c)) {
      throw const PermissionDeniedException();
    }
    final list = <(Reservation, AppUser)>[];
    for (final r in _b.reservations.where(
      (r) => r.courseId == courseId && r.isActive,
    )) {
      final u = _b.users.byId(r.userId);
      if (u != null) list.add((r, u));
    }
    list.sort((a, b) {
      final s = a.$1.status.index.compareTo(b.$1.status.index);
      return s != 0 ? s : a.$1.createdAt.compareTo(b.$1.createdAt);
    });
    return list;
  }

  /// Pointage de présence (à partir de 15 min avant le début).
  Future<void> markAttendance(String reservationId, bool attended) async {
    final me = _b.requireRole(Backend.staff);
    final r =
        _b.reservations.byId(reservationId) ??
        (throw const NotFoundException());
    final c = _b.courses.byId(r.courseId) ?? (throw const NotFoundException());
    if (!_b.courseService.canManage(me, c)) {
      throw const PermissionDeniedException();
    }
    if (r.status != ReservationStatus.confirmed) {
      throw const BusinessRuleException(
        'Seuls les inscrits confirmés sont pointés.',
      );
    }
    if (c.startAt == null ||
        _b.now().isBefore(c.startAt!.subtract(const Duration(minutes: 15)))) {
      throw const BusinessRuleException(
        'La présence se marque à partir de 15 min avant le cours.',
      );
    }
    await _b.reservations.save(r.copyWith(attended: attended));
    _b.bus.emit();
  }

  /// Note (1 à 5 étoiles) après un cours terminé.
  Future<void> rate(String reservationId, int stars, {String? comment}) async {
    final me = _b.requireUser();
    final r =
        _b.reservations.byId(reservationId) ??
        (throw const NotFoundException());
    if (r.userId != me.id) throw const PermissionDeniedException();
    final c = _b.courses.byId(r.courseId) ?? (throw const NotFoundException());
    if (c.statusAt(_b.now()) != CourseStatus.done) {
      throw const BusinessRuleException(
        'Vous pourrez noter ce cours une fois terminé.',
      );
    }
    if (r.status != ReservationStatus.confirmed || r.attended == false) {
      throw const BusinessRuleException(
        'Seuls les participants peuvent noter.',
      );
    }
    if (stars < 1 || stars > 5) {
      throw const ValidationException('Note : de 1 à 5 étoiles.');
    }
    await _b.reservations.save(
      r.copyWith(rating: stars, comment: comment?.trim()),
    );
    _b.bus.emit();
  }

  /// Prochain cours confirmé de l'abonné (accueil).
  (Reservation, Course)? nextBooking(String userId) {
    final now = _b.now();
    (Reservation, Course)? best;
    for (final r in _b.reservations.where(
      (r) => r.userId == userId && r.status == ReservationStatus.confirmed,
    )) {
      final c = _b.courses.byId(r.courseId);
      if (c == null || c.statusAt(now) != CourseStatus.scheduled) continue;
      if (best == null || c.startAt!.isBefore(best.$2.startAt!)) best = (r, c);
    }
    return best;
  }

  /// Cours suivis (terminés, confirmés) par l'abonné.
  List<(Reservation, Course)> attendedCourses(String userId) {
    final now = _b.now();
    final list = <(Reservation, Course)>[];
    for (final r in _b.reservations.where(
      (r) => r.userId == userId && r.status == ReservationStatus.confirmed,
    )) {
      final c = _b.courses.byId(r.courseId);
      if (c != null && c.statusAt(now) == CourseStatus.done) list.add((r, c));
    }
    list.sort((a, b) => b.$2.startAt!.compareTo(a.$2.startAt!));
    return list;
  }
}
