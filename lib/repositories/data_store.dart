import '../models/json.dart';

/// Interface de persistance (une « table » par collection de documents).
///
/// Deux implémentations :
/// - [SqliteDataStore] : SQLite sur le téléphone (sqflite) ;
/// - [MemoryDataStore] : en mémoire, pour les tests.
/// Une implémentation Firebase/Firestore pourrait être ajoutée sans
/// toucher aux services ni aux écrans.
abstract class DataStore {
  Future<void> open();
  Future<List<Json>> loadAll(String collection);
  Future<void> put(String collection, String id, Json data);
  Future<void> putAll(String collection, Map<String, Json> docs);
  Future<void> delete(String collection, String id);
  Future<String?> getMeta(String key);
  Future<void> setMeta(String key, String value);
  Future<void> clear();
}

/// Noms des collections (= tables SQLite).
class Collections {
  Collections._();
  static const users = 'users';
  static const credentials = 'credentials';
  static const exercises = 'exercises';
  static const workouts = 'workouts';
  static const programs = 'programs';
  static const sessions = 'sessions';
  static const weights = 'weights';
  static const courses = 'courses';
  static const reservations = 'reservations';
  static const notifications = 'notifications';
  static const products = 'products';
  static const orders = 'orders';
  static const audit = 'audit';
  static const announcements = 'announcements';
  static const wgerCache = 'wger_cache';

  static const all = [
    users,
    credentials,
    exercises,
    workouts,
    programs,
    sessions,
    weights,
    courses,
    reservations,
    notifications,
    products,
    orders,
    audit,
    announcements,
    wgerCache,
  ];
}

/// Implémentation en mémoire (tests unitaires et de widgets).
class MemoryDataStore implements DataStore {
  final Map<String, Map<String, Json>> _data = {};
  final Map<String, String> _meta = {};

  @override
  Future<void> open() async {}

  @override
  Future<List<Json>> loadAll(String collection) async =>
      (_data[collection] ?? {}).values.map((j) => Json.from(j)).toList();

  @override
  Future<void> put(String collection, String id, Json data) async {
    (_data[collection] ??= {})[id] = Json.from(data);
  }

  @override
  Future<void> putAll(String collection, Map<String, Json> docs) async {
    final table = _data[collection] ??= {};
    docs.forEach((id, j) => table[id] = Json.from(j));
  }

  @override
  Future<void> delete(String collection, String id) async {
    _data[collection]?.remove(id);
  }

  @override
  Future<String?> getMeta(String key) async => _meta[key];

  @override
  Future<void> setMeta(String key, String value) async => _meta[key] = value;

  @override
  Future<void> clear() async {
    _data.clear();
    _meta.clear();
  }
}
