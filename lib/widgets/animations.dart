import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Animations réutilisables (200-500 ms, Curves.easeOutCubic).

const Duration kAnim = Duration(milliseconds: 350);
const Curve kCurve = Curves.easeOutCubic;

/// Apparition en cascade : fondu + glissement, décalé selon [index].
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 24,
    this.animate = true,
  });

  final Widget child;
  final int index;
  final double offset;

  /// `false` : affiché directement (ex. carte déplacée lors d'un tri).
  final bool animate;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  // Le décalage de la cascade est intégré à la durée (Interval) : aucun
  // Timer, l'animation reste pilotée par le moteur de rendu.
  late final int _delayMs = 40 * math.min(widget.index, 8);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 420 + _delayMs),
  )..forward(from: widget.animate ? 0 : 1);
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(_delayMs / (420 + _delayMs), 1, curve: kCurve),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _t.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Compteur animé (gros chiffres des dashboards et récapitulatifs).
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    required this.style,
    this.format,
    this.duration = const Duration(milliseconds: 900),
  });

  final double value;
  final TextStyle style;
  final String Function(double)? format;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: kCurve,
      builder: (_, v, _) =>
          Text(format?.call(v) ?? v.round().toString(), style: style),
    );
  }
}

/// Anneau de progression animé (objectif hebdomadaire).
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 120,
    this.stroke = 12,
    this.color = AppColors.red,
    this.track = AppColors.cream,
    this.child,
  });

  final double progress;
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0, 1)),
      duration: const Duration(milliseconds: 1000),
      curve: kCurve,
      builder: (_, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(v, stroke, color, track),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.stroke, this.color, this.track);
  final double value;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(r, 0, math.pi * 2, false, base);
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}

/// Barre de progression animée arrondie.
class AnimatedBar extends StatelessWidget {
  const AnimatedBar({
    super.key,
    required this.value,
    this.color = AppColors.red,
    this.height = 8,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 600),
      curve: kCurve,
      builder: (_, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: v,
          minHeight: height,
          color: color,
          backgroundColor: AppColors.divider,
        ),
      ),
    );
  }
}

/// Transition de page personnalisée (fondu + glissement vers le haut).
Route<T> gfRoute<T>(Widget page, {RouteSettings? settings}) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: kCurve);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Pulsation d'échelle au toucher (boutons, favoris, kudos).
class TapScale extends StatefulWidget {
  const TapScale({super.key, required this.child, required this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    // GestureDetector (cours S04) pour l'effet d'appui.
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.92 : 1,
        duration: const Duration(milliseconds: 150),
        child: widget.child,
      ),
    );
  }
}
