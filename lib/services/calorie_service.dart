import '../models/enums.dart';

/// Zones physiologiques de fréquence cardiaque (modèle standard ACSM / Strava).
enum HeartRateZone {
  resting('Repos / Échauffement', 0.50, 0.60),
  fatBurn('Brûlage des graisses', 0.60, 0.70),
  aerobic('Aérobie & Cardio', 0.70, 0.80),
  anaerobic('Anaérobie / Seuil', 0.80, 0.90),
  maximum('Effort Maximal', 0.90, 1.00);

  const HeartRateZone(this.label, this.minPercent, this.maxPercent);
  final String label;
  final double minPercent;
  final double maxPercent;
}

/// Service de calcul scientifique des calories dépensées pendant l'entraînement.
///
/// Fondements scientifiques :
/// 1. Formule de Keytel et al. (Journal of Sports Sciences, 2005) basée sur la
///    fréquence cardiaque (FC), le poids, l'âge et le genre.
/// 2. Modèle des Équivalents Métaboliques (METs - Compendium of Physical Activities).
/// 3. Formule de Tanaka et al. (2001) pour la fréquence cardiaque maximale : FCmax = 208 - (0,7 × âge).
/// 4. Facteur thermo-cardiaque dérivé des conditions météo (API Open-Meteo).
class CalorieService {
  const CalorieService();

  /// Estimation de la fréquence cardiaque maximale (formule validée de Tanaka).
  static int maxHeartRate(int age) {
    final clampedAge = age.clamp(14, 99);
    return (208 - 0.7 * clampedAge).round();
  }

  /// Détermine la zone cardiaque actuelle d'après la fréquence cardiaque et l'âge.
  static HeartRateZone zoneFor({required int heartRate, required int age}) {
    final fcMax = maxHeartRate(age);
    final ratio = heartRate / fcMax;

    if (ratio >= HeartRateZone.maximum.minPercent) return HeartRateZone.maximum;
    if (ratio >= HeartRateZone.anaerobic.minPercent) return HeartRateZone.anaerobic;
    if (ratio >= HeartRateZone.aerobic.minPercent) return HeartRateZone.aerobic;
    if (ratio >= HeartRateZone.fatBurn.minPercent) return HeartRateZone.fatBurn;
    return HeartRateZone.resting;
  }

  /// Équivalent Métabolique (MET) de référence selon la typologie de l'exercice.
  static double metForType(ExerciseType type) {
    return switch (type) {
      ExerciseType.cardio => 8.5,
      ExerciseType.strength => 5.5,
      ExerciseType.mobility || ExerciseType.stretching => 2.8,
    };
  }

  /// Calcul de la dépense calorique instantanée par seconde (formule de Keytel).
  ///
  /// Équations de Keytel (énergie en kcal/min convertie en kcal/s) :
  /// Homme : [(-55.0969 + (0.6309 × FC) + (0.1988 × Poids) + (0.2017 × Âge)) / 4.184] / 60
  /// Femme : [(-20.4022 + (0.4472 × FC) - (0.1263 × Poids) + (0.0740 × Âge)) / 4.184] / 60
  static double burnPerSecond({
    required int heartRate,
    required double weightKg,
    required int age,
    required Gender gender,
    ExerciseType? exerciseType,
    double thermalStressFactor = 1.0,
  }) {
    if (heartRate <= 40 || weightKg <= 20) return 0.01;

    double kcalPerMin;
    if (gender == Gender.male) {
      kcalPerMin = (-55.0969 + (0.6309 * heartRate) + (0.1988 * weightKg) + (0.2017 * age)) / 4.184;
    } else {
      kcalPerMin = (-20.4022 + (0.4472 * heartRate) - (0.1263 * weightKg) + (0.0740 * age)) / 4.184;
    }

    if (kcalPerMin <= 0) {
      // Repli métabolique MET si FC très basse au repos
      final met = exerciseType != null ? metForType(exerciseType) : 4.0;
      kcalPerMin = (met * 3.5 * weightKg) / 200;
    }

    // Application du facteur métabolique d'exercice et du stress thermique météo
    var rate = (kcalPerMin / 60.0) * thermalStressFactor;

    // Légère pondération selon la typologie de l'exercice
    if (exerciseType == ExerciseType.cardio) {
      rate *= 1.10;
    } else if (exerciseType == ExerciseType.mobility || exerciseType == ExerciseType.stretching) {
      rate *= 0.85;
    }

    return rate.clamp(0.005, 0.45); // Entre 0.3 et 27 kcal / minute
  }

  /// Calcule l'estimation globale des calories pour une séance complète.
  static int estimateSessionCalories({
    required int averageHeartRate,
    required int durationSec,
    required double weightKg,
    required int age,
    required Gender gender,
    ExerciseType exerciseType = ExerciseType.strength,
    double thermalStressFactor = 1.0,
  }) {
    if (durationSec <= 0) return 0;
    final perSec = burnPerSecond(
      heartRate: averageHeartRate,
      weightKg: weightKg,
      age: age,
      gender: gender,
      exerciseType: exerciseType,
      thermalStressFactor: thermalStressFactor,
    );
    return (perSec * durationSec).round().clamp(1, 4000);
  }
}
