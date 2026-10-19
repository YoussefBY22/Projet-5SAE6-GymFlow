import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Conditions météo récupérées via l'API publique Open-Meteo.
class WeatherInfo {
  const WeatherInfo({
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.weatherCode,
    required this.isDay,
    required this.fetchedAt,
  });

  final double temperature;
  final double apparentTemperature;
  final int humidity;
  final int weatherCode;
  final bool isDay;
  final DateTime fetchedAt;

  /// Facteur de stress thermo-cardiaque pour le métabolisme et l'effort.
  /// En ambiance chaude et humide (>26°C ou >60% humidité), la thermorégulation
  /// induit une dérive cardiaque (« cardiac drift ») augmentant la dépense métabolique.
  double get thermalStressFactor {
    if (apparentTemperature > 30) return 1.12;
    if (apparentTemperature > 26) return 1.06;
    if (apparentTemperature < 15) return 1.02;
    return 1.0;
  }

  /// Description textuelle en français selon le code WMO Open-Meteo.
  String get conditionDescription {
    return switch (weatherCode) {
      0 => 'Ciel dégagé',
      1 || 2 => 'Partiellement nuageux',
      3 => 'Couvert',
      45 || 48 => 'Brouillard',
      51 || 53 || 55 => 'Bruine légère',
      61 || 63 || 65 => 'Pluie',
      71 || 73 || 75 => 'Chute de neige',
      80 || 81 || 82 => 'Averses',
      95 || 96 || 99 => 'Orage',
      _ => 'Temps tempéré',
    };
  }

  IconData get icon {
    return switch (weatherCode) {
      0 => isDay ? Icons.wb_sunny : Icons.nightlight_round,
      1 || 2 => isDay ? Icons.wb_cloudy : Icons.cloud_outlined,
      3 => Icons.cloud,
      45 || 48 => Icons.blur_on,
      51 || 53 || 55 || 61 || 63 || 65 || 80 || 81 || 82 => Icons.water_drop,
      95 || 96 || 99 => Icons.flash_on,
      _ => Icons.thermostat,
    };
  }
}

/// Service d'intégration de l'API externe Open-Meteo (API 2).
/// API REST gratuite, sans clé d'authentification requise.
/// Géolocalisation par défaut : Club GymFlow Lac 2, Tunis (36.83° N, 10.24° E).
class WeatherService {
  WeatherService({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  final http.Client _client;
  WeatherInfo? _cached;
  static const Duration _cacheTtl = Duration(minutes: 30);

  /// Coordonnées géographiques de la salle GymFlow Club Lac 2 (Tunis).
  static const double gymLatitude = 36.8347;
  static const double gymLongitude = 10.2407;

  /// Récupère la météo en temps réel avec cache et repli hors-ligne.
  Future<WeatherInfo> getCurrentWeather({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh && _cached != null && now.difference(_cached!.fetchedAt) < _cacheTtl) {
      return _cached!;
    }

    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$gymLatitude'
        '&longitude=$gymLongitude'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code'
        '&timezone=auto',
      );

      final res = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>;

        final info = WeatherInfo(
          temperature: (current['temperature_2m'] as num).toDouble(),
          apparentTemperature: (current['apparent_temperature'] as num).toDouble(),
          humidity: (current['relative_humidity_2m'] as num).toInt(),
          weatherCode: (current['weather_code'] as num).toInt(),
          isDay: (current['is_day'] as num).toInt() == 1,
          fetchedAt: now,
        );
        _cached = info;
        return info;
      }
    } catch (_) {
      // Repli hors-ligne : environnement intérieur climatisé de la salle.
    }

    // Valeur de secours standard en salle de sport (22°C, 45% humidité).
    return _cached ??= WeatherInfo(
      temperature: 22.0,
      apparentTemperature: 22.0,
      humidity: 45,
      weatherCode: 0,
      isDay: true,
      fetchedAt: now,
    );
  }
}
