import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../models/course.dart';
import '../models/enums.dart';
import '../models/exercise.dart';
import '../models/session_log.dart';
import '../models/shop.dart';
import '../models/workout.dart';
import '../services/backend.dart';
import 'animations.dart';
import 'bits.dart';
import 'common.dart';
import 'media.dart';

/// Couleur associée à un niveau (texte blanc lisible sur chacune).
Color levelColor(Level l) => switch (l) {
  Level.beginner => AppColors.success,
  Level.intermediate => AppColors.navy,
  Level.advanced => AppColors.red,
};

/// Bouton favori animé (cœur).
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.id, this.onDark = false});
  final String id;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return ListenableBuilder(
      listenable: b.auth,
      builder: (context, _) {
        final fav = b.userService.isFavorite(id);
        return IconButton(
          tooltip: fav ? 'Retirer des favoris' : 'Ajouter aux favoris',
          onPressed: () =>
              runAction(context, () => b.userService.toggleFavorite(id)),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Icon(
              fav ? Icons.favorite : Icons.favorite_border,
              key: ValueKey(fav),
              color: fav
                  ? AppColors.red
                  : (onDark ? AppColors.white : AppColors.navy),
            ),
          ),
        );
      },
    );
  }
}

/// Ligne d'exercice (liste de la bibliothèque).
class ExerciseTile extends StatelessWidget {
  const ExerciseTile({
    super.key,
    required this.exercise,
    this.onTap,
    this.trailing,
  });
  final Exercise exercise;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    return GfCard(
      padding: const EdgeInsets.all(Gap.s),
      onTap:
          onTap ??
          () => Navigator.pushNamed(context, Routes.exercise, arguments: e.id),
      child: Row(
        children: [
          Hero(
            tag: 'ex_${e.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: AppColors.white,
                width: 76,
                height: 76,
                child: ExerciseImage(e, cacheWidth: 240),
              ),
            ),
          ),
          const SizedBox(width: Gap.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.subtitle(size: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${e.primaryMuscle.label} · ${e.equipment.label}',
                  style: AppText.label(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Pill(e.level.label, color: levelColor(e.level)),
                    Pill(e.type.label),
                    if (e.mainVideo != null)
                      const Pill('Vidéo', icon: Icons.play_circle_outline),
                  ],
                ),
              ],
            ),
          ),
          trailing ?? FavoriteButton(id: e.id),
        ],
      ),
    );
  }
}

/// Carte avec image de couverture et voile sombre (texte blanc lisible).
class CoverCard extends StatelessWidget {
  const CoverCard({
    super.key,
    required this.image,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.heroTag,
    this.pills = const [],
    this.height = 170,
    this.topRight,
  });

  final String? image;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Object? heroTag;
  final List<Widget> pills;
  final double height;
  final Widget? topRight;

  @override
  Widget build(BuildContext context) {
    final img = NetImage(image, height: height, width: double.infinity);
    return GfCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            heroTag == null ? img : Hero(tag: heroTag!, child: img),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.35, 1],
                  colors: [
                    Color(0x9900101F),
                    Color(0x1A00101F),
                    Color(0xE600101F),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 6, runSpacing: 4, children: pills),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title(color: AppColors.white, size: 19),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label(color: AppColors.cream),
                  ),
                ],
              ),
            ),
            if (topRight != null)
              Positioned(top: 4, right: 4, child: topRight!),
          ],
        ),
      ),
    );
  }
}

class WorkoutCard extends StatelessWidget {
  const WorkoutCard({super.key, required this.workout});
  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final w = workout;
    return CoverCard(
      image: w.coverImage,
      heroTag: 'w_${w.id}',
      title: w.name,
      subtitle:
          '${w.focus} · ${w.items.length} exercices · ~${w.estimatedMinutes} min',
      pills: [
        if (w.isPrivate)
          const Pill('Personnel', color: AppColors.red, icon: Icons.lock),
        Pill(w.level.label, color: levelColor(w.level)),
        Pill(w.goal.label, color: AppColors.gold),
      ],
      topRight: FavoriteButton(id: w.id, onDark: true),
      onTap: () =>
          Navigator.pushNamed(context, Routes.workout, arguments: w.id),
    );
  }
}

class ProgramCard extends StatelessWidget {
  const ProgramCard({super.key, required this.program, this.active = false});
  final Program program;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = program;
    return CoverCard(
      image: p.coverImage,
      heroTag: 'p_${p.id}',
      height: 190,
      title: p.name,
      subtitle:
          '${p.daysPerWeek} j/semaine · ${p.weeks} semaines · ${p.equipment}',
      pills: [
        if (active)
          const Pill('Mon programme', color: AppColors.red, icon: Icons.flag),
        Pill(p.level.label, color: levelColor(p.level)),
        Pill(p.goal.label, color: AppColors.gold),
      ],
      topRight: FavoriteButton(id: p.id, onDark: true),
      onTap: () =>
          Navigator.pushNamed(context, Routes.program, arguments: p.id),
    );
  }
}

/// Carte « cours » (liste des cours, accueil).
class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course, this.compact = false});
  final Course course;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final c = course;
    final status = b.courseService.statusOf(c);
    final coach = b.users.byId(c.coachId);
    final me = b.auth.currentUser;
    final booking = me == null
        ? null
        : b.reservationService.activeFor(c.id, me.id);
    final confirmed = b.courseService.confirmedCount(c.id);
    final full = confirmed >= c.capacity;
    final rating = b.courseService.averageRating(c.id);
    return GfCard(
      padding: EdgeInsets.zero,
      onTap: () =>
          Navigator.pushNamed(context, Routes.courseDetail, arguments: c.id),
      child: Row(
        children: [
          Hero(
            tag: 'c_${c.id}',
            child: NetImage(
              c.imageUrl,
              width: compact ? 88 : 104,
              height: compact ? 104 : 124,
              fallbackIcon: c.category.icon,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(Gap.s + 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(c.category.icon, size: 16, color: AppColors.red),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          c.category.label.toUpperCase(),
                          style: AppText.label(
                            color: AppColors.red,
                            size: 11,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (status == CourseStatus.toPlan)
                        const Pill('Bientôt', color: AppColors.gold),
                      if (status == CourseStatus.done) const Pill('Terminé'),
                      if (status == CourseStatus.cancelled)
                        const Pill('Annulé', color: AppColors.red),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.subtitle(size: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.startAt == null
                        ? 'Date à venir · ${coach?.fullName ?? ''}'
                        : '${Fmt.dateTime(c.startAt!)} · ${c.durationMin} min',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label(),
                  ),
                  if (!compact) ...[
                    Text(
                      '${coach?.fullName ?? 'Coach'} · ${c.room}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label(),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (booking != null)
                        Pill(
                          booking.status == ReservationStatus.confirmed
                              ? 'Réservé'
                              : 'En attente',
                          color: booking.status == ReservationStatus.confirmed
                              ? AppColors.success
                              : AppColors.gold,
                          icon: booking.status == ReservationStatus.confirmed
                              ? Icons.check
                              : Icons.hourglass_top,
                        )
                      else if (status == CourseStatus.scheduled)
                        Pill(
                          full ? 'Complet' : '${c.capacity - confirmed} places',
                          color: full ? AppColors.red : AppColors.cream,
                        ),
                      if (rating != null) RatingStars(value: rating, size: 14),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte produit (grille boutique).
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return GfCard(
      padding: EdgeInsets.zero,
      onTap: () =>
          Navigator.pushNamed(context, Routes.product, arguments: p.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'pr_${p.id}',
                  child: NetImage(
                    p.images.isEmpty ? null : p.images.first,
                    fallbackIcon: p.category.icon,
                    cacheWidth: 500,
                  ),
                ),
                if (!p.inStock)
                  const Positioned(
                    left: 8,
                    top: 8,
                    child: Pill('Rupture', color: AppColors.red),
                  )
                else if (p.onPromo)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Pill(
                      '-${p.discountPercent} %',
                      color: AppColors.gold,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.s + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.subtitle(size: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        Fmt.money(p.effectivePrice),
                        style: AppText.stat(color: AppColors.red, size: 15),
                      ),
                    ),
                    if (p.onPromo) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          Fmt.money(p.price),
                          overflow: TextOverflow.ellipsis,
                          style: AppText.label(
                            size: 11,
                          ).copyWith(decoration: TextDecoration.lineThrough),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte « activité » du fil façon Strava : avatar, titre, stats, Bravo.
class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.session});
  final SessionLog session;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final s = session;
    final user = b.users.byId(s.userId);
    final me = b.auth.currentUser;
    final mine = me?.id == s.userId;
    return GfCard(
      onTap: () =>
          Navigator.pushNamed(context, Routes.sessionDetail, arguments: s.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Le profil de l'auteur ne s'ouvre que s'il l'a rendu visible.
              GestureDetector(
                onTap: !mine && b.community.canOpenProfile(s.userId)
                    ? () => Navigator.pushNamed(
                        context,
                        Routes.member,
                        arguments: s.userId,
                      )
                    : null,
                child: GfAvatar(user, radius: 20),
              ),
              const SizedBox(width: Gap.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mine ? 'Vous' : (user?.fullName ?? 'Membre'),
                      style: AppText.subtitle(size: 14),
                    ),
                    Text(
                      Fmt.relative(s.startedAt, now: b.now()),
                      style: AppText.label(size: 12),
                    ),
                  ],
                ),
              ),
              if (mine)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: s.shared
                      ? const Pill('Partagée', icon: Icons.public)
                      : const Pill('Privée', icon: Icons.lock_outline),
                ),
              if (s.prCount > 0)
                Pill(
                  '${s.prCount} record${s.prCount > 1 ? 's' : ''}',
                  color: AppColors.gold,
                  icon: Icons.emoji_events,
                ),
            ],
          ),
          const SizedBox(height: Gap.s),
          Text(s.title, style: AppText.title(size: 18)),
          const SizedBox(height: Gap.s),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: Fmt.duration(Duration(seconds: s.durationSec)),
                  label: 'Durée',
                ),
              ),
              Expanded(
                child: StatTile(
                  value: '${s.exerciseCount}',
                  label: 'Exercices',
                ),
              ),
              Expanded(
                child: StatTile(value: '${s.totalSets}', label: 'Séries'),
              ),
              Expanded(
                child: StatTile(
                  value: s.totalVolume >= 1000
                      ? '${Fmt.dec1(s.totalVolume / 1000)} t'
                      : '${s.totalVolume.round()} kg',
                  label: 'Volume',
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.s),
          _MiniBars(session: s),
          const Divider(height: Gap.l),
          if (s.shared)
            Row(
              children: [
                KudosButton(session: s, enabled: !mine),
                const SizedBox(width: Gap.s),
                Expanded(
                  child: Text(
                    s.kudos.isEmpty
                        ? (mine
                              ? 'Pas encore de Bravo'
                              : 'Soyez le premier à dire Bravo')
                        : '${s.kudos.length} Bravo',
                    style: AppText.label(),
                  ),
                ),
              ],
            )
          else
            const InfoRow(Icons.lock_outline, 'Visible par vous seul'),
        ],
      ),
    );
  }
}

/// Mini-visuel : volume par exercice sous forme de barres.
class _MiniBars extends StatelessWidget {
  const _MiniBars({required this.session});
  final SessionLog session;

  @override
  Widget build(BuildContext context) {
    final byExercise = <String, double>{};
    for (final s in session.sets) {
      byExercise[s.exerciseId] =
          (byExercise[s.exerciseId] ?? 0) +
          (s.volume > 0 ? s.volume : (s.durationSec ?? s.reps * 10).toDouble());
    }
    if (byExercise.isEmpty) return const SizedBox.shrink();
    final maxV = byExercise.values.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final v in byExercise.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: maxV == 0 ? 0 : v / maxV),
                  duration: const Duration(milliseconds: 600),
                  curve: kCurve,
                  builder: (_, t, _) => FractionallySizedBox(
                    heightFactor: 0.2 + 0.8 * t,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bouton « Bravo » (kudos) avec animation de rebond.
class KudosButton extends StatefulWidget {
  const KudosButton({super.key, required this.session, this.enabled = true});
  final SessionLog session;
  final bool enabled;

  @override
  State<KudosButton> createState() => _KudosButtonState();
}

class _KudosButtonState extends State<KudosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = Backend.I.auth.currentUser;
    final given = me != null && widget.session.kudos.contains(me.id);
    final bg = given ? AppColors.red : AppColors.cream;
    final fg = onColor(bg);
    return ScaleTransition(
      scale: TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 60),
      ]).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut)),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledForegroundColor: AppColors.inkSoft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        onPressed: widget.enabled
            ? () async {
                _c.forward(from: 0);
                await runAction(
                  context,
                  () => Backend.I.trainingLog.toggleKudos(widget.session.id),
                );
              }
            : null,
        icon: Icon(given ? Icons.thumb_up : Icons.thumb_up_outlined, size: 18),
        label: Text(given ? 'Bravo !' : 'Bravo'),
      ),
    );
  }
}
