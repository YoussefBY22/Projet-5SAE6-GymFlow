import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gymflow/core/security.dart';
import 'package:gymflow/models/sentiment.dart';
import 'package:gymflow/repositories/data_store.dart';
import 'package:gymflow/services/backend.dart';
import 'package:gymflow/services/payment/payment_gateway.dart';
import 'package:gymflow/services/platform/platform_services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// Démarrage : aucun appel réseau, même avec des clés IA configurées, et
/// coût du jeu de démonstration borné (page web qui ne gèle pas).
void main() {
  late List<http.Request> requests;
  late http.Client client;

  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('fr_FR');
    requests = [];
    client = MockClient((req) async {
      requests.add(req);
      return http.Response('{}', 200);
    });
  });

  Future<Backend> init(DataStore store) => Backend.init(
    store: store,
    sessionStorage: MemorySessionStorage(),
    notifier: RecordingNotifier(),
    calendar: NoopCalendar(),
    clock: () => testNow,
    passwordIterations: 60,
    payment: SimulatedPaymentGateway(latency: Duration.zero),
    httpClient: client,
    geminiApiKey: 'gemini_test_key',
    hfToken: 'hf_test_token',
  );

  test('premier lancement (jeu de démo) : aucun appel HTTP', () async {
    final b = await init(MemoryDataStore());
    expect(b.sentiment.geminiEnabled, isTrue);
    expect(b.sentiment.hfEnabled, isTrue);
    expect(b.users.count, greaterThan(0));
    expect(requests, isEmpty, reason: requests.map((r) => r.url).join('\n'));
    // Les avis de démo sont tout de même analysés (localement).
    final commented = b.reservations.where(
      (r) => r.comment?.isNotEmpty ?? false,
    );
    expect(commented, isNotEmpty);
    expect(
      commented.every((r) => r.sentiment?.source == SentimentSource.local),
      isTrue,
    );
  });

  test('mise à niveau d\'anciens avis au démarrage : 100 % locale', () async {
    final store = MemoryDataStore();
    var b = await init(store);
    // Base « d'avant » : avis sans ton, mise à niveau jamais faite.
    for (final r in b.reservations.all) {
      final json = r.toJson()..remove('sentiment');
      await store.put(Collections.reservations, r.id, json);
    }
    await store.setMeta('review_sentiment', '0');
    requests.clear();

    b = await init(store);
    expect(requests, isEmpty, reason: requests.map((r) => r.url).join('\n'));
    final commented = b.reservations.where(
      (r) => r.comment?.isNotEmpty ?? false,
    );
    expect(commented, isNotEmpty);
    for (final r in commented) {
      expect(r.sentiment, isNotNull, reason: r.comment);
      expect(r.sentiment!.source, SentimentSource.local);
    }
    expect(await store.getMeta('review_sentiment'), '1');
  });

  test('jeu de démo : une empreinte par mot de passe public', () async {
    final b = await init(MemoryDataStore());
    final salts = b.credentials.all.map((c) => c.salt).toSet();
    expect(salts, hasLength(3), reason: 'admin, coachs, abonnés');
    for (final email in [
      'admin@gymflow.tn',
      'amira@gymflow.tn',
      'ines@gymflow.tn',
      'nour@gymflow.tn',
    ]) {
      await loginAs(b, email);
      expect(b.auth.currentUser?.email, email);
      await b.auth.logout();
    }
  });

  test('inscription : le compte garde son propre sel', () async {
    final b = await init(MemoryDataStore());
    final demoSalts = b.credentials.all.map((c) => c.salt).toSet();
    await b.auth.setPassword('u_ines', 'Nouveau2026!');
    expect(demoSalts, isNot(contains(b.credentials.byId('u_ines')!.salt)));
  });

  test('PBKDF2 asynchrone : même empreinte que la version synchrone', () async {
    final h = PasswordHasher(iterations: 2500);
    final salt = h.newSalt();
    expect(
      await h.hashAsync('Membre2026!', salt, yieldEvery: 500),
      h.hash('Membre2026!', salt),
    );
  });
}
