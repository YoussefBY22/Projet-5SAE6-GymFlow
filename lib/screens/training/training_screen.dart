import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/enums.dart';
import '../../services/backend.dart';
import '../../services/exercise_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/bits.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../shell/main_shell.dart';

/// Onglet Entraînement (TabBar : Programmes / Workouts / Exercices).
/// Pour le super admin, le même écran sert d'onglet « Contenu ».
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

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _add() {
    final route = switch (_tabs.index) {
      0 => Routes.programForm,
      1 => Routes.workoutForm,
      _ => Routes.exerciseForm,
    };
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final user = Backend.I.auth.currentUser!;
    return Scaffold(
      appBar: AppBar(
        leading: const ShellMenuButton(),
        title: Text(widget.contentMode ? 'Contenu' : 'Entraînement'),
        actions: [
          if (user.canManageContent)
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
      floatingActionButton: !user.canManageContent && _tabs.index == 1
          // Abonné : crée ses propres workouts (privés).
          ? FloatingActionButton.extended(
              key: const Key('my_workout_fab'),
              heroTag: 'training_fab',
              onPressed: () => Navigator.pushNamed(context, Routes.workoutForm),
              icon: const Icon(Icons.add),
              label: const Text('Mon workout'),
            )
          : user.canManageContent
          ? FloatingActionButton.extended(
              heroTag: 'training_fab',
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: Text(switch (_tabs.index) {
                0 => 'Programme',
                1 => 'Workout',
                _ => 'Exercice',
              }),
            )
          : null,
      body: TabBarView(
        controller: _tabs,
        children: const [ProgramsTab(), WorkoutsTab(), ExercisesTab()],
      ),
    );
  }
}

class ProgramsTab extends StatelessWidget {
  const ProgramsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return ListenableBuilder(
      listenable: Listenable.merge([b.bus, b.auth]),
      builder: (context, _) {
        final programs = b.workoutService.programs();
        final activeId = b.auth.currentUser?.activeProgramId;
        programs.sort(
          (a, c) => (c.id == activeId ? 1 : 0) - (a.id == activeId ? 1 : 0),
        );
        if (programs.isEmpty) {
          return const EmptyState(
            icon: Icons.calendar_view_week,
            title: 'Aucun programme',
            message: 'Les programmes créés par les coachs apparaîtront ici.',
          );
        }
        return ResponsiveList(
          minTileWidth: 440,
          maxWidth: 1200,
          itemCount: programs.length,
          itemBuilder: (_, i) => FadeSlideIn(
            index: i,
            child: ProgramCard(
              program: programs[i],
              active: programs[i].id == activeId,
            ),
          ),
        );
      },
    );
  }
}

class WorkoutsTab extends StatefulWidget {
  const WorkoutsTab({super.key});

  @override
  State<WorkoutsTab> createState() => _WorkoutsTabState();
}

class _WorkoutsTabState extends State<WorkoutsTab> {
  Level? _level;
  Goal? _goal;
  bool _mine = false;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return ListenableBuilder(
      listenable: b.bus,
      builder: (context, _) {
        final me = b.auth.currentUser;
        final workouts = b.workoutService.workouts(
          level: _level,
          goal: _goal,
          personalOnly: _mine,
        );
        return Column(
          children: [
            const SizedBox(height: Gap.s),
            ChipBar(
              children: [
                if (me != null && me.isMember)
                  GfFilterChip(
                    label: 'Mes workouts',
                    icon: Icons.lock_outline,
                    selected: _mine,
                    onTap: () => setState(() => _mine = !_mine),
                  ),
                for (final l in Level.values)
                  GfFilterChip(
                    label: l.label,
                    selected: _level == l,
                    onTap: () =>
                        setState(() => _level = _level == l ? null : l),
                  ),
                for (final g in Goal.values)
                  GfFilterChip(
                    label: g.label,
                    icon: g.icon,
                    selected: _goal == g,
                    onTap: () => setState(() => _goal = _goal == g ? null : g),
                  ),
              ],
            ),
            Expanded(
              child: workouts.isEmpty
                  ? EmptyState(
                      icon: _mine ? Icons.edit_note : Icons.search_off,
                      title: _mine ? 'Aucun workout perso' : 'Aucun workout',
                      message: _mine
                          ? 'Composez votre propre séance avec « Mon workout » : '
                                'elle reste visible par vous seul.'
                          : 'Aucun workout ne correspond à ces filtres.',
                    )
                  : ResponsiveList(
                      minTileWidth: 380,
                      maxWidth: 1200,
                      top: Gap.s,
                      itemCount: workouts.length,
                      itemBuilder: (_, i) => FadeSlideIn(
                        index: i,
                        child: WorkoutCard(workout: workouts[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Bibliothèque d'exercices : recherche instantanée + filtres animés.
class ExercisesTab extends StatefulWidget {
  const ExercisesTab({super.key});

  @override
  State<ExercisesTab> createState() => _ExercisesTabState();
}

class _ExercisesTabState extends State<ExercisesTab> {
  final _search = TextEditingController();
  String _query = '';
  Muscle? _muscle;
  Level? _level;
  Equipment? _equipment;
  bool _favorites = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickEquipment() async {
    final picked = await showModalBottomSheet<Equipment?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(Gap.m),
              child: Text('Équipement', style: AppText.title(size: 18)),
            ),
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('Tous'),
              onTap: () => Navigator.pop(ctx),
            ),
            for (final e in Equipment.values)
              ListTile(
                leading: Icon(
                  _equipment == e
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(e.label),
                onTap: () => Navigator.pop(ctx, e),
              ),
          ],
        ),
      ),
    );
    setState(() => _equipment = picked);
  }

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return ListenableBuilder(
      listenable: Listenable.merge([b.bus, b.auth]),
      builder: (context, _) {
        final list = b.exerciseService.list(
          ExerciseFilter(
            query: _query,
            muscle: _muscle,
            level: _level,
            equipment: _equipment,
            favoritesOnly: _favorites,
          ),
        );
        return Column(
          children: [
            Padding(
              padding: pagePadding(context, maxWidth: 1200, bottom: 0),
              child: TextField(
                controller: _search,
                // Recherche instantanée (cours S02.2 : onChanged / onSubmitted).
                onChanged: (v) => setState(() => _query = v),
                onSubmitted: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Rechercher un exercice, un muscle…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _search.clear();
                            _query = '';
                          }),
                        ),
                ),
              ),
            ),
            const SizedBox(height: Gap.s),
            ChipBar(
              children: [
                GfFilterChip(
                  label: 'Favoris',
                  icon: Icons.favorite_border,
                  selected: _favorites,
                  onTap: () => setState(() => _favorites = !_favorites),
                ),
                GfFilterChip(
                  label: _equipment?.label ?? 'Équipement',
                  icon: Icons.tune,
                  selected: _equipment != null,
                  onTap: _pickEquipment,
                ),
                for (final l in Level.values)
                  GfFilterChip(
                    label: l.label,
                    selected: _level == l,
                    onTap: () =>
                        setState(() => _level = _level == l ? null : l),
                  ),
              ],
            ),
            ChipBar(
              children: [
                for (final m in Muscle.values)
                  GfFilterChip(
                    label: m.label,
                    selected: _muscle == m,
                    onTap: () =>
                        setState(() => _muscle = _muscle == m ? null : m),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.m,
                vertical: Gap.xs,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    '${list.length} exercice${list.length > 1 ? 's' : ''}',
                    key: ValueKey(list.length),
                    style: AppText.label(),
                  ),
                ),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? EmptyState(
                      icon: Icons.search_off,
                      title: 'Aucun résultat',
                      message:
                          'Essayez un autre mot-clé ou retirez des filtres.',
                      action: 'Réinitialiser',
                      onAction: () => setState(() {
                        _search.clear();
                        _query = '';
                        _muscle = null;
                        _level = null;
                        _equipment = null;
                        _favorites = false;
                      }),
                    )
                  : ResponsiveList(
                      minTileWidth: 440,
                      maxWidth: 1200,
                      top: Gap.xs,
                      spacing: Gap.s,
                      itemCount: list.length,
                      itemBuilder: (_, i) => FadeSlideIn(
                        index: i,
                        child: ExerciseTile(exercise: list[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
