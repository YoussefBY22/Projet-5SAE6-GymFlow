import 'package:flutter/foundation.dart';

import '../core/formatters.dart';
import '../models/course.dart';
import '../models/enums.dart';
import '../models/misc.dart';
import '../repositories/repository.dart';
import 'backend.dart';

/// Centre de notifications (in-app) + rappels locaux du téléphone.
class NotificationService extends ChangeNotifier {
  NotificationService(this._b);
  final Backend _b;

  Future<AppNotification> notify(
    String userId,
    NotificationType type,
    String title,
    String body, {
    String? route,
    String? refId,
  }) async {
    final n = await _b.notificationsRepo.save(
      AppNotification(
        id: IdGen.next('n_'),
        userId: userId,
        type: type,
        title: title,
        body: body,
        createdAt: _b.now(),
        route: route,
        refId: refId,
      ),
    );
    notifyListeners();
    return n;
  }

  List<AppNotification> mine() {
    final u = _b.requireUser();
    return _b.notificationsRepo.where((n) => n.userId == u.id)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int get unreadCount {
    final u = _b.auth.currentUser;
    if (u == null) return 0;
    return _b.notificationsRepo
        .where((n) => n.userId == u.id && !n.read)
        .length;
  }

  Future<void> markRead(String id) async {
    final u = _b.requireUser();
    final n = _b.notificationsRepo.byId(id);
    if (n == null || n.userId != u.id || n.read) return;
    await _b.notificationsRepo.save(n.markRead());
    notifyListeners();
  }

  Future<void> markAllRead() async {
    final u = _b.requireUser();
    final unread = _b.notificationsRepo.where(
      (n) => n.userId == u.id && !n.read,
    );
    await _b.notificationsRepo.saveAll(unread.map((n) => n.markRead()));
    notifyListeners();
  }

  /// Identifiant stable d'un rappel (réservation + décalage).
  static int reminderId(String reservationId, int hoursBefore) =>
      (reservationId.hashCode ^ (hoursBefore * 7919)) & 0x7fffffff;

  /// Planifie les rappels 24 h et 1 h avant le cours.
  Future<void> scheduleCourseReminders(Reservation r, Course c) async {
    final start = c.startAt;
    if (start == null) return;
    for (final h in const [24, 1]) {
      await _b.notifier.schedule(
        reminderId(r.id, h),
        h == 24 ? 'Demain : ${c.title}' : 'Dans 1 h : ${c.title}',
        '${Fmt.dateTime(start)} · ${c.room}',
        start.subtract(Duration(hours: h)),
      );
    }
  }

  Future<void> cancelCourseReminders(String reservationId) async {
    for (final h in const [24, 1]) {
      await _b.notifier.cancel(reminderId(reservationId, h));
    }
  }
}
