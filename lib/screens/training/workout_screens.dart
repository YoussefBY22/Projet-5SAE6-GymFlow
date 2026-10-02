import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/enums.dart';
import '../../models/exercise.dart';
import '../../models/workout.dart';
import '../../services/backend.dart';
import '../../widgets/animations.dart';
import '../../widgets/bits.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../../widgets/media.dart';
import '../../widgets/pickers.dart';

const weekdayNames = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

/// En-tête avec image de couverture (Hero) et voile pour l'AppBar.
SliverAppBar coverAppBar({
  required String? image,
  required Object heroTag,
  List<Widget> actions = const [],
}) {
  return SliverAppBar(
    pinned: true,
    expandedHeight: 230,
    actions: actions,
    flexibleSpace: FlexibleSpaceBar(
      background: Stack(
        fit: StackFit.expand,
        children: [
          Hero(tag: heroTag, child: NetImage(image)),
          const TopScrim(),
        ],
      ),
    ),
  );
}

/// Menu Modifier / Supprimer réservé au propriétaire (ou à l'admin).
PopupMenuButton<String> ownerMenu({
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) => PopupMenuButton<String>(
  tooltip: 'Options',
  onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
  itemBuilder: (_) => const [
    PopupMenuItem(value: 'edit', child: Text('Modifier')),
    PopupMenuItem(value: 'delete', child: Text('Supprimer')),
  ],
);

/// Détail d'un workout + bouton « Lancer la séance ».
class WorkoutDetailScreen extends StatelessWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});
  final String workoutId;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return ListenableBuilder(
      listenable: b.bus,
      builder: (context, _) {
        final w = b.workoutService.workoutById(workoutId);
        if (w == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.search_off,
              title: 'Workout introuvable',
              message: 'Il a peut-être été supprimé.',
            ),
          );
        }
        final me = b.auth.currentUser!;
        final items = b.workoutService.resolve(w);
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              coverAppBar(
                image: w.coverImage,
                heroTag: 'w_${w.id}',
                actions: [
                  FavoriteButton(id: w.id, onDark: true),
                  if (b.workoutService.canEditWorkout(me, w))
                    ownerMenu(
                      onEdit: () => Navigator.pushNamed(
                        context,
                        Routes.workoutForm,
                        arguments: w.id,
                      ),
                      onDelete: () async {
                        final ok = await confirm(
                          context,
                          title: 'Supprimer le workout ?',
                          message: '« ${w.name} » sera supprimé.',
                          confirmLabel: 'Supprimer',
                          destructive: true,
                        );
                        if (!ok || !context.mounted) return;
                        final done = await runAction(
                          context,
                          () => b.workoutService.deleteWorkout(w.id),
                          success: 'Workout supprimé.',
                        );
                        if (done && context.mounted) Navigator.pop(context);
                      },
                    ),
                ],
              ),
              SliverPadding(
                padding: pagePadding(context, maxWidth: 900, bottom: Gap.m),
                sliver: SliverList.list(
                  children: [
                    Text(w.name, style: AppText.title(size: 26)),
                    const SizedBox(height: 4),
                    Text(w.focus, style: AppText.label(size: 14)),
                    const SizedBox(height: Gap.s),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Pill(w.level.label, color: levelColor(w.level)),
                        Pill(
                          w.goal.label,
                          color: AppColors.gold,
                          icon: w.goal.icon,
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.m),
                    GfCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: StatTile(
                              value: '${items.length}',
                              label: 'Exercices',
                              icon: Icons.list,
                            ),
                          ),
                          Expanded(
                            child: StatTile(
                              value: '${w.totalSets}',
                              label: 'Séries',
                              icon: Icons.repeat,
                            ),
                          ),
                          Expanded(
                            child: StatTile(
                              value: '~${w.estimatedMinutes}',
                              label: 'Minutes',
                              icon: Icons.timer_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Gap.m),
                    Text(w.description, style: AppText.body()),
                    const SizedBox(height: Gap.l),
                    Text(
                      'Déroulé de la séance',
                      style: AppText.title(size: 18),
                    ),
                    const SizedBox(height: Gap.s),
                    for (var i = 0; i < items.length; i++)
                      FadeSlideIn(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: Gap.s),
                          child: _WorkoutItemTile(
                            index: i,
                            item: items[i].$1,
                            exercise: items[i].$2,
                          ),
                        ),
                      ),
                    const SizedBox(height: 96),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.m),
            child: LoadingButton(
              key: const Key('start_session'),
              label: 'Lancer la séance',
              icon: Icons.play_arrow,
              loading: false,
              onPressed: items.isEmpty
                  ? null
                  : () => Navigator.pushNamed(
                      context,
                      Routes.player,
                      arguments: w.id,
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _WorkoutItemTile extends StatelessWidget {
  const _WorkoutItemTile({
    required this.index,
    required this.item,
    required this.exercise,
  });
  final int index;
  final WorkoutItem item;
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final details = [
      '${item.sets} × ${item.isTimed ? '${item.durationSec} s' : '${item.reps} reps'}',
      'repos ${item.restSec} s',
      if (item.tempo.isNotEmpty) 'tempo ${item.tempo}',
    ].join(' · ');
    return GfCard(
      padding: const EdgeInsets.all(Gap.s),
      onTap: () =>
          Navigator.pushNamed(context, Routes.exercise, arguments: exercise.id),
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 64,
                  height: 64,
                  color: AppColors.white,
                  child: ExerciseImage(exercise, cacheWidth: 200),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: AppText.label(color: AppColors.white, size: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: Gap.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: AppText.subtitle(size: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(details, style: AppText.label(size: 12)),
                if (item.suggestedLoad.isNotEmpty)
                  Text(
                    'Charge : ${item.suggestedLoad}',
                    style: AppText.label(size: 12, color: AppColors.navy),
                  ),
                if (item.notes.isNotEmpty)
                  Text(
                    item.notes,
                    style: AppText.label(size: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.inkSoft),
        ],
      ),
    );
  }
}

/// Création / modification d'un workout (liste ordonnée d'exercices).
class WorkoutFormScreen extends StatefulWidget {
  const WorkoutFormScreen({super.key, this.workoutId});
  final String? workoutId;

  @override
  State<WorkoutFormScreen> createState() => _WorkoutFormScreenState();
}

class _WorkoutFormScreenState extends State<WorkoutFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _focus = TextEditingController();
  final _cover = TextEditingController();
  Level _level = Level.beginner;
  Goal _goal = Goal.fitness;
  final List<WorkoutItem> _items = [];
  bool _saving = false;
  Workout? _existing;

  @override
  void initState() {
    super.initState();
    final w = widget.workoutId == null
        ? null
        : Backend.I.workoutService.workoutById(widget.workoutId!);
    if (w != null) {
      _existing = w;
      _name.text = w.name;
      _description.text = w.description;
      _focus.text = w.focus;
      _cover.text = w.coverImage ?? '';
      _level = w.level;
      _goal = w.goal;
      _items.addAll(w.items);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _focus, _cover]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addExercise() async {
    final picked = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _ExercisePicker(),
    );
    if (picked == null || !mounted) return;
    final item = await _editItem(
      WorkoutItem(exerciseId: picked.id, sets: 3, reps: 10, restSec: 60),
    );
    if (item != null) setState(() => _items.add(item));
  }

  Future<WorkoutItem?> _editItem(WorkoutItem item) {
    return showModalBottomSheet<WorkoutItem>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ItemEditor(item: item),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await runAction(
      context,
      () => Backend.I.workoutService.saveWorkout(
        id: _existing?.id,
        name: _name.text,
        description: _description.text,
        focus: _focus.text,
        level: _level,
        goal: _goal,
        items: _items,
        coverImage: _cover.text.trim().isEmpty ? null : _cover.text.trim(),
      ),
      success: 'Workout enregistré.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _existing == null ? 'Nouveau workout' : 'Modifier le workout',
        ),
      ),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            // Champs non paresseux : tous restent montés pour la validation.
            SliverPadding(
              padding: pagePadding(context, maxWidth: 760, bottom: Gap.m),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (b.auth.currentUser?.isMember ?? false)
                      const Padding(
                        padding: EdgeInsets.only(bottom: Gap.m),
                        child: GfCard(
                          color: AppColors.cream,
                          child: InfoRow(
                            Icons.lock_outline,
                            'Workout personnel : visible par vous seul. '
                            'Vous pourrez partager les séances réalisées, si vous le souhaitez.',
                          ),
                        ),
                      ),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Nom (ex. Push Day)',
                      ),
                      validator: Validators.text(
                        field: 'Le nom',
                        min: 3,
                        max: 60,
                      ),
                    ),
                    const SizedBox(height: Gap.m),
                    TextFormField(
                      controller: _focus,
                      decoration: const InputDecoration(
                        labelText:
                            'Zones travaillées (ex. Pectoraux · Épaules)',
                      ),
                      validator: Validators.text(
                        field: 'Les zones',
                        max: 80,
                        optional: true,
                      ),
                    ),
                    const SizedBox(height: Gap.m),
                    TextFormField(
                      controller: _description,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      validator: Validators.text(
                        field: 'La description',
                        max: 500,
                        optional: true,
                      ),
                    ),
                    const SizedBox(height: Gap.m),
                    Row(
                      children: [
                        Expanded(
                          child: EnumDropdown<Level>(
                            label: 'Niveau',
                            value: _level,
                            values: Level.values,
                            labelOf: (l) => l.label,
                            onChanged: (l) => setState(() => _level = l),
                          ),
                        ),
                        const SizedBox(width: Gap.s),
                        Expanded(
                          child: EnumDropdown<Goal>(
                            label: 'Objectif',
                            value: _goal,
                            values: Goal.values,
                            labelOf: (g) => g.label,
                            onChanged: (g) => setState(() => _goal = g),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.m),
                    TextFormField(
                      controller: _cover,
                      decoration: const InputDecoration(
                        labelText:
                            'Image de couverture (adresse web, facultatif)',
                      ),
                      validator: Validators.url,
                    ),
                    FormSection(
                      'Exercices (${_items.length}) — maintenez pour réordonner',
                    ),
                  ],
                ),
              ),
            ),
            SliverReorderableList(
              itemCount: _items.length,
              onReorderItem: (from, to) =>
                  setState(() => _items.insert(to, _items.removeAt(from))),
              itemBuilder: (context, i) {
                final item = _items[i];
                final e = b.exercises.byId(item.exerciseId);
                return ReorderableDelayedDragStartListener(
                  key: ValueKey('${item.exerciseId}_$i'),
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.s),
                    child: GfCard(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.s),
                      onTap: () async {
                        final edited = await _editItem(item);
                        if (edited != null) setState(() => _items[i] = edited);
                      },
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.navy,
                          child: Text(
                            '${i + 1}',
                            style: AppText.label(color: AppColors.white),
                          ),
                        ),
                        title: Text(
                          e?.name ?? 'Exercice supprimé',
                          style: AppText.subtitle(size: 14),
                        ),
                        subtitle: Text(
                          '${item.sets} × ${item.isTimed ? '${item.durationSec} s' : '${item.reps} reps'} · repos ${item.restSec} s',
                          style: AppText.label(size: 12),
                        ),
                        trailing: IconButton(
                          tooltip: 'Retirer',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.red,
                          ),
                          onPressed: () => setState(() => _items.removeAt(i)),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            SliverPadding(
              padding: pagePadding(context, maxWidth: 760, bottom: Gap.m),
              sliver: SliverList.list(
                children: [
                  OutlinedButton.icon(
                    onPressed: _addExercise,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un exercice'),
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
          ],
        ),
      ),
    );
  }
}

/// Sélecteur d'exercice (feuille modale avec recherche).
class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker();

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = Backend.I.exerciseService.list().where((e) {
      final q = _q.toLowerCase();
      return q.isEmpty ||
          e.name.toLowerCase().contains(q) ||
          e.primaryMuscle.label.toLowerCase().contains(q);
    }).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.s),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                hintText: 'Rechercher un exercice',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) => ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: ExerciseImage(list[i], cacheWidth: 150),
                  ),
                ),
                title: Text(list[i].name),
                subtitle: Text(list[i].primaryMuscle.label),
                onTap: () => Navigator.pop(context, list[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Réglage d'une ligne : séries, reps ou durée, repos, tempo, charge, notes.
class _ItemEditor extends StatefulWidget {
  const _ItemEditor({required this.item});
  final WorkoutItem item;

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  final _formKey = GlobalKey<FormState>();
  late bool _timed = widget.item.isTimed;
  late final _sets = TextEditingController(text: '${widget.item.sets}');
  late final _reps = TextEditingController(text: '${widget.item.reps ?? 10}');
  late final _duration = TextEditingController(
    text: '${widget.item.durationSec ?? 30}',
  );
  late final _rest = TextEditingController(text: '${widget.item.restSec}');
  late final _tempo = TextEditingController(text: widget.item.tempo);
  late final _load = TextEditingController(text: widget.item.suggestedLoad);
  late final _notes = TextEditingController(text: widget.item.notes);

  @override
  void dispose() {
    for (final c in [_sets, _reps, _duration, _rest, _tempo, _load, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      WorkoutItem(
        exerciseId: widget.item.exerciseId,
        sets: int.parse(_sets.text.trim()),
        reps: _timed ? null : int.parse(_reps.text.trim()),
        durationSec: _timed ? int.parse(_duration.text.trim()) : null,
        restSec: int.parse(_rest.text.trim()),
        tempo: _tempo.text.trim(),
        suggestedLoad: _load.text.trim(),
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = Backend.I.exercises.byId(widget.item.exerciseId);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.l),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(e?.name ?? 'Exercice', style: AppText.title(size: 18)),
              const SizedBox(height: Gap.m),
              Wrap(
                spacing: Gap.s,
                children: [
                  GfFilterChip(
                    label: 'Répétitions',
                    selected: !_timed,
                    onTap: () => setState(() => _timed = false),
                  ),
                  GfFilterChip(
                    label: 'Durée',
                    selected: _timed,
                    onTap: () => setState(() => _timed = true),
                  ),
                ],
              ),
              const SizedBox(height: Gap.m),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sets,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Séries'),
                      validator: Validators.intRange(
                        field: 'Séries',
                        min: 1,
                        max: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: _timed
                        ? TextFormField(
                            controller: _duration,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Durée (s)',
                            ),
                            validator: Validators.intRange(
                              field: 'Durée',
                              min: 5,
                              max: 3600,
                            ),
                          )
                        : TextFormField(
                            controller: _reps,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Répétitions',
                            ),
                            validator: Validators.intRange(
                              field: 'Reps',
                              min: 1,
                              max: 100,
                            ),
                          ),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: TextFormField(
                      controller: _rest,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Repos (s)'),
                      validator: Validators.intRange(
                        field: 'Repos',
                        min: 0,
                        max: 600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.m),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tempo,
                      decoration: const InputDecoration(
                        labelText: 'Tempo (ex. 3-1-1)',
                      ),
                      validator: Validators.text(
                        field: 'Tempo',
                        max: 12,
                        optional: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: TextFormField(
                      controller: _load,
                      decoration: const InputDecoration(
                        labelText: 'Charge suggérée',
                      ),
                      validator: Validators.text(
                        field: 'Charge',
                        max: 40,
                        optional: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes'),
                validator: Validators.text(
                  field: 'Notes',
                  max: 200,
                  optional: true,
                ),
              ),
              const SizedBox(height: Gap.l),
              ElevatedButton(onPressed: _submit, child: const Text('Valider')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Détail d'un programme : planning de la semaine, suivre le programme.
class ProgramDetailScreen extends StatelessWidget {
  const ProgramDetailScreen({super.key, required this.programId});
  final String programId;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return ListenableBuilder(
      listenable: Listenable.merge([b.bus, b.auth]),
      builder: (context, _) {
        final p = b.workoutService.programById(programId);
        if (p == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.search_off,
              title: 'Programme introuvable',
              message: 'Il a peut-être été supprimé.',
            ),
          );
        }
        final me = b.auth.currentUser!;
        final following = me.activeProgramId == p.id;
        final today = b.now().weekday;
        final author = b.users.byId(p.authorId);
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              coverAppBar(
                image: p.coverImage,
                heroTag: 'p_${p.id}',
                actions: [
                  FavoriteButton(id: p.id, onDark: true),
                  if (b.workoutService.canEditProgram(me, p))
                    ownerMenu(
                      onEdit: () => Navigator.pushNamed(
                        context,
                        Routes.programForm,
                        arguments: p.id,
                      ),
                      onDelete: () async {
                        final ok = await confirm(
                          context,
                          title: 'Supprimer le programme ?',
                          message: '« ${p.name} » sera supprimé.',
                          confirmLabel: 'Supprimer',
                          destructive: true,
                        );
                        if (!ok || !context.mounted) return;
                        final done = await runAction(
                          context,
                          () => b.workoutService.deleteProgram(p.id),
                          success: 'Programme supprimé.',
                        );
                        if (done && context.mounted) Navigator.pop(context);
                      },
                    ),
                ],
              ),
              SliverPadding(
                padding: pagePadding(context, maxWidth: 900, bottom: Gap.m),
                sliver: SliverList.list(
                  children: [
                    Text(p.name, style: AppText.title(size: 24)),
                    const SizedBox(height: Gap.s),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Pill(p.level.label, color: levelColor(p.level)),
                        Pill(
                          p.goal.label,
                          color: AppColors.gold,
                          icon: p.goal.icon,
                        ),
                        Pill('${p.daysPerWeek} j/sem.'),
                        Pill('${p.weeks} semaines'),
                      ],
                    ),
                    const SizedBox(height: Gap.m),
                    Text(p.description, style: AppText.body()),
                    const SizedBox(height: Gap.s),
                    InfoRow(Icons.fitness_center, 'Matériel : ${p.equipment}'),
                    if (author != null)
                      InfoRow(Icons.sports, 'Conçu par ${author.fullName}'),
                    const SizedBox(height: Gap.l),
                    Text('Ma semaine type', style: AppText.title(size: 18)),
                    const SizedBox(height: Gap.s),
                    for (var d = 1; d <= 7; d++)
                      Builder(
                        builder: (context) {
                          final day = p.days
                              .where((x) => x.weekday == d)
                              .firstOrNull;
                          final w = day == null
                              ? null
                              : b.workouts.byId(day.workoutId);
                          final isToday = d == today;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: Gap.s),
                            child: GfCard(
                              color: isToday
                                  ? AppColors.cream
                                  : AppColors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: Gap.m,
                                vertical: Gap.s,
                              ),
                              onTap: w == null
                                  ? null
                                  : () => Navigator.pushNamed(
                                      context,
                                      Routes.workout,
                                      arguments: w.id,
                                    ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 86,
                                    child: Text(
                                      weekdayNames[d - 1],
                                      style: AppText.subtitle(
                                        size: 14,
                                        color: isToday
                                            ? AppColors.red
                                            : AppColors.navy,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      w?.name ?? 'Repos / récupération',
                                      style: AppText.body(
                                        size: 14,
                                        color: w == null
                                            ? AppColors.inkSoft
                                            : AppColors.ink,
                                      ),
                                    ),
                                  ),
                                  if (w != null)
                                    const Icon(
                                      Icons.chevron_right,
                                      color: AppColors.inkSoft,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: Gap.m),
                    if (me.isMember)
                      following
                          ? OutlinedButton.icon(
                              onPressed: () => runAction(
                                context,
                                () => b.userService.setActiveProgram(null),
                                success: 'Programme arrêté.',
                              ),
                              icon: const Icon(Icons.flag_outlined),
                              label: const Text('Arrêter ce programme'),
                            )
                          : ElevatedButton.icon(
                              onPressed: () => runAction(
                                context,
                                () => b.userService.setActiveProgram(p.id),
                                success:
                                    'Programme suivi : retrouvez-le sur l\'accueil.',
                              ),
                              icon: const Icon(Icons.flag),
                              label: const Text('Suivre ce programme'),
                            ),
                    const SizedBox(height: Gap.xl),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Création / modification d'un programme (un workout par jour).
class ProgramFormScreen extends StatefulWidget {
  const ProgramFormScreen({super.key, this.programId});
  final String? programId;

  @override
  State<ProgramFormScreen> createState() => _ProgramFormScreenState();
}

class _ProgramFormScreenState extends State<ProgramFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _weeks = TextEditingController(text: '6');
  final _equipment = TextEditingController();
  final _cover = TextEditingController();
  Level _level = Level.beginner;
  Goal _goal = Goal.fitness;
  final Map<int, String?> _days = {for (var d = 1; d <= 7; d++) d: null};
  bool _saving = false;
  Program? _existing;

  @override
  void initState() {
    super.initState();
    final p = widget.programId == null
        ? null
        : Backend.I.workoutService.programById(widget.programId!);
    if (p != null) {
      _existing = p;
      _name.text = p.name;
      _description.text = p.description;
      _weeks.text = '${p.weeks}';
      _equipment.text = p.equipment;
      _cover.text = p.coverImage ?? '';
      _level = p.level;
      _goal = p.goal;
      for (final d in p.days) {
        _days[d.weekday] = d.workoutId;
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _weeks, _equipment, _cover]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await runAction(
      context,
      () => Backend.I.workoutService.saveProgram(
        id: _existing?.id,
        name: _name.text,
        description: _description.text,
        level: _level,
        goal: _goal,
        weeks: int.parse(_weeks.text.trim()),
        equipment: _equipment.text,
        coverImage: _cover.text.trim().isEmpty ? null : _cover.text.trim(),
        days: [
          for (final e in _days.entries)
            if (e.value != null)
              ProgramDay(weekday: e.key, workoutId: e.value!),
        ],
      ),
      success: 'Programme enregistré.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final workouts = Backend.I.workoutService.workouts();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _existing == null ? 'Nouveau programme' : 'Modifier le programme',
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: pagePadding(context, maxWidth: 760, bottom: Gap.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nom du programme',
                ),
                validator: Validators.text(field: 'Le nom', min: 3, max: 60),
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: Validators.text(
                  field: 'La description',
                  max: 500,
                  optional: true,
                ),
              ),
              const SizedBox(height: Gap.m),
              Row(
                children: [
                  Expanded(
                    child: EnumDropdown<Level>(
                      label: 'Niveau',
                      value: _level,
                      values: Level.values,
                      labelOf: (l) => l.label,
                      onChanged: (l) => setState(() => _level = l),
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: EnumDropdown<Goal>(
                      label: 'Objectif',
                      value: _goal,
                      values: Goal.values,
                      labelOf: (g) => g.label,
                      onChanged: (g) => setState(() => _goal = g),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.m),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weeks,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Durée (semaines)',
                      ),
                      validator: Validators.intRange(
                        field: 'La durée',
                        min: 1,
                        max: 52,
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: TextFormField(
                      controller: _equipment,
                      decoration: const InputDecoration(labelText: 'Matériel'),
                      validator: Validators.text(field: 'Le matériel', max: 60),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _cover,
                decoration: const InputDecoration(
                  labelText: 'Image de couverture (adresse web, facultatif)',
                ),
                validator: Validators.url,
              ),
              const FormSection('Planning de la semaine'),
              for (var d = 1; d <= 7; d++)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.s),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _days[d],
                    isExpanded: true,
                    decoration: InputDecoration(labelText: weekdayNames[d - 1]),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Repos'),
                      ),
                      for (final w in workouts)
                        DropdownMenuItem<String?>(
                          value: w.id,
                          child: Text(w.name),
                        ),
                    ],
                    onChanged: (v) => setState(() => _days[d] = v),
                  ),
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
