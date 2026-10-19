import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/enums.dart';
import '../../models/workout.dart';
import '../../services/backend.dart';
import '../../services/workout_generator_service.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';

/// Ouvre l'assistant intelligent de génération de workout (Métier Avancé 2).
Future<void> showWorkoutGeneratorModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const WorkoutGeneratorSheet(),
  );
}

class WorkoutGeneratorSheet extends StatefulWidget {
  const WorkoutGeneratorSheet({super.key});

  @override
  State<WorkoutGeneratorSheet> createState() => _WorkoutGeneratorSheetState();
}

class _WorkoutGeneratorSheetState extends State<WorkoutGeneratorSheet> {
  String _focusGroup = 'Full Body';
  Goal _goal = Goal.fitness;
  Level _level = Level.intermediate;
  GeneratedWorkout? _preview;
  bool _saving = false;

  final _focusOptions = const [
    'Full Body',
    'Haut du corps',
    'Bas du corps',
    'Cardio & Abdos',
  ];

  @override
  void initState() {
    super.initState();
    final user = Backend.I.auth.currentUser;
    if (user != null) {
      _goal = user.goal;
    }
    _generate();
  }

  void _generate() {
    final user = Backend.I.auth.currentUser!;
    setState(() {
      _preview = WorkoutGeneratorService.generate(
        user: user,
        goal: _goal,
        level: _level,
        focusGroup: _focusGroup,
      );
    });
  }

  Future<void> _saveAndLaunch({bool launchImmediately = false}) async {
    final p = _preview;
    if (p == null) return;
    setState(() => _saving = true);

    try {
      final saved = await Backend.I.workoutService.saveWorkout(
        name: p.name,
        description: p.description,
        level: p.level,
        goal: p.goal,
        items: p.items,
        focus: p.focus,
      );

      if (!mounted) return;
      Navigator.pop(context);

      showSnack(context, 'Workout « ${saved.name} » généré avec succès !');

      if (launchImmediately) {
        Navigator.pushNamed(context, Routes.player, arguments: saved.id);
      } else {
        Navigator.pushNamed(context, Routes.workout, arguments: saved.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, e.toString(), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: Gap.m,
        left: Gap.m,
        right: Gap.m,
        bottom: MediaQuery.of(context).viewInsets.bottom + Gap.l,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: Gap.m),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: AppColors.gold, size: 24),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Générateur Intelligent ACSM', style: AppText.title(size: 18)),
                        Text(
                          'Recommandation algorithmique de workout selon votre profil',
                          style: AppText.label(size: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: Gap.m),

              // Sélecteurs de critères
              Text('Ciblage musculaire', style: AppText.subtitle(size: 14)),
              const SizedBox(height: Gap.xs),
              Wrap(
                spacing: 8,
                children: [
                  for (final f in _focusOptions)
                    ChoiceChip(
                      label: Text(f),
                      selected: _focusGroup == f,
                      onSelected: (val) {
                        if (val) {
                          _focusGroup = f;
                          _generate();
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: Gap.s),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Level>(
                      value: _level,
                      decoration: const InputDecoration(labelText: 'Niveau', isDense: true),
                      items: [
                        for (final l in Level.values)
                          DropdownMenuItem(value: l, child: Text(l.label)),
                      ],
                      onChanged: (l) {
                        if (l != null) {
                          _level = l;
                          _generate();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: Gap.m),
                  Expanded(
                    child: DropdownButtonFormField<Goal>(
                      value: _goal,
                      decoration: const InputDecoration(labelText: 'Objectif', isDense: true),
                      items: [
                        for (final g in Goal.values)
                          DropdownMenuItem(value: g, child: Text(g.label)),
                      ],
                      onChanged: (g) {
                        if (g != null) {
                          _goal = g;
                          _generate();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.m),

              // Aperçu de la recommandation générée
              if (preview != null) ...[
                GfCard(
                  color: AppColors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview.name,
                              style: AppText.subtitle(size: 15),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.cream,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer_outlined, size: 14, color: AppColors.navy),
                                const SizedBox(width: 4),
                                Text('~${preview.estimatedMinutes} min', style: AppText.label(size: 11)),
                                const SizedBox(width: 8),
                                const Icon(Icons.local_fire_department, size: 14, color: AppColors.red),
                                const SizedBox(width: 2),
                                Text('~${preview.estimatedCalories} kcal', style: AppText.label(size: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(preview.description, style: AppText.label(size: 12)),
                      const Divider(height: Gap.m),
                      Text(
                        'Exercices retenus (${preview.items.length}) :',
                        style: AppText.subtitle(size: 13),
                      ),
                      const SizedBox(height: 4),
                      for (var i = 0; i < preview.items.length; i++) ...[
                        _buildItemPreview(i + 1, preview.items[i]),
                        if (i < preview.items.length - 1) const SizedBox(height: 4),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Gap.m),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : () => _saveAndLaunch(launchImmediately: false),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Enregistrer'),
                      ),
                    ),
                    const SizedBox(width: Gap.s),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : () => _saveAndLaunch(launchImmediately: true),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Lancer séance'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemPreview(int index, WorkoutItem item) {
    final ex = Backend.I.exercises.byId(item.exerciseId);
    final name = ex?.nameIn(Backend.I.library.contentLang) ?? 'Exercice';
    final repsText = item.isTimed ? '${item.durationSec} s' : '${item.reps} reps';

    return Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: AppColors.navy.withOpacity(0.08),
          child: Text('$index', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.navy)),
        ),
        const SizedBox(width: Gap.s),
        Expanded(
          child: Text(name, style: AppText.body(size: 13)),
        ),
        Text(
          '${item.sets} × $repsText (Repos ${item.restSec} s)',
          style: AppText.label(size: 11),
        ),
      ],
    );
  }
}
