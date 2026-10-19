import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import 'calorie_service.dart';

/// Appareil montre connectée Bluetooth détecté.
class SmartwatchDevice {
  const SmartwatchDevice({
    required this.id,
    required this.name,
    required this.brand,
    required this.macAddress,
    required this.rssi,
    required this.batteryLevel,
    this.isConnected = false,
  });

  final String id;
  final String name;
  final String brand;
  final String macAddress;
  final int rssi; // Signal en dBm (ex: -55 dBm)
  final int batteryLevel; // Pourcentage batterie
  final bool isConnected;

  SmartwatchDevice copyWith({bool? isConnected, int? batteryLevel, int? rssi}) {
    return SmartwatchDevice(
      id: id,
      name: name,
      brand: brand,
      macAddress: macAddress,
      rssi: rssi ?? this.rssi,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

/// Télémétrie en temps réel transmise par la montre en Bluetooth.
class SmartwatchTelemetry {
  const SmartwatchTelemetry({
    required this.heartRate,
    required this.averageHeartRate,
    required this.maxHeartRate,
    required this.stepCount,
    required this.caloriesBurned,
    required this.activeDurationSec,
    required this.zone,
    required this.timestamp,
  });

  final int heartRate; // BPM instantané
  final int averageHeartRate; // BPM moyen
  final int maxHeartRate; // BPM pic
  final int stepCount; // Pas cumulés pendant la séance
  final double caloriesBurned; // Calories calculées
  final int activeDurationSec; // Secondes d'activité
  final HeartRateZone zone; // Zone d'effort actuelle
  final DateTime timestamp;

  int get caloriesInt => caloriesBurned.round();
}

/// Service de simulation Bluetooth Low Energy (BLE) de smartwatch.
///
/// Implémente le profil standard GATT Heart Rate Service (UUID 0x180D)
/// et la caractéristique Heart Rate Measurement (UUID 0x2A37).
///
/// Génère une télémétrie biométrique réaliste réagissant dynamiquement
/// aux phases de la séance (effort d'une série vs temps de repos).
class SmartwatchService {
  SmartwatchService();

  final ValueNotifier<SmartwatchDevice?> connectedDevice = ValueNotifier<SmartwatchDevice?>(null);
  final ValueNotifier<SmartwatchTelemetry?> telemetry = ValueNotifier<SmartwatchTelemetry?>(null);
  final ValueNotifier<bool> isScanning = ValueNotifier<bool>(false);
  final ValueNotifier<List<SmartwatchDevice>> availableDevices = ValueNotifier<List<SmartwatchDevice>>([]);

  Timer? _telemetryTimer;
  Timer? _scanTimer;
  final Random _rng = Random();

  // Contexte de l'effort courant pour piloter la dynamique cardiaque
  bool _isExercising = false;
  ExerciseType _currentExerciseType = ExerciseType.strength;
  double _userWeightKg = 75.0;
  int _userAge = 25;
  Gender _userGender = Gender.male;
  double _thermalStressFactor = 1.0;

  // Compteurs accumulés pour la séance
  double _currentHeartRate = 82.0;
  int _maxHeartRateSeen = 82;
  double _sumHeartRate = 0.0;
  int _heartRateTicks = 0;
  int _stepsAccumulated = 0;
  double _caloriesAccumulated = 0.0;
  int _activeSeconds = 0;

  bool get isConnected => connectedDevice.value != null;

  /// Lance un scan BLE simulé pour découvrir les montres à portée.
  Future<void> startScan() async {
    isScanning.value = true;
    availableDevices.value = [];

    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(milliseconds: 1400), () {
      availableDevices.value = [
        const SmartwatchDevice(
          id: 'ble_gf_watch_pro',
          name: 'GymFlow Watch Pro',
          brand: 'GymFlow (GATT 0x180D)',
          macAddress: 'DC:A6:32:8B:44:01',
          rssi: -52,
          batteryLevel: 94,
        ),
        const SmartwatchDevice(
          id: 'ble_garmin_965',
          name: 'Garmin Forerunner 965',
          brand: 'Garmin',
          macAddress: '3C:71:BF:12:AA:77',
          rssi: -65,
          batteryLevel: 78,
        ),
        const SmartwatchDevice(
          id: 'ble_apple_ultra',
          name: 'Apple Watch Ultra 2',
          brand: 'Apple',
          macAddress: 'F0:18:98:33:DE:5B',
          rssi: -59,
          batteryLevel: 85,
        ),
        const SmartwatchDevice(
          id: 'ble_galaxy_watch',
          name: 'Samsung Galaxy Watch 6',
          brand: 'Samsung WearOS',
          macAddress: '68:C4:4D:90:E1:2A',
          rssi: -71,
          batteryLevel: 62,
        ),
      ];
      isScanning.value = false;
    });
  }

  /// Connexion Bluetooth à un appareil spécifique.
  Future<void> connect(SmartwatchDevice device) async {
    _scanTimer?.cancel();
    isScanning.value = false;

    // Réinitialisation des métriques de session
    _currentHeartRate = 80.0 + _rng.nextInt(10);
    _maxHeartRateSeen = _currentHeartRate.round();
    _sumHeartRate = _currentHeartRate;
    _heartRateTicks = 1;
    _stepsAccumulated = 0;
    _caloriesAccumulated = 0.0;
    _activeSeconds = 0;

    final connected = device.copyWith(isConnected: true);
    connectedDevice.value = connected;

    _startTelemetryStream();
  }

  /// Déconnexion de la smartwatch.
  void disconnect() {
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
    connectedDevice.value = null;
    telemetry.value = null;
  }

  /// Met à jour l'état de l'exercice pour moduler dynamiquement la FC et les pas.
  void setExerciseContext({
    required bool isExercising,
    required ExerciseType exerciseType,
    required double userWeightKg,
    required int userAge,
    required Gender userGender,
    double thermalStressFactor = 1.0,
  }) {
    _isExercising = isExercising;
    _currentExerciseType = exerciseType;
    _userWeightKg = userWeightKg;
    _userAge = userAge;
    _userGender = userGender;
    _thermalStressFactor = thermalStressFactor;
  }

  /// Boucle périodique d'émission de paquets BLE (1 seconde).
  void _startTelemetryStream() {
    _telemetryTimer?.cancel();
    _telemetryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isConnected) return;

      _activeSeconds++;

      // Détermination de la cible cardiaque selon l'effort
      double targetHr;
      if (_isExercising) {
        // En série : FC monte vers 130 - 170 BPM selon le type
        targetHr = switch (_currentExerciseType) {
          ExerciseType.cardio => 155.0 + _rng.nextDouble() * 15,
          ExerciseType.strength => 135.0 + _rng.nextDouble() * 15,
          ExerciseType.mobility || ExerciseType.stretching => 105.0 + _rng.nextDouble() * 10,
        };
        // En exercice : 1 à 2 pas par seconde
        _stepsAccumulated += _rng.nextBool() ? 2 : 1;
      } else {
        // En repos / récupération : FC redescend vers 95 - 110 BPM
        targetHr = 100.0 + _rng.nextDouble() * 10;
        // Au repos : pas occasionnel
        if (_rng.nextInt(5) == 0) _stepsAccumulated += 1;
      }

      // Transition progressive lissée vers la cible (inertie physiologique)
      _currentHeartRate += (targetHr - _currentHeartRate) * 0.15;
      final hrInt = _currentHeartRate.round();

      if (hrInt > _maxHeartRateSeen) {
        _maxHeartRateSeen = hrInt;
      }
      _sumHeartRate += hrInt;
      _heartRateTicks++;
      final avgHr = (_sumHeartRate / _heartRateTicks).round();

      // Calcul des calories de cette seconde via CalorieService (Keytel)
      final burnThisSec = CalorieService.burnPerSecond(
        heartRate: hrInt,
        weightKg: _userWeightKg,
        age: _userAge,
        gender: _userGender,
        exerciseType: _currentExerciseType,
        thermalStressFactor: _thermalStressFactor,
      );
      _caloriesAccumulated += burnThisSec;

      final zone = CalorieService.zoneFor(heartRate: hrInt, age: _userAge);

      telemetry.value = SmartwatchTelemetry(
        heartRate: hrInt,
        averageHeartRate: avgHr,
        maxHeartRate: _maxHeartRateSeen,
        stepCount: _stepsAccumulated,
        caloriesBurned: _caloriesAccumulated,
        activeDurationSec: _activeSeconds,
        zone: zone,
        timestamp: DateTime.now(),
      );
    });
  }

  void dispose() {
    _telemetryTimer?.cancel();
    _scanTimer?.cancel();
    connectedDevice.dispose();
    telemetry.dispose();
    isScanning.dispose();
    availableDevices.dispose();
  }
}
