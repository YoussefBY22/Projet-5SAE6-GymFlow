import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/shop.dart';
import 'common.dart';

/// Carte « Nutrition » de la fiche produit (côté abonné) : valeurs pour
/// 100 g, Nutri-Score, allergènes, calculs de l'application et résumé IA.
class NutritionCard extends StatelessWidget {
  const NutritionCard({super.key, required this.product});
  final Product product;

  static String _g(double v) => v == v.roundToDouble()
      ? '${v.toInt()} g'
      : '${v.toStringAsFixed(1).replaceAll('.', ',')} g';

  /// Prix au millime près (le dinar compte 1 000 millimes).
  static String tndPerGram(double v) =>
      '${v.toStringAsFixed(3).replaceAll('.', ',')} DT/g';

  @override
  Widget build(BuildContext context) {
    final n = product.nutrition!;
    final perServing = n.proteinPerServing;
    final perGram = product.pricePerProteinGram;
    final rows = <(String, String)>[
      if (n.proteins != null) ('Protéines', _g(n.proteins!)),
      if (n.carbs != null) ('Glucides', _g(n.carbs!)),
      if (n.sugars != null) ('dont sucres', _g(n.sugars!)),
      if (n.fat != null) ('Lipides', _g(n.fat!)),
      if (n.kcal != null) ('Énergie', '${n.kcal!.round()} kcal'),
    ];
    return GfCard(
      key: const Key('nutrition_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant_menu, color: AppColors.navy),
              const SizedBox(width: Gap.s),
              Expanded(
                child: Text('Nutrition', style: AppText.title(size: 18)),
              ),
              Semantics(
                label: 'Nutri-Score ${n.nutriScoreLabel}',
                child: ExcludeSemantics(
                  child: Pill(
                    'Nutri-Score ${n.nutriScoreLabel}',
                    color: _scoreColor(n.nutriScoreLetter),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.m),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Protéines par portion',
                  value: perServing == null
                      ? '—'
                      : '${_g(perServing)} (${_g(n.servingG!)})',
                ),
              ),
              const SizedBox(width: Gap.s),
              Expanded(
                child: _Metric(
                  label: 'Prix du gramme de protéine',
                  value: perGram == null ? '—' : tndPerGram(perGram),
                ),
              ),
            ],
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: Gap.m),
            Text('Pour 100 g', style: AppText.subtitle(size: 14)),
            const SizedBox(height: 4),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(label, style: AppText.body(size: 14))),
                    Text(value, style: AppText.subtitle(size: 14)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: Gap.s),
          Text(
            n.allergens.isEmpty
                ? 'Aucun allergène signalé : vérifiez l\'emballage.'
                : 'Allergènes : ${n.allergens.join(', ')}.',
            style: AppText.body(size: 14),
          ),
          if (product.aiSummary != null) ...[
            const SizedBox(height: Gap.m),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Gap.s),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: AppColors.navy,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Résumé pour le sportif',
                        style: AppText.subtitle(size: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(product.aiSummary!, style: AppText.body(size: 14)),
                  const SizedBox(height: 4),
                  Text(
                    'Rédigé par l\'IA à partir de ces valeurs, relu par la '
                    'salle. Ne remplace pas l\'avis d\'un professionnel de '
                    'santé.',
                    style: AppText.label(size: 12),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Gap.s),
          Text(
            n.source == null
                ? 'Valeurs saisies par la salle.'
                : 'Source : ${n.source}',
            style: AppText.label(size: 12),
          ),
        ],
      ),
    );
  }

  static Color _scoreColor(String? letter) => switch (letter) {
    'A' || 'B' => AppColors.success,
    'C' => AppColors.gold,
    'D' || 'E' => AppColors.red,
    _ => AppColors.cream,
  };
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Gap.s),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppText.stat(size: 17)),
        Text(label, style: AppText.label(size: 12)),
      ],
    ),
  );
}

/// La carte n'est affichée que s'il y a des valeurs ou un résumé.
bool showNutritionCard(Product p) =>
    p.nutrition != null &&
    (!p.nutrition!.isEmpty || (p.aiSummary?.isNotEmpty ?? false));
