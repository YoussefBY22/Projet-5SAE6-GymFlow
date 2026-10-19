import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/errors.dart';
import '../core/security.dart';
import '../models/course.dart';
import '../models/enums.dart';
import '../models/exercise.dart';
import '../models/misc.dart';
import '../models/session_log.dart';
import '../models/shop.dart';
import '../models/user.dart';
import '../models/workout.dart';
import '../repositories/data_store.dart';
import '../repositories/repository.dart';
import 'ai_assistant_service.dart';
import 'announcement_service.dart';
import 'audit_service.dart';
import 'auth_service.dart';
import 'cart_service.dart';
import 'email_service.dart';
import 'community_service.dart';
import 'course_service.dart';
import 'dashboard_service.dart';
import 'exercise_service.dart';
import 'library_service.dart';
import 'media_storage.dart';
import 'notification_service.dart';
import 'order_service.dart';
import 'payment/payment_gateway.dart';
import 'privacy_service.dart';
import 'platform/platform_services.dart';
import 'product_service.dart';
import 'progress_service.dart';
import 'reservation_service.dart';
import 'seed/seed_service.dart';
import 'training_log_service.dart';
import 'user_service.dart';
import 'calorie_service.dart';
import 'smartwatch_service.dart';
import 'weather_service.dart';
import 'wger_api.dart';
import 'workout_service.dart';

/// Signal « les données ont changé » : les écrans l'écoutent avec
/// `ListenableBuilder` pour se rafraîchir (accueil, profil, dashboards…).
class DataBus extends ChangeNotifier {
  int version = 0;
  void emit() {
    version++;
    notifyListeners();
  }
}

/// Point d'accès unique aux « API internes » de GymFlow.
/// Chaque service applique ses propres contrôles de rôle.
class Backend {
  Backend._({
    required this.store,
    required this.sessionStorage,
    required this.notifier,
    required this.calendar,
    required this.httpClient,
    required this.clock,
    required this.passwordIterations,
    PaymentGateway? payment,
  }) {
    users = _repo(
      Collections.users,
      AppUser.fromJson,
      (u) => u.toJson(),
      (u) => u.id,
    );
    credentials = _repo(
      Collections.credentials,
      Credential.fromJson,
      (c) => c.toJson(),
      (c) => c.userId,
    );
    exercises = _repo(
      Collections.exercises,
      Exercise.fromJson,
      (e) => e.toJson(),
      (e) => e.id,
    );
    workouts = _repo(
      Collections.workouts,
      Workout.fromJson,
      (w) => w.toJson(),
      (w) => w.id,
    );
    programs = _repo(
      Collections.programs,
      Program.fromJson,
      (p) => p.toJson(),
      (p) => p.id,
    );
    sessions = _repo(
      Collections.sessions,
      SessionLog.fromJson,
      (s) => s.toJson(),
      (s) => s.id,
    );
    weights = _repo(
      Collections.weights,
      WeightEntry.fromJson,
      (w) => w.toJson(),
      (w) => w.id,
    );
    courses = _repo(
      Collections.courses,
      Course.fromJson,
      (c) => c.toJson(),
      (c) => c.id,
    );
    reservations = _repo(
      Collections.reservations,
      Reservation.fromJson,
      (r) => r.toJson(),
      (r) => r.id,
    );
    notificationsRepo = _repo(
      Collections.notifications,
      AppNotification.fromJson,
      (n) => n.toJson(),
      (n) => n.id,
    );
    products = _repo(
      Collections.products,
      Product.fromJson,
      (p) => p.toJson(),
      (p) => p.id,
    );
    orders = _repo(
      Collections.orders,
      ShopOrder.fromJson,
      (o) => o.toJson(),
      (o) => o.id,
    );
    auditRepo = _repo(
      Collections.audit,
      AuditEntry.fromJson,
      (a) => a.toJson(),
      (a) => a.id,
    );
    announcementsRepo = _repo(
      Collections.announcements,
      Announcement.fromJson,
      (a) => a.toJson(),
      (a) => a.id,
    );

    auth = AuthService(this);
    userService = UserService(this);
    audit = AuditService(this);
    notifications = NotificationService(this);
    library = LibraryService(this);
    exerciseService = ExerciseService(this);
    workoutService = WorkoutService(this);
    trainingLog = TrainingLogService(this);
    progress = ProgressService(this);
    courseService = CourseService(this);
    reservationService = ReservationService(this);
    productService = ProductService(this);
    cart = CartService(this);
    orderService = OrderService(this);
    dashboard = DashboardService(this);
    announcements = AnnouncementService(this);
    wger = WgerApi(this);
    privacy = PrivacyService(this);
    assistant = AiAssistantService(this);
    mailer = EmailService(this);
    community = CommunityService(this);
    media = MediaStorage();
    smartwatch = SmartwatchService();
    calorieCalculator = const CalorieService();
    weather = WeatherService(httpClient: httpClient);
    this.payment = payment ?? PaymentGateway.fromConfig(httpClient);
  }

  static Backend? _instance;

  /// Instance courante (initialisée dans `main()` ou dans les tests).
  static Backend get I {
    final b = _instance;
    if (b == null) throw StateError('Backend non initialisé.');
    return b;
  }

  static bool get isReady => _instance != null;

  /// Initialise le backend : ouverture du stockage, chargement des
  /// dépôts, jeu de démonstration au premier lancement, session.
  static Future<Backend> init({
    required DataStore store,
    SessionStorage? sessionStorage,
    LocalNotifier? notifier,
    CalendarGateway? calendar,
    http.Client? httpClient,
    DateTime Function()? clock,
    PaymentGateway? payment,
    bool seed = true,
    int passwordIterations = PasswordHasher.defaultIterations,
  }) async {
    final b = Backend._(
      store: store,
      sessionStorage: sessionStorage ?? MemorySessionStorage(),
      notifier: notifier ?? RecordingNotifier(),
      calendar: calendar ?? NoopCalendar(),
      httpClient: httpClient ?? http.Client(),
      clock: clock ?? DateTime.now,
      passwordIterations: passwordIterations,
      payment: payment,
    );
    _instance = b;
    await store.open();
    await b.reload();
    if (seed) {
      await SeedService(b).seedIfEmpty();
      await SeedService(b).upgrade();
    }
    await b.auth.restoreSession();
    return b;
  }

  final DataStore store;
  final SessionStorage sessionStorage;
  final LocalNotifier notifier;
  final CalendarGateway calendar;
  final http.Client httpClient;

  /// Itérations PBKDF2 (réduites dans les tests pour la rapidité).
  final int passwordIterations;

  /// Horloge injectable (tests des règles horaires).
  DateTime Function() clock;
  final DataBus bus = DataBus();
  final List<Repository<dynamic>> _repos = [];

  late final Repository<AppUser> users;
  late final Repository<Credential> credentials;
  late final Repository<Exercise> exercises;
  late final Repository<Workout> workouts;
  late final Repository<Program> programs;
  late final Repository<SessionLog> sessions;
  late final Repository<WeightEntry> weights;
  late final Repository<Course> courses;
  late final Repository<Reservation> reservations;
  late final Repository<AppNotification> notificationsRepo;
  late final Repository<Product> products;
  late final Repository<ShopOrder> orders;
  late final Repository<AuditEntry> auditRepo;
  late final Repository<Announcement> announcementsRepo;

  late final AuthService auth;
  late final UserService userService;
  late final AuditService audit;
  late final NotificationService notifications;
  late final LibraryService library;
  late final ExerciseService exerciseService;
  late final WorkoutService workoutService;
  late final TrainingLogService trainingLog;
  late final ProgressService progress;
  late final CourseService courseService;
  late final ReservationService reservationService;
  late final ProductService productService;
  late final CartService cart;
  late final OrderService orderService;
  late final DashboardService dashboard;
  late final AnnouncementService announcements;
  late final WgerApi wger;
  late final PrivacyService privacy;
  late final AiAssistantService assistant;
  late final EmailService mailer;
  late final CommunityService community;
  late final MediaStorage media;
  late final SmartwatchService smartwatch;
  late final CalorieService calorieCalculator;
  late final WeatherService weather;
  late final PaymentGateway payment;

  Repository<T> _repo<T>(
    String collection,
    T Function(Map<String, dynamic>) fromJson,
    Map<String, dynamic> Function(T) toJson,
    String Function(T) idOf,
  ) {
    final r = Repository<T>(
      store: store,
      collection: collection,
      fromJson: fromJson,
      toJson: toJson,
      idOf: idOf,
    );
    _repos.add(r);
    return r;
  }

  Future<void> reload() async {
    for (final r in _repos) {
      await r.load();
    }
  }

  /// Heure courante.
  DateTime now() => clock();

  /// Utilisateur connecté, ou exception si la session a expiré.
  /// Vérifie aussi que le compte est toujours actif.
  AppUser requireUser() {
    final u = auth.currentUser;
    if (u == null) throw const NotAuthenticatedException();
    final fresh = users.byId(u.id);
    if (fresh == null || !fresh.active) {
      throw const NotAuthenticatedException(
        'Votre compte a été désactivé. Contactez la salle.',
      );
    }
    return fresh;
  }

  /// Contrôle de rôle appliqué dans chaque méthode de service.
  AppUser requireRole(Set<UserRole> roles) {
    final u = requireUser();
    if (!roles.contains(u.role)) throw const PermissionDeniedException();
    return u;
  }

  static const staff = {UserRole.superAdmin, UserRole.coach};
  static const adminOnly = {UserRole.superAdmin};
  static const everyone = {
    UserRole.superAdmin,
    UserRole.coach,
    UserRole.member,
  };
}
