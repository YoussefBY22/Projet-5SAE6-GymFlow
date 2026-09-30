import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/repositories/data_store.dart';
import 'package:gymflow/repositories/sqlite_data_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Dépôt SQLite réel (via sqflite_common_ffi sur PC) : écriture, lecture,
/// mise à jour, suppression et métadonnées.
void main() {
  setUpAll(sqfliteFfiInit);

  test('aller-retour SQLite des documents', () async {
    final store = SqliteDataStore(
      fileName: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    await store.open();
    await store.put(Collections.users, 'u1', {'id': 'u1', 'fullName': 'Nour'});
    await store.putAll(Collections.users, {
      'u2': {'id': 'u2', 'fullName': 'Ahmed'},
      'u1': {'id': 'u1', 'fullName': 'Nour Ben Ammar'},
    });
    final users = await store.loadAll(Collections.users);
    expect(users.length, 2);
    expect(
      users.firstWhere((u) => u['id'] == 'u1')['fullName'],
      'Nour Ben Ammar',
    );
    await store.delete(Collections.users, 'u2');
    expect((await store.loadAll(Collections.users)).length, 1);
    await store.setMeta('seed_version', '1');
    expect(await store.getMeta('seed_version'), '1');
    await store.clear();
    expect(await store.loadAll(Collections.users), isEmpty);
  });
}
