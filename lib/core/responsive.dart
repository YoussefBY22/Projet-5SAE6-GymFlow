import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// Adaptation téléphone / tablette / ordinateur.
///
/// Sur grand écran : navigation latérale (NavigationRail), contenu centré
/// avec une largeur maximale lisible, listes de cartes en grille.
class Breakpoints {
  Breakpoints._();

  /// Au-delà : navigation latérale à la place de la barre du bas.
  static const double wide = 900;

  /// Au-delà : navigation latérale déployée (libellés visibles).
  static const double extended = 1280;
}

double screenWidth(BuildContext context) => MediaQuery.sizeOf(context).width;

bool isWide(BuildContext context) => screenWidth(context) >= Breakpoints.wide;

/// Marges d'une page dont le contenu est centré et limité à [maxWidth].
EdgeInsets pagePadding(
  BuildContext context, {
  double maxWidth = 1100,
  double top = Gap.m,
  double bottom = Gap.xl,
}) {
  final side = math.max(Gap.m, (screenWidth(context) - maxWidth) / 2);
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

/// Nombre de colonnes pour une liste de cartes d'au moins [minTileWidth].
int columnsFor(
  BuildContext context, {
  double minTileWidth = 420,
  double maxWidth = 1100,
  int max = 3,
}) {
  final usable = math.min(screenWidth(context), maxWidth) - 2 * Gap.m;
  return (usable / minTileWidth).floor().clamp(1, max);
}

/// Contenu centré à largeur maximale (formulaires, détails).
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child, this.maxWidth = 760});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Liste paresseuse de cartes : une colonne sur téléphone, plusieurs
/// colonnes (rangées de cartes à hauteur naturelle) sur grand écran, le tout
/// centré dans une largeur maximale lisible.
class ResponsiveList extends StatelessWidget {
  const ResponsiveList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minTileWidth = 420,
    this.maxWidth = 1100,
    this.maxColumns = 3,
    this.top = Gap.m,
    this.bottom = 96,
    this.spacing = Gap.m,
    this.controller,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double minTileWidth;
  final double maxWidth;
  final int maxColumns;
  final double top;
  final double bottom;
  final double spacing;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final side = math.max(Gap.m, (c.maxWidth - maxWidth) / 2);
        final usable = c.maxWidth - 2 * side;
        final cols = (usable / minTileWidth).floor().clamp(1, maxColumns);
        final rows = (itemCount / cols).ceil();
        return ListView.separated(
          controller: controller,
          padding: EdgeInsets.fromLTRB(side, top, side, bottom),
          itemCount: rows,
          separatorBuilder: (_, _) => SizedBox(height: spacing),
          itemBuilder: (context, r) {
            if (cols == 1) return itemBuilder(context, r);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var k = 0; k < cols; k++) ...[
                  if (k > 0) SizedBox(width: spacing),
                  Expanded(
                    child: r * cols + k < itemCount
                        ? itemBuilder(context, r * cols + k)
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

/// Grille de cartes à hauteur naturelle (colonnes côte à côte sur grand
/// écran, une seule colonne sur téléphone).
class ResponsiveWrapGrid extends StatelessWidget {
  const ResponsiveWrapGrid({
    super.key,
    required this.children,
    this.minTileWidth = 420,
    this.spacing = Gap.m,
  });

  final List<Widget> children;
  final double minTileWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = (c.maxWidth / minTileWidth).floor().clamp(1, 4);
        if (cols == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                children[i],
              ],
            ],
          );
        }
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: w, child: child),
          ],
        );
      },
    );
  }
}
