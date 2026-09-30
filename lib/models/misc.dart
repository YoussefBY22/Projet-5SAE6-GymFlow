import 'enums.dart';
import 'json.dart';

/// Notification du centre de notifications de l'application.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.route,
    this.refId,
  });

  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  /// Route nommée à ouvrir au toucher (ex. détail du cours).
  final String? route;
  final String? refId;

  AppNotification markRead() => AppNotification(
    id: id,
    userId: userId,
    type: type,
    title: title,
    body: body,
    createdAt: createdAt,
    read: true,
    route: route,
    refId: refId,
  );

  Json toJson() => {
    'id': id,
    'userId': userId,
    'type': type.name,
    'title': title,
    'body': body,
    'createdAt': dateToJson(createdAt),
    'read': read,
    'route': route,
    'refId': refId,
  };

  factory AppNotification.fromJson(Json j) => AppNotification(
    id: j['id'] as String,
    userId: j['userId'] as String,
    type: enumFrom(NotificationType.values, j['type'], NotificationType.system),
    title: j['title'] as String,
    body: j['body'] as String? ?? '',
    createdAt: dateOr(j['createdAt'], DateTime(2026)),
    read: j['read'] as bool? ?? false,
    route: j['route'] as String?,
    refId: j['refId'] as String?,
  );
}

/// Journal d'audit des actions sensibles (admin).
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.action,
    required this.details,
    required this.createdAt,
    this.targetId,
  });

  final String id;
  final String actorId;
  final String actorName;
  final String action;
  final String details;
  final String? targetId;
  final DateTime createdAt;

  Json toJson() => {
    'id': id,
    'actorId': actorId,
    'actorName': actorName,
    'action': action,
    'details': details,
    'targetId': targetId,
    'createdAt': dateToJson(createdAt),
  };

  factory AuditEntry.fromJson(Json j) => AuditEntry(
    id: j['id'] as String,
    actorId: j['actorId'] as String,
    actorName: j['actorName'] as String? ?? '',
    action: j['action'] as String,
    details: j['details'] as String? ?? '',
    targetId: j['targetId'] as String?,
    createdAt: dateOr(j['createdAt'], DateTime(2026)),
  );
}

/// Annonce du club (affichée dans la bannière et la page Annonces).
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.authorId,
    required this.createdAt,
    this.imageUrl,
    this.pinned = false,
  });

  final String id;
  final String title;
  final String body;
  final String authorId;
  final DateTime createdAt;
  final String? imageUrl;
  final bool pinned;

  Json toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'authorId': authorId,
    'createdAt': dateToJson(createdAt),
    'imageUrl': imageUrl,
    'pinned': pinned,
  };

  factory Announcement.fromJson(Json j) => Announcement(
    id: j['id'] as String,
    title: j['title'] as String,
    body: j['body'] as String? ?? '',
    authorId: j['authorId'] as String? ?? '',
    createdAt: dateOr(j['createdAt'], DateTime(2026)),
    imageUrl: j['imageUrl'] as String?,
    pinned: j['pinned'] as bool? ?? false,
  );
}
