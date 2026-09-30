import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/course.dart';
import '../../models/enums.dart';
import '../../models/session_log.dart';
import '../../models/user.dart';
import '../../services/backend.dart';
import '../../services/progress_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/bits.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/pickers.dart';
import '../shell/main_shell.dart';
import '../shop/shop_screens.dart';

/// Espace personnel (TabBar : Infos / Progression / Achats).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final isMember = b.auth.currentUser?.isMember ?? false;
    return DefaultTabController(
      length: isMember ? 3 : 2,
      child: Scaffold(
        appBar: AppBar(
          leading: const ShellMenuButton(),
          title: const Text('Mon espace'),
          actions: [
            IconButton(
              tooltip: 'Modifier le profil',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.pushNamed(context, Routes.editProfile),
            ),
            const NotificationBell(),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Infos'),
              if (isMember) const Tab(text: 'Progression'),
              const Tab(text: 'Achats'),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: Listenable.merge([b.bus, b.auth]),
          builder: (context, _) {
            final user = b.auth.currentUser;
            if (user == null) return const SizedBox.shrink();
            return TabBarView(
              children: [
                _InfosTab(user: user),
                if (isMember) ProgressView(user: user),
                const _PurchasesTab(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InfosTab extends StatelessWidget {
  const _InfosTab({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final now = b.now();
    final bmi = ProgressService.bmi(user.weightKg, user.heightCm);
    final sessions = user.isMember
        ? b.trainingLog.historyOf(user.id)
        : <SessionLog>[];
    final attended = user.isMember
        ? b.reservationService.attendedCourses(user.id)
        : <(Reservation, Course)>[];
    final sub = user.subscription;
    return ListView(
      padding: const EdgeInsets.all(Gap.m),
      children: [
        GfCard(
          child: Row(
            children: [
              Hero(tag: 'avatar', child: GfAvatar(user, radius: 36)),
              const SizedBox(width: Gap.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName, style: AppText.title()),
                    Text(user.email, style: AppText.label()),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Pill(
                          user.role.label,
                          color: AppColors.navy,
                          icon: user.role.icon,
                        ),
                        if (user.isMember)
                          Pill(
                            user.goal.label,
                            color: AppColors.gold,
                            icon: user.goal.icon,
                          ),
                        if (user.specialty != null) Pill(user.specialty!),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (user.isMember) ...[
          const SizedBox(height: Gap.m),
          GfCard(
            color: sub.isActiveAt(now) ? AppColors.navy : AppColors.redSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.card_membership,
                      color: sub.isActiveAt(now)
                          ? AppColors.gold
                          : AppColors.red,
                    ),
                    const SizedBox(width: Gap.s),
                    Expanded(
                      child: Text(
                        'Abonnement ${sub.type.label}',
                        style: AppText.subtitle(
                          color: sub.isActiveAt(now)
                              ? AppColors.white
                              : AppColors.red,
                        ),
                      ),
                    ),
                    Pill(
                      sub.isActiveAt(now) ? 'Actif' : 'Expiré',
                      color: sub.isActiveAt(now)
                          ? AppColors.success
                          : AppColors.red,
                    ),
                  ],
                ),
                const SizedBox(height: Gap.s),
                if (sub.start != null && sub.end != null) ...[
                  Text(
                    'Du ${Fmt.date(sub.start!)} au ${Fmt.date(sub.end!)}',
                    style: AppText.body(
                      size: 14,
                      color: sub.isActiveAt(now)
                          ? AppColors.cream
                          : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: Gap.s),
                  if (sub.isActiveAt(now)) ...[
                    AnimatedBar(
                      value:
                          1 -
                          sub.daysLeft(now) /
                              (sub.end!
                                  .difference(sub.start!)
                                  .inDays
                                  .clamp(1, 400)),
                      color: AppColors.gold,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${sub.daysLeft(now)} jours restants',
                      style: AppText.stat(color: AppColors.white, size: 16),
                    ),
                  ] else
                    Text(
                      'Renouvelez-le à l\'accueil pour réserver des cours.',
                      style: AppText.body(size: 14),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Gap.m),
          GfCard(
            child: Row(
              children: [
                Expanded(
                  child: StatTile(
                    value: user.age == null ? '—' : '${user.age}',
                    label: 'ans',
                  ),
                ),
                Expanded(
                  child: StatTile(
                    value: user.heightCm == null
                        ? '—'
                        : user.heightCm!.toStringAsFixed(0),
                    label: 'cm',
                  ),
                ),
                Expanded(
                  child: StatTile(
                    value: user.weightKg == null
                        ? '—'
                        : Fmt.dec1(user.weightKg!),
                    label: 'kg',
                  ),
                ),
                Expanded(
                  child: StatTile(
                    value: bmi == null ? '—' : Fmt.dec1(bmi),
                    label: bmi == null
                        ? 'IMC'
                        : 'IMC · ${ProgressService.bmiCategory(bmi)}',
                  ),
                ),
              ],
            ),
          ),
          SectionHeader('Badges & succès'),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: Gap.s,
            crossAxisSpacing: Gap.s,
            childAspectRatio: 0.82,
            children: [
              for (final badge in b.progress.badgesOf(user.id))
                GfCard(
                  padding: const EdgeInsets.all(Gap.s),
                  color: badge.unlocked ? AppColors.cream : AppColors.white,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ProgressRing(
                        progress: badge.progress,
                        size: 52,
                        stroke: 5,
                        color: badge.unlocked ? AppColors.red : AppColors.navy,
                        track: AppColors.divider,
                        child: Icon(
                          badge.icon,
                          color: badge.unlocked
                              ? AppColors.red
                              : AppColors.inkSoft,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        badge.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: AppText.subtitle(size: 12),
                      ),
                      Text(
                        badge.description,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label(size: 10),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SectionHeader('Historique des séances (${sessions.length})'),
          if (sessions.isEmpty)
            const GfCard(
              child: InfoRow(
                Icons.fitness_center,
                'Aucune séance pour l\'instant. Lancez votre premier workout !',
              ),
            )
          else
            for (final s in sessions.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.s),
                child: GfCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.m,
                    vertical: Gap.s,
                  ),
                  onTap: () => Navigator.pushNamed(
                    context,
                    Routes.sessionDetail,
                    arguments: s.id,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.fitness_center, color: AppColors.red),
                      const SizedBox(width: Gap.s),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title, style: AppText.subtitle(size: 14)),
                            Text(
                              '${Fmt.dayShort(s.startedAt)} · ${Fmt.duration(Duration(seconds: s.durationSec))} · ${s.totalSets} séries',
                              style: AppText.label(size: 12),
                            ),
                          ],
                        ),
                      ),
                      if (s.prCount > 0)
                        Pill('${s.prCount} PR', color: AppColors.gold),
                    ],
                  ),
                ),
              ),
          SectionHeader('Cours suivis (${attended.length})'),
          if (attended.isEmpty)
            const GfCard(
              child: InfoRow(
                Icons.event,
                'Vos cours terminés apparaîtront ici.',
              ),
            )
          else
            for (final (r, c) in attended.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.s),
                child: GfCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.m,
                    vertical: Gap.s,
                  ),
                  onTap: () => Navigator.pushNamed(
                    context,
                    Routes.courseDetail,
                    arguments: c.id,
                  ),
                  child: Row(
                    children: [
                      Icon(c.category.icon, color: AppColors.navy),
                      const SizedBox(width: Gap.s),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.title, style: AppText.subtitle(size: 14)),
                            Text(
                              Fmt.dayShort(c.startAt!),
                              style: AppText.label(size: 12),
                            ),
                          ],
                        ),
                      ),
                      if (r.rating != null)
                        RatingStars(value: r.rating!.toDouble(), size: 14)
                      else
                        const Pill('À noter', color: AppColors.gold),
                    ],
                  ),
                ),
              ),
        ] else ...[
          const SizedBox(height: Gap.m),
          if (user.bio != null)
            GfCard(child: Text(user.bio!, style: AppText.body())),
          const SizedBox(height: Gap.m),
          GfCard(
            child: Row(
              children: [
                Expanded(
                  child: StatTile(
                    value:
                        '${b.exercises.all.where((e) => e.authorId == user.id).length}',
                    label: 'Exercices créés',
                  ),
                ),
                Expanded(
                  child: StatTile(
                    value:
                        '${b.workouts.all.where((w) => w.authorId == user.id).length}',
                    label: 'Workouts',
                  ),
                ),
                Expanded(
                  child: StatTile(
                    value:
                        '${b.courses.all.where((c) => c.coachId == user.id).length}',
                    label: 'Cours',
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Gap.xl),
      ],
    );
  }
}

class _PurchasesTab extends StatelessWidget {
  const _PurchasesTab();

  @override
  Widget build(BuildContext context) {
    final orders = Backend.I.orderService.mine();
    if (orders.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'Aucun achat',
        message: 'Vos articles achetés à la boutique apparaîtront ici.',
        action: 'Voir la boutique',
        onAction: () => MainShell.tab.value = 3,
      );
    }
    final items = <String, int>{};
    for (final o in orders) {
      for (final l in o.lines) {
        items[l.name] = (items[l.name] ?? 0) + l.quantity;
      }
    }
    return ListView(
      padding: const EdgeInsets.all(Gap.m),
      children: [
        Text('Articles achetés', style: AppText.title(size: 18)),
        const SizedBox(height: Gap.s),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in items.entries) Pill('${e.value} × ${e.key}'),
          ],
        ),
        const SizedBox(height: Gap.l),
        Text('Commandes', style: AppText.title(size: 18)),
        const SizedBox(height: Gap.s),
        for (final o in orders)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.s),
            child: OrderTile(order: o),
          ),
      ],
    );
  }
}

/// Progression : objectif hebdo (anneau), série, poids (courbe),
/// volume hebdomadaire, records personnels.
class ProgressView extends StatelessWidget {
  const ProgressView({super.key, required this.user});
  final AppUser user;

  Future<void> _addWeight(BuildContext context) async {
    final value = await askText(
      context,
      title: 'Nouvelle pesée',
      label: 'Poids (kg)',
      initial: user.weightKg == null ? '' : Fmt.dec1(user.weightKg!),
      validator: Validators.decimalRange(field: 'Le poids', min: 30, max: 250),
    );
    if (value == null || !context.mounted) return;
    await runAction(
      context,
      () => Backend.I.progress.addWeight(Validators.parseDecimal(value)!),
      success: 'Pesée enregistrée.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Backend.I.progress;
    final week = p.sessionsThisWeek(user.id);
    final streak = p.streakDays(user.id);
    final weights = p.weightsOf(user.id);
    final volume = p.weeklyVolume(user.id);
    final records = p.recordsOf(user.id);
    final bmi = ProgressService.bmi(user.weightKg, user.heightCm);
    return ListView(
      padding: const EdgeInsets.all(Gap.m),
      children: [
        GfCard(
          child: Row(
            children: [
              ProgressRing(
                progress: user.weeklyGoal == 0 ? 0 : week / user.weeklyGoal,
                size: 110,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedCounter(
                      value: week.toDouble(),
                      style: AppText.display(size: 28),
                    ),
                    Text(
                      '/ ${user.weeklyGoal} séances',
                      style: AppText.label(size: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Objectif de la semaine', style: AppText.subtitle()),
                    const SizedBox(height: Gap.s),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          color: AppColors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          streak == 0
                              ? 'Pas encore de série'
                              : "$streak jour${streak > 1 ? 's' : ''} d'affilée",
                          style: AppText.subtitle(size: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      week >= user.weeklyGoal
                          ? 'Objectif atteint, bravo !'
                          : 'Encore ${user.weeklyGoal - week} séance(s) pour l\'atteindre.',
                      style: AppText.label(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SectionHeader(
          'Poids',
          action: 'Ajouter',
          onAction: () => _addWeight(context),
        ),
        GfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (bmi != null)
                Text(
                  'IMC actuel : ${Fmt.dec1(bmi)} — ${ProgressService.bmiCategory(bmi)}',
                  style: AppText.label(),
                ),
              const SizedBox(height: Gap.s),
              GfLineChart(
                points: [for (final w in weights) (w.date, w.weightKg)],
                unit: 'kg',
              ),
            ],
          ),
        ),
        const SectionHeader('Volume soulevé par semaine'),
        GfCard(
          child: GfBarChart(
            bars: [for (final (d, v) in volume) ('${d.day}/${d.month}', v)],
            color: AppColors.navy,
            valueLabel: (v) => v >= 1000
                ? '${(v / 1000).toStringAsFixed(1)} t'
                : v.toStringAsFixed(0),
          ),
        ),
        SectionHeader('Records personnels (${records.length})'),
        if (records.isEmpty)
          const GfCard(
            child: InfoRow(
              Icons.emoji_events_outlined,
              'Vos records apparaîtront après vos premières séances avec charges.',
            ),
          )
        else
          for (final r in records.take(10))
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.s),
              child: GfCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.m,
                  vertical: Gap.s,
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.gold,
                      child: Icon(
                        Icons.emoji_events,
                        color: AppColors.navy,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: Gap.s),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.exerciseName,
                            style: AppText.subtitle(size: 14),
                          ),
                          Text(
                            '1RM estimé : ${Fmt.kg(r.estimatedOneRm.roundToDouble())} · ${Fmt.date(r.date)}',
                            style: AppText.label(size: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${Fmt.kg(r.bestLoadKg)} × ${r.repsAtBest}',
                      style: AppText.stat(size: 15),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: Gap.xl),
      ],
    );
  }
}

/// Route dédiée « Ma progression » (depuis le Drawer).
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return Scaffold(
      appBar: AppBar(title: const Text('Ma progression')),
      body: ListenableBuilder(
        listenable: Listenable.merge([b.bus, b.auth]),
        builder: (context, _) => ProgressView(user: b.auth.currentUser!),
      ),
    );
  }
}

/// Édition du profil (photo via image_picker, mensurations, objectif).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AppUser _user = Backend.I.auth.currentUser!;
  late final _name = TextEditingController(text: _user.fullName);
  late final _age = TextEditingController(text: _user.age?.toString() ?? '');
  late final _height = TextEditingController(
    text: _user.heightCm?.toStringAsFixed(0) ?? '',
  );
  late final _weight = TextEditingController(
    text: _user.weightKg == null ? '' : Fmt.dec1(_user.weightKg!),
  );
  late final _phone = TextEditingController(text: _user.phone ?? '');
  late Goal _goal = _user.goal;
  late Gender _gender = _user.gender;
  late int _weeklyGoal = _user.weeklyGoal;
  late String? _avatar = _user.avatarPath;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _age, _height, _weight, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final path = await pickImageFile(context);
    if (path != null) setState(() => _avatar = path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await runAction(
      context,
      () => Backend.I.userService.updateProfile(
        fullName: _name.text,
        age: int.tryParse(_age.text.trim()),
        heightCm: Validators.parseDecimal(_height.text),
        weightKg: Validators.parseDecimal(_weight.text),
        goal: _goal,
        gender: _gender,
        avatarPath: _avatar,
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        weeklyGoal: _weeklyGoal,
      ),
      success: 'Profil mis à jour.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _user.copyWith(avatarPath: _avatar);
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier mon profil')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Gap.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      Hero(tag: 'avatar', child: GfAvatar(preview, radius: 48)),
                      const Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.red,
                          child: Icon(
                            Icons.photo_camera,
                            color: AppColors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_avatar != null)
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _avatar = null),
                    child: const Text('Retirer la photo'),
                  ),
                ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nom complet'),
                validator: Validators.name,
              ),
              const SizedBox(height: Gap.m),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _age,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Âge'),
                      validator: Validators.intRange(
                        field: 'L\'âge',
                        min: 12,
                        max: 100,
                        optional: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: TextFormField(
                      controller: _height,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Taille (cm)',
                      ),
                      validator: Validators.decimalRange(
                        field: 'La taille',
                        min: 100,
                        max: 230,
                        optional: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: TextFormField(
                      controller: _weight,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Poids (kg)',
                      ),
                      validator: Validators.decimalRange(
                        field: 'Le poids',
                        min: 30,
                        max: 250,
                        optional: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone (facultatif)',
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return null;
                  return RegExp(r'^\+?[\d\s]{8,16}$').hasMatch(t)
                      ? null
                      : 'Numéro invalide.';
                },
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
              const FormSection('Objectif'),
              Wrap(
                spacing: Gap.s,
                runSpacing: Gap.s,
                children: [
                  for (final g in Goal.values)
                    GfFilterChip(
                      label: g.label,
                      icon: g.icon,
                      selected: _goal == g,
                      onTap: () => setState(() => _goal = g),
                    ),
                ],
              ),
              FormSection(
                'Objectif hebdomadaire : $_weeklyGoal séance${_weeklyGoal > 1 ? 's' : ''}',
              ),
              Slider(
                value: _weeklyGoal.toDouble(),
                min: 1,
                max: 7,
                divisions: 6,
                label: '$_weeklyGoal',
                activeColor: AppColors.red,
                inactiveColor: AppColors.divider,
                onChanged: (v) => setState(() => _weeklyGoal = v.round()),
              ),
              const SizedBox(height: Gap.l),
              LoadingButton(
                label: 'Enregistrer',
                loading: _saving,
                onPressed: _save,
                icon: Icons.check,
              ),
              const SizedBox(height: Gap.l),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paramètres : mot de passe, notifications, déconnexion.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await runAction(
      context,
      () => Backend.I.auth.changePassword(_old.text, _new.text),
      success: 'Mot de passe modifié.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) _formKey.currentState!.reset();
    if (ok) {
      _old.clear();
      _new.clear();
      _confirm.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(Gap.m),
        children: [
          Text('Sécurité', style: AppText.title(size: 18)),
          const SizedBox(height: Gap.s),
          GfCard(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _old,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe actuel',
                    ),
                    validator: (v) => (v ?? '').isEmpty ? 'Obligatoire.' : null,
                  ),
                  const SizedBox(height: Gap.m),
                  TextFormField(
                    controller: _new,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nouveau mot de passe',
                    ),
                    validator: Validators.password,
                  ),
                  const SizedBox(height: Gap.m),
                  TextFormField(
                    controller: _confirm,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirmer'),
                    validator: (v) => v != _new.text
                        ? 'Les mots de passe ne correspondent pas.'
                        : null,
                  ),
                  const SizedBox(height: Gap.m),
                  LoadingButton(
                    label: 'Changer le mot de passe',
                    loading: _saving,
                    onPressed: _changePassword,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.l),
          Text('Notifications', style: AppText.title(size: 18)),
          const SizedBox(height: Gap.s),
          GfCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Autoriser les rappels de cours'),
              subtitle: const Text(
                'Rappels 24 h et 1 h avant vos cours réservés',
              ),
              onTap: () => b.notifier.requestPermission(),
            ),
          ),
          const SizedBox(height: Gap.l),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: const BorderSide(color: AppColors.red),
            ),
            onPressed: () async {
              await b.auth.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  Routes.login,
                  (_) => false,
                );
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}
