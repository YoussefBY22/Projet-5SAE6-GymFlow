import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/content.dart';
import '../../services/backend.dart';
import '../../widgets/animations.dart';
import '../../widgets/common.dart';
import '../../widgets/pickers.dart';

/// File de validation (coachs et admin) : contenus proposés par les
/// abonnés, à accepter (publiés pour tous) ou refuser avec un motif.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  static String routeOf(ContentKind k) => switch (k) {
    ContentKind.exercise => Routes.exercise,
    ContentKind.workout => Routes.workout,
    ContentKind.program => Routes.program,
  };

  Future<void> _reject(BuildContext context, LibraryItem x) async {
    final reason = await askText(
      context,
      title: 'Refuser « ${x.name} »',
      label: 'Motif communiqué à l\'auteur',
      hint: 'Ex. ajoutez une étape, précisez le repos…',
      validator: Validators.text(field: 'Le motif', min: 5, max: 300),
    );
    if (reason == null || !context.mounted) return;
    await runAction(
      context,
      () => Backend.I.library.reject(x.kind, x.id, reason),
      success: 'Refus envoyé à l\'auteur.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return Scaffold(
      appBar: AppBar(title: const Text('Propositions à valider')),
      body: ListenableBuilder(
        listenable: b.bus,
        builder: (context, _) {
          final queue = b.library.reviewQueue();
          if (queue.isEmpty) {
            return const EmptyState(
              icon: Icons.fact_check_outlined,
              title: 'Rien à valider',
              message:
                  'Les exercices, workouts et programmes proposés par les '
                  'membres apparaîtront ici.',
            );
          }
          return ListView(
            padding: pagePadding(context, maxWidth: 900),
            children: [
              const GfCard(
                color: AppColors.cream,
                child: InfoRow(
                  Icons.info_outline,
                  'Vérifiez la sécurité des consignes (charges, amplitude, '
                  'repos) et la qualité des médias avant de publier. '
                  'Un refus doit toujours être motivé.',
                ),
              ),
              const SizedBox(height: Gap.m),
              for (var i = 0; i < queue.length; i++)
                FadeSlideIn(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Gap.s),
                    child: _ReviewCard(
                      item: queue[i],
                      onReject: () => _reject(context, queue[i]),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.item, required this.onReject});
  final LibraryItem item;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final x = item;
    final deps = b.library
        .dependenciesOf(x)
        .where((d) => d.publication.isPending)
        .toList();
    return GfCard(
      key: ValueKey('review_${x.id}'),
      onTap: () => Navigator.pushNamed(
        context,
        ReviewScreen.routeOf(x.kind),
        arguments: x.id,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.navy,
                child: Icon(x.kind.icon, color: AppColors.white, size: 20),
              ),
              const SizedBox(width: Gap.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(x.name, style: AppText.subtitle()),
                    if (x.altName != null)
                      Text(
                        x.altName!,
                        style: AppText.label(
                          size: 12,
                        ).copyWith(fontStyle: FontStyle.italic),
                      ),
                    Text(
                      '${x.kind.label} · ${b.library.authorLabel(x)}'
                      '${x.publication.submittedAt == null ? '' : ' · ${Fmt.relative(x.publication.submittedAt!, now: b.now())}'}',
                      style: AppText.label(size: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.navy),
            ],
          ),
          if (deps.isNotEmpty) ...[
            const SizedBox(height: Gap.s),
            InfoRow(
              Icons.link,
              'Publié avec : ${deps.map((d) => '${d.kind.lower} « ${d.name} »').join(', ')}',
            ),
          ],
          const SizedBox(height: Gap.s),
          Wrap(
            spacing: Gap.s,
            runSpacing: Gap.s,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
                onPressed: onReject,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Refuser'),
              ),
              ElevatedButton.icon(
                key: ValueKey('approve_${x.id}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: AppColors.white,
                ),
                onPressed: () => runAction(
                  context,
                  () => b.library.approve(x.kind, x.id),
                  success: '« ${x.name} » est publié.',
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Publier'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
