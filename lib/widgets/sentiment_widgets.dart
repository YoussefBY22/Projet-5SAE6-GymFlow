import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/course.dart';
import '../models/sentiment.dart';
import '../models/user.dart';
import '../services/backend.dart';
import '../services/dashboard_service.dart';
import 'animations.dart';
import 'bits.dart';
import 'charts.dart';
import 'common.dart';

/// Couleurs des tons, prises dans la palette (contraste AA testé) :
/// positif marine, neutre or, négatif rouge.
Color sentimentColor(SentimentTone tone) => switch (tone) {
  SentimentTone.positive => AppColors.navy,
  SentimentTone.neutral => AppColors.gold,
  SentimentTone.negative => AppColors.red,
};

/// Texte de l'infobulle d'un badge : modèle IA, ou raison du repli local
/// (jamais de clé). Visible aussi en release.
String sentimentDetail(SentimentResult r) {
  if (r.source == SentimentSource.ia) {
    final model = r.provider == null ? '' : ' ${r.provider!.label}';
    return 'Analyse IA$model (confiance ${(r.score * 100).round()} %)';
  }
  final why = r.fallbackReason;
  return why == null || why.isEmpty
      ? 'Analyse locale par mots-clés'
      : 'Analyse locale par mots-clés. IA indisponible : $why';
}

/// Pastille 😊 / 😐 / 😞 d'un avis, avec l'origine de l'analyse.
/// Un appui (ou le survol) affiche le détail.
class SentimentBadge extends StatelessWidget {
  const SentimentBadge(this.result, {super.key});

  final SentimentResult result;

  @override
  Widget build(BuildContext context) {
    final tone = result.tone;
    final bg = sentimentColor(tone);
    final fg = onColor(bg);
    final ia = result.source == SentimentSource.ia;
    final detail = sentimentDetail(result);
    return Tooltip(
      message: detail,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 6),
      child: Semantics(
        label: 'Ton de l\'avis : ${tone.label}. $detail.',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tone.emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(
                '${tone.label} · ${ia ? 'IA' : 'local'}',
                style: AppText.label(
                  color: fg,
                  size: 12,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              if (!ia && (result.fallbackReason?.isNotEmpty ?? false)) ...[
                const SizedBox(width: 4),
                Icon(Icons.info_outline, size: 14, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ton de l'avis d'une réservation, toujours à jour (relu à chaque
/// changement de données) : « analyse en cours », badge, et bouton
/// « Réanalyser avec l'IA » pour un avis analysé localement (auteur,
/// coach du cours, admin).
class ReviewSentiment extends StatelessWidget {
  const ReviewSentiment(this.reservation, {super.key});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return ListenableBuilder(
      listenable: b.bus,
      builder: (context, _) {
        final r = b.reservations.byId(reservation.id) ?? reservation;
        final hasComment = r.comment?.trim().isNotEmpty ?? false;
        if (!hasComment) return const SizedBox.shrink();
        if (b.sentiment.isPending(r.id)) {
          return const Pill('Analyse du ton…', icon: Icons.auto_awesome);
        }
        final s = r.sentiment;
        if (s == null) return const SizedBox.shrink();
        return Wrap(
          spacing: Gap.s,
          runSpacing: Gap.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SentimentBadge(s),
            if (b.sentiment.canReanalyze(r))
              TextButton.icon(
                key: ValueKey('reanalyze_${r.id}'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 36),
                  padding: const EdgeInsets.symmetric(horizontal: Gap.s),
                ),
                onPressed: () => _reanalyze(context, r.id),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Réanalyser avec l\'IA'),
              ),
          ],
        );
      },
    );
  }

  static Future<void> _reanalyze(BuildContext context, String id) async {
    final b = Backend.I;
    SentimentResult? result;
    final ok = await runAction(
      context,
      () async => result = await b.sentiment.reanalyze(id),
    );
    if (!ok || !context.mounted || result == null) return;
    final r = result!;
    showSnack(
      context,
      r.source == SentimentSource.ia
          ? 'Analyse IA : ${r.tone.label}.'
          : 'IA toujours indisponible : ${r.fallbackReason ?? 'raison inconnue'}.',
      error: r.source != SentimentSource.ia,
    );
  }
}

/// Avis (étoiles, commentaire, ton) dans une liste du staff.
class ReviewTile extends StatelessWidget {
  const ReviewTile(this.reservation, {super.key, this.title});

  final Reservation reservation;

  /// Titre affiché à côté de l'avatar (cours ou auteur).
  final String? title;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final r = reservation;
    final comment = r.comment?.trim() ?? '';
    return GfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GfAvatar(b.users.byId(r.userId), radius: 16),
              const SizedBox(width: Gap.s),
              Expanded(
                child: Text(
                  title ?? b.users.byId(r.userId)?.fullName ?? 'Ancien membre',
                  style: AppText.subtitle(size: 13),
                ),
              ),
              if (r.rating != null)
                RatingStars(value: r.rating!.toDouble(), size: 14),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('« $comment »', style: AppText.body(size: 13)),
            const SizedBox(height: Gap.xs),
            ReviewSentiment(r),
          ],
        ],
      ),
    );
  }
}

/// « Score de satisfaction IA » : part d'avis positifs, répartition et
/// histogramme par cours ; par coach pour l'administrateur.
///
/// Le panneau écoute lui-même le bus de données : il est recalculé à
/// chaque changement (nouvel avis, analyse terminée en arrière-plan),
/// même placé en `const` dans un écran. Bouton « Actualiser » en plus.
class SatisfactionPanel extends StatefulWidget {
  const SatisfactionPanel({super.key, this.showCoaches = false});

  final bool showCoaches;

  @override
  State<SatisfactionPanel> createState() => _SatisfactionPanelState();
}

class _SatisfactionPanelState extends State<SatisfactionPanel> {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Backend.I.bus,
    builder: (context, _) => _content(context),
  );

  void _refresh() {
    setState(() {});
    showSnack(context, 'Score de satisfaction actualisé.');
  }

  Widget _refreshButton() => Align(
    alignment: Alignment.centerRight,
    child: TextButton.icon(
      key: const ValueKey('satisfaction_refresh'),
      onPressed: _refresh,
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Actualiser'),
    ),
  );

  Widget _content(BuildContext context) {
    final d = Backend.I.dashboard;
    final overall = d.satisfaction();
    if (overall.total == 0) {
      return GfCard(
        child: Column(
          children: [
            const InfoRow(
              Icons.auto_awesome,
              'Pas encore d\'avis commenté à analyser.',
            ),
            _refreshButton(),
          ],
        ),
      );
    }
    final byCourse = d.satisfactionByCourse();
    final byCoach = widget.showCoaches
        ? d.satisfactionByCoach()
        : const <(AppUser, SatisfactionStat)>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _refreshButton(),
              Row(
                children: [
                  Text(
                    '${(overall.rate * 100).round()} %',
                    style: AppText.display(size: 30),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: Text(
                      'd\'avis positifs sur ${overall.total} avis analysés',
                      style: AppText.label(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.s),
              Wrap(
                spacing: Gap.s,
                runSpacing: Gap.xs,
                children: [
                  _count(SentimentTone.positive, overall.positive),
                  _count(SentimentTone.neutral, overall.neutral),
                  _count(SentimentTone.negative, overall.negative),
                ],
              ),
              const SizedBox(height: Gap.m),
              Text(
                'Par cours (${byCourse.length})',
                style: AppText.subtitle(size: 14),
              ),
              if (byCourse.length > _maxBars)
                Text(
                  'Graphique : les $_maxBars cours les plus commentés ; '
                  'liste complète dessous.',
                  style: AppText.label(size: 12),
                ),
              const SizedBox(height: Gap.s),
              GfBarChart(
                height: 180,
                bars: [
                  for (final (c, s) in byCourse.take(_maxBars))
                    (_short(c.title), s.rate * 100),
                ],
                valueLabel: (v) => '${v.round()} %',
              ),
              const SizedBox(height: Gap.xs),
              for (final (c, s) in byCourse)
                Text(
                  '${c.title} · ${c.startAt == null ? '' : '${Fmt.dayShort(c.startAt!)} · '}'
                  '${(s.rate * 100).round()} % (${s.total} avis)',
                  style: AppText.label(size: 12),
                ),
            ],
          ),
        ),
        if (byCoach.isNotEmpty) ...[
          const SizedBox(height: Gap.s),
          GfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Par coach', style: AppText.subtitle(size: 14)),
                for (final (coach, s) in byCoach)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(
                            '${coach.fullName}\n${s.total} avis',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.label(size: 12),
                          ),
                        ),
                        Expanded(
                          child: AnimatedBar(
                            value: s.rate,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(width: Gap.s),
                        SizedBox(
                          width: 44,
                          child: Text(
                            '${(s.rate * 100).round()} %',
                            textAlign: TextAlign.right,
                            style: AppText.subtitle(size: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static const _maxBars = 8;

  static String _short(String title) =>
      title.length <= 9 ? title : '${title.substring(0, 8)}…';

  Widget _count(SentimentTone tone, int n) {
    final bg = sentimentColor(tone);
    return Pill('${tone.emoji} ${tone.label} : $n', color: bg);
  }
}
