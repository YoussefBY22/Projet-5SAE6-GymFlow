import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/routes.dart';
import 'core/theme.dart';

/// Racine de l'application (cours S01 : MaterialApp + arbre de widgets).
class GymFlowApp extends StatelessWidget {
  const GymFlowApp({super.key, this.initialRoute = Routes.splash});

  final String initialRoute;

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymFlow',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      // Mode clair uniquement : aucun thème sombre.
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: initialRoute,
      // Une seule route initiale (sinon « /home » empilerait aussi « / »).
      onGenerateInitialRoutes: (name) => [
        Routes.onGenerateRoute(RouteSettings(name: name)),
      ],
      onGenerateRoute: Routes.onGenerateRoute,
    );
  }
}
