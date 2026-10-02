import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../services/bootstrap.dart';
import '../../widgets/animations.dart';
import '../../widgets/common.dart';

/// Splash animé : attend l'initialisation (base SQLite, jeu de démo,
/// session) puis redirige vers l'onboarding, la connexion ou l'accueil.
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
      final seen = prefs.getBool('onboarding_done') ?? false;
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

/// Onboarding court en 3 pages (PageView + indicateurs animés).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      'assets/images/onboarding1.jpg',
      'Entraînez-vous à votre rythme',
      'Programmes, séances guidées pas à pas et vidéos de chaque exercice, du débutant au confirmé.',
    ),
    (
      'assets/images/onboarding2.jpg',
      'Réservez vos cours en un geste',
      'Yoga, HIIT, spinning, boxe… Réservez, recevez un rappel et ajoutez-le à votre agenda.',
    ),
    (
      'assets/images/onboarding3.jpg',
      'Suivez vos progrès',
      'Séries, records, objectifs de la semaine : chaque séance compte. Bravo à vous !',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) Navigator.pushReplacementNamed(context, Routes.login);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final (image, title, text) = _pages[i];
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(image, fit: BoxFit.cover),
                  const TopScrim(height: 140),
                  // Dégradé sombre : texte blanc lisible sur la photo.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.25, 0.65],
                        colors: [Color(0x33001226), Color(0xF2001A38)],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, 140),
                      // Ordinateur : texte à largeur lisible.
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: AppText.display(
                                  color: AppColors.white,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(height: Gap.m),
                              Text(
                                text,
                                style: AppText.body(
                                  color: AppColors.cream,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(Gap.s),
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.white),
                  onPressed: _finish,
                  child: const Text('Passer'),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(Gap.l),
                child: Row(
                  children: [
                    for (var i = 0; i < _pages.length; i++)
                      AnimatedContainer(
                        duration: kAnim,
                        curve: kCurve,
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _page ? 28 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? AppColors.gold
                              : AppColors.navyMuted,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: last
                          ? _finish
                          : () => _controller.nextPage(
                              duration: kAnim,
                              curve: kCurve,
                            ),
                      child: Text(last ? 'Commencer' : 'Suivant'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
