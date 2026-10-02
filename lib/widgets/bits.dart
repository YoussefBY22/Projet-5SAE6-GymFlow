import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import 'animations.dart';

/// Puce de filtre animée (sélection : fond marine + texte blanc ;
/// sinon fond blanc + texte marine).
class GfFilterChip extends StatelessWidget {
  const GfFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.navy : AppColors.white;
    final fg = onColor(bg);
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: TapScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: kCurve,
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? AppColors.navy : AppColors.outline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: selected
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: fg,
                        key: const ValueKey(1),
                      )
                    : (icon != null
                          ? Icon(
                              icon,
                              size: 16,
                              color: fg,
                              key: const ValueKey(2),
                            )
                          : const SizedBox(key: ValueKey(3))),
              ),
              if (selected || icon != null) const SizedBox(width: 6),
              Text(
                label,
                style: AppText.label(
                  color: fg,
                  size: 13,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rangée horizontale défilante de puces.
class ChipBar extends StatelessWidget {
  const ChipBar({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Grand écran : les filtres s'affichent tous, sur plusieurs lignes,
    // alignés sur le contenu (pas de défilement horizontal à la souris).
    if (isWide(context)) {
      final pad = pagePadding(context, maxWidth: 1200, top: 4, bottom: 4);
      return Padding(
        padding: pad,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Wrap(spacing: Gap.s, runSpacing: Gap.xs, children: children),
        ),
      );
    }
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: 4),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: Gap.s),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

/// Étoiles de notation : remplissage jaune doré + contour marine
/// (contraste suffisant sur fond clair).
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.value,
    this.size = 18,
    this.onChanged,
  });

  final double value;
  final double size;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(i),
            child: Padding(
              padding: EdgeInsets.all(onChanged == null ? 0 : 6),
              child: Semantics(
                label: 'Étoile $i',
                child: Stack(
                  children: [
                    Icon(
                      Icons.star,
                      size: size,
                      color: value >= i - 0.25
                          ? AppColors.gold
                          : AppColors.white,
                    ),
                    Icon(Icons.star_border, size: size, color: AppColors.navy),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Confettis de célébration (fin de séance, record battu).
class Confetti extends StatefulWidget {
  const Confetti({super.key, this.pieces = 90});
  final int pieces;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();
  late final List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    final r = math.Random();
    const colors = [
      AppColors.red,
      AppColors.gold,
      AppColors.navy,
      Color(0xFF0F5E9C),
    ];
    _pieces = List.generate(
      widget.pieces,
      (i) => _Piece(
        x: r.nextDouble(),
        delay: r.nextDouble() * 0.35,
        speed: 0.6 + r.nextDouble() * 0.6,
        drift: (r.nextDouble() - 0.5) * 0.3,
        spin: r.nextDouble() * 6,
        size: 6 + r.nextDouble() * 6,
        color: colors[i % colors.length],
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _c.value),
        ),
      ),
    );
  }
}

class _Piece {
  _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.spin,
    required this.size,
    required this.color,
  });
  final double x, delay, speed, drift, spin, size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * p.speed * (size.height + 60);
      final x = (p.x + p.drift * local) * size.width;
      final paint = Paint()..color = p.color.withValues(alpha: 1 - local * 0.6);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local * math.pi);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.5,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// Pastille de compteur (panier, notifications non lues).
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, required this.child});
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: 4,
          top: 4,
          child: AnimatedScale(
            scale: count > 0 ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.navy, width: 1),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: AppText.label(
                  color: AppColors.navy,
                  size: 11,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
