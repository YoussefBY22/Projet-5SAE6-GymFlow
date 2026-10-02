import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../core/formatters.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../services/backend.dart';
import '../../widgets/animations.dart';
import '../../widgets/bits.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../shell/main_shell.dart';

/// Dashboard coach : prochains cours, inscrits, présence, notes,
/// contenus créés et fil du club.
class CoachHomeScreen extends StatelessWidget {
  const CoachHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return Scaffold(
      appBar: AppBar(
        leading: const ShellMenuButton(),
        title: const Text('Espace coach'),
        actions: const [NotificationBell()],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([b.bus, b.auth]),
        builder: (context, _) {
          final me = b.auth.currentUser!;
          final stats = b.dashboard.coachStats();
          return ListView(
            padding: pagePadding(context, bottom: Gap.m),
            children: [
              Text('Bonjour ${me.firstName} !', style: AppText.title(size: 22)),
              Text(me.specialty ?? 'Coach GymFlow', style: AppText.label()),
              const SizedBox(height: Gap.m),
              GridView.count(
                crossAxisCount: isWide(context) ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: Gap.s,
                crossAxisSpacing: Gap.s,
                childAspectRatio: 1.45,
                children: [
                  _KpiCard(
                    icon: Icons.event,
                    value: stats.upcoming.length.toDouble(),
                    label: 'Cours à venir',
                    color: AppColors.navy,
                  ),
                  _KpiCard(
                    icon: Icons.groups,
                    value: stats.enrolled.toDouble(),
                    label: 'Inscrits',
                    color: AppColors.red,
                  ),
                  _KpiCard(
                    icon: Icons.fact_check,
                    value: stats.attendanceRate * 100,
                    label: 'Taux de présence',
                    format: (v) => '${v.round()} %',
                    color: AppColors.success,
                  ),
                  _KpiCard(
                    icon: Icons.star,
                    value: stats.averageRating ?? 0,
                    label: '${stats.ratingsCount} notes reçues',
                    format: (v) =>
                        stats.averageRating == null ? '—' : '${Fmt.dec1(v)}/5',
                    color: AppColors.navy,
                  ),
                ],
              ),
              SectionHeader(
                'Mes prochains cours',
                action: 'Planning',
                onAction: () => MainShell.tab.value = 2,
              ),
              if (stats.upcoming.isEmpty)
                GfCard(
                  color: AppColors.cream,
                  onTap: () => Navigator.pushNamed(context, Routes.courseForm),
                  child: const InfoRow(
                    Icons.add,
                    'Aucun cours programmé : créez-en un.',
                  ),
                )
              else
                for (var i = 0; i < stats.upcoming.length && i < 5; i++)
                  FadeSlideIn(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: Gap.s),
                      child: GfCard(
                        onTap: () => Navigator.pushNamed(
                          context,
                          Routes.attendance,
                          arguments: stats.upcoming[i].id,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              stats.upcoming[i].category.icon,
                              color: AppColors.red,
                            ),
                            const SizedBox(width: Gap.s),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stats.upcoming[i].title,
                                    style: AppText.subtitle(size: 14),
                                  ),
                                  Text(
                                    Fmt.dateTime(stats.upcoming[i].startAt!),
                                    style: AppText.label(size: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  AnimatedBar(
                                    value: b.courseService.fillRate(
                                      stats.upcoming[i],
                                    ),
                                    height: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: Gap.s),
                            Pill(
                              '${b.courseService.confirmedCount(stats.upcoming[i].id)}/${stats.upcoming[i].capacity}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              const SectionHeader('Mes contenus'),
              Row(
                children: [
                  Expanded(
                    child: GfCard(
                      onTap: () => MainShell.tab.value = 1,
                      child: StatTile(
                        value: '${stats.exercises}',
                        label: 'Exercices créés',
                        icon: Icons.fitness_center,
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: GfCard(
                      onTap: () => MainShell.tab.value = 1,
                      child: StatTile(
                        value: '${stats.workouts}',
                        label: 'Workouts',
                        icon: Icons.list_alt,
                      ),
                    ),
                  ),
                ],
              ),
              const SectionHeader('Dernières notes'),
              ..._latestRatings(b, me.id),
              const SectionHeader('Fil du club'),
              for (final s in b.trainingLog.feed(limit: 4))
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.s),
                  child: ActivityCard(session: s),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _latestRatings(Backend b, String coachId) {
    final mine = b.courses.all
        .where((c) => c.coachId == coachId)
        .map((c) => c.id)
        .toSet();
    final rated = b.reservations.where(
      (r) => mine.contains(r.courseId) && r.rating != null,
    )..sort((a, c) => c.createdAt.compareTo(a.createdAt));
    if (rated.isEmpty) {
      return [
        const GfCard(child: InfoRow(Icons.star_border, 'Pas encore de note.')),
      ];
    }
    return [
      for (final r in rated.take(3))
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.s),
          child: GfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GfAvatar(b.users.byId(r.userId), radius: 16),
                    const SizedBox(width: Gap.s),
                    Expanded(
                      child: Text(
                        b.courses.byId(r.courseId)?.title ?? '',
                        style: AppText.subtitle(size: 13),
                      ),
                    ),
                    RatingStars(value: r.rating!.toDouble(), size: 14),
                  ],
                ),
                if (r.comment != null && r.comment!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('« ${r.comment} »', style: AppText.body(size: 13)),
                ],
              ],
            ),
          ),
        ),
    ];
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.format,
  });

  final IconData icon;
  final double value;
  final String label;
  final Color color;
  final String Function(double)? format;

  @override
  Widget build(BuildContext context) {
    return GfCard(
      padding: const EdgeInsets.all(Gap.s + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color),
          AnimatedCounter(
            value: value,
            format: format,
            style: AppText.display(color: color, size: 26),
          ),
          Text(
            label,
            style: AppText.label(size: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Carte KPI réutilisée par le dashboard admin.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = AppColors.navy,
    this.format,
    this.onTap,
  });

  final IconData icon;
  final double value;
  final String label;
  final Color color;
  final String Function(double)? format;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: _KpiCard(
      icon: icon,
      value: value,
      label: label,
      color: color,
      format: format,
    ),
  );
}
