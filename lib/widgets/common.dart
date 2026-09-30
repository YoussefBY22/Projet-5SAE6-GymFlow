import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../core/errors.dart';
import '../core/theme.dart';
import '../models/user.dart';

/// Widgets réutilisables du design system GymFlow.

/// Carte blanche arrondie avec ombre légère (style Strava).
class GfCard extends StatelessWidget {
  const GfCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.m),
    this.onTap,
    this.color = AppColors.white,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: color,
        elevation: 1.5,
        shadowColor: const Color(0x22002855),
        borderRadius: BorderRadius.circular(Gap.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Titre de section avec action optionnelle « Voir tout ».
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.m, Gap.l, Gap.s, Gap.s),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.title(size: 18))),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// Badge / pastille. Les couleurs de texte suivent la règle `onColor`.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color = AppColors.cream, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = onColor(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label(
                color: fg,
                size: 12,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Image réseau (en cache) ou fichier local, avec squelette et repli.
class NetImage extends StatelessWidget {
  const NetImage(
    this.source, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.fallbackIcon = Icons.fitness_center,
    this.cacheWidth = 800,
  });

  final String? source;
  final BoxFit fit;
  final double? width;
  final double? height;
  final IconData fallbackIcon;
  final int cacheWidth;

  /// Désactivé dans les tests (pas d'accès réseau) : affiche le repli.
  static bool networkEnabled = true;

  Widget _fallback() => Container(
    width: width,
    height: height,
    color: AppColors.cream,
    alignment: Alignment.center,
    child: Icon(fallbackIcon, color: AppColors.navy, size: 36),
  );

  @override
  Widget build(BuildContext context) {
    final src = source;
    if (src == null || src.isEmpty) return _fallback();
    if (src.startsWith('http')) {
      if (!networkEnabled) return _fallback();
      return CachedNetworkImage(
        imageUrl: src,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: cacheWidth,
        fadeInDuration: const Duration(milliseconds: 250),
        placeholder: (_, _) =>
            Skeleton(width: width, height: height, radius: 0),
        errorWidget: (_, _, _) => _fallback(),
      );
    }
    if (src.startsWith('assets/')) {
      return Image.asset(src, width: width, height: height, fit: fit);
    }
    return Image.file(
      File(src),
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }
}

/// Bloc squelette animé (shimmer) pour les états de chargement.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.width, this.height = 16, this.radius = 12});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.skeleton,
      highlightColor: AppColors.background,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.skeleton,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Liste de cartes squelettes pendant un chargement.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5, this.itemHeight = 88});

  final int count;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(Gap.m),
      itemCount: count,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, _) => const SizedBox(height: Gap.s),
      itemBuilder: (_, _) => Skeleton(height: itemHeight, radius: Gap.radius),
    );
  }
}

/// État vide illustré.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.cream,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppColors.navy),
            ),
            const SizedBox(height: Gap.m),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.title(size: 18),
            ),
            const SizedBox(height: Gap.s),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.body(color: AppColors.inkSoft),
            ),
            if (action != null) ...[
              const SizedBox(height: Gap.m),
              ElevatedButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// État d'erreur avec bouton « Réessayer ».
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: error is NetworkException ? Icons.wifi_off : Icons.error_outline,
      title: 'Oups…',
      message: friendlyError(error),
      action: 'Réessayer',
      onAction: onRetry,
    );
  }
}

/// Avatar : photo de profil si disponible, sinon initiales colorées.
class GfAvatar extends StatelessWidget {
  const GfAvatar(this.user, {super.key, this.radius = 20});

  final AppUser? user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final u = user;
    final color = u == null
        ? AppColors.navy
        : AppColors.accents[u.id.hashCode.abs() % AppColors.accents.length];
    if (u?.avatarPath != null) {
      return ClipOval(
        child: NetImage(
          u!.avatarPath,
          width: radius * 2,
          height: radius * 2,
          fallbackIcon: Icons.person,
          cacheWidth: (radius * 4).round(),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        u?.initials ?? '?',
        style: AppText.subtitle(color: onColor(color), size: radius * 0.75),
      ),
    );
  }
}

/// Tuile de statistique (gros chiffre + libellé).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.color = AppColors.navy,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) Icon(icon, size: 18, color: color),
        Text(value, style: AppText.stat(color: color, size: 20)),
        Text(label, style: AppText.label(size: 12)),
      ],
    );
  }
}

/// Affiche un message (succès ou erreur) en bas de l'écran.
void showSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: error ? AppColors.red : AppColors.navy,
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle,
              color: AppColors.white,
            ),
            const SizedBox(width: Gap.s),
            Expanded(
              child: Text(message, style: AppText.body(color: AppColors.white)),
            ),
          ],
        ),
      ),
    );
}

/// Exécute une action métier et affiche l'erreur éventuelle.
/// Renvoie `true` en cas de succès.
Future<bool> runAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (success != null && context.mounted) showSnack(context, success);
    return true;
  } catch (e) {
    if (context.mounted) showSnack(context, friendlyError(e), error: true);
    return false;
  }
}

/// Boîte de dialogue de confirmation.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: destructive ? AppColors.red : AppColors.navy,
            foregroundColor: AppColors.white,
            minimumSize: const Size(96, 44),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Bouton principal avec indicateur de chargement intégré.
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
    this.icon,
    this.color = AppColors.red,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fg = onColor(color);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: fg,
        ),
        onPressed: loading ? null : onPressed,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: loading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.navy,
                  ),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20),
                      const SizedBox(width: Gap.s),
                    ],
                    Flexible(
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Voile sombre en haut d'une image pleine largeur : garantit la lisibilité
/// des icônes blanches de l'AppBar posées sur une photo claire.
class TopScrim extends StatelessWidget {
  const TopScrim({super.key, this.height = 120});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC00101F), Color(0x0000101F)],
          ),
        ),
      ),
    );
  }
}

/// Ligne d'information icône + texte.
class InfoRow extends StatelessWidget {
  const InfoRow(this.icon, this.text, {super.key});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.inkSoft),
          const SizedBox(width: Gap.s),
          Expanded(child: Text(text, style: AppText.body(size: 14))),
        ],
      ),
    );
  }
}
