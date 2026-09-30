import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'contrast.dart';

/// Palette imposée du design system GymFlow (mode clair uniquement).
class AppColors {
  AppColors._();

  static const Color navy = Color(0xFF002855); // Primary
  static const Color red = Color(0xFFBA0C2F); // Action / énergie
  static const Color gold = Color(0xFFFFCF70); // Badges, records, étoiles
  static const Color cream = Color(0xFFFFF4E0); // Cartes chaudes
  static const Color background = Color(0xFFF5F5F0); // Fond d'écran
  static const Color white = Color(0xFFFFFFFF);

  static const Color ink = Color(0xFF1F2937); // Texte principal gris foncé
  static const Color inkSoft = Color(0xFF4B5563); // Texte secondaire (minimum)
  static const Color navyMuted = Color(
    0xFFB9C3D1,
  ); // Texte secondaire sur marine
  static const Color outline = Color(0xFF6B7280); // Bordures de champs
  static const Color divider = Color(0xFFE5E3DC);
  static const Color success = Color(0xFF166534); // Vert foncé (texte blanc)
  static const Color successSoft = Color(
    0xFFDCFCE7,
  ); // Fond vert pâle (texte vert foncé)
  static const Color redSoft = Color(
    0xFFFDE8EC,
  ); // Fond rouge pâle (texte rouge)
  static const Color skeleton = Color(0xFFE7E5DE);
  static const Color overlay = Color(0xCC00101F); // Voile sombre sur photo

  /// Couleurs de catégories (graphiques, avatars) — toutes lisibles avec du blanc.
  static const List<Color> accents = [
    navy,
    red,
    Color(0xFF0F5E9C),
    Color(0xFF7A1F5C),
    Color(0xFF166534),
    Color(0xFF8A4B08),
  ];
}

/// Retourne la couleur de texte/icône lisible sur [background] :
/// blanc sur les fonds foncés (marine, rouge…), marine sur les fonds clairs.
/// Règle de lisibilité : jamais foncé sur foncé, jamais clair sur clair.
Color onColor(Color background) {
  if (background == AppColors.gold) return AppColors.navy;
  if (background == AppColors.navy || background == AppColors.red) {
    return AppColors.white;
  }
  final withWhite = contrastRatio(background, AppColors.white);
  final withNavy = contrastRatio(background, AppColors.navy);
  return withWhite >= withNavy ? AppColors.white : AppColors.navy;
}

/// Espacements (grille de 8 px) et rayons.
class Gap {
  Gap._();
  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
  static const double radius = 16;
}

/// Styles de texte : Poppins pour titres et gros chiffres, Inter pour le texte.
class AppText {
  AppText._();

  static TextStyle display({Color color = AppColors.navy, double size = 34}) =>
      GoogleFonts.poppins(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.1,
      );

  static TextStyle title({Color color = AppColors.navy, double size = 20}) =>
      GoogleFonts.poppins(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.2,
      );

  static TextStyle subtitle({Color color = AppColors.navy, double size = 16}) =>
      GoogleFonts.poppins(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle body({Color color = AppColors.ink, double size = 15}) =>
      GoogleFonts.inter(fontSize: size, color: color, height: 1.4);

  static TextStyle label({Color color = AppColors.inkSoft, double size = 13}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle stat({Color color = AppColors.navy, double size = 22}) =>
      GoogleFonts.poppins(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

/// Thème Material de l'application (clair uniquement, aucun thème sombre).
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.navy,
      onPrimary: AppColors.white,
      secondary: AppColors.red,
      onSecondary: AppColors.white,
      tertiary: AppColors.gold,
      onTertiary: AppColors.navy,
      error: AppColors.red,
      onError: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkSoft,
      surfaceContainerHighest: AppColors.cream,
      outline: AppColors.outline,
      outlineVariant: AppColors.divider,
    );
    final textTheme = GoogleFonts.interTextTheme().apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.navy,
    );
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Gap.radius),
    );
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme.copyWith(
        headlineMedium: AppText.title(size: 26),
        titleLarge: AppText.title(),
        titleMedium: AppText.subtitle(),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.title(color: AppColors.white, size: 19),
        iconTheme: const IconThemeData(color: AppColors.white),
        actionsIconTheme: const IconThemeData(color: AppColors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 1.5,
        shadowColor: const Color(0x22002855),
        shape: rounded,
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.red,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.divider,
          disabledForegroundColor: AppColors.inkSoft,
          minimumSize: const Size(64, 52),
          shape: rounded,
          textStyle: AppText.subtitle(color: AppColors.white, size: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          minimumSize: const Size(64, 52),
          side: const BorderSide(color: AppColors.navy, width: 1.5),
          shape: rounded,
          textStyle: AppText.subtitle(size: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.navy,
          minimumSize: const Size(48, 48),
          textStyle: AppText.subtitle(size: 14),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        labelStyle: AppText.label(),
        floatingLabelStyle: AppText.label(color: AppColors.navy),
        hintStyle: AppText.body(color: AppColors.inkSoft),
        helperStyle: AppText.label(),
        errorStyle: AppText.label(color: AppColors.red, size: 12),
        prefixIconColor: AppColors.inkSoft,
        suffixIconColor: AppColors.inkSoft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: border(AppColors.outline),
        enabledBorder: border(AppColors.outline),
        focusedBorder: border(AppColors.navy, 2),
        errorBorder: border(AppColors.red),
        focusedErrorBorder: border(AppColors.red, 2),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.red,
        unselectedItemColor: AppColors.inkSoft,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: AppText.label(color: AppColors.red, size: 11),
        unselectedLabelStyle: AppText.label(size: 11),
        elevation: 8,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.white,
        unselectedLabelColor: AppColors.navyMuted,
        indicatorColor: AppColors.gold,
        indicatorSize: TabBarIndicatorSize.label,
        labelPadding: const EdgeInsets.symmetric(horizontal: 10),
        labelStyle: AppText.subtitle(color: AppColors.white, size: 13),
        unselectedLabelStyle: AppText.subtitle(
          color: AppColors.navyMuted,
          size: 13,
        ),
        dividerColor: Colors.transparent,
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: AppColors.white),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.navy,
        contentTextStyle: AppText.body(color: AppColors.white),
        actionTextColor: AppColors.gold,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        titleTextStyle: AppText.title(size: 18),
        contentTextStyle: AppText.body(),
        shape: rounded,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        showDragHandle: true,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.red,
        linearTrackColor: AppColors.divider,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.navy,
        textColor: AppColors.ink,
        titleTextStyle: AppText.body(color: AppColors.ink),
        subtitleTextStyle: AppText.label(),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.white
              : AppColors.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.success
              : AppColors.divider,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.success
              : AppColors.white,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.white),
        side: const BorderSide(color: AppColors.outline, width: 1.5),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.white,
        textStyle: AppText.body(),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
