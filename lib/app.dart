import 'package:flutter/gestures.dart';
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
      // Ordinateur : carrousels, bannière et présentation se font glisser
      // aussi à la souris / au pavé tactile (pas seulement au doigt).
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
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
