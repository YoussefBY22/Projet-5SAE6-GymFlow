import 'dart:math';

import '../../models/course.dart';
import '../../models/enums.dart';
import '../../models/misc.dart';
import '../../models/session_log.dart';
import '../../models/shop.dart';
import '../../models/user.dart';
import '../../models/workout.dart';
import '../backend.dart';
import 'seed_exercises.dart';
import 'seed_workouts.dart';

/// Compte de démonstration affiché sur l'écran de connexion.
class DemoAccount {
  const DemoAccount(this.label, this.email, this.password, this.role);
  final String label;
  final String email;
  final String password;
  final UserRole role;
}

/// Comptes de démo (panneau retirable sur l'écran de connexion).
const demoAccounts = <DemoAccount>[
  DemoAccount(
    'Karim — Super Admin',
    'admin@gymflow.tn',
    'Admin2026!',
    UserRole.superAdmin,
  ),
  DemoAccount(
    'Amira — Coach yoga',
    'amira@gymflow.tn',
    'Coach2026!',
    UserRole.coach,
  ),
  DemoAccount(
    'Mehdi — Coach force',
    'mehdi@gymflow.tn',
    'Coach2026!',
    UserRole.coach,
  ),
  DemoAccount(
    'Sarra — Coach cardio',
    'sarra@gymflow.tn',
    'Coach2026!',
    UserRole.coach,
  ),
  DemoAccount(
    'Nour — Abonnée (nouvelle)',
    'nour@gymflow.tn',
    'Membre2026!',
    UserRole.member,
  ),
  DemoAccount(
    'Ahmed — Abonné confirmé',
    'ahmed@gymflow.tn',
    'Membre2026!',
    UserRole.member,
  ),
  DemoAccount(
    'Hedi — Abonnement expiré',
    'hedi@gymflow.tn',
    'Membre2026!',
    UserRole.member,
  ),
  DemoAccount(
    'Walid — Compte désactivé',
    'walid@gymflow.tn',
    'Membre2026!',
    UserRole.member,
  ),
];

/// Charge le jeu de données de démonstration au premier lancement.
class SeedService {
  SeedService(this._b);
  final Backend _b;
  final Random _rnd = Random(2026);

  static const _seedKey = 'seed_version';
  static const _seedVersion = '1';

  late DateTime _now;
  late DateTime _today;
  final Map<String, String> _ids = {};

  Future<void> seedIfEmpty() async {
    if (await _b.store.getMeta(_seedKey) == _seedVersion) return;
    if (_b.users.count > 0) return;
    await seed();
    await _b.store.setMeta(_seedKey, _seedVersion);
  }

  DateTime _day(int offset, [int hour = 0, int minute = 0]) =>
      DateTime(_today.year, _today.month, _today.day + offset, hour, minute);

  Future<void> seed() async {
    _now = _b.now();
    _today = DateTime(_now.year, _now.month, _now.day);
    await _seedUsers();
    await _seedContent();
    await _seedCourses();
    await _seedHistory();
    await _seedShop();
    await _seedAnnouncements();
  }

  // ------------------------------------------------------------------ Comptes

  Future<void> _seedUsers() async {
    Subscription sub(SubscriptionType t, int startOffset) {
      final start = _day(startOffset);
      final end = DateTime(start.year, start.month + t.months, start.day);
      return Subscription(type: t, start: start, end: end);
    }

    final users = <String, (AppUser, String)>{
      'admin': (
        AppUser(
          id: 'u_admin',
          email: 'admin@gymflow.tn',
          fullName: 'Karim Belhadj',
          role: UserRole.superAdmin,
          gender: Gender.male,
          age: 44,
          phone: '+216 71 000 100',
          createdAt: _day(-400),
        ),
        'Admin2026!',
      ),
      'amira': (
        AppUser(
          id: 'u_amira',
          email: 'amira@gymflow.tn',
          fullName: 'Amira Trabelsi',
          role: UserRole.coach,
          gender: Gender.female,
          age: 33,
          specialty: 'Yoga, Pilates & mobilité',
          bio: 'Professeure de yoga certifiée RYT-500, 10 ans d\'expérience.',
          createdAt: _day(-380),
        ),
        'Coach2026!',
      ),
      'mehdi': (
        AppUser(
          id: 'u_mehdi',
          email: 'mehdi@gymflow.tn',
          fullName: 'Mehdi Jaziri',
          role: UserRole.coach,
          gender: Gender.male,
          age: 36,
          specialty: 'Musculation & force',
          bio:
              'Préparateur physique, ancien haltérophile de l\'équipe nationale.',
          createdAt: _day(-370),
        ),
        'Coach2026!',
      ),
      'sarra': (
        AppUser(
          id: 'u_sarra',
          email: 'sarra@gymflow.tn',
          fullName: 'Sarra Haddad',
          role: UserRole.coach,
          gender: Gender.female,
          age: 29,
          specialty: 'HIIT, cardio, boxe & danse',
          bio: 'Coach cardio et boxe, énergie garantie à chaque cours !',
          createdAt: _day(-300),
        ),
        'Coach2026!',
      ),
      'nour': (
        AppUser(
          id: 'u_nour',
          email: 'nour@gymflow.tn',
          fullName: 'Nour Ben Ammar',
          role: UserRole.member,
          gender: Gender.female,
          age: 24,
          heightCm: 165,
          weightKg: 61,
          goal: Goal.fitness,
          weeklyGoal: 3,
          subscription: sub(SubscriptionType.monthly, -3),
          createdAt: _day(-3),
        ),
        'Membre2026!',
      ),
      'ahmed': (
        AppUser(
          id: 'u_ahmed',
          email: 'ahmed@gymflow.tn',
          fullName: 'Ahmed Gharbi',
          role: UserRole.member,
          gender: Gender.male,
          age: 31,
          heightCm: 180,
          weightKg: 82,
          goal: Goal.muscleGain,
          weeklyGoal: 4,
          activeProgramId: 'p_ppl',
          subscription: sub(SubscriptionType.yearly, -120),
          createdAt: _day(-240),
        ),
        'Membre2026!',
      ),
      'leila': (
        AppUser(
          id: 'u_leila',
          email: 'leila@gymflow.tn',
          fullName: 'Leila Mansour',
          role: UserRole.member,
          gender: Gender.female,
          age: 45,
          heightCm: 162,
          weightKg: 64,
          goal: Goal.fitness,
          weeklyGoal: 3,
          activeProgramId: 'p_fullbody',
          subscription: sub(SubscriptionType.quarterly, -40),
          createdAt: _day(-200),
        ),
        'Membre2026!',
      ),
      'omar': (
        AppUser(
          id: 'u_omar',
          email: 'omar@gymflow.tn',
          fullName: 'Omar Chaabane',
          role: UserRole.member,
          gender: Gender.male,
          age: 58,
          heightCm: 174,
          weightKg: 88,
          goal: Goal.fitness,
          weeklyGoal: 2,
          activeProgramId: 'p_fullbody',
          subscription: sub(SubscriptionType.quarterly, -30),
          createdAt: _day(-35),
        ),
        'Membre2026!',
      ),
      'ines': (
        AppUser(
          id: 'u_ines',
          email: 'ines@gymflow.tn',
          fullName: 'Ines Kammoun',
          role: UserRole.member,
          gender: Gender.female,
          age: 29,
          heightCm: 168,
          weightKg: 57,
          goal: Goal.endurance,
          weeklyGoal: 4,
          activeProgramId: 'p_endurance',
          subscription: sub(SubscriptionType.yearly, -200),
          createdAt: _day(-210),
        ),
        'Membre2026!',
      ),
      'rami': (
        AppUser(
          id: 'u_rami',
          email: 'rami@gymflow.tn',
          fullName: 'Rami Bouzid',
          role: UserRole.member,
          gender: Gender.male,
          age: 22,
          heightCm: 183,
          weightKg: 78,
          goal: Goal.muscleGain,
          weeklyGoal: 5,
          activeProgramId: 'p_ppl',
          subscription: sub(SubscriptionType.monthly, -12),
          createdAt: _day(-150),
        ),
        'Membre2026!',
      ),
      'salma': (
        AppUser(
          id: 'u_salma',
          email: 'salma@gymflow.tn',
          fullName: 'Salma Jebali',
          role: UserRole.member,
          gender: Gender.female,
          age: 36,
          heightCm: 160,
          weightKg: 76,
          goal: Goal.weightLoss,
          weeklyGoal: 3,
          activeProgramId: 'p_weightloss_home',
          subscription: sub(SubscriptionType.quarterly, -60),
          createdAt: _day(-70),
        ),
        'Membre2026!',
      ),
      'hedi': (
        AppUser(
          id: 'u_hedi',
          email: 'hedi@gymflow.tn',
          fullName: 'Hedi Ferchichi',
          role: UserRole.member,
          gender: Gender.male,
          age: 40,
          heightCm: 177,
          weightKg: 90,
          goal: Goal.weightLoss,
          weeklyGoal: 3,
          subscription: sub(SubscriptionType.monthly, -40),
          createdAt: _day(-90),
        ),
        'Membre2026!',
      ),
      'walid': (
        AppUser(
          id: 'u_walid',
          email: 'walid@gymflow.tn',
          fullName: 'Walid Sassi',
          role: UserRole.member,
          active: false,
          gender: Gender.male,
          age: 27,
          goal: Goal.muscleGain,
          subscription: sub(SubscriptionType.monthly, -50),
          createdAt: _day(-26),
        ),
        'Membre2026!',
      ),
    };

    await _b.users.saveAll(users.values.map((e) => e.$1));
    for (final e in users.entries) {
      _ids[e.key] = e.value.$1.id;
      await _b.auth.setPassword(e.value.$1.id, e.value.$2);
    }
    await _b.auditRepo.save(
      AuditEntry(
        id: 'a_seed_walid',
        actorId: 'u_admin',
        actorName: 'Karim Belhadj',
        action: 'Désactivation',
        details: 'Walid Sassi (Abonné) — impayés',
        targetId: 'u_walid',
        createdAt: _day(-6, 10, 12),
      ),
    );
    for (final key in [
      'nour',
      'ahmed',
      'leila',
      'omar',
      'ines',
      'rami',
      'salma',
      'hedi',
    ]) {
      await _note(
        key,
        NotificationType.system,
        'Bienvenue chez GymFlow !',
        'Réservez vos cours, lancez vos séances et suivez votre progression.',
        users[key]!.$1.createdAt,
        read: key != 'nour',
      );
    }
    await _note(
      'hedi',
      NotificationType.system,
      'Votre abonnement a expiré',
      'Passez à l\'accueil pour le renouveler et continuer à réserver vos cours.',
      _day(-10, 9),
    );
  }

  Future<void> _note(
    String userKey,
    NotificationType type,
    String title,
    String body,
    DateTime at, {
    bool read = false,
    String? route,
    String? refId,
  }) async {
    await _b.notificationsRepo.save(
      AppNotification(
        id: 'n_${_b.notificationsRepo.count + 1}_$userKey',
        userId: _ids[userKey]!,
        type: type,
        title: title,
        body: body,
        createdAt: at,
        read: read,
        route: route,
        refId: refId,
      ),
    );
  }

  // --------------------------------------------------------------- Contenu

  Future<void> _seedContent() async {
    final created = _day(-60);
    await _b.exercises.saveAll(
      seedExercises.map((e) => e.build(_ids[e.author]!, created)),
    );
    final workouts = seedWorkouts(created).map(
      (s) =>
          Workout.fromJson({...s.workout.toJson(), 'authorId': _ids[s.author]}),
    );
    await _b.workouts.saveAll(workouts);
    final programs = seedPrograms(created).map(
      (s) =>
          Program.fromJson({...s.program.toJson(), 'authorId': _ids[s.author]}),
    );
    await _b.programs.saveAll(programs);
  }

  // ----------------------------------------------------------------- Cours

  Future<void> _seedCourses() async {
    final img = unsplash;
    Course c(
      String key,
      String title,
      String description,
      CourseCategory cat,
      Level level,
      String coach,
      String room,
      int capacity,
      int duration,
      DateTime? start,
      String image, {
      int createdDaysAgo = 30,
      bool included = true,
      double price = 0,
    }) => Course(
      id: 'c_$key',
      title: title,
      description: description,
      category: cat,
      level: level,
      coachId: _ids[coach]!,
      room: room,
      capacity: capacity,
      durationMin: duration,
      startAt: start,
      createdAt: _now.subtract(Duration(days: createdDaysAgo, hours: 2)),
      imageUrl: img(image),
      priceIncluded: included,
      price: price,
    );

    const yoga = 'photo-1761035005546-62b8018b212a';
    const yoga2 = 'photo-1651077920873-ac1be1b82290';
    const hiit = 'photo-1517130038641-a774d04afb3c';
    const spin = 'photo-1520877880798-5ee004e3f11e';
    const spin2 = 'photo-1709315821780-3c092a9eddda';
    const box = 'photo-1561532325-7d5231a2dede';
    const ring = 'photo-1716307043003-dbe6a5cc496e';
    const pilates = 'photo-1747239069226-55382c570116';
    const zumba = 'photo-1524594152303-9fd13543fe6e';
    const barbell = 'photo-1722925541142-5db2668ca492';
    const deadlift = 'photo-1517836357463-d25dfeac3438';
    const stretch = 'photo-1683056255281-e52a141924f0';
    const stretch2 = 'photo-1593431763017-c689a61b729a';

    final courses = [
      // Terminés (avec présences et notes)
      c(
        'd1',
        'Yoga Vinyasa',
        'Enchaînements fluides synchronisés avec la respiration.',
        CourseCategory.yoga,
        Level.intermediate,
        'amira',
        'Studio Zen',
        15,
        60,
        _day(-2, 18),
        yoga,
      ),
      c(
        'd2',
        'HIIT 45',
        'Intervalles haute intensité : 40 s d\'effort, 20 s de repos.',
        CourseCategory.hiit,
        Level.intermediate,
        'sarra',
        'Salle Énergie',
        20,
        45,
        _day(-3, 19),
        hiit,
      ),
      c(
        'd3',
        'Spinning Endurance',
        'Montées, sprints et récupération en musique.',
        CourseCategory.spinning,
        Level.beginner,
        'sarra',
        'Studio Vélo',
        18,
        45,
        _day(-5, 7, 30),
        spin,
      ),
      c(
        'd4',
        'Force & technique : squat',
        'Atelier technique pour progresser en sécurité sur le squat.',
        CourseCategory.strength,
        Level.intermediate,
        'mehdi',
        'Plateau musculation',
        10,
        75,
        _day(-6, 18, 30),
        barbell,
      ),
      c(
        'd5',
        'Pilates Core',
        'Renforcement profond de la sangle abdominale.',
        CourseCategory.pilates,
        Level.beginner,
        'amira',
        'Studio Zen',
        12,
        50,
        _day(-8, 12, 15),
        pilates,
      ),
      c(
        'd6',
        'Boxe Cardio',
        'Enchaînements au sac, cardio et coordination.',
        CourseCategory.boxing,
        Level.beginner,
        'sarra',
        'Ring',
        16,
        60,
        _day(-10, 19, 30),
        box,
      ),
      // Programmés (semaine en cours et suivante)
      c(
        's1',
        'Yoga Vinyasa',
        'Enchaînements fluides synchronisés avec la respiration.',
        CourseCategory.yoga,
        Level.intermediate,
        'amira',
        'Studio Zen',
        15,
        60,
        _day(1, 18),
        yoga,
      ),
      c(
        's2',
        'HIIT Express',
        '30 minutes chrono pour la pause déjeuner.',
        CourseCategory.hiit,
        Level.intermediate,
        'sarra',
        'Salle Énergie',
        20,
        30,
        _day(1, 12, 30),
        hiit,
      ),
      c(
        's3',
        'Spinning Sunrise',
        'Réveil musculaire sur le vélo avant le travail.',
        CourseCategory.spinning,
        Level.beginner,
        'sarra',
        'Studio Vélo',
        6,
        45,
        _day(2, 7, 30),
        spin2,
      ),
      c(
        's4',
        'Musculation guidée débutants',
        'Découverte des machines et des gestes de base avec un coach.',
        CourseCategory.strength,
        Level.beginner,
        'mehdi',
        'Plateau musculation',
        8,
        60,
        _day(2, 18, 30),
        barbell,
      ),
      c(
        's5',
        'Zumba Party',
        'Danse fitness sur rythmes latinos : on transpire en s\'amusant.',
        CourseCategory.zumba,
        Level.beginner,
        'sarra',
        'Salle Énergie',
        25,
        55,
        _day(3, 19),
        zumba,
      ),
      c(
        's6',
        'Pilates Reformer — Initiation',
        'Nouveau ! Découvrez le Pilates sur machine Reformer.',
        CourseCategory.pilates,
        Level.beginner,
        'amira',
        'Studio Zen',
        8,
        50,
        _day(4, 10),
        pilates,
        createdDaysAgo: 2,
      ),
      c(
        's7',
        'Boxe Technique',
        'Garde, déplacements et combinaisons au sac et aux pattes d\'ours.',
        CourseCategory.boxing,
        Level.intermediate,
        'sarra',
        'Ring',
        14,
        60,
        _day(5, 19, 30),
        ring,
      ),
      c(
        's8',
        'Stretching & mobilité',
        'Nouveau ! Séance douce pour gagner en souplesse.',
        CourseCategory.stretching,
        Level.beginner,
        'amira',
        'Studio Zen',
        15,
        45,
        _day(8, 9),
        stretch,
        createdDaysAgo: 1,
      ),
      c(
        's9',
        'Clinique soulevé de terre',
        'Nouveau ! Atelier de 90 min en petit groupe pour maîtriser le soulevé de terre.',
        CourseCategory.strength,
        Level.intermediate,
        'mehdi',
        'Plateau musculation',
        6,
        90,
        _day(9, 18),
        deadlift,
        createdDaysAgo: 3,
        included: false,
        price: 25,
      ),
      c(
        's10',
        'Yoga doux seniors',
        'Postures accessibles, équilibre et respiration.',
        CourseCategory.yoga,
        Level.beginner,
        'amira',
        'Studio Zen',
        12,
        50,
        _day(10, 10, 30),
        yoga2,
      ),
      c(
        's11',
        'HIIT 45',
        'Intervalles haute intensité : 40 s d\'effort, 20 s de repos.',
        CourseCategory.hiit,
        Level.intermediate,
        'sarra',
        'Salle Énergie',
        20,
        45,
        _day(11, 19),
        hiit,
      ),
      // À planifier (coach affecté, sans date)
      c(
        'p1',
        'Cross Training découverte',
        'Bientôt : circuits fonctionnels variés en petit groupe.',
        CourseCategory.hiit,
        Level.intermediate,
        'sarra',
        'Salle Énergie',
        12,
        60,
        null,
        hiit,
        createdDaysAgo: 4,
      ),
      c(
        'p2',
        'Yin Yoga & respiration',
        'Bientôt : postures longues et relaxation profonde.',
        CourseCategory.yoga,
        Level.beginner,
        'amira',
        'Studio Zen',
        14,
        75,
        null,
        stretch2,
        createdDaysAgo: 5,
      ),
      c(
        'p3',
        'Kettlebell fondamentaux',
        'Bientôt : swing, goblet squat et get-up en toute sécurité.',
        CourseCategory.strength,
        Level.beginner,
        'mehdi',
        'Plateau musculation',
        10,
        60,
        null,
        deadlift,
        createdDaysAgo: 6,
      ),
    ];
    await _b.courses.saveAll(courses);

    var n = 0;
    Future<void> book(
      String courseKey,
      String userKey, {
      bool? attended,
      int? rating,
      String? comment,
      ReservationStatus status = ReservationStatus.confirmed,
      int daysBefore = 4,
    }) async {
      final course = courses.firstWhere((x) => x.id == 'c_$courseKey');
      final ref = course.startAt ?? _now;
      final r = Reservation(
        id: 'r_seed_${n++}',
        courseId: course.id,
        userId: _ids[userKey]!,
        status: status,
        createdAt: ref.subtract(Duration(days: daysBefore, minutes: n * 7)),
        attended: attended,
        rating: rating,
        comment: comment,
      );
      await _b.reservations.save(r);
      if (status == ReservationStatus.confirmed &&
          course.statusAt(_now) == CourseStatus.scheduled) {
        await _b.notifications.scheduleCourseReminders(r, course);
      }
    }

    // Cours terminés : présences + notes.
    await book(
      'd1',
      'leila',
      attended: true,
      rating: 5,
      comment: 'Amira est géniale, cours très fluide.',
    );
    await book('d1', 'ines', attended: true, rating: 4);
    await book('d1', 'salma', attended: false);
    await book(
      'd2',
      'ines',
      attended: true,
      rating: 5,
      comment: 'Intense mais super motivant !',
    );
    await book('d2', 'rami', attended: true, rating: 4);
    await book('d2', 'salma', attended: true, rating: 5);
    await book('d2', 'ahmed', attended: true, rating: 4);
    await book('d3', 'ines', attended: true, rating: 5);
    await book(
      'd3',
      'omar',
      attended: true,
      rating: 4,
      comment: 'Parfait pour reprendre en douceur.',
    );
    await book('d3', 'leila', attended: true, rating: 4);
    await book(
      'd4',
      'ahmed',
      attended: true,
      rating: 5,
      comment: 'J\'ai enfin compris le placement du dos.',
    );
    await book('d4', 'rami', attended: true, rating: 5);
    await book('d5', 'leila', attended: true, rating: 5);
    await book('d5', 'salma', attended: true, rating: 4);
    await book('d5', 'omar', attended: true, rating: 3);
    await book('d6', 'rami', attended: true, rating: 4);
    await book('d6', 'ines', attended: true, rating: 5);
    await book('d6', 'hedi', attended: true, rating: 4);

    // Cours programmés : réservations confirmées.
    await book('s1', 'leila');
    await book('s1', 'ines');
    await book('s2', 'rami');
    await book('s2', 'salma');
    // Spinning Sunrise : complet (6/6) + liste d'attente.
    for (final u in ['ahmed', 'leila', 'omar', 'ines', 'rami', 'salma']) {
      await book('s3', u, daysBefore: 3);
    }
    await book('s4', 'omar');
    await book('s5', 'salma');
    await book('s5', 'ines');
    await book('s6', 'leila');
    await book('s7', 'rami');
    await book('s9', 'ahmed');

    for (final u in ['ahmed', 'leila', 'omar', 'ines', 'rami', 'salma']) {
      await _note(
        u,
        NotificationType.reservation,
        'Réservation confirmée',
        'Spinning Sunrise · ${_day(2, 7, 30).day}/${_day(2).month} à 07:30 · Studio Vélo',
        _now.subtract(const Duration(days: 1)),
        read: u != 'ahmed',
        route: '/courses/detail',
        refId: 'c_s3',
      );
    }
    await _note(
      'amira',
      NotificationType.course,
      'Nouveau cours affecté',
      '« Yin Yoga & respiration » (à planifier).',
      _now.subtract(const Duration(days: 5)),
      route: '/courses/detail',
      refId: 'c_p2',
    );
  }

  // ------------------------------------------------------ Historique séances

  static const Map<String, double> _baseLoad = {
    'bench': 60,
    'db_bench': 22,
    'incline_db': 20,
    'db_fly': 12,
    'cable_cross': 15,
    'latpull': 50,
    'bb_row': 50,
    'db_row': 24,
    'cable_row': 45,
    'deadlift': 100,
    'facepull': 15,
    'ohp': 40,
    'db_shoulder': 16,
    'lateral': 8,
    'reardelt': 6,
    'shrug': 24,
    'bb_curl': 30,
    'db_curl': 12,
    'hammer': 12,
    'preacher': 25,
    'pushdown': 25,
    'skull': 25,
    'oh_ext': 16,
    'squat': 80,
    'goblet': 20,
    'legpress': 120,
    'lunge': 14,
    'bulgarian': 12,
    'rdl': 60,
    'legcurl': 35,
    'legext': 40,
    'calf': 60,
    'hipthrust': 80,
    'kbswing': 16,
  };

  Future<void> _seedHistory() async {
    // (profil, facteur de charge, jours d'entraînement, semaines d'historique)
    final plans = <(String, double, Map<int, String>, int)>[
      ('ahmed', 1.0, {1: 'push', 2: 'pull', 4: 'legs', 6: 'push'}, 8),
      ('rami', 1.2, {1: 'push', 2: 'pull', 3: 'legs', 5: 'push', 6: 'pull'}, 8),
      ('leila', 0.45, {1: 'fb_a', 3: 'fb_b', 6: 'mobility'}, 8),
      ('omar', 0.55, {2: 'fb_a', 5: 'fb_b'}, 4),
      (
        'ines',
        0.5,
        {1: 'cardio_kb', 3: 'hiit_home', 5: 'core', 7: 'mobility'},
        8,
      ),
      ('salma', 0.4, {1: 'hiit_home', 3: 'core', 5: 'hiit_home'}, 8),
      ('hedi', 0.8, {2: 'upper', 4: 'lower'}, 8),
    ];

    final pending = <SessionLog>[];
    for (final (key, factor, days, weeks) in plans) {
      final userId = _ids[key]!;
      for (var d = weeks * 7; d >= 1; d--) {
        final date = _day(-d);
        var workoutKey = days[date.weekday];
        // Hedi a arrêté il y a 5 semaines (abonnement expiré).
        if (key == 'hedi' && d < 35) workoutKey = null;
        // Ahmed : série de 3 jours consécutifs pour la démo des streaks.
        if (key == 'ahmed' && d <= 3) {
          workoutKey = ['push', 'pull', 'legs'][3 - d];
        }
        if (workoutKey == null) continue;
        if (_rnd.nextDouble() < 0.12 && d > 3) continue; // séance manquée
        final weekIndex = weeks - (d ~/ 7);
        pending.add(
          _buildSession(
            userId,
            workoutKey,
            date,
            factor,
            weekIndex,
            pending.length,
          ),
        );
      }
    }
    pending.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final memberIds = [
      for (final k in ['ahmed', 'leila', 'omar', 'ines', 'rami', 'salma'])
        _ids[k]!,
    ];
    for (final s in pending) {
      final records = _b.progress.detectRecords(s.userId, s.sets, s.startedAt);
      final kudos = memberIds
          .where((id) => id != s.userId && _rnd.nextDouble() < 0.3)
          .toList();
      await _b.sessions.save(s.copyWith(prCount: records.length, kudos: kudos));
    }

    // Pesées hebdomadaires (tendance selon l'objectif).
    final trends = <String, (double, double)>{
      'ahmed': (79.5, 82),
      'rami': (75, 78),
      'leila': (65.5, 64),
      'omar': (90, 88),
      'ines': (57.5, 57),
      'salma': (82, 76),
      'hedi': (91, 90),
    };
    var w = 0;
    for (final e in trends.entries) {
      for (var i = 0; i <= 8; i++) {
        final t = i / 8;
        final kg =
            e.value.$1 +
            (e.value.$2 - e.value.$1) * t +
            (_rnd.nextDouble() - 0.5) * 0.6;
        await _b.weights.save(
          WeightEntry(
            id: 'wt_seed_${w++}',
            userId: _ids[e.key]!,
            date: _day(-56 + i * 7, 8),
            weightKg: double.parse(kg.toStringAsFixed(1)),
          ),
        );
      }
    }
  }

  SessionLog _buildSession(
    String userId,
    String workoutKey,
    DateTime date,
    double factor,
    int weekIndex,
    int index,
  ) {
    final workout = _b.workouts.byId('w_$workoutKey')!;
    final start = date.add(
      Duration(hours: 7 + _rnd.nextInt(12), minutes: _rnd.nextInt(4) * 15),
    );
    final sets = <SetLog>[];
    for (final item in workout.items) {
      final ex = _b.exercises.byId(item.exerciseId)!;
      final key = item.exerciseId.substring(3);
      final base = _baseLoad[key];
      for (var s = 1; s <= item.sets; s++) {
        double load = 0;
        if (base != null) {
          // Progression d'environ 1,5 % par semaine, arrondie à 2,5 kg (1 kg
          // pour les petites charges).
          final raw = base * factor * (1 + 0.015 * weekIndex);
          final step = raw >= 20 ? 2.5 : 1.0;
          load = (raw / step).round() * step;
        }
        final reps = item.isTimed
            ? 1
            : max(
                1,
                (item.reps ?? 10) - (s == item.sets ? _rnd.nextInt(2) : 0),
              );
        sets.add(
          SetLog(
            exerciseId: ex.id,
            exerciseName: ex.name,
            setIndex: s,
            reps: reps,
            loadKg: load,
            durationSec: item.isTimed ? item.durationSec : null,
          ),
        );
      }
    }
    final minutes = workout.estimatedMinutes + _rnd.nextInt(9) - 3;
    return SessionLog(
      id: 's_seed_$index',
      userId: userId,
      workoutId: workout.id,
      title: workout.name,
      startedAt: start,
      durationSec: max(10, minutes) * 60 + _rnd.nextInt(59),
      sets: sets,
      exerciseCount: workout.items.length,
    );
  }

  // --------------------------------------------------------------- Boutique

  Future<void> _seedShop() async {
    Product p(
      String key,
      String name,
      String description,
      ProductCategory cat,
      double price,
      int stock,
      List<String> images, {
      double? promo,
      bool featured = false,
    }) => Product(
      id: 'pr_$key',
      name: name,
      description: description,
      category: cat,
      price: price,
      promoPrice: promo,
      stock: stock,
      images: images.map(unsplash).toList(),
      featured: featured,
      createdAt: _day(-45),
    );

    final products = [
      p(
        'whey',
        'Whey protéine vanille 2 kg',
        'Protéine de lactosérum concentrée, 24 g de protéines par dose de 30 g. Idéale après la séance.',
        ProductCategory.supplements,
        189,
        14,
        ['photo-1693996045300-521e9d08cabc'],
        featured: true,
      ),
      p(
        'isolate',
        'Whey isolate chocolat 900 g',
        'Isolat ultra-filtré, faible en lactose et en sucres. 27 g de protéines par dose.',
        ProductCategory.supplements,
        149,
        6,
        ['photo-1704650311190-7eeb9c4f6e11'],
        promo: 129,
      ),
      p(
        'creatine',
        'Créatine monohydrate 300 g',
        'Créatine pure micronisée, 3 à 5 g par jour pour la force et la puissance.',
        ProductCategory.supplements,
        69,
        20,
        ['photo-1693996045435-af7c48b9cafb'],
      ),
      p(
        'bcaa',
        'BCAA 2:1:1 pastèque 400 g',
        'Acides aminés branchés à boire pendant l\'entraînement.',
        ProductCategory.supplements,
        79,
        0,
        ['photo-1709976142749-4a83767c4228'],
      ),
      p(
        'bar',
        'Barres protéinées (boîte de 12)',
        '20 g de protéines par barre, saveur caramel-cacahuète. Collation pratique.',
        ProductCategory.supplements,
        54,
        25,
        ['photo-1633360821154-1935fb5671e6'],
        featured: true,
      ),
      p(
        'shaker',
        'Shaker GymFlow 700 ml',
        'Shaker étanche avec grille de mélange, sans BPA.',
        ProductCategory.accessories,
        18,
        40,
        ['photo-1595348020949-87cdfbb44174'],
      ),
      p(
        'bottle',
        'Gourde isotherme 750 ml',
        'Garde l\'eau fraîche 24 h. Inox double paroi.',
        ProductCategory.accessories,
        35,
        15,
        ['photo-1649888254873-d9870ee286ee'],
      ),
      p(
        'rope',
        'Corde à sauter speed',
        'Câble acier gainé, poignées roulements à billes, longueur réglable.',
        ProductCategory.accessories,
        29,
        12,
        ['photo-1516876345887-6dd74f80787a'],
      ),
      p(
        'bands',
        'Kit élastiques de résistance (5 niveaux)',
        'Cinq bandes de 5 à 40 kg pour s\'entraîner partout.',
        ProductCategory.accessories,
        45,
        9,
        ['photo-1584827386916-b5351d3ba34b'],
        promo: 39,
        featured: true,
      ),
      p(
        'mat',
        'Tapis de yoga 6 mm',
        'Antidérapant, épaisseur confortable pour les genoux, sangle de transport.',
        ProductCategory.accessories,
        65,
        7,
        ['photo-1646239646963-b0b9be56d6b5'],
      ),
      p(
        'gloves',
        'Gants de musculation',
        'Paume renforcée et respirante pour protéger les mains.',
        ProductCategory.accessories,
        39,
        11,
        ['photo-1557127972-1c446ea89ea5'],
      ),
      p(
        'roller',
        'Rouleau de massage (foam roller)',
        'Relâchement myofascial après l\'effort, mousse haute densité.',
        ProductCategory.accessories,
        49,
        5,
        ['photo-1591741535585-9c4f52b3f13f'],
      ),
      p(
        'tshirt',
        'T-shirt technique GymFlow',
        'Tissu respirant à séchage rapide. Tailles XS à XXL.',
        ProductCategory.clothing,
        42,
        30,
        ['photo-1716951980904-fbe5c5aa2279'],
      ),
      p(
        'leggings',
        'Legging sport taille haute',
        'Maintien confortable, tissu opaque et extensible.',
        ProductCategory.clothing,
        69,
        18,
        ['photo-1600696491085-19dbbeb4f8c1'],
        featured: true,
      ),
      p(
        'towel',
        'Serviette microfibre',
        'Compacte, absorbante et à séchage rapide.',
        ProductCategory.clothing,
        22,
        3,
        ['photo-1638183130424-873c491cca1b'],
      ),
      p(
        'iso',
        'Boisson isotonique (pack de 6)',
        'Réhydratation et électrolytes pendant l\'effort. Saveur agrumes.',
        ProductCategory.drinks,
        24,
        20,
        ['photo-1506353219544-65860ffc5f41'],
      ),
    ];
    await _b.products.saveAll(products);

    Product prod(String k) => products.firstWhere((x) => x.id == 'pr_$k');
    final orders = <(String, List<(String, int)>, OrderStatus, int)>[
      ('ahmed', [('whey', 1), ('shaker', 1)], OrderStatus.delivered, 40),
      ('rami', [('creatine', 1), ('bar', 2)], OrderStatus.delivered, 25),
      ('ines', [('rope', 1), ('iso', 2)], OrderStatus.delivered, 18),
      ('salma', [('bands', 1), ('mat', 1)], OrderStatus.prepared, 4),
      ('leila', [('leggings', 1)], OrderStatus.paid, 1),
      ('rami', [('isolate', 1)], OrderStatus.paid, 0),
    ];
    var i = 0;
    for (final (user, lines, status, daysAgo) in orders) {
      i++;
      final at = _now.subtract(Duration(days: daysAgo, hours: 3 + i));
      await _b.orders.save(
        ShopOrder(
          id: 'o_seed_$i',
          number: 'GF-${at.year}-${(i).toString().padLeft(4, '0')}',
          userId: _ids[user]!,
          lines: [
            for (final (k, q) in lines)
              OrderLine(
                productId: prod(k).id,
                name: prod(k).name,
                unitPrice: prod(k).effectivePrice,
                quantity: q,
                image: prod(k).images.first,
              ),
          ],
          status: status,
          paymentMethod: 'simulated',
          paymentRef: 'SIM-SEED-${1000 + i}',
          createdAt: at,
        ),
      );
    }
    await _note(
      'salma',
      NotificationType.order,
      'Commande GF-${_now.year}-0004 prête',
      'Votre commande vous attend à l\'accueil.',
      _now.subtract(const Duration(days: 3)),
      route: '/orders',
    );
  }

  Future<void> _seedAnnouncements() async {
    await _b.announcementsRepo.saveAll([
      Announcement(
        id: 'an_1',
        title: 'Ouverture dès 6 h en semaine',
        body:
            'À partir de lundi, la salle ouvre à 6 h du lundi au vendredi pour les lève-tôt !',
        authorId: _ids['admin']!,
        createdAt: _now.subtract(const Duration(days: 2)),
        imageUrl: unsplash('photo-1593079831268-3381b0db4a77'),
        pinned: true,
      ),
      Announcement(
        id: 'an_2',
        title: '-15 % sur les compléments',
        body:
            'Tout le mois, profitez de prix réduits sur une sélection de compléments à la boutique.',
        authorId: _ids['admin']!,
        createdAt: _now.subtract(const Duration(days: 4)),
        imageUrl: unsplash('photo-1693996045300-521e9d08cabc'),
      ),
      Announcement(
        id: 'an_3',
        title: 'Défi du mois : 12 séances',
        body:
            'Réalisez 12 séances ce mois-ci et gagnez un t-shirt GymFlow. Suivez votre compteur dans votre profil.',
        authorId: _ids['admin']!,
        createdAt: _now.subtract(const Duration(days: 6)),
        imageUrl: unsplash('photo-1633394782240-f81aba3f850d'),
      ),
    ]);
  }
}
