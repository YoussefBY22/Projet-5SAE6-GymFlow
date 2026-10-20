import 'enums.dart';
import 'json.dart';
import 'sentiment.dart';

/// Cours collectif. Le statut est calculé à partir de la date :
/// sans date → « À planifier », date future → « Programmé »,
/// fin passée → « Terminé » (transition automatique).
class Course {
  const Course({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.level,
    required this.coachId,
    required this.room,
    required this.capacity,
    required this.durationMin,
    required this.createdAt,
    this.startAt,
    this.priceIncluded = true,
    this.price = 0,
    this.imageUrl,
    this.cancelled = false,
    this.cancelReason,
  });

  final String id;
  final String title;
  final String description;
  final CourseCategory category;
  final Level level;
  final String coachId;
  final String room;
  final int capacity;
  final int durationMin;
  final DateTime createdAt;

  /// `null` tant que le cours est « À planifier ».
  final DateTime? startAt;
  final bool priceIncluded;
  final double price;
  final String? imageUrl;
  final bool cancelled;
  final String? cancelReason;

  DateTime? get endAt => startAt?.add(Duration(minutes: durationMin));

  CourseStatus statusAt(DateTime now) {
    if (cancelled) return CourseStatus.cancelled;
    if (startAt == null) return CourseStatus.toPlan;
    if (!endAt!.isAfter(now)) return CourseStatus.done;
    return CourseStatus.scheduled;
  }

  /// Vrai si les créneaux de deux cours se chevauchent.
  bool overlaps(Course other) {
    if (startAt == null || other.startAt == null) return false;
    return startAt!.isBefore(other.endAt!) && other.startAt!.isBefore(endAt!);
  }

  Course copyWith({
    String? title,
    String? description,
    CourseCategory? category,
    Level? level,
    String? coachId,
    String? room,
    int? capacity,
    int? durationMin,
    DateTime? startAt,
    bool clearStart = false,
    bool? priceIncluded,
    double? price,
    String? imageUrl,
    bool? cancelled,
    String? cancelReason,
  }) => Course(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    category: category ?? this.category,
    level: level ?? this.level,
    coachId: coachId ?? this.coachId,
    room: room ?? this.room,
    capacity: capacity ?? this.capacity,
    durationMin: durationMin ?? this.durationMin,
    createdAt: createdAt,
    startAt: clearStart ? null : (startAt ?? this.startAt),
    priceIncluded: priceIncluded ?? this.priceIncluded,
    price: price ?? this.price,
    imageUrl: imageUrl ?? this.imageUrl,
    cancelled: cancelled ?? this.cancelled,
    cancelReason: cancelReason ?? this.cancelReason,
  );

  Json toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category.name,
    'level': level.name,
    'coachId': coachId,
    'room': room,
    'capacity': capacity,
    'durationMin': durationMin,
    'createdAt': dateToJson(createdAt),
    'startAt': dateToJson(startAt),
    'priceIncluded': priceIncluded,
    'price': price,
    'imageUrl': imageUrl,
    'cancelled': cancelled,
    'cancelReason': cancelReason,
  };

  factory Course.fromJson(Json j) => Course(
    id: j['id'] as String,
    title: j['title'] as String,
    description: j['description'] as String? ?? '',
    category: enumFrom(
      CourseCategory.values,
      j['category'],
      CourseCategory.strength,
    ),
    level: enumFrom(Level.values, j['level'], Level.beginner),
    coachId: j['coachId'] as String,
    room: j['room'] as String? ?? '',
    capacity: toInt(j['capacity'], 10),
    durationMin: toInt(j['durationMin'], 45),
    createdAt: dateOr(j['createdAt'], DateTime(2026)),
    startAt: dateFromJson(j['startAt']),
    priceIncluded: j['priceIncluded'] as bool? ?? true,
    price: toDouble(j['price']),
    imageUrl: j['imageUrl'] as String?,
    cancelled: j['cancelled'] as bool? ?? false,
    cancelReason: j['cancelReason'] as String?,
  );
}

/// Statut de l'email de confirmation d'une réservation.
enum EmailStatus {
  sent('Email envoyé'),
  failed('Email non envoyé'),
  notConfigured('Email non configuré');

  const EmailStatus(this.label);
  final String label;
}

/// Dernier envoi de l'email de confirmation (EmailJS). Aucune clé n'y
/// figure : seulement l'adresse réellement utilisée et une raison lisible.
class EmailDelivery {
  const EmailDelivery({
    required this.status,
    required this.attemptedAt,
    this.sentAt,
    this.to,
    this.error,
  });

  final EmailStatus status;

  /// Dernière tentative (sert à limiter les renvois).
  final DateTime attemptedAt;
  final DateTime? sentAt;

  /// Adresse réellement utilisée (destinataire de démo le cas échéant).
  final String? to;
  final String? error;

  Json toJson() => {
    'status': status.name,
    'attemptedAt': dateToJson(attemptedAt),
    'sentAt': dateToJson(sentAt),
    'to': to,
    'error': error,
  };

  static EmailDelivery? fromJson(Object? v) {
    if (v is! Map) return null;
    return EmailDelivery(
      status: enumFrom(EmailStatus.values, v['status'], EmailStatus.failed),
      attemptedAt: dateOr(v['attemptedAt'], DateTime(2026)),
      sentAt: dateFromJson(v['sentAt']),
      to: v['to'] as String?,
      error: v['error'] as String?,
    );
  }
}

/// Réservation d'un abonné sur un cours.
class Reservation {
  const Reservation({
    required this.id,
    required this.courseId,
    required this.userId,
    required this.status,
    required this.createdAt,
    this.attended,
    this.rating,
    this.comment,
    this.sentiment,
    this.bookingCode,
    this.email,
    this.checkedInAt,
    this.checkedInBy,
  });

  final String id;
  final String courseId;
  final String userId;
  final ReservationStatus status;
  final DateTime createdAt;

  /// Présence marquée par le coach (`null` = pas encore pointée).
  final bool? attended;

  /// Note de 1 à 5 étoiles après le cours.
  final int? rating;
  final String? comment;

  /// Ton du commentaire, analysé une seule fois à l'envoi
  /// (`null` = pas de commentaire, analyse en cours ou ancien avis).
  final SentimentResult? sentiment;

  /// Code du ticket QR (`GF-XXXX-XXXX`), invalide une fois la réservation
  /// annulée.
  final String? bookingCode;

  /// Email de confirmation (EmailJS) ; `null` = jamais tenté.
  final EmailDelivery? email;

  /// Présence validée par code / QR : heure et validateur.
  final DateTime? checkedInAt;
  final String? checkedInBy;

  bool get isActive => status != ReservationStatus.cancelled;

  Reservation copyWith({
    ReservationStatus? status,
    bool? attended,
    int? rating,
    String? comment,
    SentimentResult? sentiment,
    bool clearSentiment = false,
    String? bookingCode,
    EmailDelivery? email,
    DateTime? checkedInAt,
    String? checkedInBy,
  }) => Reservation(
    id: id,
    courseId: courseId,
    userId: userId,
    status: status ?? this.status,
    createdAt: createdAt,
    attended: attended ?? this.attended,
    rating: rating ?? this.rating,
    comment: comment ?? this.comment,
    sentiment: clearSentiment ? null : (sentiment ?? this.sentiment),
    bookingCode: bookingCode ?? this.bookingCode,
    email: email ?? this.email,
    checkedInAt: checkedInAt ?? this.checkedInAt,
    checkedInBy: checkedInBy ?? this.checkedInBy,
  );

  Json toJson() => {
    'id': id,
    'courseId': courseId,
    'userId': userId,
    'status': status.name,
    'createdAt': dateToJson(createdAt),
    'attended': attended,
    'rating': rating,
    'comment': comment,
    'sentiment': sentiment?.toJson(),
    'bookingCode': bookingCode,
    'email': email?.toJson(),
    'checkedInAt': dateToJson(checkedInAt),
    'checkedInBy': checkedInBy,
  };

  factory Reservation.fromJson(Json j) => Reservation(
    id: j['id'] as String,
    courseId: j['courseId'] as String,
    userId: j['userId'] as String,
    status: enumFrom(
      ReservationStatus.values,
      j['status'],
      ReservationStatus.confirmed,
    ),
    createdAt: dateOr(j['createdAt'], DateTime(2026)),
    attended: j['attended'] as bool?,
    rating: toIntOrNull(j['rating']),
    comment: j['comment'] as String?,
    sentiment: SentimentResult.fromJson(j['sentiment']),
    bookingCode: j['bookingCode'] as String?,
    email: EmailDelivery.fromJson(j['email']),
    checkedInAt: dateFromJson(j['checkedInAt']),
    checkedInBy: j['checkedInBy'] as String?,
  );
}
