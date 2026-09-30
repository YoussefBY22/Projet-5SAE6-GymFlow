import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/enums.dart';
import '../../models/exercise.dart';
import '../../services/backend.dart';
import '../../services/wger_api.dart';
import '../../widgets/animations.dart';
import '../../widgets/bits.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../../widgets/media.dart';
import '../../widgets/pickers.dart';

/// Détail d'un exercice : médias, étapes, erreurs fréquentes, respiration.
class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});
  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return ListenableBuilder(
      listenable: b.bus,
      builder: (context, _) {
        final e = b.exerciseService.byId(exerciseId);
        if (e == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.search_off,
              title: 'Exercice introuvable',
              message: 'Il a peut-être été supprimé.',
            ),
          );
        }
        final me = b.auth.currentUser!;
        final canEdit = b.exerciseService.canEdit(me, e);
        final videos = e.media.where((m) => m.kind != MediaKind.image).toList();
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 260,
                actions: [
                  FavoriteButton(id: e.id, onDark: true),
                  if (canEdit)
                    PopupMenuButton<String>(
                      tooltip: 'Options',
                      onSelected: (v) async {
                        if (v == 'edit') {
                          Navigator.pushNamed(
                            context,
                            Routes.exerciseForm,
                            arguments: e.id,
                          );
                        } else if (v == 'delete') {
                          final ok = await confirm(
                            context,
                            title: 'Supprimer l\'exercice ?',
                            message:
                                '« ${e.name} » sera définitivement supprimé.',
                            confirmLabel: 'Supprimer',
                            destructive: true,
                          );
                          if (!ok || !context.mounted) return;
                          final done = await runAction(
                            context,
                            () => b.exerciseService.delete(e.id),
                            success: 'Exercice supprimé.',
                          );
                          if (done && context.mounted) Navigator.pop(context);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Supprimer'),
                        ),
                      ],
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'ex_${e.id}',
                        child: Container(
                          color: AppColors.white,
                          child: NetImage(
                            exerciseThumb(e),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      // Voile sombre en haut : icônes blanches de l'AppBar lisibles.
                      const TopScrim(),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(Gap.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.name, style: AppText.title(size: 24)),
                      const SizedBox(height: Gap.s),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Pill(e.level.label, color: levelColor(e.level)),
                          Pill(e.type.label),
                          Pill(e.equipment.label, icon: Icons.fitness_center),
                          Pill(
                            e.primaryMuscle.label,
                            color: AppColors.gold,
                            icon: Icons.accessibility_new,
                          ),
                          for (final m in e.secondaryMuscles) Pill(m.label),
                        ],
                      ),
                      const SizedBox(height: Gap.m),
                      Text(e.description, style: AppText.body()),
                      if (videos.isNotEmpty) ...[
                        const SizedBox(height: Gap.l),
                        Text('Vidéos', style: AppText.title(size: 18)),
                        for (final v in videos) ...[
                          const SizedBox(height: Gap.s),
                          MediaView(v),
                          if (v.caption != null)
                            Text(v.caption!, style: AppText.label(size: 12)),
                        ],
                      ],
                      if (e.images.length > 1) ...[
                        const SizedBox(height: Gap.l),
                        Text('Images', style: AppText.title(size: 18)),
                        const SizedBox(height: Gap.s),
                        SizedBox(
                          height: 140,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: e.images.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: Gap.s),
                            itemBuilder: (_, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                color: AppColors.white,
                                width: 180,
                                child: NetImage(
                                  e.images[i].source,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (e.steps.isNotEmpty) ...[
                        const SizedBox(height: Gap.l),
                        Text('Exécution', style: AppText.title(size: 18)),
                        const SizedBox(height: Gap.s),
                        for (var i = 0; i < e.steps.length; i++)
                          FadeSlideIn(
                            index: i,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: Gap.s),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundColor: AppColors.navy,
                                    child: Text(
                                      '${i + 1}',
                                      style: AppText.label(
                                        color: AppColors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: Gap.s),
                                  Expanded(
                                    child: Text(
                                      e.steps[i],
                                      style: AppText.body(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                      if (e.mistakes.isNotEmpty) ...[
                        const SizedBox(height: Gap.m),
                        GfCard(
                          color: AppColors.redSoft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: AppColors.red,
                                  ),
                                  const SizedBox(width: Gap.s),
                                  Text(
                                    'Erreurs fréquentes',
                                    style: AppText.subtitle(
                                      color: AppColors.red,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: Gap.s),
                              for (final m in e.mistakes)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '• $m',
                                    style: AppText.body(size: 14),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      if (e.breathing.isNotEmpty) ...[
                        const SizedBox(height: Gap.m),
                        GfCard(
                          color: AppColors.cream,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.air, color: AppColors.navy),
                              const SizedBox(width: Gap.s),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Respiration',
                                      style: AppText.subtitle(),
                                    ),
                                    Text(
                                      e.breathing,
                                      style: AppText.body(size: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: Gap.l),
                      Text(
                        'Ajouté par ${b.users.byId(e.authorId)?.fullName ?? 'GymFlow'}${e.wgerId != null ? ' · données wger.de' : ''}',
                        style: AppText.label(size: 12),
                      ),
                      const SizedBox(height: Gap.xl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Création / modification d'un exercice (admin et coachs).
class ExerciseFormScreen extends StatefulWidget {
  const ExerciseFormScreen({super.key, this.exerciseId});
  final String? exerciseId;

  @override
  State<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends State<ExerciseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _steps = TextEditingController();
  final _mistakes = TextEditingController();
  final _breathing = TextEditingController();
  Muscle _muscle = Muscle.chest;
  final Set<Muscle> _secondary = {};
  Equipment _equipment = Equipment.dumbbell;
  Level _level = Level.beginner;
  ExerciseType _type = ExerciseType.strength;
  final List<MediaItem> _media = [];
  bool _saving = false;
  Exercise? _existing;

  @override
  void initState() {
    super.initState();
    final e = widget.exerciseId == null
        ? null
        : Backend.I.exerciseService.byId(widget.exerciseId!);
    if (e != null) {
      _existing = e;
      _name.text = e.name;
      _description.text = e.description;
      _steps.text = e.steps.join('\n');
      _mistakes.text = e.mistakes.join('\n');
      _breathing.text = e.breathing;
      _muscle = e.primaryMuscle;
      _secondary.addAll(e.secondaryMuscles);
      _equipment = e.equipment;
      _level = e.level;
      _type = e.type;
      _media.addAll(e.media);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _steps, _mistakes, _breathing]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _lines(TextEditingController c) => c.text
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  Future<void> _addMedia() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_photo_alternate_outlined),
              title: const Text('Photo (galerie ou appareil)'),
              onTap: () => Navigator.pop(ctx, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Image depuis une adresse web'),
              onTap: () => Navigator.pop(ctx, 'url'),
            ),
            ListTile(
              leading: const Icon(Icons.video_file_outlined),
              title: const Text('Vidéo depuis le téléphone'),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
            ListTile(
              leading: const Icon(Icons.smart_display_outlined),
              title: const Text('Lien YouTube'),
              onTap: () => Navigator.pop(ctx, 'youtube'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    MediaItem? item;
    switch (choice) {
      case 'photo':
        final path = await pickImageFile(context);
        if (path != null) item = MediaItem(kind: MediaKind.image, source: path);
      case 'url':
        final url = await askText(
          context,
          title: 'Image web',
          label: 'Adresse de l\'image',
          hint: 'https://…',
          validator: (v) => Validators.url(v, optional: false),
        );
        if (url != null) item = MediaItem(kind: MediaKind.image, source: url);
      case 'video':
        final path = await pickVideoFile(context);
        if (path != null) {
          item = MediaItem(
            kind: MediaKind.video,
            source: path,
            caption: 'Vidéo importée',
          );
        }
      case 'youtube':
        final link = await askText(
          context,
          title: 'Vidéo YouTube',
          label: 'Lien ou identifiant YouTube',
          hint: 'https://youtu.be/…',
          validator: (v) =>
              youtubeId(v ?? '') == null ? 'Lien YouTube invalide.' : null,
        );
        if (link != null) {
          item = MediaItem(
            kind: MediaKind.youtube,
            source: youtubeId(link)!,
            caption: 'Vidéo YouTube',
          );
        }
    }
    if (item != null) setState(() => _media.add(item!));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final s = Backend.I.exerciseService;
    final ok = await runAction(context, () async {
      final existing = _existing;
      if (existing == null) {
        await s.create(
          name: _name.text,
          primaryMuscle: _muscle,
          secondaryMuscles: _secondary.toList(),
          equipment: _equipment,
          level: _level,
          type: _type,
          description: _description.text,
          steps: _lines(_steps),
          mistakes: _lines(_mistakes),
          breathing: _breathing.text,
          media: _media,
        );
      } else {
        await s.update(
          existing.copyWith(
            name: _name.text.trim(),
            primaryMuscle: _muscle,
            secondaryMuscles: _secondary.toList(),
            equipment: _equipment,
            level: _level,
            type: _type,
            description: _description.text.trim(),
            steps: _lines(_steps),
            mistakes: _lines(_mistakes),
            breathing: _breathing.text.trim(),
            media: _media,
          ),
        );
      }
    }, success: _existing == null ? 'Exercice créé.' : 'Exercice mis à jour.');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _existing == null ? 'Nouvel exercice' : 'Modifier l\'exercice',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(Gap.m),
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nom de l\'exercice',
                ),
                validator: Validators.text(field: 'Le nom', min: 3, max: 80),
              ),
              const SizedBox(height: Gap.m),
              EnumDropdown<Muscle>(
                label: 'Muscle principal',
                value: _muscle,
                values: Muscle.values,
                labelOf: (m) => m.label,
                onChanged: (m) => setState(() => _muscle = m),
              ),
              const FormSection('Muscles secondaires'),
              Wrap(
                spacing: Gap.s,
                runSpacing: Gap.s,
                children: [
                  for (final m in Muscle.values.where((m) => m != _muscle))
                    GfFilterChip(
                      label: m.label,
                      selected: _secondary.contains(m),
                      onTap: () => setState(
                        () => _secondary.contains(m)
                            ? _secondary.remove(m)
                            : _secondary.add(m),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Gap.m),
              Row(
                children: [
                  Expanded(
                    child: EnumDropdown<Equipment>(
                      label: 'Équipement',
                      value: _equipment,
                      values: Equipment.values,
                      labelOf: (e) => e.label,
                      onChanged: (e) => setState(() => _equipment = e),
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: EnumDropdown<Level>(
                      label: 'Niveau',
                      value: _level,
                      values: Level.values,
                      labelOf: (l) => l.label,
                      onChanged: (l) => setState(() => _level = l),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.m),
              EnumDropdown<ExerciseType>(
                label: 'Type',
                value: _type,
                values: ExerciseType.values,
                labelOf: (t) => t.label,
                onChanged: (t) => setState(() => _type = t),
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: Validators.text(
                  field: 'La description',
                  min: 10,
                  max: 600,
                ),
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _steps,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Étapes d\'exécution',
                  helperText: 'Une étape par ligne',
                  alignLabelWithHint: true,
                ),
                validator: (v) => _lines(_steps).isEmpty
                    ? 'Indiquez au moins une étape.'
                    : null,
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _mistakes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Erreurs fréquentes',
                  helperText: 'Une erreur par ligne',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: Gap.m),
              TextFormField(
                controller: _breathing,
                decoration: const InputDecoration(
                  labelText: 'Conseil de respiration',
                ),
                validator: Validators.text(
                  field: 'Le conseil',
                  max: 200,
                  optional: true,
                ),
              ),
              const FormSection('Médias'),
              for (var i = 0; i < _media.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.s),
                  child: GfCard(
                    padding: const EdgeInsets.all(Gap.s),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 64,
                            height: 48,
                            child: switch (_media[i].kind) {
                              MediaKind.image => NetImage(_media[i].source),
                              MediaKind.youtube => NetImage(
                                youtubeThumb(_media[i].source),
                              ),
                              MediaKind.video => Container(
                                color: AppColors.navy,
                                child: const Icon(
                                  Icons.movie,
                                  color: AppColors.white,
                                ),
                              ),
                            },
                          ),
                        ),
                        const SizedBox(width: Gap.s),
                        Expanded(
                          child: Text(
                            '${_media[i].kind.label} · ${_media[i].isLocalFile ? 'fichier du téléphone' : _media[i].source}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.label(),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Retirer',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.red,
                          ),
                          onPressed: () => setState(() => _media.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _addMedia,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une image ou une vidéo'),
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

/// Import d'exercices depuis l'API publique wger.de (cache hors-ligne).
class WgerImportScreen extends StatefulWidget {
  const WgerImportScreen({super.key});

  @override
  State<WgerImportScreen> createState() => _WgerImportScreenState();
}

class _WgerImportScreenState extends State<WgerImportScreen> {
  int _category = wgerCategories.keys.first;
  late Future<(List<WgerExercise>, bool)> _future = _load();
  final Set<int> _importing = {};

  Future<(List<WgerExercise>, bool)> _load() =>
      Backend.I.wger.browse(categoryId: _category);

  void _reload() => setState(() => _future = _load());

  Future<void> _import(WgerExercise w) async {
    setState(() => _importing.add(w.id));
    await runAction(
      context,
      () => Backend.I.wger.import(w),
      success: '« ${w.name} » ajouté à la bibliothèque.',
    );
    if (mounted) setState(() => _importing.remove(w.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importer depuis wger')),
      body: Column(
        children: [
          const SizedBox(height: Gap.s),
          ChipBar(
            children: [
              for (final e in wgerCategories.entries)
                GfFilterChip(
                  label: e.value,
                  selected: _category == e.key,
                  onTap: () {
                    _category = e.key;
                    _reload();
                  },
                ),
            ],
          ),
          Expanded(
            child: FutureBuilder<(List<WgerExercise>, bool)>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SkeletonList(count: 6, itemHeight: 76);
                }
                if (snap.hasError) {
                  return ErrorState(
                    error: snap.error ?? const NetworkException(),
                    onRetry: _reload,
                  );
                }
                final (list, fromCache) = snap.data!;
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.cloud_off,
                    title: 'Aucun exercice',
                    message: 'Cette catégorie ne contient pas d\'exercice.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(Gap.m),
                  itemCount: list.length + (fromCache ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: Gap.s),
                  itemBuilder: (_, i) {
                    if (fromCache && i == 0) {
                      return const GfCard(
                        color: AppColors.cream,
                        child: InfoRow(
                          Icons.wifi_off,
                          'Hors-ligne : affichage des données en cache.',
                        ),
                      );
                    }
                    final w = list[i - (fromCache ? 1 : 0)];
                    final done = Backend.I.wger.alreadyImported(w.id);
                    return GfCard(
                      padding: const EdgeInsets.all(Gap.s),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 64,
                              height: 64,
                              color: AppColors.white,
                              child: NetImage(
                                w.images.isEmpty ? null : w.images.first,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(width: Gap.s),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.subtitle(size: 14),
                                ),
                                Text(
                                  '${w.mappedMuscle.label} · ${w.mappedEquipment.label} · ${w.license}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.label(size: 12),
                                ),
                              ],
                            ),
                          ),
                          if (done)
                            const Pill(
                              'Importé',
                              color: AppColors.success,
                              icon: Icons.check,
                            )
                          else if (_importing.contains(w.id))
                            const Padding(
                              padding: EdgeInsets.all(Gap.s),
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else
                            IconButton.filledTonal(
                              tooltip: 'Importer',
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.navy,
                                foregroundColor: AppColors.white,
                              ),
                              onPressed: () => _import(w),
                              icon: const Icon(Icons.download),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
