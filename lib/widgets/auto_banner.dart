import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/announcement_service.dart';
import 'animations.dart';
import 'common.dart';

/// Bannière défilante automatique (carrousel publicitaire) :
/// défilement toutes les 4 s, pause au toucher, points indicateurs,
/// badge « Nouveau », voile sombre pour la lisibilité du texte blanc.
class AutoBanner extends StatefulWidget {
  const AutoBanner({super.key, required this.items, this.height = 190});
  final List<BannerItem> items;
  final double height;

  @override
  State<AutoBanner> createState() => _AutoBannerState();
}

class _AutoBannerState extends State<AutoBanner> {
  final _controller = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _page = 0;
  bool _touching = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _advance());
  }

  void _advance() {
    if (!mounted ||
        _touching ||
        widget.items.length < 2 ||
        !_controller.hasClients) {
      return;
    }
    final next = (_page + 1) % widget.items.length;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 600),
      curve: kCurve,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: Listener(
            onPointerDown: (_) => _touching = true,
            onPointerUp: (_) => _touching = false,
            onPointerCancel: (_) => _touching = false,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.items.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final item = widget.items[i];
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    var delta = 0.0;
                    if (_controller.position.haveDimensions) {
                      delta = (_controller.page ?? 0) - i;
                    } else {
                      delta = (_page - i).toDouble();
                    }
                    final scale = (1 - delta.abs() * 0.06).clamp(0.9, 1.0);
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: item.route == null
                          ? null
                          : () => Navigator.pushNamed(
                              context,
                              item.route!,
                              arguments: item.argument,
                            ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            NetImage(
                              item.imageUrl,
                              fallbackIcon: Icons.campaign,
                            ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: [0.1, 1],
                                  colors: [
                                    Color(0x3300101F),
                                    Color(0xF000101F),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(Gap.m),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Pill(item.badge, color: AppColors.red),
                                      if (item.isNew) ...[
                                        const Pill(
                                          'Nouveau',
                                          color: AppColors.gold,
                                          icon: Icons.auto_awesome,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.title(
                                      color: AppColors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.body(
                                      color: AppColors.cream,
                                      size: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: Gap.s),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.items.length; i++)
              AnimatedContainer(
                duration: kAnim,
                curve: kCurve,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _page ? AppColors.red : AppColors.outline,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
