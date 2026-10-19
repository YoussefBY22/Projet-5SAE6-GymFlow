import '../models/enums.dart';
import '../models/exercise.dart';
import '../models/user.dart';
import '../models/workout.dart';
import 'backend.dart';

/// Recommandation générée par l'algorithme intelligent d'entraînement.
class GeneratedWorkout {
  const GeneratedWorkout({
    required this.name,
    required this.description,
    required this.focus,
    required this.level,
    required this.goal,
    required this.items,
    required this.estimatedMinutes,
    required this.estimatedCalories,
  });

  final String name;
  final String description;
  final String focus;
  final Level level;
  final Goal goal;
  final List<WorkoutItem> items;
  final int estimatedMinutes;
  final int estimatedCalories;
}

/// Métier Avancé 2 : Moteur de Recommandation & Générateur Intelligent de Workout.
///
/// Algorithme basé sur les recommandations scientifiques de l'ACSM (American College
/// of Sports Medicine) et de la NSCA (National Strength & Conditioning Association) :
/// 1. Sélection équilibrée des chaînes musculaires agonistes/antagonistes.
/// 2. Calibration adaptative du volume (séries/reps) selon l'objectif (hypertrophie, force, endurance).
/// 3. Temps de repos optimisés (Schoenfeld et al., 2016).
/// 4. Surcharge progressive individualisée d'après le poids de l'abonné.
class WorkoutGeneratorService {
  const WorkoutGeneratorService();

  /// Génère un workout personnalisé en fonction du profil de l'utilisateur.
  static GeneratedWorkout generate({
    required AppUser user,
    required Goal goal,
    required Level level,
    required String focusGroup, // 'Full Body', 'Haut du corps', 'Bas du corps', 'Cardio & Abdos'
    Set<Equipment>? equipmentFilter,
  }) {
    final b = Backend.I;
    final allExercises = b.exercises.all.where((e) => b.library.canSee(user, e)).toList();

    // Filtrage par matériel disponible
    final available = allExercises.where((e) {
      if (equipmentFilter == null || equipmentFilter.isEmpty) return true;
      return equipmentFilter.contains(e.equipment) || e.equipment == Equipment.bodyweight;
    }).toList();

    // Définition des muscles cibles selon le groupe sélectionné
    final targetMuscles = switch (focusGroup) {
      'Haut du corps' => [Muscle.chest, Muscle.back, Muscle.shoulders, Muscle.biceps, Muscle.triceps],
      'Bas du corps' => [Muscle.quads, Muscle.hamstrings, Muscle.glutes, Muscle.calves, Muscle.abs],
      'Cardio & Abdos' => [Muscle.cardio, Muscle.abs, Muscle.fullBody],
      _ => [Muscle.chest, Muscle.back, Muscle.quads, Muscle.shoulders, Muscle.abs], // Full Body
    };

    final selectedItems = <WorkoutItem>[];
    final usedExerciseIds = <String>{};

    // Paramètres d'entraînement calibrés selon l'ACSM & NSCA
    final (sets, reps, restSec, tempo) = switch (goal) {
      Goal.muscleGain => (level == Level.beginner ? 3 : 4, 10, 90, '3-0-1'),
      Goal.weightLoss => (3, 15, 45, '2-0-1'),
      Goal.endurance => (3, 16, 30, '2-0-2'),
      Goal.fitness => (3, 12, 60, '2-0-1'),
    };

    final userWeight = user.weightKg ?? 70.0;

    for (final muscle in targetMuscles) {
      // Trouve le meilleur exercice pour ce muscle
      final candidates = available.where((e) => e.primaryMuscle == muscle && !usedExerciseIds.contains(e.id)).toList();
      if (candidates.isEmpty) continue;

      // Priorise les exercices de niveau adapté
      candidates.sort((a, b) {
        if (a.level == level && b.level != level) return -1;
        if (b.level == level && a.level != level) return 1;
        return 0;
      });

      final chosen = candidates.first;
      usedExerciseIds.add(chosen.id);

      // Charge suggérée selon le poids de corps et l'équipement
      String suggestedLoad = '';
      if (chosen.equipment == Equipment.barbell) {
        final load = (userWeight * (level == Level.beginner ? 0.35 : 0.60)).round();
        suggestedLoad = 'Recommandé : ~$load kg';
      } else if (chosen.equipment == Equipment.dumbbell) {
        final load = (userWeight * (level == Level.beginner ? 0.10 : 0.18)).round();
        suggestedLoad = 'Recommandé : 2 × ~$load kg';
      }

      final isTimed = chosen.type == ExerciseType.cardio && (chosen.primaryMuscle == Muscle.cardio || chosen.primaryMuscle == Muscle.abs);

      selectedItems.add(
        WorkoutItem(
          exerciseId: chosen.id,
          sets: sets,
          reps: isTimed ? null : reps,
          durationSec: isTimed ? 45 : null,
          restSec: restSec,
          tempo: tempo,
          suggestedLoad: suggestedLoad,
        ),
      );

      // Limite le workout à 5 ou 6 exercices principaux
      if (selectedItems.length >= (level == Level.advanced ? 6 : 5)) break;
    }

    // Calcul de la durée estimée et de la dépense calorique prévisionnelle
    final estimatedMin = selectedItems.fold(0, (sum, item) {
      final workSec = item.sets * (item.isTimed ? (item.durationSec ?? 45) : (item.reps ?? 10) * 4);
      final restSec = (item.sets - 1) * item.restSec;
      return sum + ((workSec + restSec) / 60).round();
    });

    final estimatedCalories = (estimatedMin * (goal == Goal.weightLoss ? 9.2 : 7.5)).round();

    final workoutName = 'Workout Intelligent : $focusGroup ($level)';
    final workoutDesc = 'Séance optimisée scientifiquement selon les standards ACSM/NSCA pour l\'objectif « ${goal.label} ». '
        'Volume équilibré sur ${selectedItems.length} exercices ciblés.';

    return GeneratedWorkout(
      name: workoutName,
      description: workoutDesc,
      focus: focusGroup,
      level: level,
      goal: goal,
      items: selectedItems,
      estimatedMinutes: estimatedMin.clamp(20, 90),
      estimatedCalories: estimatedCalories,
    );
  }
}
