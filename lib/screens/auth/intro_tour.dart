import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/legal.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/privacy.dart';
import '../../services/backend.dart';
import '../../widgets/animations.dart';
import '../../widgets/common.dart';

/// Présentation verticale de l'application, montrée à la création du
/// compte ou à la première connexion (et rejouable depuis le menu).
/// On fait défiler du bas vers le haut ; la dernière page recueille les
/// consentements, **tous désactivés par défaut**.
class IntroTourScreen extends StatefulWidget {
  const IntroTourScreen({super.key});

  @override
  State<IntroTourScreen> createState() => _IntroTourScreenState();
}

class _IntroTourScreenState extends State<IntroTourScreen>
    with SingleTickerProviderStateMixin {
  final _pager = PageController();
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  int _page = 0;

  static const _slides = [
    (
      Icons.waving_hand_outlined,
      'Bienvenue dans GymFlow',
      'Entraîne-toi pas à pas, réserve tes cours, suis tes progrès et '
          'retrouve la communauté de ta salle — à ton rythme.',
      [
        'Programmes et séances guidées en vidéo',
        'Réservation des cours avec rappels',
        'Boutique de la salle',
      ],
    ),
    (
      Icons.lock_outline,
      'Tes séances t\'appartiennent',
      'Chaque séance terminée reste privée. C\'est toi qui décides de la '
          'partager sur le fil du club, comme une publication.',
      [
        'Rien n\'est publié sans ton accord',
        'Tu peux retirer une séance partagée à tout moment',
        'Tes mesures (poids, taille, IMC) ne sont jamais partagées',
      ],
    ),
    (
      Icons.edit_note,
      'Crée tes propres workouts',
      'Compose tes séances avec les exercices de la bibliothèque : séries, '
          'répétitions, repos. Tes workouts personnels ne sont visibles que '
          'par toi.',
      [
        'Plus de 50 exercices avec vidéos',
        'Lance-les dans le lecteur de séance',
        'Suis tes records automatiquement',
      ],
    ),
    (
      Icons.groups_outlined,
      'La communauté de la salle',
      'Découvre les membres qui ont choisi d\'être visibles : leur photo, '
          'leurs séances partagées et, s\'ils le souhaitent, leurs réseaux '
          '(Instagram, Facebook, LinkedIn, Snapchat, e-mail).',
      [
        'Ton profil est masqué tant que tu ne l\'actives pas',
        'Les mineurs ne sont jamais visibles',
        'Un profil inapproprié peut être signalé à la salle',
      ],
    ),
    (
      Icons.verified_user_outlined,
      'Tes données, tes droits',
      'Tu peux à tout moment télécharger tes données, modifier tes choix ou '
          'supprimer ton compte depuis Paramètres → Confidentialité.',
      [
        'Mot de passe chiffré, jamais visible, même par la salle',
        'Pas de publicité, pas de revente de données',
        'Aucune localisation ni accès à tes contacts',
      ],
    ),
  ];

  int get _count => _slides.length + 1;

  @override
  void dispose() {
    _pager.dispose();
    _bounce.dispose();
    super.dispose();
  }

  void _skip() => _pager.animateToPage(
    _count - 1,
    duration: const Duration(milliseconds: 500),
    curve: kCurve,
  );

  bool _moving = false;

  /// Ordinateur : molette et flèches du clavier passent d'une page à l'autre.
  Future<void> _step(int delta) async {
    final target = (_page + delta).clamp(0, _count - 1);
    if (_moving || target == _page) return;
    _moving = true;
    await _pager.animateToPage(
      target,
      duration: const Duration(milliseconds: 450),
      curve: kCurve,
    );
    _moving = false;
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _count - 1;
    final wide = isWide(context);
    final pager = PageView.builder(
      controller: _pager,
      scrollDirection: Axis.vertical,
      // Ordinateur : la molette fait défiler page par page (voir _step).
      physics: wide ? const NeverScrollableScrollPhysics() : null,
      itemCount: _count,
      onPageChanged: (i) => setState(() => _page = i),
      itemBuilder: (_, i) => i < _slides.length
          ? _Slide(data: _slides[i], index: i)
          : const _ChoicesPage(),
    );
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Stack(
          children: [
            if (!wide)
              pager
            else
              CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                      _step(1),
                  const SingleActivator(LogicalKeyboardKey.pageDown): () =>
                      _step(1),
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                      _step(-1),
                  const SingleActivator(LogicalKeyboardKey.pageUp): () =>
                      _step(-1),
                },
                child: Focus(
                  autofocus: true,
                  child: Listener(
                    // La dernière page (formulaire) défile elle-même ;
                    // on y remonte avec la flèche ↑.
                    onPointerSignal: (e) {
                      if (e is! PointerScrollEvent || last) return;
                      if (e.scrollDelta.dy > 0) _step(1);
                      if (e.scrollDelta.dy < 0) _step(-1);
                    },
                    child: pager,
                  ),
                ),
              ),
            // Indicateurs verticaux.
            Positioned(
              right: Gap.m,
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _count; i++)
                    AnimatedContainer(
                      duration: kAnim,
                      curve: kCurve,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      width: 8,
                      height: i == _page ? 26 : 8,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? AppColors.gold
                            : AppColors.navyMuted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
            if (!last)
              Positioned(
                top: Gap.s,
                right: Gap.s,
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.white),
                  onPressed: _skip,
                  child: const Text('Passer'),
                ),
              ),
            if (!last)
              Positioned(
                left: 0,
                right: 0,
                bottom: Gap.m,
                child: AnimatedBuilder(
                  animation: _bounce,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, -8 * _bounce.value),
                    child: child,
                  ),
                  child: Center(
                    child: TextButton(
                      key: const Key('intro_next'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.cream,
                      ),
                      onPressed: () => _step(1),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            wide
                                ? Icons.keyboard_double_arrow_down
                                : Icons.keyboard_double_arrow_up,
                            color: AppColors.gold,
                            size: 32,
                          ),
                          Text(
                            wide
                                ? 'Suivant · molette ou flèche ↓'
                                : 'Glisse vers le haut',
                            style: AppText.label(color: AppColors.cream),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.data, required this.index});
  final (IconData, String, String, List<String>) data;
  final int index;

  @override
  Widget build(BuildContext context) {
    final (icon, title, text, points) = data;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gap.l, Gap.xl, 48, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeSlideIn(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: index.isEven ? AppColors.red : AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 44,
                    color: index.isEven ? AppColors.white : AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(height: Gap.l),
              Text(
                title,
                style: AppText.display(color: AppColors.white, size: 30),
              ),
              const SizedBox(height: Gap.m),
              Text(text, style: AppText.body(color: AppColors.cream, size: 16)),
              const SizedBox(height: Gap.l),
              for (var i = 0; i < points.length; i++)
                FadeSlideIn(
                  index: i + 1,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Gap.s),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.gold,
                          size: 20,
                        ),
                        const SizedBox(width: Gap.s),
                        Expanded(
                          child: Text(
                            points[i],
                            style: AppText.body(color: AppColors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dernière page : consentements explicites (aucun pré-coché).
class _ChoicesPage extends StatefulWidget {
  const _ChoicesPage();

  @override
  State<_ChoicesPage> createState() => _ChoicesPageState();
}

class _ChoicesPageState extends State<_ChoicesPage> {
  late final _user = Backend.I.auth.currentUser!;
  late bool _terms = Backend.I.privacy.hasAcceptedTerms(_user);
  late bool _visible = _user.privacy.profileVisible;
  late bool _social = _user.privacy.showSocialLinks;
  late bool _askShare = _user.privacy.askToShareSessions;
  late bool _clubFeed = _user.privacy.showClubFeed;
  bool _saving = false;

  Future<void> _finish() async {
    final b = Backend.I;
    if (!_terms) {
      showSnack(
        context,
        'Acceptez les conditions et la politique de confidentialité pour continuer.',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    final ok = await runAction(context, () async {
      if (!b.privacy.hasAcceptedTerms(b.auth.currentUser!)) {
        await b.privacy.recordConsent(ConsentType.terms, true);
      }
      await b.privacy.updateSettings(
        b.auth.currentUser!.privacy.copyWith(
          profileVisible: _visible,
          showSocialLinks: _social,
          askToShareSessions: _askShare,
          showClubFeed: _clubFeed,
        ),
      );
      await b.privacy.completeIntro();
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      // Relu depuis le menu : on revient simplement en arrière.
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, Routes.home, (_) => false);
      }
    }
  }

  Widget _switch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool>? onChanged,
  ) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(title, style: AppText.subtitle(size: 15)),
      subtitle: Text(subtitle, style: AppText.label(size: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final minor = !_user.isAdult;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gap.m, Gap.xl, 40, Gap.l),
          child: GfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Tes choix', style: AppText.title(size: 22)),
                const SizedBox(height: 4),
                Text(
                  'Tout est désactivé par défaut. Tu peux changer d\'avis à tout '
                  'moment dans Paramètres → Confidentialité.',
                  style: AppText.body(size: 14, color: AppColors.inkSoft),
                ),
                const SizedBox(height: Gap.m),
                CheckboxListTile(
                  key: const Key('intro_terms'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _terms,
                  onChanged: (v) => setState(() => _terms = v ?? false),
                  title: Text(
                    'J\'accepte les conditions d\'utilisation et la politique '
                    'de confidentialité (version ${Legal.version})',
                    style: AppText.body(size: 14),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pushNamed(context, Routes.legal),
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('Lire les documents'),
                  ),
                ),
                const Divider(),
                if (minor)
                  const InfoRow(
                    Icons.shield_outlined,
                    'Compte mineur : le profil ne peut pas être rendu visible.',
                  )
                else ...[
                  _switch(
                    'Rendre mon profil visible',
                    'Les autres membres voient ta photo, ton prénom et ton nom, '
                        'ton objectif et tes séances partagées.',
                    _visible,
                    (v) => setState(() {
                      _visible = v;
                      if (!v) _social = false;
                    }),
                  ),
                  _switch(
                    'Afficher mes réseaux sociaux',
                    'Uniquement ceux que tu renseignes dans Confidentialité.',
                    _social,
                    _visible ? (v) => setState(() => _social = v) : null,
                  ),
                ],
                _switch(
                  'Me proposer de partager mes séances',
                  'Après chaque séance, une question : partager ou garder privé.',
                  _askShare,
                  (v) => setState(() => _askShare = v),
                ),
                _switch(
                  'Voir l\'activité du club sur mon accueil',
                  'Affichage seulement : ne publie rien.',
                  _clubFeed,
                  (v) => setState(() => _clubFeed = v),
                ),
                const SizedBox(height: Gap.m),
                LoadingButton(
                  key: const Key('intro_start'),
                  label: 'C\'est parti !',
                  icon: Icons.rocket_launch_outlined,
                  loading: _saving,
                  onPressed: _finish,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
