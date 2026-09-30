import 'dart:math';

import '../models/json.dart';
import 'data_store.dart';

/// Dépôt générique typé au-dessus d'un [DataStore].
/// Les documents sont gardés en cache mémoire (lecture instantanée) et
/// chaque écriture est répercutée immédiatement dans le stockage.
class Repository<T> {
  Repository({
    required this.store,
    required this.collection,
    required this.fromJson,
    required this.toJson,
    required this.idOf,
  });

  final DataStore store;
  final String collection;
  final T Function(Json) fromJson;
  final Json Function(T) toJson;
  final String Function(T) idOf;

  final Map<String, T> _cache = {};

  Future<void> load() async {
    _cache.clear();
    for (final j in await store.loadAll(collection)) {
      final item = fromJson(j);
      _cache[idOf(item)] = item;
    }
  }

  List<T> get all => List.unmodifiable(_cache.values);
  int get count => _cache.length;
  bool get isEmpty => _cache.isEmpty;

  T? byId(String? id) => id == null ? null : _cache[id];

  List<T> where(bool Function(T) test) => _cache.values.where(test).toList();

  Future<T> save(T item) async {
    _cache[idOf(item)] = item;
    await store.put(collection, idOf(item), toJson(item));
    return item;
  }

  Future<void> saveAll(Iterable<T> items) async {
    final docs = <String, Json>{};
    for (final item in items) {
      _cache[idOf(item)] = item;
      docs[idOf(item)] = toJson(item);
    }
    await store.putAll(collection, docs);
  }

  Future<void> delete(String id) async {
    _cache.remove(id);
    await store.delete(collection, id);
  }
}

/// Générateur d'identifiants uniques courts (horodatage + aléa).
class IdGen {
  IdGen._();
  static final Random _r = Random();
  static int _counter = 0;

  static String next([String prefix = '']) {
    _counter = (_counter + 1) % 1296;
    final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final c = _counter.toRadixString(36).padLeft(2, '0');
    final r = _r.nextInt(1 << 20).toRadixString(36).padLeft(4, '0');
    return '$prefix$t$c$r';
  }
}
