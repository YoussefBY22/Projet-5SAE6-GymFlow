import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../core/formatters.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/enums.dart';
import '../../models/prefs.dart';
import '../../models/user.dart';
import '../../services/backend.dart';
import '../../widgets/animations.dart';
import '../../widgets/bits.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/pickers.dart';
import '../coach/coach_home.dart';
import '../shell/main_shell.dart';

/// Dashboard super admin : chiffres animés, graphiques, raccourcis.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return Scaffold(
      appBar: AppBar(
        leading: const ShellMenuButton(),
        title: const Text('Tableau de bord'),
        actions: const [NotificationBell()],
      ),
      body: ListenableBuilder(
        listenable: b.bus,
        builder: (context, _) {
          final s = b.dashboard.adminStats();
          final signups = b.dashboard.signupsPerWeek();
          final fill = b.dashboard.fillRates();
          final topCourses = b.dashboard.topCourses();
          final topProducts = b.dashboard.topProducts();
          final revenue = b.dashboard.revenuePerWeek();
          return ListView(
            padding: pagePadding(context, bottom: Gap.m),
            children: [
              Text('Vue d\'ensemble du club', style: AppText.title(size: 22)),
              Text(Fmt.day(b.now()), style: AppText.label()),
              const SizedBox(height: Gap.m),
              GridView.count(
                crossAxisCount: isWide(context) ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: Gap.s,
                crossAxisSpacing: Gap.s,
                childAspectRatio: 1.3,
                children: [
                  KpiCard(
                    icon: Icons.group,
                    value: s.members.toDouble(),
                    label: 'Abonnés (${s.activeSubscriptions} actifs)',
                    onTap: () => MainShell.tab.value = 1,
                  ),
                  KpiCard(
                    icon: Icons.sports,
                    value: s.coaches.toDouble(),
                    label: 'Coachs',
                    color: AppColors.red,
                    onTap: () => MainShell.tab.value = 1,
                  ),
                  KpiCard(
                    icon: Icons.event,
                    value: s.upcomingCourses.toDouble(),
                    label: 'Cours à venir (${s.doneCourses} terminés)',
                    onTap: () => MainShell.tab.value = 2,
                  ),
                  KpiCard(
                    icon: Icons.event_available,
                    value: s.reservations.toDouble(),
                    label: 'Réservations actives',
                    color: AppColors.success,
                  ),
                  KpiCard(
                    icon: Icons.fitness_center,
                    value: s.exercises.toDouble(),
                    label: 'Exercices',
                    onTap: () => MainShell.tab.value = 3,
                  ),
                  KpiCard(
                    icon: Icons.calendar_view_week,
                    value: s.programs.toDouble(),
                    label: 'Programmes (${s.workouts} workouts)',
                    color: AppColors.red,
                    onTap: () => MainShell.tab.value = 3,
                  ),
                  KpiCard(
                    icon: Icons.payments,
                    value: s.revenue,
                    label: 'CA total (mois : ${Fmt.money(s.revenueMonth)})',
                    format: (v) => '${v.round()} DT',
                    color: AppColors.success,
                    onTap: () => MainShell.tab.value = 4,
                  ),
                  KpiCard(
                    icon: Icons.inventory_2,
                    value: s.pendingOrders.toDouble(),
                    label: 'Commandes à traiter',
                    color: AppColors.red,
                    onTap: () =>
                        Navigator.pushNamed(context, Routes.adminOrders),
                  ),
                ],
              ),
              const SectionHeader('Inscriptions par semaine'),
              GfCard(
                child: GfBarChart(
                  bars: [
                    for (final (d, n) in signups)
                      ('${d.day}/${d.month}', n.toDouble()),
                  ],
                  color: AppColors.red,
                ),
              ),
              const SectionHeader('Taux de remplissage des cours'),
              GfCard(
                child: Column(
                  children: [
                    for (final (c, rate) in fill)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text(
                                '${c.title}\n${Fmt.dayShort(c.startAt!)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.label(size: 12),
                              ),
                            ),
                            Expanded(
                              child: AnimatedBar(
                                value: rate,
                                color: rate >= 1
                                    ? AppColors.red
                                    : AppColors.navy,
                              ),
                            ),
                            const SizedBox(width: Gap.s),
                            SizedBox(
                              width: 44,
                              child: Text(
                                '${(rate * 100).round()} %',
                                textAlign: TextAlign.right,
                                style: AppText.subtitle(size: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SectionHeader('Chiffre d\'affaires par semaine'),
              GfCard(
                child: GfLineChart(
                  points: [for (final (d, v) in revenue) (d, v)],
                  unit: 'TND',
                  color: AppColors.success,
                ),
              ),
              const SectionHeader('Top cours'),
              _RankList(items: topCourses, unit: 'réservations'),
              const SectionHeader('Top produits'),
              _RankList(items: topProducts, unit: 'vendus'),
              const SectionHeader('Raccourcis'),
              Wrap(
                spacing: Gap.s,
                runSpacing: Gap.s,
                children: [
                  ActionChip(
                    avatar: const Icon(
                      Icons.person_add_alt,
                      color: AppColors.navy,
                    ),
                    label: const Text('Créer un coach'),
                    onPressed: () =>
                        Navigator.pushNamed(context, Routes.newCoach),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.add, color: AppColors.navy),
                    label: const Text('Nouveau cours'),
                    onPressed: () =>
                        Navigator.pushNamed(context, Routes.courseForm),
                  ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.campaign_outlined,
                      color: AppColors.navy,
                    ),
                    label: const Text('Publier une annonce'),
                    onPressed: () =>
                        Navigator.pushNamed(context, Routes.announcementForm),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.history, color: AppColors.navy),
                    label: const Text('Journal d\'audit'),
                    onPressed: () => Navigator.pushNamed(context, Routes.audit),
                  ),
                ],
              ),
              const SizedBox(height: Gap.xl),
            ],
          );
        },
      ),
    );
  }
}

class _RankList extends StatelessWidget {
  const _RankList({required this.items, required this.unit});
  final List<(String, int)> items;
  final String unit;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const GfCard(child: InfoRow(Icons.info_outline, 'Aucune donnée.'));
    }
    final max = items.first.$2;
    return GfCard(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: i == 0 ? AppColors.gold : AppColors.cream,
                    child: Text(
                      '${i + 1}',
                      style: AppText.label(color: AppColors.navy, size: 12),
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].$1,
                          style: AppText.subtitle(size: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        AnimatedBar(
                          value: max == 0 ? 0 : items[i].$2 / max,
                          height: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Text('${items[i].$2} $unit', style: AppText.label(size: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Gestion des utilisateurs et coachs (recherche, filtres, activation).
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, this.standalone = false});
  final bool standalone;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  static const _listKey = 'users';
  final _query = TextEditingController();
  late FilterValues _filters = Backend.I.library.savedFilters(_listKey);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _setFilters(FilterValues f) {
    setState(() => _filters = f);
    Backend.I.library.saveFilters(_listKey, f);
  }

  List<AppUser> _results(FilterValues f) {
    final now = Backend.I.now();
    return Backend.I.userService.list(query: _query.text).where((u) {
      if (f.isActive('role') && !f.has('role', u.role.name)) return false;
      if (f.isActive('status') &&
          !f.has('status', u.active ? 'active' : 'inactive')) {
        return false;
      }
      if (f.isActive('subscription')) {
        if (!u.isMember) return false;
        final ok = u.subscription.isActiveAt(now) ? 'valid' : 'expired';
        if (!f.has('subscription', ok)) return false;
      }
      return true;
    }).toList();
  }

  static final _groups = [
    FilterGroup(
      id: 'role',
      title: 'Rôle',
      icon: Icons.badge_outlined,
      options: [
        for (final r in UserRole.values)
          FilterOption(r.name, r.label, icon: r.icon),
      ],
    ),
    const FilterGroup(
      id: 'status',
      title: 'Compte',
      icon: Icons.toggle_on_outlined,
      options: [
        FilterOption('active', 'Actif'),
        FilterOption('inactive', 'Désactivé'),
      ],
    ),
    const FilterGroup(
      id: 'subscription',
      title: 'Abonnement',
      icon: Icons.card_membership,
      options: [
        FilterOption('valid', 'En cours'),
        FilterOption('expired', 'Expiré'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return Scaffold(
      appBar: AppBar(
        leading: widget.standalone ? null : const ShellMenuButton(),
        title: const Text('Utilisateurs'),
        actions: const [NotificationBell()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'users_fab',
        onPressed: () => Navigator.pushNamed(context, Routes.newCoach),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Coach'),
      ),
      body: ListenableBuilder(
        listenable: b.bus,
        builder: (context, _) {
          final users = _results(_filters);
          return Column(
            children: [
              FilterSearchBar(
                groups: _groups,
                values: _filters,
                onChanged: _setFilters,
                resultCount: (f) => _results(f).length,
                hint: 'Nom ou e-mail',
                query: _query,
                onQuery: (_) => setState(() {}),
              ),
              const SizedBox(height: Gap.xs),
              Expanded(
                child: users.isEmpty
                    ? const EmptyState(
                        icon: Icons.person_search,
                        title: 'Aucun utilisateur',
                        message: 'Modifiez la recherche ou les filtres.',
                      )
                    : ResponsiveList(
                        minTileWidth: 460,
                        maxWidth: 1200,
                        top: Gap.s,
                        spacing: Gap.s,
                        itemCount: users.length,
                        itemBuilder: (_, i) => FadeSlideIn(
                          index: i,
                          child: _UserTile(user: users[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final me = b.auth.currentUser!;
    final now = b.now();
    return GfCard(
      padding: const EdgeInsets.symmetric(horizontal: Gap.s, vertical: Gap.xs),
      onTap: () =>
          Navigator.pushNamed(context, Routes.userDetail, arguments: user.id),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Opacity(opacity: user.active ? 1 : 0.5, child: GfAvatar(user)),
        title: Text(user.fullName, style: AppText.subtitle(size: 14)),
        subtitle: Text(
          [
            user.role.label,
            if (user.isMember)
              user.subscription.isActiveAt(now)
                  ? 'abonnement actif'
                  : 'sans abonnement actif',
            if (!user.active) 'désactivé',
          ].join(' · '),
          style: AppText.label(size: 12),
        ),
        trailing: user.id == me.id
            ? const Pill('Vous')
            : Switch(
                value: user.active,
                onChanged: (v) async {
                  if (!v) {
                    final ok = await confirm(
                      context,
                      title: 'Désactiver ${user.firstName} ?',
                      message:
                          'Le compte ne pourra plus se connecter et sa session sera invalidée.',
                      confirmLabel: 'Désactiver',
                      destructive: true,
                    );
                    if (!ok) return;
                  }
                  if (!context.mounted) return;
                  await runAction(
                    context,
                    () => b.userService.setActive(user.id, v),
                    success: v ? 'Compte activé.' : 'Compte désactivé.',
                  );
                },
              ),
      ),
    );
  }
}

/// Fiche utilisateur (admin) : rôle, abonnement, activité. Aucun accès
/// au mot de passe ni connexion « en tant que ».
class UserDetailScreen extends StatelessWidget {
  const UserDetailScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return ListenableBuilder(
      listenable: b.bus,
      builder: (context, _) {
        final u = b.userService.byId(userId);
        if (u == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.person_off,
              title: 'Utilisateur supprimé',
              message: '',
            ),
          );
        }
        final me = b.auth.currentUser!;
        final now = b.now();
        final self = u.id == me.id;
        final sessions = b.sessions.where((s) => s.userId == u.id).length;
        final bookings = b.reservations
            .where((r) => r.userId == u.id && r.isActive)
            .length;
        final orders = b.orders.where((o) => o.userId == u.id);
        return Scaffold(
          appBar: AppBar(title: Text(u.fullName)),
          body: ListView(
            padding: pagePadding(context, maxWidth: 900, bottom: Gap.m),
            children: [
              GfCard(
                child: Row(
                  children: [
                    GfAvatar(u, radius: 32),
                    const SizedBox(width: Gap.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.fullName, style: AppText.title(size: 18)),
                          Text(u.email, style: AppText.label()),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: [
                              Pill(u.role.label, color: AppColors.navy),
                              Pill(
                                u.active ? 'Actif' : 'Désactivé',
                                color: u.active
                                    ? AppColors.success
                                    : AppColors.red,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Gap.s),
              const GfCard(
                color: AppColors.cream,
                child: InfoRow(
                  Icons.lock_outline,
                  'Les mots de passe sont chiffrés : ni vous ni l\'équipe ne pouvez les consulter.',
                ),
              ),
              const SizedBox(height: Gap.m),
              GfCard(
                child: Column(
                  children: [
                    InfoRow(
                      Icons.calendar_today,
                      'Inscrit le ${Fmt.date(u.createdAt)}',
                    ),
                    if (u.lastLoginAt != null)
                      InfoRow(
                        Icons.login,
                        'Dernière connexion ${Fmt.relative(u.lastLoginAt!, now: now)}',
                      ),
                    if (u.isMember) ...[
                      InfoRow(
                        Icons.card_membership,
                        '${u.subscription.type.label} · ${u.subscription.isActiveAt(now) ? '${u.subscription.daysLeft(now)} j restants' : 'expiré'}',
                      ),
                      InfoRow(
                        Icons.fitness_center,
                        '$sessions séances · $bookings réservations actives',
                      ),
                      InfoRow(
                        Icons.shopping_bag_outlined,
                        '${orders.length} commandes · ${Fmt.money(orders.fold(0.0, (s, o) => s + o.total))}',
                      ),
                    ],
                    if (u.isCoach)
                      InfoRow(Icons.sports, u.specialty ?? 'Coach'),
                  ],
                ),
              ),
              if (!self) ...[
                const FormSection('Rôle'),
                Wrap(
                  spacing: Gap.s,
                  children: [
                    for (final r in UserRole.values)
                      GfFilterChip(
                        label: r.label,
                        icon: r.icon,
                        selected: u.role == r,
                        onTap: () async {
                          if (u.role == r) return;
                          final ok = await confirm(
                            context,
                            title: 'Changer le rôle ?',
                            message: '${u.fullName} deviendra « ${r.label} ».',
                          );
                          if (ok && context.mounted) {
                            await runAction(
                              context,
                              () => b.userService.changeRole(u.id, r),
                              success: 'Rôle mis à jour.',
                            );
                          }
                        },
                      ),
                  ],
                ),
                if (u.isMember) ...[
                  const FormSection('Abonnement'),
                  Wrap(
                    spacing: Gap.s,
                    runSpacing: Gap.s,
                    children: [
                      for (final t in SubscriptionType.values.where(
                        (t) => t != SubscriptionType.none,
                      ))
                        GfFilterChip(
                          label: t.price > 0
                              ? '${t.label} · ${t.price.round()} DT'
                              : t.label,
                          selected:
                              u.subscription.type == t &&
                              u.subscription.isActiveAt(now),
                          onTap: () => runAction(
                            context,
                            () => b.userService.updateSubscription(u.id, t),
                            success: 'Abonnement « ${t.label} » activé.',
                          ),
                        ),
                    ],
                  ),
                  const FormSection('Communauté'),
                  GfCard(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.m),
                    child: Column(
                      children: [
                        InfoRow(
                          u.privacy.profileVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          u.privacy.profileVisible
                              ? 'Le membre a choisi d\'être visible.'
                              : 'Profil privé (choix du membre).',
                        ),
                        SwitchListTile(
                          key: const Key('admin_hide_member'),
                          contentPadding: EdgeInsets.zero,
                          value: u.privacy.hiddenByAdmin,
                          onChanged: (v) async {
                            final ok = await confirm(
                              context,
                              title: v
                                  ? 'Masquer ce membre de la communauté ?'
                                  : 'Lever la mesure de modération ?',
                              message: v
                                  ? 'Son profil et ses séances partagées ne seront plus visibles. '
                                        'Le membre est notifié et l\'action est tracée.'
                                  : 'Le membre retrouvera ses propres réglages de visibilité.',
                            );
                            if (ok && context.mounted) {
                              await runAction(
                                context,
                                () => b.community.setHiddenByAdmin(u.id, v),
                                success: v
                                    ? 'Membre masqué de la communauté.'
                                    : 'Mesure levée.',
                              );
                            }
                          },
                          title: const Text('Masquer de la communauté'),
                          subtitle: const Text(
                            'Modération (ex. après un signalement).',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: Gap.l),
                OutlinedButton.icon(
                  onPressed: () => runAction(
                    context,
                    () => b.userService.setActive(u.id, !u.active),
                    success: u.active ? 'Compte désactivé.' : 'Compte activé.',
                  ),
                  icon: Icon(
                    u.active ? Icons.block : Icons.check_circle_outline,
                  ),
                  label: Text(
                    u.active ? 'Désactiver le compte' : 'Réactiver le compte',
                  ),
                ),
                const SizedBox(height: Gap.s),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.red),
                  onPressed: () async {
                    final ok = await confirm(
                      context,
                      title: 'Supprimer ce compte ?',
                      message:
                          'Action définitive, tracée dans le journal d\'audit.',
                      confirmLabel: 'Supprimer',
                      destructive: true,
                    );
                    if (!ok || !context.mounted) return;
                    final done = await runAction(
                      context,
                      () => b.userService.deleteUser(u.id),
                      success: 'Compte supprimé.',
                    );
                    if (done && context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer le compte'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Création d'un compte coach par le super admin.
class NewCoachScreen extends StatefulWidget {
  const NewCoachScreen({super.key});

  @override
  State<NewCoachScreen> createState() => _NewCoachScreenState();
}

class _NewCoachScreenState extends State<NewCoachScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _specialty = TextEditingController();
  final _password = TextEditingController();
  Gender _gender = Gender.female;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _specialty, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await runAction(
      context,
      () => Backend.I.userService.createCoach(
        fullName: _name.text,
        email: _email.text,
        temporaryPassword: _password.text,
        gender: _gender,
        specialty: _specialty.text,
      ),
      success:
          'Coach créé. Communiquez-lui son mot de passe provisoire en main propre.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau coach')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: pagePadding(context, maxWidth: 760, bottom: Gap.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nom complet'),
                validator: Validators.name,
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-mail professionnel',
                ),
                validator: Validators.email,
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _specialty,
                decoration: const InputDecoration(
                  labelText: 'Spécialité (ex. Pilates, CrossFit)',
                ),
                validator: Validators.text(
                  field: 'La spécialité',
                  min: 3,
                  max: 60,
                ),
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe provisoire',
                  helperText: 'Le coach pourra le changer dans Paramètres.',
                ),
                validator: Validators.password,
              ),
              const FormSection('Genre'),
              Wrap(
                spacing: Gap.s,
                children: [
                  for (final g in Gender.values)
                    GfFilterChip(
                      label: g.label,
                      selected: _gender == g,
                      onTap: () => setState(() => _gender = g),
                    ),
                ],
              ),
              const SizedBox(height: Gap.l),
              LoadingButton(
                label: 'Créer le coach',
                loading: _saving,
                onPressed: _save,
                icon: Icons.person_add_alt,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Journal d'audit des actions sensibles.
class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return ListenableBuilder(
      listenable: b.bus,
      builder: (context, _) {
        final entries = b.audit.entries();
        return Scaffold(
          appBar: AppBar(title: const Text('Journal d\'audit')),
          body: entries.isEmpty
              ? const EmptyState(
                  icon: Icons.history,
                  title: 'Journal vide',
                  message: 'Les actions d\'administration apparaîtront ici.',
                )
              : ListView.separated(
                  padding: pagePadding(context, maxWidth: 900, bottom: Gap.m),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Gap.s),
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    return GfCard(
                      padding: const EdgeInsets.all(Gap.s + 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            color: AppColors.navy,
                          ),
                          const SizedBox(width: Gap.s),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.action,
                                  style: AppText.subtitle(size: 14),
                                ),
                                Text(e.details, style: AppText.body(size: 13)),
                                Text(
                                  '${e.actorName} · ${Fmt.dateTime(e.createdAt)}',
                                  style: AppText.label(size: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
