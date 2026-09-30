import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'repositories/data_store.dart';
import 'repositories/sqlite_data_store.dart';
import 'services/backend.dart';
import 'services/bootstrap.dart';
import 'services/platform/platform_services.dart';

/// Point d'entrée (cours S01 : main() → runApp()).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Polices embarquées dans les assets : pas de téléchargement à l'exécution.
  GoogleFonts.config.allowRuntimeFetching = false;
  await initializeDateFormatting('fr_FR');
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFFFFFFF),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final notifier = FlutterLocalNotifier();
  await notifier.init();

  // Le backend (SQLite + jeu de démo) est initialisé pendant le splash.
  BackendBootstrap.start(
    () => Backend.init(
      // Web (prévisualisation) : données en mémoire ; Android : SQLite.
      store: kIsWeb ? MemoryDataStore() : SqliteDataStore(),
      sessionStorage: SecureSessionStorage(),
      notifier: notifier,
      calendar: DeviceCalendar(),
    ),
  );

  runApp(const GymFlowApp());
}
