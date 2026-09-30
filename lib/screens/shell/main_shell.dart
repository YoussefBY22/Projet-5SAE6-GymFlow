import 'package:flutter/material.dart';

import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/enums.dart';
import '../../services/backend.dart';
import '../../widgets/bits.dart';
import '../../widgets/common.dart';
import '../admin/admin_screens.dart';
import '../admin/shop_admin_screens.dart';
import '../coach/coach_home.dart';
import '../courses/course_screens.dart';
import '../home/member_home.dart';
import '../profile/profile_screens.dart';
import '../shop/shop_screens.dart';
import '../training/training_screen.dart';

/// Coquille principale : BottomNavigationBar + Drawer selon le rôle
/// (cours S04). Les onglets gardent leur état grâce à IndexedStack.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Ouvre le Drawer de la coquille depuis un écran d'onglet (chaque
  /// onglet a son propre Scaffold/AppBar).
  static void openDrawer(BuildContext context) => context
      .findAncestorStateOfType<_MainShellState>()
      ?._scaffoldKey
      .currentState
      ?.openDrawer();

  /// Permet aux écrans enfants de changer d'onglet (ex. « Voir tout »).
  static final ValueNotifier<int> tab = ValueNotifier<int>(0);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Clé propre à l'instance (pas de clé globale statique partagée).
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    MainShell.tab.value = 0;
    // Demande la permission de notifications (Android 13+).
    Backend.I.notifier.requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Backend.I.auth;
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        final user = auth.currentUser;
        if (user == null) return const SizedBox.shrink();
        final isAdmin = user.role == UserRole.superAdmin;
        final tabs = isAdmin
            ? _adminTabs
            : (user.isCoach ? _coachTabs : _memberTabs);
        return ValueListenableBuilder<int>(
          valueListenable: MainShell.tab,
          builder: (context, index, _) {
            final i = index.clamp(0, tabs.length - 1);
            return Scaffold(
              key: _scaffoldKey,
              drawer: const AppDrawer(),
              body: IndexedStack(
                index: i,
                children: [for (final t in tabs) t.screen],
              ),
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: i,
                onTap: (v) => MainShell.tab.value = v,
                items: [
                  for (final t in tabs)
                    BottomNavigationBarItem(
                      icon: Icon(t.icon),
                      activeIcon: Icon(t.activeIcon),
                      label: t.label,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static const _memberTabs = [
    _Tab('Accueil', Icons.home_outlined, Icons.home, MemberHomeScreen()),
    _Tab(
      'Entraînement',
      Icons.fitness_center_outlined,
      Icons.fitness_center,
      TrainingScreen(),
    ),
    _Tab('Cours', Icons.event_outlined, Icons.event, CoursesScreen()),
    _Tab('Boutique', Icons.storefront_outlined, Icons.storefront, ShopScreen()),
    _Tab('Profil', Icons.person_outline, Icons.person, ProfileScreen()),
  ];

  static const _coachTabs = [
    _Tab(
      'Accueil',
      Icons.dashboard_outlined,
      Icons.dashboard,
      CoachHomeScreen(),
    ),
    _Tab(
      'Entraînement',
      Icons.fitness_center_outlined,
      Icons.fitness_center,
      TrainingScreen(),
    ),
    _Tab('Cours', Icons.event_outlined, Icons.event, CoursesScreen()),
    _Tab('Boutique', Icons.storefront_outlined, Icons.storefront, ShopScreen()),
    _Tab('Profil', Icons.person_outline, Icons.person, ProfileScreen()),
  ];

  static const _adminTabs = [
    _Tab(
      'Dashboard',
      Icons.insights_outlined,
      Icons.insights,
      AdminDashboardScreen(),
    ),
    _Tab('Utilisateurs', Icons.group_outlined, Icons.group, UsersScreen()),
    _Tab('Cours', Icons.event_outlined, Icons.event, CoursesScreen()),
    _Tab(
      'Contenu',
      Icons.video_library_outlined,
      Icons.video_library,
      TrainingScreen(contentMode: true),
    ),
    _Tab(
      'Boutique',
      Icons.storefront_outlined,
      Icons.storefront,
      ShopDashboardScreen(),
    ),
  ];
}

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon, this.screen);
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget screen;
}

/// Bouton « menu » qui ouvre le Drawer de la coquille.
class ShellMenuButton extends StatelessWidget {
  const ShellMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Menu',
      icon: const Icon(Icons.menu),
      onPressed: () => MainShell.openDrawer(context),
    );
  }
}

/// Cloche du centre de notifications avec pastille non lue.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final n = Backend.I.notifications;
    return ListenableBuilder(
      listenable: n,
      builder: (context, _) => CountBadge(
        count: n.unreadCount,
        child: IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => Navigator.pushNamed(context, Routes.notifications),
        ),
      ),
    );
  }
}

/// Icône panier avec nombre d'articles.
class CartButton extends StatelessWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Backend.I.cart;
    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) => CountBadge(
        count: cart.count,
        child: IconButton(
          tooltip: 'Panier',
          icon: const Icon(Icons.shopping_bag_outlined),
          onPressed: () => Navigator.pushNamed(context, Routes.cart),
        ),
      ),
    );
  }
}

/// Menu latéral (Drawer) adapté au rôle.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final user = b.auth.currentUser!;
    void go(String route) {
      Navigator.pop(context);
      Navigator.pushNamed(context, route);
    }

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.navy,
            padding: EdgeInsets.fromLTRB(
              Gap.m,
              MediaQuery.paddingOf(context).top + Gap.m,
              Gap.m,
              Gap.m,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GfAvatar(user, radius: 30),
                const SizedBox(height: Gap.s),
                Text(
                  user.fullName,
                  style: AppText.title(color: AppColors.white, size: 18),
                ),
                Text(user.email, style: AppText.label(color: AppColors.cream)),
                const SizedBox(height: Gap.s),
                Pill(
                  user.role.label,
                  color: AppColors.gold,
                  icon: user.role.icon,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _item(
                  Icons.person_outline,
                  'Mon profil',
                  () => go(Routes.editProfile),
                ),
                if (user.isMember)
                  _item(
                    Icons.show_chart,
                    'Ma progression',
                    () => go(Routes.progress),
                  ),
                _item(
                  Icons.receipt_long_outlined,
                  'Mes commandes',
                  () => go(Routes.orders),
                ),
                ListenableBuilder(
                  listenable: b.notifications,
                  builder: (context, _) => _item(
                    Icons.notifications_outlined,
                    'Notifications',
                    () => go(Routes.notifications),
                    trailing: b.notifications.unreadCount > 0
                        ? Pill(
                            '${b.notifications.unreadCount}',
                            color: AppColors.red,
                          )
                        : null,
                  ),
                ),
                _item(
                  Icons.campaign_outlined,
                  'Annonces du club',
                  () => go(Routes.announcements),
                ),
                _item(Icons.search, 'Recherche', () => go(Routes.search)),
                _item(
                  Icons.calculate_outlined,
                  'Calculateur IMC & calories',
                  () => go(Routes.calculator),
                ),
                if (user.isAdmin) ...[
                  const Divider(),
                  _section('Administration'),
                  _item(
                    Icons.person_add_alt,
                    'Créer un coach',
                    () => go(Routes.newCoach),
                  ),
                  _item(
                    Icons.inventory_2_outlined,
                    'Commandes à traiter',
                    () => go(Routes.adminOrders),
                  ),
                  _item(
                    Icons.history,
                    'Journal d\'audit',
                    () => go(Routes.audit),
                  ),
                  _item(
                    Icons.add_alert_outlined,
                    'Publier une annonce',
                    () => go(Routes.announcementForm),
                  ),
                ],
                const Divider(),
                _item(
                  Icons.settings_outlined,
                  'Paramètres',
                  () => go(Routes.settings),
                ),
                _item(
                  Icons.info_outline,
                  'Règlement & à propos',
                  () => go(Routes.about),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.red),
              title: Text(
                'Se déconnecter',
                style: AppText.subtitle(color: AppColors.red, size: 15),
              ),
              onTap: () async {
                await b.auth.logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    Routes.login,
                    (_) => false,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(Gap.m, Gap.s, Gap.m, Gap.xs),
    child: Text(t.toUpperCase(), style: AppText.label(size: 12)),
  );

  Widget _item(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Widget? trailing,
  }) => ListTile(
    leading: Icon(icon, color: AppColors.navy),
    title: Text(label, style: AppText.body(size: 15)),
    trailing: trailing,
    onTap: onTap,
  );
}
