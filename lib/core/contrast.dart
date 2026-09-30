import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Outils de contraste WCAG 2.1 (règle de lisibilité du design system).

/// Luminance relative d'une couleur (formule WCAG).
double relativeLuminance(Color color) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// Ratio de contraste entre deux couleurs opaques (1 à 21).
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Seuil WCAG AA pour du texte normal.
const double wcagAA = 4.5;

/// Seuil WCAG AA pour les grands textes et les éléments graphiques.
const double wcagAALarge = 3.0;
