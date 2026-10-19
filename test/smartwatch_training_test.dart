import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/models/enums.dart';
import 'package:gymflow/models/session_log.dart';
import 'package:gymflow/services/backend.dart';
import 'package:gymflow/services/calorie_service.dart';
import 'package:gymflow/services/smartwatch_service.dart';
import 'package:gymflow/services/weather_service.dart';
import 'package:gymflow/services/workout_generator_service.dart';

import 'helpers.dart';

void main() {
  group('SmartwatchService & Simulation Bluetooth BLE', () {
    test('Scan découvre les montres BLE disponibles', () async {
      final sw = SmartwatchService();
      expect(sw.isConnected, isFalse);
      expect(sw.availableDevices.value, isEmpty);

      await sw.startScan();
      // Le scan asynchrone complète après son délai
      await Future<void>.delayed(const Duration(milliseconds: 1600));

      expect(sw.availableDevices.value.isNotEmpty, isTrue);
      expect(
        sw.availableDevices.value.map((d) => d.name),
        contains('GymFlow Watch Pro'),
      );
      sw.dispose();
    });

    test('Connexion et déconnexion de la smartwatch', () async {
      final sw = SmartwatchService();
      const testDevice = SmartwatchDevice(
        id: 'test_watch',
        name: 'GymFlow Watch Pro',
        brand: 'GymFlow BLE',
        macAddress: 'DC:A6:32:8B:44:01',
        rssi: -55,
        batteryLevel: 90,
      );

      await sw.connect(testDevice);
      expect(sw.isConnected, isTrue);
      expect(sw.connectedDevice.value?.name, 'GymFlow Watch Pro');

      sw.disconnect();
      expect(sw.isConnected, isFalse);
      expect(sw.connectedDevice.value, isNull);
      expect(sw.telemetry.value, isNull);
      sw.dispose();
    });

    test('Télémétrie en direct et réaction au contexte de la séance', () async {
      final sw = SmartwatchService();
      const testDevice = SmartwatchDevice(
        id: 'test_watch',
        name: 'GymFlow Watch Pro',
        brand: 'GymFlow BLE',
        macAddress: 'DC:A6:32:8B:44:01',
        rssi: -55,
        batteryLevel: 90,
      );

      await sw.connect(testDevice);
      sw.setExerciseContext(
        isExercising: true,
        exerciseType: ExerciseType.cardio,
        userWeightKg: 75.0,
        userAge: 25,
        userGender: Gender.male,
        thermalStressFactor: 1.0,
      );

      // Laisser passer 2 ticks de télémétrie
      await Future<void>.delayed(const Duration(milliseconds: 2200));

      final telem = sw.telemetry.value;
      expect(telem, isNotNull);
      expect(telem!.heartRate, greaterThan(60));
      expect(telem.caloriesBurned, greaterThan(0.0));
      expect(telem.activeDurationSec, greaterThanOrEqualTo(2));

      sw.disconnect();
      sw.dispose();
    });
  });

  group('CalorieService & Formule scientifique de Keytel', () {
    test('Calcul de la FC Max selon Tanaka', () {
      // Tanaka: 208 - 0.7 * 20 = 194
      expect(CalorieService.maxHeartRate(20), 194);
      // Tanaka: 208 - 0.7 * 40 = 180
      expect(CalorieService.maxHeartRate(40), 180);
    });

    test('Zones de fréquence cardiaque ACSM / Strava', () {
      // Pour 20 ans, FCmax = 194. 150 BPM = 77% (Aérobie)
      final zone = CalorieService.zoneFor(heartRate: 150, age: 20);
      expect(zone, HeartRateZone.aerobic);

      // 180 BPM = 92% (Effort Maximal)
      final zoneMax = CalorieService.zoneFor(heartRate: 180, age: 20);
      expect(zoneMax, HeartRateZone.maximum);
    });

    test('Dépense calorique Keytel par seconde cohérente', () {
      final burnMan = CalorieService.burnPerSecond(
        heartRate: 140,
        weightKg: 75.0,
        age: 25,
        gender: Gender.male,
      );
      expect(burnMan, greaterThan(0.05));
      expect(burnMan, lessThan(0.35));

      final burnWoman = CalorieService.burnPerSecond(
        heartRate: 140,
        weightKg: 60.0,
        age: 25,
        gender: Gender.female,
      );
      expect(burnWoman, greaterThan(0.04));
      expect(burnWoman, lessThan(0.35));
    });

    test('Stress thermique augmente la dépense calorique', () {
      final normal = CalorieService.burnPerSecond(
        heartRate: 140,
        weightKg: 75.0,
        age: 25,
        gender: Gender.male,
        thermalStressFactor: 1.0,
      );
      final withHeat = CalorieService.burnPerSecond(
        heartRate: 140,
        weightKg: 75.0,
        age: 25,
        gender: Gender.male,
        thermalStressFactor: 1.12,
      );
      expect(withHeat, greaterThan(normal));
    });

    test('Estimation de séance complète', () {
      final cal = CalorieService.estimateSessionCalories(
        averageHeartRate: 135,
        durationSec: 1800, // 30 minutes
        weightKg: 75.0,
        age: 25,
        gender: Gender.male,
      );
      // Une séance de 30 min à 135 BPM dépense typiquement entre 180 et 350 kcal
      expect(cal, greaterThan(150));
      expect(cal, lessThan(450));
    });
  });

  group('WeatherService & Open-Meteo', () {
    test('Fournit des conditions météo et facteur thermique', () async {
      final ws = WeatherService();
      final w = await ws.getCurrentWeather();
      expect(w.temperature, isNotNull);
      expect(w.humidity, greaterThan(0));
      expect(w.thermalStressFactor, greaterThanOrEqualTo(1.0));
      expect(w.conditionDescription.isNotEmpty, isTrue);
    });
  });

  group('SessionLog & Persistance des métriques smartwatch', () {
    test('Sérialisation et désérialisation JSON préservent les champs smartwatch', () {
      final now = DateTime(2026, 10, 15, 14);
      final log = SessionLog(
        id: 's_test_123',
        userId: 'u_nour',
        workoutId: 'w_push',
        title: 'Push Day',
        startedAt: now,
        durationSec: 2400,
        sets: const [
          SetLog(
            exerciseId: 'ex_bench',
            exerciseName: 'Développé couché',
            setIndex: 1,
            reps: 10,
            loadKg: 50,
          ),
        ],
        caloriesBurned: 320,
        averageHeartRate: 138,
        maxHeartRate: 162,
        stepCount: 1450,
        smartwatchDevice: 'GymFlow Watch Pro',
      );

      final json = log.toJson();
      expect(json['caloriesBurned'], 320);
      expect(json['averageHeartRate'], 138);
      expect(json['maxHeartRate'], 162);
      expect(json['stepCount'], 1450);
      expect(json['smartwatchDevice'], 'GymFlow Watch Pro');

      final reconstructed = SessionLog.fromJson(json);
      expect(reconstructed.caloriesBurned, 320);
      expect(reconstructed.averageHeartRate, 138);
      expect(reconstructed.maxHeartRate, 162);
      expect(reconstructed.stepCount, 1450);
      expect(reconstructed.smartwatchDevice, 'GymFlow Watch Pro');
    });

    test('TrainingLogService enregistre les données de montre', () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      final workout = b.workouts.all.first;

      final res = await b.trainingLog.finishSession(
        workout: workout,
        startedAt: testNow,
        durationSec: 1800,
        sets: const [
          SetLog(
            exerciseId: 'ex_bench',
            exerciseName: 'Développé couché',
            setIndex: 1,
            reps: 10,
            loadKg: 40,
          ),
        ],
        caloriesBurned: 245,
        averageHeartRate: 132,
        maxHeartRate: 155,
        stepCount: 890,
        smartwatchDevice: 'GymFlow Watch Pro',
      );

      expect(res.log.caloriesBurned, 245);
      expect(res.log.averageHeartRate, 132);
      expect(res.log.maxHeartRate, 155);
      expect(res.log.stepCount, 890);
      expect(res.log.smartwatchDevice, 'GymFlow Watch Pro');

      final retrieved = b.trainingLog.byId(res.log.id);
      expect(retrieved?.caloriesBurned, 245);
      expect(retrieved?.averageHeartRate, 132);
    });
  });

  group('WorkoutGeneratorService (Métier Avancé 2)', () {
    test('Génère un workout scientifiquement calibré selon ACSM/NSCA', () async {
      final b = await makeBackend();
      await loginAs(b, 'nour@gymflow.tn');
      final user = b.auth.currentUser!;

      final generated = WorkoutGeneratorService.generate(
        user: user,
        goal: Goal.muscleGain,
        level: Level.intermediate,
        focusGroup: 'Full Body',
      );

      expect(generated.name, contains('Full Body'));
      expect(generated.items.isNotEmpty, isTrue);
      expect(generated.estimatedMinutes, greaterThan(20));
      expect(generated.estimatedCalories, greaterThan(100));

      for (final item in generated.items) {
        expect(item.sets, 4); // 4 séries pour intermédiaire en prise de masse
        expect(item.reps, 10);
        expect(item.restSec, 90);
      }
    });
  });
}
