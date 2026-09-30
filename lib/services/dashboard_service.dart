import '../models/course.dart';
import '../models/enums.dart';
import 'backend.dart';
import 'progress_service.dart';

/// Indicateurs clés du dashboard super admin.
class AdminStats {
  const AdminStats({
    required this.members,
    required this.coaches,
    required this.activeSubscriptions,
    required this.upcomingCourses,
    required this.doneCourses,
    required this.exercises,
    required this.programs,
    required this.workouts,
    required this.reservations,
    required this.revenue,
    required this.revenueMonth,
    required this.pendingOrders,
  });

  final int members;
  final int coaches;
  final int activeSubscriptions;
  final int upcomingCourses;
  final int doneCourses;
  final int exercises;
  final int programs;
  final int workouts;
  final int reservations;
  final double revenue;
  final double revenueMonth;
  final int pendingOrders;
}

/// Statistiques du coach connecté.
class CoachStats {
  const CoachStats({
    required this.upcoming,
    required this.enrolled,
    required this.attendanceRate,
    required this.averageRating,
    required this.ratingsCount,
    required this.exercises,
    required this.workouts,
  });

  final List<Course> upcoming;
  final int enrolled;
  final double attendanceRate;
  final double? averageRating;
  final int ratingsCount;
  final int exercises;
  final int workouts;
}

/// API interne des tableaux de bord (agrégations sur les autres modules).
class DashboardService {
  DashboardService(this._b);
  final Backend _b;

  AdminStats adminStats() {
    _b.requireRole(Backend.adminOnly);
    final now = _b.now();
    final monthStart = DateTime(now.year, now.month);
    final users = _b.users.all;
    return AdminStats(
      members: users.where((u) => u.isMember).length,
      coaches: users.where((u) => u.isCoach).length,
      activeSubscriptions: users
          .where(
            (u) => u.isMember && u.active && u.subscription.isActiveAt(now),
          )
          .length,
      upcomingCourses: _b.courses.all
          .where((c) => c.statusAt(now) == CourseStatus.scheduled)
          .length,
      doneCourses: _b.courses.all
          .where((c) => c.statusAt(now) == CourseStatus.done)
          .length,
      exercises: _b.exercises.count,
      programs: _b.programs.count,
      workouts: _b.workouts.count,
      reservations: _b.reservations.all.where((r) => r.isActive).length,
      revenue: _b.orderService.revenue(),
      revenueMonth: _b.orderService.revenue(since: monthStart),
      pendingOrders: _b.orders.all
          .where((o) => o.status != OrderStatus.delivered)
          .length,
    );
  }

  /// Inscriptions par semaine (8 dernières semaines).
  List<(DateTime, int)> signupsPerWeek({int weeks = 8}) {
    _b.requireRole(Backend.adminOnly);
    final start = ProgressService.startOfWeek(_b.now());
    return [
      for (var i = weeks - 1; i >= 0; i--)
        () {
          final from = DateTime(start.year, start.month, start.day - 7 * i);
          final to = DateTime(from.year, from.month, from.day + 7);
          final n = _b.users.all
              .where(
                (u) =>
                    u.isMember &&
                    !u.createdAt.isBefore(from) &&
                    u.createdAt.isBefore(to),
              )
              .length;
          return (from, n);
        }(),
    ];
  }

  /// Taux de remplissage des cours programmés et terminés récents.
  List<(Course, double)> fillRates({int limit = 8}) {
    _b.requireRole(Backend.adminOnly);
    final now = _b.now();
    final list =
        _b.courses.all
            .where(
              (c) =>
                  c.statusAt(now) == CourseStatus.scheduled ||
                  c.statusAt(now) == CourseStatus.done,
            )
            .toList()
          ..sort((a, b) => a.startAt!.compareTo(b.startAt!));
    return list
        .take(limit)
        .map((c) => (c, _b.courseService.fillRate(c)))
        .toList();
  }

  /// Cours les plus réservés (par titre).
  List<(String, int)> topCourses({int limit = 5}) {
    _b.requireRole(Backend.adminOnly);
    final counts = <String, int>{};
    for (final r in _b.reservations.all.where(
      (r) => r.status == ReservationStatus.confirmed,
    )) {
      final c = _b.courses.byId(r.courseId);
      if (c != null) counts[c.title] = (counts[c.title] ?? 0) + 1;
    }
    final list = counts.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return list.take(limit).toList();
  }

  /// Produits les plus vendus (quantités).
  List<(String, int)> topProducts({int limit = 5}) {
    _b.requireRole(Backend.adminOnly);
    final counts = <String, int>{};
    for (final o in _b.orders.all) {
      for (final l in o.lines) {
        counts[l.name] = (counts[l.name] ?? 0) + l.quantity;
      }
    }
    final list = counts.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return list.take(limit).toList();
  }

  /// Chiffre d'affaires par semaine (8 dernières semaines).
  List<(DateTime, double)> revenuePerWeek({int weeks = 8}) {
    _b.requireRole(Backend.adminOnly);
    final start = ProgressService.startOfWeek(_b.now());
    return [
      for (var i = weeks - 1; i >= 0; i--)
        () {
          final from = DateTime(start.year, start.month, start.day - 7 * i);
          final to = DateTime(from.year, from.month, from.day + 7);
          final total = _b.orders.all
              .where(
                (o) => !o.createdAt.isBefore(from) && o.createdAt.isBefore(to),
              )
              .fold<double>(0, (s, o) => s + o.total);
          return (from, total);
        }(),
    ];
  }

  CoachStats coachStats() {
    final me = _b.requireRole({UserRole.coach});
    final now = _b.now();
    final mine = _b.courses.all.where((c) => c.coachId == me.id).toList();
    final upcoming =
        mine.where((c) => c.statusAt(now) == CourseStatus.scheduled).toList()
          ..sort((a, b) => a.startAt!.compareTo(b.startAt!));
    final doneIds = mine
        .where((c) => c.statusAt(now) == CourseStatus.done)
        .map((c) => c.id)
        .toSet();
    final doneRes = _b.reservations.all.where(
      (r) =>
          doneIds.contains(r.courseId) &&
          r.status == ReservationStatus.confirmed,
    );
    final marked = doneRes.where((r) => r.attended != null).toList();
    final present = marked.where((r) => r.attended == true).length;
    final ratings = doneRes
        .where((r) => r.rating != null)
        .map((r) => r.rating!);
    final enrolled = upcoming.fold<int>(
      0,
      (s, c) => s + _b.courseService.confirmedCount(c.id),
    );
    return CoachStats(
      upcoming: upcoming,
      enrolled: enrolled,
      attendanceRate: marked.isEmpty ? 0 : present / marked.length,
      averageRating: ratings.isEmpty
          ? null
          : ratings.reduce((a, b) => a + b) / ratings.length,
      ratingsCount: ratings.length,
      exercises: _b.exercises.all.where((e) => e.authorId == me.id).length,
      workouts: _b.workouts.all.where((w) => w.authorId == me.id).length,
    );
  }
}
