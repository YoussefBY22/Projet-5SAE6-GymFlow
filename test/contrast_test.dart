import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/contrast.dart';
import 'package:gymflow/core/theme.dart';

/// Règle de lisibilité : toutes les paires texte/fond utilisées dans
/// l'application respectent WCAG AA (≥ 4,5:1).
void main() {
  // (fond, texte, contexte)
  const pairs = <(Color, Color, String)>[
    (AppColors.navy, AppColors.white, 'AppBar, cartes marine'),
    (AppColors.navy, AppColors.cream, 'sous-titres sur marine'),
    (AppColors.navy, AppColors.gold, 'chrono, minuteur, action SnackBar'),
    (AppColors.navy, AppColors.navyMuted, 'onglets non sélectionnés'),
    (AppColors.red, AppColors.white, 'boutons principaux, badges'),
    (AppColors.gold, AppColors.navy, 'badges dorés, records'),
    (AppColors.cream, AppColors.navy, 'cartes crème'),
    (AppColors.cream, AppColors.ink, 'texte sur crème'),
    (AppColors.cream, AppColors.inkSoft, 'texte secondaire sur crème'),
    (AppColors.cream, AppColors.red, 'prix / alertes sur crème'),
    (AppColors.background, AppColors.navy, 'titres sur fond'),
    (AppColors.background, AppColors.ink, 'texte sur fond'),
    (AppColors.background, AppColors.inkSoft, 'texte secondaire sur fond'),
    (AppColors.white, AppColors.navy, 'titres sur cartes'),
    (AppColors.white, AppColors.ink, 'texte sur cartes'),
    (AppColors.white, AppColors.inkSoft, 'hints, labels, onglets inactifs'),
    (AppColors.white, AppColors.red, 'prix, onglet actif, erreurs'),
    (AppColors.white, AppColors.success, 'textes de succès'),
    (AppColors.success, AppColors.white, 'pastilles de succès'),
    (AppColors.successSoft, AppColors.success, 'série validée'),
    (AppColors.redSoft, AppColors.red, 'bannières d\'erreur'),
    (AppColors.redSoft, AppColors.ink, 'texte sur bannière d\'erreur'),
    (AppColors.inkSoft, AppColors.white, 'pastille « archivé »'),
    (AppColors.outline, AppColors.white, 'texte blanc sur gris'),
  ];

  for (final (bg, fg, label) in pairs) {
    test('contraste ≥ 4,5 : $label', () {
      expect(
        contrastRatio(bg, fg),
        greaterThanOrEqualTo(wcagAA),
        reason: label,
      );
    });
  }

  test('toutes les couleurs d\'accent portent du texte blanc lisible', () {
    for (final c in AppColors.accents) {
      expect(contrastRatio(c, onColor(c)), greaterThanOrEqualTo(wcagAA));
    }
  });

  test('onColor : blanc sur foncé, marine sur clair', () {
    expect(onColor(AppColors.navy), AppColors.white);
    expect(onColor(AppColors.red), AppColors.white);
    expect(onColor(AppColors.gold), AppColors.navy);
    expect(onColor(AppColors.cream), AppColors.navy);
    expect(onColor(AppColors.white), AppColors.navy);
    expect(onColor(AppColors.background), AppColors.navy);
    expect(onColor(AppColors.success), AppColors.white);
  });

  test('éléments graphiques (bordures, icônes inactives) ≥ 3:1', () {
    expect(
      contrastRatio(AppColors.white, AppColors.outline),
      greaterThanOrEqualTo(wcagAALarge),
    );
    expect(
      contrastRatio(AppColors.background, AppColors.outline),
      greaterThanOrEqualTo(wcagAALarge),
    );
  });

  test('ratio de référence : noir sur blanc = 21', () {
    expect(
      contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 0.01),
    );
  });
}
