import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../core/config.dart';
import '../../core/formatters.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/enums.dart';
import '../../services/backend.dart';
import '../../services/exercise_service.dart';
import '../../services/progress_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/bits.dart';
import '../../widgets/common.dart';
import '../../widgets/media.dart';
import '../../widgets/pickers.dart';

/// Annonces du club.
class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final isAdmin = b.auth.currentUser!.isAdmin;
    return ListenableBuilder(
      listenable: b.bus,
      builder: (context, _) {
        final list = b.announcements.list();
        return Scaffold(
          appBar: AppBar(title: const Text('Annonces du club')),
          floatingActionButton: isAdmin
              ? FloatingActionButton(
                  tooltip: 'Publier',
                  onPressed: () =>
                      Navigator.pushNamed(context, Routes.announcementForm),
                  child: const Icon(Icons.add),
                )
              : null,
          body: list.isEmpty
              ? const EmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'Aucune annonce',
                  message: 'Les actualités du club apparaîtront ici.',
                )
              : ListView.separated(
                  padding: pagePadding(context, maxWidth: 900, bottom: Gap.m),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Gap.m),
                  itemBuilder: (_, i) {
                    final a = list[i];
                    return FadeSlideIn(
                      index: i,
                      child: GfCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (a.imageUrl != null)
                              NetImage(
                                a.imageUrl,
                                height: 150,
                                width: double.infinity,
                              ),
                            Padding(
                              padding: const EdgeInsets.all(Gap.m),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (a.pinned)
                                        const Pill(
                                          'Épinglée',
                                          color: AppColors.gold,
                                          icon: Icons.push_pin,
                                        ),
                                      const Spacer(),
                                      Text(
                                        Fmt.relative(a.createdAt, now: b.now()),
                                        style: AppText.label(size: 12),
                                      ),
                                      if (isAdmin)
                                        IconButton(
                                          tooltip: 'Supprimer',
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: AppColors.red,
                                          ),
                                          onPressed: () => runAction(
                                            context,
                                            () => b.announcements.delete(a.id),
                                            success: 'Annonce supprimée.',
                                          ),
                                        ),
                                    ],
                                  ),
                                  Text(a.title, style: AppText.title(size: 18)),
                                  const SizedBox(height: 4),
                                  Text(a.body, style: AppText.body()),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

/// Publication d'une annonce (super admin) : notifie tous les membres.
class AnnouncementFormScreen extends StatefulWidget {
  const AnnouncementFormScreen({super.key});

  @override
  State<AnnouncementFormScreen> createState() => _AnnouncementFormScreenState();
}

class _AnnouncementFormScreenState extends State<AnnouncementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _image = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _image.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await runAction(
      context,
      () => Backend.I.announcements.publish(
        _title.text,
        _body.text,
        imageUrl: _image.text.trim().isEmpty ? null : _image.text.trim(),
      ),
      success: 'Annonce publiée et envoyée aux membres.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle annonce')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: pagePadding(context, maxWidth: 760, bottom: Gap.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Titre'),
                validator: Validators.text(field: 'Le titre', min: 4, max: 80),
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _body,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true,
                ),
                validator: Validators.text(
                  field: 'Le message',
                  min: 10,
                  max: 800,
                ),
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _image,
                decoration: const InputDecoration(
                  labelText: 'Image (adresse web, facultatif)',
                ),
                validator: Validators.url,
              ),
              const SizedBox(height: Gap.l),
              LoadingButton(
                label: 'Publier',
                loading: _saving,
                onPressed: _publish,
                icon: Icons.send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Règlement de la salle et informations « À propos ».
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _rules = [
    (
      'Serviette obligatoire',
      'Posez une serviette sur les bancs et machines, et nettoyez après usage.',
    ),
    (
      'Tenue adaptée',
      'Chaussures de sport propres réservées à l\'intérieur, tenue correcte.',
    ),
    (
      'Rangement',
      'Rangez haltères, disques et accessoires après chaque exercice.',
    ),
    (
      'Respect et bienveillance',
      'La salle est ouverte à tous, tous niveaux : aucun comportement irrespectueux n\'est toléré.',
    ),
    (
      'Réservations',
      'Annulation libre jusqu\'à 2 h avant le cours. Les places libérées profitent à la liste d\'attente.',
    ),
    (
      'Sécurité',
      'Demandez l\'aide d\'un coach pour les charges lourdes. Signalez tout matériel défectueux.',
    ),
    ('Casiers', 'Les casiers sont vidés chaque soir à la fermeture.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Règlement & à propos')),
      body: ListView(
        padding: pagePadding(context, maxWidth: 900, bottom: Gap.m),
        children: [
          GfCard(
            color: AppColors.navy,
            child: Row(
              children: [
                Image.asset('assets/images/logo.png', width: 64),
                const SizedBox(width: Gap.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConfig.gymName,
                        style: AppText.title(color: AppColors.white, size: 18),
                      ),
                      Text(
                        AppConfig.gymAddress,
                        style: AppText.label(color: AppColors.cream),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lun–Ven 6 h–22 h · Sam–Dim 8 h–20 h',
                        style: AppText.label(color: AppColors.cream),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('Règlement intérieur'),
          for (var i = 0; i < _rules.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.s),
              child: GfCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.cream,
                      child: Text(
                        '${i + 1}',
                        style: AppText.label(color: AppColors.navy),
                      ),
                    ),
                    const SizedBox(width: Gap.s),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_rules[i].$1, style: AppText.subtitle(size: 14)),
                          Text(_rules[i].$2, style: AppText.body(size: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SectionHeader('À propos'),
          const GfCard(
            child: Column(
              children: [
                InfoRow(
                  Icons.info_outline,
                  'GymFlow 1.0.0 — application de démonstration.',
                ),
                InfoRow(
                  Icons.image_outlined,
                  'Images d\'exercices : wger.de (CC-BY-SA) · Photos : Unsplash.',
                ),
                InfoRow(
                  Icons.smart_display_outlined,
                  'Vidéos : YouTube (créateurs cités) et wger.de.',
                ),
                InfoRow(
                  Icons.lock_outline,
                  'Mots de passe chiffrés (PBKDF2-SHA256), session sécurisée.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Calculateur IMC et besoins caloriques (Mifflin-St Jeor).
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _user = Backend.I.auth.currentUser!;
  late final _weight = TextEditingController(
    text: _user.weightKg == null ? '' : Fmt.dec1(_user.weightKg!),
  );
  late final _height = TextEditingController(
    text: _user.heightCm?.toStringAsFixed(0) ?? '',
  );
  late final _age = TextEditingController(text: _user.age?.toString() ?? '');
  late Gender _gender = _user.gender;
  late Goal _goal = _user.goal;
  double _activity = 1.55;
  double? _bmi;
  double? _kcal;

  static const _levels = [
    (1.2, 'Sédentaire'),
    (1.375, 'Léger (1-3 séances)'),
    (1.55, 'Modéré (3-5 séances)'),
    (1.725, 'Intense (6-7 séances)'),
  ];

  @override
  void dispose() {
    _weight.dispose();
    _height.dispose();
    _age.dispose();
    super.dispose();
  }

  void _compute() {
    if (!_formKey.currentState!.validate()) return;
    final w = Validators.parseDecimal(_weight.text)!;
    final h = Validators.parseDecimal(_height.text)!;
    final a = int.parse(_age.text.trim());
    setState(() {
      _bmi = ProgressService.bmi(w, h);
      _kcal = ProgressService.dailyCalories(
        bmr: ProgressService.bmr(
          weightKg: w,
          heightCm: h,
          age: a,
          gender: _gender,
        ),
        activityFactor: _activity,
        goal: _goal,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IMC & calories')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: pagePadding(context, maxWidth: 760, bottom: Gap.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
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
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: TextFormField(
                      controller: _age,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Âge'),
                      validator: Validators.intRange(
                        field: 'L\'âge',
                        min: 12,
                        max: 100,
                      ),
                    ),
                  ),
                ],
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
              const FormSection('Niveau d\'activité'),
              Wrap(
                spacing: Gap.s,
                runSpacing: Gap.s,
                children: [
                  for (final (factor, label) in _levels)
                    GfFilterChip(
                      label: label,
                      selected: _activity == factor,
                      onTap: () => setState(() => _activity = factor),
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
              const SizedBox(height: Gap.l),
              ElevatedButton.icon(
                onPressed: _compute,
                icon: const Icon(Icons.calculate),
                label: const Text('Calculer'),
              ),
              const SizedBox(height: Gap.l),
              AnimatedSwitcher(
                duration: kAnim,
                child: _bmi == null
                    ? const SizedBox.shrink()
                    : GfCard(
                        key: ValueKey('$_bmi$_kcal'),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  AnimatedCounter(
                                    value: _bmi!,
                                    format: Fmt.dec1,
                                    style: AppText.display(size: 30),
                                  ),
                                  Text('IMC', style: AppText.label()),
                                  Text(
                                    ProgressService.bmiCategory(_bmi!),
                                    textAlign: TextAlign.center,
                                    style: AppText.subtitle(size: 13),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 70,
                              color: AppColors.divider,
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  AnimatedCounter(
                                    value: _kcal!,
                                    format: (v) => Fmt.number(v.round()),
                                    style: AppText.display(
                                      color: AppColors.red,
                                      size: 30,
                                    ),
                                  ),
                                  Text('kcal / jour', style: AppText.label()),
                                  Text(
                                    _goal.label,
                                    style: AppText.subtitle(size: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: Gap.m),
              Text(
                'Estimation indicative (formule de Mifflin-St Jeor). Pour un suivi nutritionnel, consultez un professionnel de santé.',
                style: AppText.label(size: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Recherche globale : exercices, workouts, programmes, cours, produits.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final q = ExerciseService.normalize(_q);
    bool match(String s) =>
        q.length >= 2 && ExerciseService.normalize(s).contains(q);
    final exercises = b.exercises.all
        .where((e) => match('${e.name} ${e.primaryMuscle.label}'))
        .take(8)
        .toList();
    final workouts = b.workouts.all
        .where((w) => match('${w.name} ${w.focus}'))
        .toList();
    final programs = b.programs.all.where((p) => match(p.name)).toList();
    final courses = b.courses.all
        .where((c) => match('${c.title} ${c.category.label}') && !c.cancelled)
        .take(8)
        .toList();
    final products = b.products.all
        .where((p) => p.active && match(p.name))
        .take(8)
        .toList();
    final total =
        exercises.length +
        workouts.length +
        programs.length +
        courses.length +
        products.length;

    Widget section(String title, IconData icon, List<Widget> tiles) =>
        tiles.isEmpty
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.m, Gap.m, Gap.m, Gap.xs),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: AppColors.red),
                    const SizedBox(width: 6),
                    Text(title, style: AppText.subtitle()),
                  ],
                ),
              ),
              ...tiles,
            ],
          );

    ListTile tile(
      String title,
      String subtitle,
      String? image,
      String route,
      String id,
    ) => ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: NetImage(image, cacheWidth: 150),
        ),
      ),
      title: Text(title, style: AppText.body(size: 15)),
      subtitle: Text(subtitle, style: AppText.label(size: 12)),
      onTap: () => Navigator.pushNamed(context, route, arguments: id),
    );

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          onChanged: (v) => setState(() => _q = v),
          style: AppText.body(color: AppColors.white),
          cursorColor: AppColors.gold,
          decoration: InputDecoration(
            hintText: 'Rechercher dans GymFlow…',
            hintStyle: AppText.body(color: AppColors.navyMuted),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
      body: q.length < 2
          ? const EmptyState(
              icon: Icons.search,
              title: 'Recherche globale',
              message:
                  'Tapez au moins 2 lettres : exercice, cours, produit, programme…',
            )
          : total == 0
          ? EmptyState(
              icon: Icons.search_off,
              title: 'Aucun résultat',
              message: 'Rien ne correspond à « $_q ».',
            )
          : ListView(
              children: [
                section('Exercices', Icons.fitness_center, [
                  for (final e in exercises)
                    tile(
                      e.name,
                      e.primaryMuscle.label,
                      exerciseThumb(e),
                      Routes.exercise,
                      e.id,
                    ),
                ]),
                section('Workouts', Icons.list_alt, [
                  for (final w in workouts)
                    tile(w.name, w.focus, w.coverImage, Routes.workout, w.id),
                ]),
                section('Programmes', Icons.calendar_view_week, [
                  for (final p in programs)
                    tile(
                      p.name,
                      '${p.daysPerWeek} j/sem.',
                      p.coverImage,
                      Routes.program,
                      p.id,
                    ),
                ]),
                section('Cours', Icons.event, [
                  for (final c in courses)
                    tile(
                      c.title,
                      c.startAt == null
                          ? 'À planifier'
                          : Fmt.dateTime(c.startAt!),
                      c.imageUrl,
                      Routes.courseDetail,
                      c.id,
                    ),
                ]),
                section('Boutique', Icons.storefront, [
                  for (final p in products)
                    tile(
                      p.name,
                      Fmt.money(p.effectivePrice),
                      p.images.firstOrNull,
                      Routes.product,
                      p.id,
                    ),
                ]),
                const SizedBox(height: Gap.xl),
              ],
            ),
    );
  }
}
