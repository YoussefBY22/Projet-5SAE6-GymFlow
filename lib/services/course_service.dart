import '../core/errors.dart';
import '../core/formatters.dart';
import '../models/course.dart';
import '../models/enums.dart';
import '../models/user.dart';
import '../repositories/repository.dart';
import 'backend.dart';

/// Onglets / filtres de la liste des cours.
enum CourseView {
  upcoming('À venir'),
  toPlan('À planifier'),
  done('Terminés'),
  myBookings('Mes réservations'),
  myPast('Mes cours passés');

  const CourseView(this.label);
  final String label;
}

/// API interne des cours collectifs.
class CourseService {
  CourseService(this._b);
  final Backend _b;

  CourseStatus statusOf(Course c) => c.statusAt(_b.now());

  Course? byId(String id) => _b.courses.byId(id);

  List<Course> list({
    CourseView view = CourseView.upcoming,
    String? coachId,
    CourseCategory? category,
    int? weekday,
  }) {
    final me = _b.requireUser();
    final now = _b.now();
    final myActive = {
      for (final r in _b.reservations.where(
        (r) => r.userId == me.id && r.isActive,
      ))
        r.courseId: r,
    };
    final result = _b.courses.where((c) {
      final s = c.statusAt(now);
      final keep = switch (view) {
        CourseView.upcoming => s == CourseStatus.scheduled,
        CourseView.toPlan => s == CourseStatus.toPlan,
        CourseView.done => s == CourseStatus.done,
        CourseView.myBookings =>
          myActive.containsKey(c.id) && s == CourseStatus.scheduled,
        CourseView.myPast =>
          s == CourseStatus.done &&
              myActive[c.id]?.status == ReservationStatus.confirmed,
      };
      if (!keep) return false;
      if (coachId != null && c.coachId != coachId) return false;
      if (category != null && c.category != category) return false;
      if (weekday != null && c.startAt?.weekday != weekday) return false;
      return true;
    });
    result.sort((a, b) {
      final da = a.startAt ?? a.createdAt;
      final db = b.startAt ?? b.createdAt;
      return view == CourseView.done || view == CourseView.myPast
          ? db.compareTo(da)
          : da.compareTo(db);
    });
    return result;
  }

  /// Cours à venir d'un coach (dashboard coach).
  List<Course> coachUpcoming(String coachId) => list(
    view: CourseView.upcoming,
    coachId: coachId,
  );

  int confirmedCount(String courseId) => _b.reservations
      .where(
        (r) => r.courseId == courseId && r.status == ReservationStatus.confirmed,
      )
      .length;

  int waitlistCount(String courseId) => _b.reservations
      .where(
        (r) => r.courseId == courseId && r.status == ReservationStatus.waitlisted,
      )
      .length;

  double fillRate(Course c) =>
      c.capacity == 0 ? 0 : (confirmedCount(c.id) / c.capacity).clamp(0, 1);

  /// Note moyenne (null si aucune note).
  double? averageRating(String courseId) {
    final notes = _b.reservations
        .where((r) => r.courseId == courseId && r.rating != null)
        .map((r) => r.rating!)
        .toList();
    if (notes.isEmpty) return null;
    return notes.reduce((a, b) => a + b) / notes.length;
  }

  /// Nouveautés pour la bannière : cours programmés créés récemment.
  List<Course> newCourses({int days = 14}) {
    final now = _b.now();
    final since = now.subtract(Duration(days: days));
    return _b.courses.where(
        (c) =>
            c.statusAt(now) == CourseStatus.scheduled &&
            c.createdAt.isAfter(since),
      )
      ..sort((a, b) => a.startAt!.compareTo(b.startAt!));
  }

  bool canManage(AppUser u, Course c) =>
      u.isAdmin || (u.isCoach && c.coachId == u.id);

  Future<Course> save({
    String? id,
    required String title,
    required String description,
    required CourseCategory category,
    required Level level,
    required String coachId,
    required String room,
    required int capacity,
    required int durationMin,
    DateTime? startAt,
    bool priceIncluded = true,
    double price = 0,
    String? imageUrl,
  }) async {
    final me = _b.requireRole(Backend.staff);
    // Un coach ne crée que ses propres cours ; l'admin affecte un coach.
    final effectiveCoach = me.isCoach ? me.id : coachId;
    final coach = _b.users.byId(effectiveCoach);
    if (coach == null || !coach.isCoach || !coach.active) {
      throw const ValidationException('Choisissez un coach actif.');
    }
    if (title.trim().length < 3) {
      throw const ValidationException('Titre : 3 caractères minimum.');
    }
    if (capacity < 1 || capacity > 100) {
      throw const ValidationException('Capacité : entre 1 et 100 places.');
    }
    if (durationMin < 15 || durationMin > 180) {
      throw const ValidationException('Durée : entre 15 et 180 minutes.');
    }
    if (!priceIncluded && (price <= 0 || price > 500)) {
      throw const ValidationException('Prix : entre 0,5 et 500 TND.');
    }
    final now = _b.now();
    if (startAt != null && !startAt.isAfter(now)) {
      throw const ValidationException('La date doit être dans le futur.');
    }

    if (id == null) {
      final c = Course(
        id: IdGen.next('c_'),
        title: title.trim(),
        description: description.trim(),
        category: category,
        level: level,
        coachId: effectiveCoach,
        room: room.trim(),
        capacity: capacity,
        durationMin: durationMin,
        createdAt: now,
        startAt: startAt,
        priceIncluded: priceIncluded,
        price: priceIncluded ? 0 : price,
        imageUrl: imageUrl,
      );
      await _b.courses.save(c);
      if (effectiveCoach != me.id) {
        await _b.notifications.notify(
          effectiveCoach,
          NotificationType.course,
          'Nouveau cours affecté',
          '« ${c.title} » ${startAt == null ? '(à planifier)' : 'le ${Fmt.dateTime(startAt)}'}.',
          route: '/courses/detail',
          refId: c.id,
        );
      }
      _b.bus.emit();
      return c;
    }

    final existing = _b.courses.byId(id) ?? (throw const NotFoundException());
    if (!canManage(me, existing)) {
      throw const PermissionDeniedException(
        'Un coach ne peut modifier que ses propres cours.',
      );
    }
    if (existing.statusAt(now) == CourseStatus.done) {
      throw const BusinessRuleException('Un cours terminé ne peut plus être modifié.');
    }
    if (capacity < confirmedCount(id)) {
      throw ValidationException(
        'Capacité inférieure au nombre d\'inscrits (${confirmedCount(id)}).',
      );
    }
    final updated = existing.copyWith(
      title: title.trim(),
      description: description.trim(),
      category: category,
      level: level,
      coachId: effectiveCoach,
      room: room.trim(),
      capacity: capacity,
      durationMin: durationMin,
      startAt: startAt,
      clearStart: startAt == null,
      priceIncluded: priceIncluded,
      price: priceIncluded ? 0 : price,
      imageUrl: imageUrl,
    );
    await _b.courses.save(updated);

    final timeChanged = existing.startAt != updated.startAt;
    final active = _b.reservations.where((r) => r.courseId == id && r.isActive);
    for (final r in active) {
      await _b.notifications.notify(
        r.userId,
        NotificationType.course,
        timeChanged ? 'Horaire modifié : ${updated.title}' : 'Cours modifié : ${updated.title}',
        updated.startAt == null
            ? 'Le cours repasse « à planifier ».'
            : 'Nouveau créneau : ${Fmt.dateTime(updated.startAt!)} · ${updated.room}.',
        route: '/courses/detail',
        refId: id,
      );
      if (timeChanged && r.status == ReservationStatus.confirmed) {
        await _b.notifications.cancelCourseReminders(r.id);
        await _b.notifications.scheduleCourseReminders(r, updated);
      }
    }
    // Des places supplémentaires libèrent la liste d'attente.
    await _b.reservationService.promoteWaitlist(id);
    _b.bus.emit();
    return updated;
  }

  /// Annulation d'un cours : les inscrits sont prévenus.
  Future<void> cancel(String id, String reason) async {
    final me = _b.requireRole(Backend.staff);
    final c = _b.courses.byId(id) ?? (throw const NotFoundException());
    if (!canManage(me, c)) throw const PermissionDeniedException();
    if (c.statusAt(_b.now()) == CourseStatus.done) {
      throw const BusinessRuleException('Ce cours est déjà terminé.');
    }
    await _b.courses.save(
      c.copyWith(cancelled: true, cancelReason: reason.trim()),
    );
    for (final r in _b.reservations.where((r) => r.courseId == id && r.isActive)) {
      await _b.reservations.save(r.copyWith(status: ReservationStatus.cancelled));
      await _b.notifications.cancelCourseReminders(r.id);
      await _b.notifications.notify(
        r.userId,
        NotificationType.course,
        'Cours annulé : ${c.title}',
        reason.trim().isEmpty
            ? 'Nous sommes désolés pour ce changement.'
            : 'Motif : ${reason.trim()}',
        route: '/courses/detail',
        refId: id,
      );
    }
    await _b.audit.log('Annulation de cours', c.title, targetId: id);
    _b.bus.emit();
  }
}
