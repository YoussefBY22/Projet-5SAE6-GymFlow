import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../services/backend.dart';
import '../../widgets/animations.dart';
import '../../widgets/auto_banner.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../shell/main_shell.dart';

/// Accueil abonné façon Strava : salutation, bannière des nouveautés,
/// objectif hebdo + série, prochain cours, programme, fil d'activités,
/// cours conseillés et produits à la une.
class MemberHomeScreen extends StatelessWidget {
  const MemberHomeScreen({super.key});

  String _greeting(DateTime now) {
    if (now.hour < 12) return 'Bonjour';
    if (now.hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

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
          final now = b.now();
          final week = b.progress.sessionsThisWeek(user.id);
          final streak = b.progress.streakDays(user.id);
          final activeDays = b.progress.activeWeekdays(user.id);
          final next = b.reservationService.nextBooking(user.id);
          final program = b.workoutService.nextProgramWorkout(user);
          final feed = b.trainingLog.feed(limit: 12);
          final banner = b.announcements.bannerItems();
          final suggestions = b.courseService
              .list()
              .where(
                (c) => b.reservationService.activeFor(c.id, user.id) == null,
              )
              .take(4)
              .toList();
          final featured = b.productService.featured().take(6).toList();
          var i = 0;
          return RefreshIndicator(
            color: AppColors.red,
            onRefresh: () async => b.bus.emit(),
            child: ListView(
              padding: const EdgeInsets.only(bottom: Gap.xl),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.m,
                    Gap.m,
                    Gap.m,
                    Gap.s,
                  ),
                  child: Row(
                    children: [
                      GfAvatar(user, radius: 24),
                      const SizedBox(width: Gap.s),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_greeting(now)}, ${user.firstName} !',
                              style: AppText.title(size: 22),
                            ),
                            Text(Fmt.day(now), style: AppText.label()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                FadeSlideIn(
                  index: i++,
                  child: AutoBanner(items: banner),
                ),
                const SizedBox(height: Gap.m),
                FadeSlideIn(
                  index: i++,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.m),
                    child: GfCard(
                      onTap: () =>
                          Navigator.pushNamed(context, Routes.progress),
                      child: Row(
                        children: [
                          ProgressRing(
                            progress: user.weeklyGoal == 0
                                ? 0
                                : week / user.weeklyGoal,
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
                                Text(
                                  'Cette semaine',
                                  style: AppText.subtitle(),
                                ),
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
                                Row(
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
                                                  width: d == now.weekday
                                                      ? 2
                                                      : 1,
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
                                              [
                                                'L',
                                                'M',
                                                'M',
                                                'J',
                                                'V',
                                                'S',
                                                'D',
                                              ][d - 1],
                                              style: AppText.label(size: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SectionHeader('Mon prochain cours'),
                FadeSlideIn(
                  index: i++,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.m),
                    child: next == null
                        ? GfCard(
                            color: AppColors.cream,
                            onTap: () => MainShell.tab.value = 2,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.event_available,
                                  color: AppColors.navy,
                                  size: 32,
                                ),
                                const SizedBox(width: Gap.m),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Aucun cours réservé',
                                        style: AppText.subtitle(),
                                      ),
                                      Text(
                                        'Yoga, HIIT, spinning… réservez en un geste.',
                                        style: AppText.label(),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.navy,
                                ),
                              ],
                            ),
                          )
                        : CourseCard(course: next.$2),
                  ),
                ),
                const SectionHeader('Mon entraînement'),
                FadeSlideIn(
                  index: i++,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.m),
                    child: program == null
                        ? GfCard(
                            color: AppColors.cream,
                            onTap: () => MainShell.tab.value = 1,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.flag_outlined,
                                  color: AppColors.navy,
                                  size: 32,
                                ),
                                const SizedBox(width: Gap.m),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Choisissez un programme',
                                        style: AppText.subtitle(),
                                      ),
                                      Text(
                                        'Full Body débutant, PPL, mobilité… suivez un plan adapté.',
                                        style: AppText.label(),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.navy,
                                ),
                              ],
                            ),
                          )
                        : CoverCard(
                            image: program.$2.coverImage,
                            title: 'Reprendre : ${program.$2.name}',
                            subtitle:
                                '${program.$1.name} · ${program.$3 == now.weekday ? 'aujourd\'hui' : 'prochaine séance'}',
                            pills: const [
                              Pill(
                                'Mon programme',
                                color: AppColors.red,
                                icon: Icons.flag,
                              ),
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
                  ),
                ),
                const SectionHeader('Fil du club'),
                if (feed.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: Gap.m),
                    child: GfCard(
                      child: InfoRow(
                        Icons.dynamic_feed,
                        'Aucune activité pour le moment.',
                      ),
                    ),
                  )
                else
                  for (final s in feed.take(6))
                    FadeSlideIn(
                      index: i++,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Gap.m,
                          0,
                          Gap.m,
                          Gap.s,
                        ),
                        child: ActivityCard(session: s),
                      ),
                    ),
                SectionHeader(
                  'Cours conseillés',
                  action: 'Tous les cours',
                  onAction: () => MainShell.tab.value = 2,
                ),
                for (final c in suggestions)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.s),
                    child: CourseCard(course: c, compact: true),
                  ),
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
                    itemBuilder: (_, k) => SizedBox(
                      width: 165,
                      child: ProductCard(product: featured[k]),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
