import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/theme.dart';

/// Animation de réorganisation d'une liste (technique « FLIP » : First,
/// Last, Invert, Play).
///
/// Avant un changement d'ordre (ex. ajout aux favoris), [capture] mémorise
/// la position à l'écran de chaque carte. Après la reconstruction, chaque
/// carte qui a bougé glisse de son ancienne position vers la nouvelle.
/// La carte « vedette » (celle qu'on vient de mettre en favori) se soulève
/// et vole au-dessus des autres jusqu'à sa nouvelle place.
class FlipController {
  final Map<String, _FlipItemState> _items = {};
  Map<String, Rect>? _snapshot;
  DateTime? _snapshotAt;
  String? _focus;
  ScrollController? scroll;

  bool get isReordering =>
      _snapshotAt != null &&
      DateTime.now().difference(_snapshotAt!) < _validity;

  static const _validity = Duration(milliseconds: 700);

  void capture({String? focus}) {
    _snapshot = {for (final e in _items.entries) e.key: ?e.value._globalRect()};
    _snapshotAt = DateTime.now();
    _focus = focus;
    // Si la carte vedette n'est pas construite à sa nouvelle place (liste
    // longue, défilée), on remonte en haut de la liste pour la montrer.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final id = _focus;
        if (id == null || _items.containsKey(id)) return;
        final s = scroll;
        if (s != null && s.hasClients && s.offset > 0) {
          s.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
          );
        }
      });
    });
  }

  Rect? _previous(String id) => isReordering ? (_snapshot?[id]) : null;
}

/// Rend [controller] accessible aux cartes (et au bouton favori).
class FlipScope extends InheritedWidget {
  const FlipScope({super.key, required this.controller, required super.child});
  final FlipController controller;

  static FlipController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FlipScope>()?.controller;

  @override
  bool updateShouldNotify(FlipScope old) => old.controller != controller;
}

class FlipItem extends StatefulWidget {
  const FlipItem({super.key, required this.id, required this.child});
  final String id;
  final Widget child;

  @override
  State<FlipItem> createState() => _FlipItemState();
}

class _FlipItemState extends State<FlipItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  late final CurvedAnimation _t = CurvedAnimation(
    parent: _c,
    curve: Curves.easeInOutCubic,
  );
  FlipController? _controller;
  Offset _delta = Offset.zero;
  OverlayEntry? _flight;
  Rect? _from;
  DateTime? _playedFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = FlipScope.maybeOf(context);
    if (c != _controller) {
      _controller?._items.remove(widget.id);
      _controller = c;
    }
    _register();
  }

  @override
  void didUpdateWidget(FlipItem old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) _controller?._items.remove(old.id);
    _register();
  }

  void _register() {
    final c = _controller;
    if (c == null) return;
    c._items[widget.id] = this;
    final prev = c._previous(widget.id);
    // Une seule animation par réorganisation, même si la carte est
    // reconstruite plusieurs fois.
    if (prev == null || _playedFor == c._snapshotAt) return;
    _playedFor = c._snapshotAt;
    SchedulerBinding.instance.addPostFrameCallback((_) => _play(prev));
  }

  Rect? _globalRect() {
    if (!mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _play(Rect from) {
    if (!mounted) return;
    final to = _globalRect();
    if (to == null) return;
    final d = from.topLeft - to.topLeft;
    if (d.distance < 1) return;
    final focus = _controller?._focus == widget.id;
    if (focus) {
      _fly(from);
    } else {
      setState(() => _delta = d);
      _c.forward(from: 0);
    }
  }

  /// Carte vedette : copie flottante au-dessus de la liste, avec ombre et
  /// léger grossissement, pendant que la vraie carte reste invisible.
  void _fly(Rect from) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _from = from;
    _flight?.remove();
    _flight = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: _t,
        builder: (context, child) {
          final to = _globalRect() ?? from;
          final overlayBox = overlay.context.findRenderObject() as RenderBox?;
          final origin = overlayBox?.localToGlobal(Offset.zero) ?? Offset.zero;
          final r = Rect.lerp(_from, to, _t.value)!.shift(-origin);
          final lift = 1 + 0.04 * (1 - (2 * _t.value - 1).abs());
          return Positioned(
            left: r.left,
            top: r.top,
            width: r.width,
            height: r.height,
            child: IgnorePointer(
              child: Transform.scale(
                scale: lift,
                child: Material(
                  type: MaterialType.transparency,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Gap.radius),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x55002855),
                          blurRadius: 24 * (lift - 1) / 0.04 + 4,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          );
        },
        child: HeroMode(enabled: false, child: widget.child),
      ),
    );
    overlay.insert(_flight!);
    setState(() => _delta = Offset.zero);
    _c.forward(from: 0).whenCompleteOrCancel(() {
      _flight?.remove();
      _flight = null;
      if (mounted) setState(() => _from = null);
    });
  }

  @override
  void dispose() {
    _flight?.remove();
    _flight = null;
    if (_controller?._items[widget.id] == this) {
      _controller?._items.remove(widget.id);
    }
    _t.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        if (_from != null) {
          // En vol : la place est réservée, la copie flottante est visible.
          return Opacity(opacity: 0, child: child);
        }
        if (_delta == Offset.zero || _c.isCompleted) return child!;
        return Transform.translate(
          offset: _delta * (1 - _t.value),
          child: child,
        );
      },
    );
  }
}
