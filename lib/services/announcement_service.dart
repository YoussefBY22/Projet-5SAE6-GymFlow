import '../core/errors.dart';
import '../core/formatters.dart';
import '../models/enums.dart';
import '../models/misc.dart';
import '../repositories/repository.dart';
import 'backend.dart';

/// Élément de la bannière défilante de l'accueil.
class BannerItem {
  const BannerItem({
    required this.title,
    required this.subtitle,
    required this.badge,
    this.imageUrl,
    this.route,
    this.argument,
    this.isNew = false,
  });

  final String title;
  final String subtitle;
  final String badge;
  final String? imageUrl;
  final String? route;
  final Object? argument;
  final bool isNew;
}

/// API interne des annonces du club et de la bannière de l'accueil.
class AnnouncementService {
  AnnouncementService(this._b);
  final Backend _b;

  List<Announcement> list() {
    _b.requireUser();
    return _b.announcementsRepo.all.toList()..sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  Future<Announcement> publish(
    String title,
    String body, {
    String? imageUrl,
  }) async {
    final admin = _b.requireRole(Backend.adminOnly);
    if (title.trim().length < 4) {
      throw const ValidationException('Titre : 4 caractères minimum.');
    }
    if (body.trim().length < 10) {
      throw const ValidationException('Message : 10 caractères minimum.');
    }
    final a = await _b.announcementsRepo.save(
      Announcement(
        id: IdGen.next('an_'),
        title: title.trim(),
        body: body.trim(),
        authorId: admin.id,
        createdAt: _b.now(),
        imageUrl: imageUrl,
      ),
    );
    for (final u in _b.users.all.where((u) => u.active && u.id != admin.id)) {
      await _b.notifications.notify(
        u.id,
        NotificationType.announcement,
        a.title,
        a.body,
        route: '/announcements',
      );
    }
    await _b.audit.log('Annonce publiée', a.title, targetId: a.id);
    _b.bus.emit();
    return a;
  }

  Future<void> delete(String id) async {
    _b.requireRole(Backend.adminOnly);
    await _b.announcementsRepo.delete(id);
    _b.bus.emit();
  }

  /// Bannière : nouveaux cours (avec date), promos boutique, annonces.
  List<BannerItem> bannerItems() {
    final items = <BannerItem>[];
    for (final c in _b.courseService.newCourses().take(3)) {
      items.add(
        BannerItem(
          title: c.title,
          subtitle: '${Fmt.dateTime(c.startAt!)} · ${c.room}',
          badge: 'Nouveau cours',
          imageUrl: c.imageUrl,
          route: '/courses/detail',
          argument: c.id,
          isNew: true,
        ),
      );
    }
    final promos = _b.products.all.where((p) => p.active && p.onPromo).take(2);
    for (final p in promos) {
      items.add(
        BannerItem(
          title: p.name,
          subtitle:
              '-${p.discountPercent} % · ${Fmt.money(p.effectivePrice)} au lieu de ${Fmt.money(p.price)}',
          badge: 'Promo boutique',
          imageUrl: p.images.isEmpty ? null : p.images.first,
          route: '/shop/product',
          argument: p.id,
        ),
      );
    }
    for (final a in list().take(2)) {
      items.add(
        BannerItem(
          title: a.title,
          subtitle: a.body,
          badge: 'Club',
          imageUrl: a.imageUrl,
          route: '/announcements',
        ),
      );
    }
    return items;
  }
}
