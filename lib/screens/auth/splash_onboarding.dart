import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../services/bootstrap.dart';
import 'intro_tour.dart';

/// Splash animé : attend l'initialisation (base SQLite, jeu de démo,
/// session) puis redirige vers la présentation (premier lancement), la
/// connexion ou l'accueil.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() => _error = null);
    try {
      final minDelay = Future<void>.delayed(const Duration(milliseconds: 1500));
      final backend = await BackendBootstrap.ready;
      await minDelay;
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(OnboardingFlag.key) ?? false;
      OnboardingFlag.seen = seen;
      if (!mounted) return;
      final user = backend.auth.currentUser;
      Navigator.pushReplacementNamed(
        context,
        user != null
            ? Routes.afterLogin(user)
            : (seen ? Routes.login : Routes.onboarding),
      );
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    final fade = CurvedAnimation(parent: _c, curve: const Interval(0.3, 1));
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: scale,
              child: Image.asset('assets/images/logo.png', width: 140),
            ),
            const SizedBox(height: Gap.l),
            FadeTransition(
              opacity: fade,
              child: Column(
                children: [
                  Text(
                    'GymFlow',
                    style: AppText.display(color: AppColors.white),
                  ),
                  const SizedBox(height: Gap.s),
                  Text(
                    'Bougez. Progressez. Ensemble.',
                    style: AppText.body(color: AppColors.cream),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.xl),
            if (_error == null)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: AppColors.gold,
                  strokeWidth: 3,
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: AppText.body(color: AppColors.white),
                ),
              ),
              const SizedBox(height: Gap.m),
              ElevatedButton(onPressed: _boot, child: const Text('Réessayer')),
            ],
          ],
        ),
      ),
    );
  }
}
