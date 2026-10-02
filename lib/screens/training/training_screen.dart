import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/enums.dart';
import '../../models/exercise.dart';
import '../../models/prefs.dart';
import '../../models/user.dart';
import '../../models/workout.dart';
import '../../services/backend.dart';
import '../../services/library_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/flip.dart';
import '../../widgets/library_widgets.dart';
import '../shell/main_shell.dart';

/// Onglet Entraînement (TabBar : Programmes / Workouts / Exercices).
/// Pour le super admin, le même écran sert d'onglet « Contenu ».
///
/// Chaque liste : recherche bilingue, bouton « Filtres » (mémorisés avec le
/// compte), favoris en tête avec animation, et création de contenu par
/// tous (privé pour un abonné, publiable après validation).
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key, this.contentMode = false});
  final bool contentMode;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this)
    ..addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });

  static const _kinds = [
    ContentKind.program,
    ContentKind.workout,
    ContentKind.exercise,
  ];

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _add() {
    final route = switch (_kinds[_tabs.index]) {
      ContentKind.program => Routes.programForm,
      ContentKind.workout => Routes.workoutForm,
      ContentKind.exercise => Routes.exerciseForm,
    };
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final user = Backend.I.auth.currentUser!;
    final kind = _kinds[_tabs.index];
    final staff = user.canManageContent;
    return Scaffold(
      appBar: AppBar(
        leading: const ShellMenuButton(),
        title: Text(widget.contentMode ? 'Contenu' : 'Entraînement'),
        actions: [
          const ContentLangButton(),
          const ReviewQueueButton(),
          if (staff)
            IconButton(
              tooltip: 'Importer depuis wger',
              icon: const Icon(Icons.cloud_download_outlined),
              onPressed: () => Navigator.pushNamed(context, Routes.wgerImport),
            ),
          const NotificationBell(),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Programmes'),
            Tab(text: 'Workouts'),
            Tab(text: 'Exercices'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('create_content_fab'),
        heroTag: 'training_fab',
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: Text(
          staff
              ? kind.label
              : switch (kind) {
                  ContentKind.program => 'Mon programme',
                  ContentKind.workout => 'Mon workout',
                  ContentKind.exercise => 'Mon exercice',
                },
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [for (final k in _kinds) LibraryTab(kind: k)],
      ),
    );
  }
}

/// Groupes de filtres proposés selon le type de contenu.
List<FilterGroup> libraryFilterGroups(ContentKind kind, AppUser me) {
  final origin = FilterGroup(
    id: LibraryFilters.origin,
    title: 'Origine',
    icon: Icons.source_outlined,
    options: [
      const FilterOption(
        LibraryFilters.club,
        'Club GymFlow',
        icon: Icons.verified_outlined,
      ),
      const FilterOption(
        LibraryFilters.community,
        'Communauté',
        icon: Icons.groups_outlined,
      ),
      FilterOption(
        LibraryFilters.mine,
        me.canManageContent ? 'Mes contenus' : 'Mes créations',
        icon: Icons.person_outline,
      ),
    ],
  );
  const favorites = FilterGroup(
    id: LibraryFilters.favorites,
    title: 'Favoris',
    icon: Icons.favorite_border,
    options: [
      FilterOption('only', 'Mes favoris uniquement', icon: Icons.favorite),
    ],
  );
  final level = FilterGroup(
    id: LibraryFilters.level,
    title: 'Niveau',
    icon: Icons.signal_cellular_alt,
    options: [for (final l in Level.values) FilterOption(l.name, l.label)],
  );
  final goal = FilterGroup(
    id: LibraryFilters.goal,
    title: 'Objectif',
    icon: Icons.flag_outlined,
    options: [
      for (final g in Goal.values) FilterOption(g.name, g.label, icon: g.icon),
    ],
  );
  final equipment = FilterGroup(
    id: LibraryFilters.equipment,
    title: 'Matériel disponible',
    icon: Icons.fitness_center,
    help: kind == ContentKind.exercise
        ? 'Exercices réalisables avec ce matériel.'
        : 'N\'affiche que les séances faisables avec le matériel coché.',
    options: [for (final e in Equipment.values) FilterOption(e.name, e.label)],
  );
  final muscles = FilterGroup(
    id: LibraryFilters.muscle,
    title: kind == ContentKind.exercise ? 'Muscle ciblé' : 'Muscles travaillés',
    icon: Icons.accessibility_new,
    options: [for (final m in Muscle.values) FilterOption(m.name, m.label)],
  );
  const lang = FilterGroup(
    id: LibraryFilters.lang,
    title: 'Langue disponible',
    icon: Icons.translate,
    help: 'Contenus dont le nom existe dans cette langue.',
    options: [
      FilterOption(ContentLang.fr, 'Français'),
      FilterOption(ContentLang.en, 'English'),
    ],
  );
  final status = FilterGroup(
    id: LibraryFilters.status,
    title: 'Statut de mes créations',
    icon: Icons.public,
    options: [
      for (final s in ContentStatus.values)
        FilterOption(
          s.name,
          s == ContentStatus.private ? 'Personnel' : s.label,
          icon: s.icon,
        ),
    ],
  );
  return switch (kind) {
    ContentKind.exercise => [
      favorites,
      muscles,
      equipment,
      level,
      FilterGroup(
        id: LibraryFilters.type,
        title: 'Type d\'exercice',
        icon: Icons.category_outlined,
        options: [
          for (final t in ExerciseType.values) FilterOption(t.name, t.label),
        ],
      ),
      const FilterGroup(
        id: LibraryFilters.media,
        title: 'Démonstration',
        icon: Icons.play_circle_outline,
        options: [
          FilterOption('video', 'Avec vidéo', icon: Icons.smart_display),
        ],
      ),
      origin,
      if (!me.canManageContent) status,
      lang,
    ],
    ContentKind.workout => [
      favorites,
      goal,
      level,
      const FilterGroup(
        id: LibraryFilters.duration,
        title: 'Durée',
        icon: Icons.timer_outlined,
        options: [
          FilterOption('lt30', 'Moins de 30 min'),
          FilterOption('30_45', '30 à 45 min'),
          FilterOption('45_60', '45 min à 1 h'),
          FilterOption('gt60', 'Plus d\'une heure'),
        ],
      ),
      muscles,
      equipment,
      origin,
      if (!me.canManageContent) status,
      lang,
    ],
    ContentKind.program => [
      favorites,
      goal,
      level,
      const FilterGroup(
        id: LibraryFilters.days,
        title: 'Séances par semaine',
        icon: Icons.calendar_view_week,
        options: [
          FilterOption('1_3', '1 à 3 jours'),
          FilterOption('4', '4 jours'),
          FilterOption('5_7', '5 jours ou plus'),
        ],
      ),
      const FilterGroup(
        id: LibraryFilters.weeks,
        title: 'Durée du programme',
        icon: Icons.date_range,
        options: [
          FilterOption('le4', '4 semaines ou moins'),
          FilterOption('5_8', '5 à 8 semaines'),
          FilterOption('9p', '9 semaines ou plus'),
        ],
      ),
      equipment,
      origin,
      if (!me.canManageContent) status,
      lang,
    ],
  };
}

/// Une liste de la bibliothèque (programmes, workouts ou exercices).
class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key, required this.kind});
  final ContentKind kind;

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab>
    with AutomaticKeepAliveClientMixin {
  final _query = TextEditingController();
  final _flip = FlipController();
  final _scroll = ScrollController();
  late FilterValues _filters;

  String get _listKey => switch (widget.kind) {
    ContentKind.program => LibraryFilters.programsList,
    ContentKind.workout => LibraryFilters.workoutsList,
    ContentKind.exercise => LibraryFilters.exercisesList,
  };

  @override
  void initState() {
    super.initState();
    _filters = Backend.I.library.savedFilters(_listKey);
    _flip.scroll = _scroll;
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  List<LibraryItem> _items(FilterValues f) {
    final l = Backend.I.library;
    return switch (widget.kind) {
      ContentKind.program => l.programs(query: _query.text, filters: f),
      ContentKind.workout => l.workouts(query: _query.text, filters: f),
      ContentKind.exercise => l.exercises(query: _query.text, filters: f),
    };
  }

  void _setFilters(FilterValues f) {
    setState(() => _filters = f);
    // Mémorisés avec le compte : retrouvés après une déconnexion.
    Backend.I.library.saveFilters(_listKey, f);
  }

  Widget _card(LibraryItem x, String? activeProgram) => switch (x) {
    final Program p => ProgramCard(program: p, active: p.id == activeProgram),
    final Workout w => WorkoutCard(workout: w),
    final Exercise e => ExerciseTile(exercise: e),
    _ => const SizedBox.shrink(),
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final b = Backend.I;
    return ListenableBuilder(
      listenable: Listenable.merge([b.bus, b.auth]),
      builder: (context, _) {
        final me = b.auth.currentUser;
        if (me == null) return const SizedBox.shrink();
        final items = _items(_filters);
        final groups = libraryFilterGroups(widget.kind, me);
        final hint = switch (widget.kind) {
          ContentKind.program => 'Rechercher un programme (FR / EN)',
          ContentKind.workout => 'Workout, exercice, muscle… (FR / EN)',
          ContentKind.exercise => 'Ex. développé couché, bench press, dos…',
        };
        final reordering = _flip.isReordering;
        return Column(
          children: [
            FilterSearchBar(
              key: ValueKey('filters_${widget.kind.name}'),
              groups: groups,
              values: _filters,
              onChanged: _setFilters,
              resultCount: (f) => _items(f).length,
              hint: hint,
              query: _query,
              onQuery: (_) => setState(() {}),
            ),
            Padding(
              padding: pagePadding(context, maxWidth: 1200, top: 6, bottom: 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${items.length} ${widget.kind.lower}${items.length > 1 ? 's' : ''}',
                  style: AppText.label(size: 12),
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? EmptyState(
                      icon: Icons.search_off,
                      title: 'Aucun résultat',
                      message: _filters.activeCount > 0
                          ? 'Aucun ${widget.kind.lower} ne correspond à ces filtres.'
                          : 'Essayez un autre mot, en français ou en anglais.',
                      action: _filters.activeCount > 0 || _query.text.isNotEmpty
                          ? 'Tout effacer'
                          : null,
                      onAction: () {
                        _query.clear();
                        _setFilters({});
                      },
                    )
                  : FlipScope(
                      controller: _flip,
                      child: ResponsiveList(
                        controller: _scroll,
                        minTileWidth: widget.kind == ContentKind.workout
                            ? 380
                            : 440,
                        maxWidth: 1200,
                        top: Gap.s,
                        spacing: widget.kind == ContentKind.exercise
                            ? Gap.s
                            : Gap.m,
                        itemCount: items.length,
                        itemBuilder: (_, i) => FlipItem(
                          key: ValueKey(items[i].id),
                          id: items[i].id,
                          child: FadeSlideIn(
                            index: i,
                            animate: !reordering,
                            child: _card(items[i], me.activeProgramId),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
