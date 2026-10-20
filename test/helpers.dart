import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gymflow/repositories/data_store.dart';
import 'package:gymflow/services/backend.dart';
import 'package:gymflow/services/payment/payment_gateway.dart';
import 'package:gymflow/services/platform/platform_services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Heure de référence des tests : mercredi 30 septembre 2026, 10 h.
final testNow = DateTime(2026, 9, 30, 10);

/// Crée un backend en mémoire avec le jeu de démonstration et une horloge
/// contrôlée. Les itérations PBKDF2 sont réduites pour la rapidité.
Future<Backend> makeBackend({
  DateTime? now,
  bool seed = true,
  http.Client? httpClient,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});
  await initializeDateFormatting('fr_FR');
  var current = now ?? testNow;
  final b = await Backend.init(
    store: MemoryDataStore(),
    sessionStorage: MemorySessionStorage(),
    notifier: RecordingNotifier(),
    calendar: NoopCalendar(),
    clock: () => current,
    passwordIterations: 60,
    payment: SimulatedPaymentGateway(latency: Duration.zero),
    seed: seed,
    // Jamais de vrai réseau dans les tests : FormSubmit (email par défaut,
    // sans clé) enverrait sinon de vrais emails à chaque réservation.
    httpClient: httpClient ?? offlineEmailClient(),
  );
  b.clock = () => current;
  b.email.retryDelay = Duration.zero;
  _setNow = (d) => current = d;
  return b;
}

void Function(DateTime)? _setNow;

/// Avance l'horloge du backend de test.
void setNow(DateTime d) => _setNow?.call(d);

Future<void> loginAs(Backend b, String email) => b.auth.login(
  email,
  email.startsWith('admin')
      ? 'Admin2026!'
      : ['amira', 'mehdi', 'sarra'].any(email.startsWith)
      ? 'Coach2026!'
      : 'Membre2026!',
);

/// Client HTTP des tests par défaut : répond comme FormSubmit (succès)
/// sans aucun accès réseau.
http.Client offlineEmailClient() => MockClient(
  (_) async =>
      http.Response('{"success":"true","message":"test hors ligne"}', 200),
);
