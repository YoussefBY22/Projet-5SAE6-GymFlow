import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../screens/admin/admin_screens.dart';
import '../screens/admin/shop_admin_screens.dart';
import '../screens/auth/auth_screens.dart';
import '../screens/auth/splash_onboarding.dart';
import '../screens/courses/course_screens.dart';
import '../screens/misc/misc_screens.dart';
import '../screens/profile/profile_screens.dart';
import '../screens/shell/main_shell.dart';
import '../screens/shop/shop_screens.dart';
import '../screens/training/exercise_screens.dart';
import '../screens/training/player_screens.dart';
import '../screens/training/workout_screens.dart';
import '../services/backend.dart';
import '../services/training_log_service.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';

/// Routes nommées centralisées (cours S04 : pushNamed + arguments)
/// avec garde de rôle appliquée à chaque navigation.
class Routes {
  Routes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const forgot = '/forgot';
  static const home = '/home';

  static const exercise = '/exercise';
  static const exerciseForm = '/exercise/form';
  static const wgerImport = '/exercise/wger';
  static const workout = '/workout';
  static const workoutForm = '/workout/form';
  static const program = '/program';
  static const programForm = '/program/form';
  static const player = '/session/player';
  static const summary = '/session/summary';
  static const sessionDetail = '/session/detail';

  static const courseDetail = '/courses/detail';
  static const courseForm = '/courses/form';
  static const attendance = '/courses/attendance';
  static const notifications = '/notifications';

  static const product = '/shop/product';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const orderConfirmation = '/order/confirmation';
  static const orders = '/orders';
  static const order = '/order';

  static const editProfile = '/profile/edit';
  static const progress = '/progress';
  static const settings = '/settings';

  static const users = '/admin/users';
  static const userDetail = '/admin/user';
  static const newCoach = '/admin/coach/new';
  static const audit = '/admin/audit';
  static const shopAdmin = '/admin/shop';
  static const productForm = '/admin/product/form';
  static const adminOrders = '/admin/orders';

  static const announcements = '/announcements';
  static const announcementForm = '/announcement/form';
  static const about = '/about';
  static const calculator = '/calculator';
  static const search = '/search';

  static const _staff = {UserRole.superAdmin, UserRole.coach};
  static const _admin = {UserRole.superAdmin};
  static const _member = {UserRole.member};

  /// Définition des routes : constructeur + rôles autorisés
  /// (`null` = tout utilisateur connecté).
  static final Map<String, _RouteDef> _table = {
    splash: _RouteDef((_) => const SplashScreen(), public: true),
    onboarding: _RouteDef((_) => const OnboardingScreen(), public: true),
    login: _RouteDef((_) => const LoginScreen(), public: true),
    register: _RouteDef((_) => const RegisterScreen(), public: true),
    forgot: _RouteDef((_) => const ForgotPasswordScreen(), public: true),
    home: _RouteDef((_) => const MainShell()),
    exercise: _RouteDef((a) => ExerciseDetailScreen(exerciseId: a! as String)),
    exerciseForm: _RouteDef(
      (a) => ExerciseFormScreen(exerciseId: a as String?),
      roles: _staff,
    ),
    wgerImport: _RouteDef((_) => const WgerImportScreen(), roles: _staff),
    workout: _RouteDef((a) => WorkoutDetailScreen(workoutId: a! as String)),
    workoutForm: _RouteDef(
      (a) => WorkoutFormScreen(workoutId: a as String?),
      roles: _staff,
    ),
    program: _RouteDef((a) => ProgramDetailScreen(programId: a! as String)),
    programForm: _RouteDef(
      (a) => ProgramFormScreen(programId: a as String?),
      roles: _staff,
    ),
    player: _RouteDef((a) => SessionPlayerScreen(workoutId: a! as String)),
    summary: _RouteDef(
      (a) => SessionSummaryScreen(result: a! as SessionResult),
    ),
    sessionDetail: _RouteDef(
      (a) => SessionDetailScreen(sessionId: a! as String),
    ),
    courseDetail: _RouteDef((a) => CourseDetailScreen(courseId: a! as String)),
    courseForm: _RouteDef(
      (a) => CourseFormScreen(courseId: a as String?),
      roles: _staff,
    ),
    attendance: _RouteDef(
      (a) => AttendanceScreen(courseId: a! as String),
      roles: _staff,
    ),
    notifications: _RouteDef((_) => const NotificationsScreen()),
    product: _RouteDef((a) => ProductDetailScreen(productId: a! as String)),
    cart: _RouteDef((_) => const CartScreen()),
    checkout: _RouteDef((a) => CheckoutScreen(direct: a as DirectPurchase?)),
    orderConfirmation: _RouteDef(
      (a) => OrderConfirmationScreen(orderId: a! as String),
    ),
    orders: _RouteDef((_) => const OrdersScreen()),
    order: _RouteDef((a) => OrderDetailScreen(orderId: a! as String)),
    editProfile: _RouteDef((_) => const EditProfileScreen()),
    progress: _RouteDef((_) => const ProgressScreen(), roles: _member),
    settings: _RouteDef((_) => const SettingsScreen()),
    users: _RouteDef((_) => const UsersScreen(standalone: true), roles: _admin),
    userDetail: _RouteDef(
      (a) => UserDetailScreen(userId: a! as String),
      roles: _admin,
    ),
    newCoach: _RouteDef((_) => const NewCoachScreen(), roles: _admin),
    audit: _RouteDef((_) => const AuditScreen(), roles: _admin),
    shopAdmin: _RouteDef(
      (_) => const ShopDashboardScreen(standalone: true),
      roles: _admin,
    ),
    productForm: _RouteDef(
      (a) => ProductFormScreen(productId: a as String?),
      roles: _admin,
    ),
    adminOrders: _RouteDef((_) => const AdminOrdersScreen(), roles: _admin),
    announcements: _RouteDef((_) => const AnnouncementsScreen()),
    announcementForm: _RouteDef(
      (_) => const AnnouncementFormScreen(),
      roles: _admin,
    ),
    about: _RouteDef((_) => const AboutScreen()),
    calculator: _RouteDef((_) => const CalculatorScreen()),
    search: _RouteDef((_) => const SearchScreen()),
  };

  /// Rôles autorisés pour une route (utilisé par les tests de droits).
  static Set<UserRole>? rolesFor(String name) => _table[name]?.roles;

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final def = _table[settings.name];
    if (def == null) {
      return gfRoute(const NotFoundScreen(), settings: settings);
    }
    if (!def.public) {
      final user = Backend.isReady ? Backend.I.auth.currentUser : null;
      if (user == null) {
        return gfRoute(
          const LoginScreen(),
          settings: const RouteSettings(name: login),
        );
      }
      if (def.roles != null && !def.roles!.contains(user.role)) {
        return gfRoute(const AccessDeniedScreen(), settings: settings);
      }
    }
    return gfRoute(def.build(settings.arguments), settings: settings);
  }
}

class _RouteDef {
  const _RouteDef(this.build, {this.roles, this.public = false});
  final Widget Function(Object? argument) build;
  final Set<UserRole>? roles;
  final bool public;
}

/// Écran affiché quand le rôle ne permet pas l'accès.
class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accès refusé')),
      body: EmptyState(
        icon: Icons.lock_outline,
        title: 'Accès réservé',
        message: 'Votre rôle ne permet pas d\'ouvrir cette page.',
        action: 'Retour',
        onAction: () => Navigator.pop(context),
      ),
    );
  }
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page introuvable')),
      body: EmptyState(
        icon: Icons.explore_off,
        title: 'Page introuvable',
        message: 'Cette page n\'existe pas ou plus.',
        action: 'Retour',
        onAction: () => Navigator.pop(context),
      ),
    );
  }
}
