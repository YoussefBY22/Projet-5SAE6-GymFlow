import 'enums.dart';
import 'json.dart';

/// Abonnement d'un membre à la salle.
class Subscription {
  const Subscription({required this.type, this.start, this.end});

  final SubscriptionType type;
  final DateTime? start;
  final DateTime? end;

  static const Subscription none = Subscription(type: SubscriptionType.none);

  bool isActiveAt(DateTime now) =>
      type != SubscriptionType.none && end != null && end!.isAfter(now);

  int daysLeft(DateTime now) {
    if (end == null || !end!.isAfter(now)) return 0;
    // Jours entamés restants (arrondi supérieur).
    return (end!.difference(now).inMinutes / (24 * 60)).ceil();
  }

  Json toJson() => {
    'type': type.name,
    'start': dateToJson(start),
    'end': dateToJson(end),
  };

  factory Subscription.fromJson(Json? j) {
    if (j == null) return none;
    return Subscription(
      type: enumFrom(SubscriptionType.values, j['type'], SubscriptionType.none),
      start: dateFromJson(j['start']),
      end: dateFromJson(j['end']),
    );
  }
}

/// Utilisateur de l'application. Ne contient JAMAIS de mot de passe :
/// les empreintes sont dans [Credential], invisibles pour l'interface.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.createdAt,
    this.active = true,
    this.gender = Gender.male,
    this.age,
    this.heightCm,
    this.weightKg,
    this.goal = Goal.fitness,
    this.avatarPath,
    this.phone,
    this.bio,
    this.subscription = Subscription.none,
    this.weeklyGoal = 3,
    this.favoriteIds = const {},
    this.activeProgramId,
    this.lastLoginAt,
    this.specialty,
  });

  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final bool active;
  final Gender gender;
  final int? age;
  final double? heightCm;
  final double? weightKg;
  final Goal goal;
  final String? avatarPath;
  final String? phone;
  final String? bio;
  final Subscription subscription;

  /// Nombre de séances visé par semaine (anneau d'objectif).
  final int weeklyGoal;

  /// Favoris : identifiants d'exercices, workouts et programmes.
  final Set<String> favoriteIds;

  /// Programme suivi (« Reprendre mon programme »).
  final String? activeProgramId;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  /// Spécialité affichée pour les coachs.
  final String? specialty;

  bool get isAdmin => role == UserRole.superAdmin;
  bool get isCoach => role == UserRole.coach;
  bool get isMember => role == UserRole.member;
  bool get canManageContent => isAdmin || isCoach;

  String get firstName => fullName.split(' ').first;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  AppUser copyWith({
    String? email,
    String? fullName,
    UserRole? role,
    bool? active,
    Gender? gender,
    int? age,
    double? heightCm,
    double? weightKg,
    Goal? goal,
    String? avatarPath,
    bool clearAvatar = false,
    String? phone,
    String? bio,
    Subscription? subscription,
    int? weeklyGoal,
    Set<String>? favoriteIds,
    String? activeProgramId,
    bool clearActiveProgram = false,
    DateTime? lastLoginAt,
    String? specialty,
  }) {
    return AppUser(
      id: id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      active: active ?? this.active,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      goal: goal ?? this.goal,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      subscription: subscription ?? this.subscription,
      weeklyGoal: weeklyGoal ?? this.weeklyGoal,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      activeProgramId: clearActiveProgram
          ? null
          : (activeProgramId ?? this.activeProgramId),
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      specialty: specialty ?? this.specialty,
    );
  }

  Json toJson() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'role': role.name,
    'active': active,
    'gender': gender.name,
    'age': age,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'goal': goal.name,
    'avatarPath': avatarPath,
    'phone': phone,
    'bio': bio,
    'subscription': subscription.toJson(),
    'weeklyGoal': weeklyGoal,
    'favoriteIds': favoriteIds.toList(),
    'activeProgramId': activeProgramId,
    'createdAt': dateToJson(createdAt),
    'lastLoginAt': dateToJson(lastLoginAt),
    'specialty': specialty,
  };

  factory AppUser.fromJson(Json j) => AppUser(
    id: j['id'] as String,
    email: j['email'] as String,
    fullName: j['fullName'] as String,
    role: enumFrom(UserRole.values, j['role'], UserRole.member),
    active: j['active'] as bool? ?? true,
    gender: enumFrom(Gender.values, j['gender'], Gender.male),
    age: toIntOrNull(j['age']),
    heightCm: toDoubleOrNull(j['heightCm']),
    weightKg: toDoubleOrNull(j['weightKg']),
    goal: enumFrom(Goal.values, j['goal'], Goal.fitness),
    avatarPath: j['avatarPath'] as String?,
    phone: j['phone'] as String?,
    bio: j['bio'] as String?,
    subscription: Subscription.fromJson(
      j['subscription'] == null
          ? null
          : Map<String, dynamic>.from(j['subscription'] as Map),
    ),
    weeklyGoal: toInt(j['weeklyGoal'], 3),
    favoriteIds: stringList(j['favoriteIds']).toSet(),
    activeProgramId: j['activeProgramId'] as String?,
    createdAt: dateOr(j['createdAt'], DateTime(2026)),
    lastLoginAt: dateFromJson(j['lastLoginAt']),
    specialty: j['specialty'] as String?,
  );
}

/// Données d'authentification (jamais exposées à l'interface).
class Credential {
  const Credential({
    required this.userId,
    required this.hash,
    required this.salt,
    required this.iterations,
    this.failedAttempts = 0,
    this.lockedUntil,
    this.resetCodeHash,
    this.resetCodeExpires,
    this.sessionDigest,
  });

  final String userId;
  final String hash;
  final String salt;
  final int iterations;
  final int failedAttempts;
  final DateTime? lockedUntil;
  final String? resetCodeHash;
  final DateTime? resetCodeExpires;

  /// Empreinte SHA-256 du jeton de session courant.
  final String? sessionDigest;

  Credential copyWith({
    String? hash,
    String? salt,
    int? iterations,
    int? failedAttempts,
    DateTime? lockedUntil,
    bool clearLock = false,
    String? resetCodeHash,
    DateTime? resetCodeExpires,
    bool clearReset = false,
    String? sessionDigest,
    bool clearSession = false,
  }) {
    return Credential(
      userId: userId,
      hash: hash ?? this.hash,
      salt: salt ?? this.salt,
      iterations: iterations ?? this.iterations,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: clearLock ? null : (lockedUntil ?? this.lockedUntil),
      resetCodeHash: clearReset ? null : (resetCodeHash ?? this.resetCodeHash),
      resetCodeExpires: clearReset
          ? null
          : (resetCodeExpires ?? this.resetCodeExpires),
      sessionDigest: clearSession
          ? null
          : (sessionDigest ?? this.sessionDigest),
    );
  }

  Json toJson() => {
    'id': userId,
    'hash': hash,
    'salt': salt,
    'iterations': iterations,
    'failedAttempts': failedAttempts,
    'lockedUntil': dateToJson(lockedUntil),
    'resetCodeHash': resetCodeHash,
    'resetCodeExpires': dateToJson(resetCodeExpires),
    'sessionDigest': sessionDigest,
  };

  factory Credential.fromJson(Json j) => Credential(
    userId: j['id'] as String,
    hash: j['hash'] as String,
    salt: j['salt'] as String,
    iterations: toInt(j['iterations'], 12000),
    failedAttempts: toInt(j['failedAttempts']),
    lockedUntil: dateFromJson(j['lockedUntil']),
    resetCodeHash: j['resetCodeHash'] as String?,
    resetCodeExpires: dateFromJson(j['resetCodeExpires']),
    sessionDigest: j['sessionDigest'] as String?,
  );
}
