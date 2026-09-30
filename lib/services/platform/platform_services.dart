import 'package:add_2_calendar/add_2_calendar.dart' as cal;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Adaptateurs vers les services du téléphone, derrière des interfaces
/// pour pouvoir être remplacés par des versions de test.

/// Stockage sécurisé du jeton de session.
abstract class SessionStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureSessionStorage implements SessionStorage {
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MemorySessionStorage implements SessionStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Notifications locales du téléphone (rappels de cours).
abstract class LocalNotifier {
  Future<void> init();
  Future<void> requestPermission();
  Future<void> schedule(int id, String title, String body, DateTime at);
  Future<void> show(int id, String title, String body);
  Future<void> cancel(int id);
}

class FlutterLocalNotifier implements LocalNotifier {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'gymflow_rappels',
      'Rappels de cours',
      channelDescription: 'Rappels 24 h et 1 h avant vos cours réservés',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFFBA0C2F),
    ),
  );

  @override
  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Africa/Tunis'));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications indisponibles : ${e.runtimeType}');
    }
  }

  @override
  Future<void> requestPermission() async {
    if (!_ready) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> schedule(int id, String title, String body, DateTime at) async {
    if (!_ready || !at.isAfter(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: _details,
        // Mode inexact : évite la permission SCHEDULE_EXACT_ALARM.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Planification impossible : ${e.runtimeType}');
    }
  }

  @override
  Future<void> show(int id, String title, String body) async {
    if (!_ready) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details,
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (!_ready) return;
    await _plugin.cancel(id: id);
  }
}

/// Version de test : garde la trace des rappels planifiés.
class RecordingNotifier implements LocalNotifier {
  final Map<int, DateTime> scheduled = {};
  final List<String> shown = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> schedule(int id, String title, String body, DateTime at) async {
    scheduled[id] = at;
  }

  @override
  Future<void> show(int id, String title, String body) async => shown.add(title);

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
}

/// Ajout d'un événement dans l'agenda du téléphone.
abstract class CalendarGateway {
  Future<bool> addEvent({
    required String title,
    required String description,
    required String location,
    required DateTime start,
    required DateTime end,
  });
}

class DeviceCalendar implements CalendarGateway {
  @override
  Future<bool> addEvent({
    required String title,
    required String description,
    required String location,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      return await cal.Add2Calendar.addEvent2Cal(
        cal.Event(
          title: title,
          description: description,
          location: location,
          startDate: start,
          endDate: end,
          timeZone: 'Africa/Tunis',
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

class NoopCalendar implements CalendarGateway {
  final List<String> added = [];

  @override
  Future<bool> addEvent({
    required String title,
    required String description,
    required String location,
    required DateTime start,
    required DateTime end,
  }) async {
    added.add(title);
    return true;
  }
}

/// Retour haptique (vibration en fin de minuteur de repos).
class Haptics {
  Haptics._();
  static Future<void> restOver() async {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await HapticFeedback.vibrate();
  }
}
