import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import '../../models/content.dart';
import '../../services/backend.dart';
import '../../widgets/animations.dart';
import '../../widgets/auto_banner.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../shell/main_shell.dart';

/// Accueil abonné façon Strava : salutation, bannière des nouveautés,
/// objectif hebdo + série, prochain cours, programme, communauté, fil
/// d'activités (celle des autres peut être masquée), cours conseillés et
/// produits à la une.
///
/// Téléphone : une colonne. Ordinateur : deux colonnes (mon entraînement à
/// gauche, communauté et fil à droite) dans une largeur maximale lisible.
class MemberHomeScreen extends StatelessWidget {
  const MemberHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return Scaffold(
      appBar: AppBar(
        leading: const ShellMenuButton(),
        title: const Text('GymFlow'),
        actions: [
          IconButton(
            tooltip: 'Rechercher',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(context, Routes.search),
          ),
          const NotificationBell(),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([b.bus, b.auth]),
        builder: (context, _) {
          final user = b.auth.currentUser;
          if (user == null) return const SizedBox.shrink();
          return _HomeBody(user: user);
        },
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.user});
  final AppUser user;

  String _greeting(DateTime now) {
    if (now.hour < 12) return 'Bonjour';
    if (now.hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  static const _maxWidth = 1240.0;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final now = b.now();
    final wide = isWide(context);
    var i = 0;

    final greeting = Padding(
      padding: const EdgeInsets.fromLTRB(Gap.m, Gap.m, Gap.m, Gap.s),
      child: Row(
        children: [
          GfAvatar(user, radius: wide ? 30 : 24),
          const SizedBox(width: Gap.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting(now)}, ${user.firstName} !',
                  style: AppText.title(size: wide ? 26 : 22),
                ),
                Text(Fmt.day(now), style: AppText.label()),
              ],
            ),
          ),
        ],
      ),
    );

    final training = <Widget>[
      FadeSlideIn(
        index: i++,
        child: AutoBanner(items: b.announcements.bannerItems()),
      ),
      const SizedBox(height: Gap.m),
      FadeSlideIn(
        index: i++,
        child: _WeekCard(user: user, now: now),
      ),
      const SectionHeader('Mon prochain cours'),
      FadeSlideIn(
        index: i++,
        child: _NextCourse(user: user),
      ),
      const SectionHeader('Mon entraînement'),
      FadeSlideIn(
        index: i++,
        child: _ProgramCard(user: user, now: now),
      ),
    ];

    final community = <Widget>[
      if (wide) const SizedBox(height: Gap.s),
      FadeSlideIn(
        index: i++,
        child: _CommunityCard(user: user),
      ),
      _ClubFeed(user: user, startIndex: i),
    ];

    final suggestions = b.courseService
        .list()
        .where((c) => b.reservationService.activeFor(c.id, user.id) == null)
        .take(4)
        .toList();
    final courses = <Widget>[
      SectionHeader(
        'Cours conseillés',
        action: 'Tous les cours',
        onAction: () => MainShell.tab.value = 2,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.m),
        child: ResponsiveWrapGrid(
          minTileWidth: 340,
          spacing: Gap.s,
          children: [
            for (final c in suggestions) CourseCard(course: c, compact: true),
          ],
        ),
      ),
    ];

    final featured = b.productService.featured().take(8).toList();
    final shop = <Widget>[
      SectionHeader(
        'À la une en boutique',
        action: 'Boutique',
        onAction: () => MainShell.tab.value = 3,
      ),
      SizedBox(
        height: 250,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Gap.m),
          itemCount: featured.length,
          separatorBuilder: (_, _) => const SizedBox(width: Gap.s),
          itemBuilder: (_, k) =>
              SizedBox(width: 165, child: ProductCard(product: featured[k])),
        ),
      ),
    ];

    final Widget content;
    if (!wide) {
      content = ListView(
        padding: const EdgeInsets.only(bottom: Gap.xl),
        children: [
          greeting,
          ...training,
          const SizedBox(height: Gap.s),
          ...community,
          ...courses,
          ...shop,
        ],
      );
    } else {
      final side = math.max(0.0, (screenWidth(context) - _maxWidth) / 2);
      content = ListView(
        padding: EdgeInsets.fromLTRB(side, Gap.s, side, Gap.xl),
        children: [
          greeting,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [...training, ...courses],
                ),
              ),
              Expanded(
                flex: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: community,
                ),
              ),
            ],
          ),
          ...shop,
        ],
      );
    }
    return RefreshIndicator(
      color: AppColors.red,
      onRefresh: () async => b.bus.emit(),
      child: content,
    );
  }
}

/// Anneau de l'objectif hebdomadaire + série + jours actifs.
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.user, required this.now});
  final AppUser user;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final week = b.progress.sessionsThisWeek(user.id);
    final streak = b.progress.streakDays(user.id);
    final activeDays = b.progress.activeWeekdays(user.id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.m),
      child: GfCard(
        onTap: () => Navigator.pushNamed(context, Routes.progress),
        child: Row(
          children: [
            ProgressRing(
              progress: user.weeklyGoal == 0 ? 0 : week / user.weeklyGoal,
              size: 96,
              stroke: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedCounter(
                    value: week.toDouble(),
                    style: AppText.display(size: 26),
                  ),
                  Text(
                    'sur ${user.weeklyGoal}',
                    style: AppText.label(size: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cette semaine', style: AppText.subtitle()),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: AppColors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          streak == 0
                              ? 'Lancez votre série !'
                              : 'Série de $streak jour${streak > 1 ? 's' : ''}',
                          style: AppText.subtitle(
                            size: 14,
                            color: AppColors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.s),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Row(
                      children: [
                        for (var d = 1; d <= 7; d++)
                          Expanded(
                            child: Column(
                              children: [
                                AnimatedContainer(
                                  duration: kAnim,
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: activeDays.contains(d)
                                        ? AppColors.red
                                        : AppColors.white,
                                    border: Border.all(
                                      color: d == now.weekday
                                          ? AppColors.navy
                                          : AppColors.outline,
                                      width: d == now.weekday ? 2 : 1,
                                    ),
                                  ),
                                  child: activeDays.contains(d)
                                      ? const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: AppColors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  const ['L', 'M', 'M', 'J', 'V', 'S', 'D'][d -
                                      1],
                                  style: AppText.label(size: 11),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextCourse extends StatelessWidget {
  const _NextCourse({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final next = Backend.I.reservationService.nextBooking(user.id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.m),
      child: next == null
          ? const _CtaCard(
              icon: Icons.event_available,
              title: 'Aucun cours réservé',
              text: 'Yoga, HIIT, spinning… réservez en un geste.',
              tab: 2,
            )
          : CourseCard(course: next.$2),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.user, required this.now});
  final AppUser user;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final program = Backend.I.workoutService.nextProgramWorkout(user);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.m),
      child: program == null
          ? const _CtaCard(
              icon: Icons.flag_outlined,
              title: 'Choisissez un programme',
              text:
                  'Full Body débutant, PPL, mobilité… ou créez votre propre workout.',
              tab: 1,
            )
          : CoverCard(
              image: program.$2.coverImage,
              title:
                  'Reprendre : ${program.$2.nameIn(Backend.I.library.contentLang)}',
              subtitle:
                  '${program.$1.nameIn(Backend.I.library.contentLang)} · ${program.$3 == now.weekday ? 'aujourd\'hui' : 'prochaine séance'}',
              pills: const [
                Pill('Mon programme', color: AppColors.red, icon: Icons.flag),
              ],
              topRight: Padding(
                padding: const EdgeInsets.all(Gap.s),
                child: IconButton.filled(
                  tooltip: 'Lancer la séance',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: AppColors.white,
                  ),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    Routes.player,
                    arguments: program.$2.id,
                  ),
                  icon: const Icon(Icons.play_arrow),
                ),
              ),
              onTap: () => Navigator.pushNamed(
                context,
                Routes.workout,
                arguments: program.$2.id,
              ),
            ),
    );
  }
}

class _CtaCard extends StatelessWidget {
  const _CtaCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.tab,
  });
  final IconData icon;
  final String title;
  final String text;
  final int tab;

  @override
  Widget build(BuildContext context) {
    return GfCard(
      color: AppColors.cream,
      onTap: () => MainShell.tab.value = tab,
      child: Row(
        children: [
          Icon(icon, color: AppColors.navy, size: 32),
          const SizedBox(width: Gap.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.subtitle()),
                Text(text, style: AppText.label()),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.navy),
        ],
      ),
    );
  }
}

/// Accès à l'annuaire des membres visibles + état de ma propre visibilité.
class _CommunityCard extends StatelessWidget {
  const _CommunityCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final count = b.community.visibleCount();
    final visible = user.privacy.isPubliclyVisible;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.m),
      child: GfCard(
        key: const Key('community_card'),
        onTap: () => Navigator.pushNamed(context, Routes.community),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.navy,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.groups, color: AppColors.white),
            ),
            const SizedBox(width: Gap.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Membres de la salle', style: AppText.subtitle()),
                  Text(
                    '$count membre${count > 1 ? 's' : ''} visible${count > 1 ? 's' : ''}',
                    style: AppText.label(),
                  ),
                  const SizedBox(height: 4),
                  Pill(
                    visible ? 'Mon profil : visible' : 'Mon profil : privé',
                    color: visible ? AppColors.success : AppColors.navy,
                    icon: visible ? Icons.visibility : Icons.lock_outline,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.navy),
          ],
        ),
      ),
    );
  }
}

/// Fil d'activité : mes séances + celles que les autres ont choisi de
/// partager. L'activité des autres se masque d'un geste (préférence
/// enregistrée dans les paramètres de confidentialité).
class _ClubFeed extends StatelessWidget {
  const _ClubFeed({required this.user, required this.startIndex});
  final AppUser user;
  final int startIndex;

  Future<void> _toggle(BuildContext context, bool show) async {
    try {
      await Backend.I.privacy.updateSettings(
        user.privacy.copyWith(showClubFeed: show),
      );
      if (context.mounted) {
        showSnack(
          context,
          show
              ? 'Activité des autres membres affichée.'
              : 'Activité des autres membres masquée. Réactivable ici ou dans Confidentialité.',
        );
      }
    } catch (e) {
      if (context.mounted) showSnack(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final showOthers = user.privacy.showClubFeed;
    final feed = b.trainingLog.feed(limit: 12, includeOthers: showOthers);
    var i = startIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.m, Gap.l, Gap.xs, Gap.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  showOthers ? 'Fil du club' : 'Mes séances',
                  style: AppText.title(size: 18),
                ),
              ),
              TextButton.icon(
                key: const Key('feed_toggle'),
                onPressed: () => _toggle(context, !showOthers),
                icon: Icon(
                  showOthers
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                ),
                label: Text(
                  showOthers ? 'Masquer les autres' : 'Voir les autres',
                ),
              ),
            ],
          ),
        ),
        if (!showOthers)
          const Padding(
            padding: EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.s),
            child: InfoRow(
              Icons.visibility_off_outlined,
              'L\'activité des autres membres est masquée.',
            ),
          ),
        if (feed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.m),
            child: GfCard(
              child: InfoRow(
                Icons.dynamic_feed,
                showOthers
                    ? 'Aucune activité partagée pour le moment.'
                    : 'Aucune séance pour le moment. Lancez un workout !',
              ),
            ),
          )
        else
          for (final s in feed.take(6))
            FadeSlideIn(
              index: i++,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.s),
                child: ActivityCard(session: s),
              ),
            ),
      ],
    );
  }
}
