import 'package:flutter/material.dart';

/// Central design tokens so every surface reads as one cohesive app.
class AppColors {
  // Layered surfaces (background -> panel -> elevated).
  static const bg = Color(0xFF0E1116);
  static const stage = Color(0xFF0B0E12);
  static const panel = Color(0xFF161A20);
  static const panel2 = Color(0xFF1D222A);
  static const elev = Color(0xFF232A33);

  static const line = Color(0xFF2A313B);
  static const line2 = Color(0xFF333C47);

  static const tx = Color(0xFFEDF1F6);
  static const tx2 = Color(0xFF9AA4B0);
  static const tx3 = Color(0xFF69727E);

  static const accent = Color(0xFF2FB463);
  static const accentDim = Color(0xFF238A4C);
  static const danger = Color(0xFFE2504A);

  static const home = Color(0xFFE23B3B);
  static const away = Color(0xFF2E6CF0);
  static const ball = Color(0xFFF5D93B);
}

class AppRadii {
  static const panel = 14.0;
  static const control = 9.0;
  static const chip = 7.0;
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.dark,
  ).copyWith(
    surface: AppColors.panel,
    primary: AppColors.accent,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: '.AppleSystemUIFont',
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.tx),
      bodyMedium: TextStyle(fontSize: 13.5, color: AppColors.tx),
      labelLarge: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
    ),
    dividerColor: AppColors.line,
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: AppColors.accent,
      inactiveTrackColor: AppColors.panel2,
      thumbColor: Colors.white,
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xF01B2028),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.line2),
      ),
      textStyle: const TextStyle(fontSize: 12, color: AppColors.tx),
      waitDuration: const Duration(milliseconds: 350),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.panel2,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: const BorderSide(color: AppColors.line2),
      ),
      textStyle: const TextStyle(fontSize: 13, color: AppColors.tx),
      labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 13, color: AppColors.tx)),
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppColors.panel2),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(10),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
          side: const BorderSide(color: AppColors.line2),
        )),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.panel2,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line2),
      ),
      titleTextStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.tx),
      contentTextStyle: const TextStyle(fontSize: 13.5, color: AppColors.tx2, height: 1.4),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.elev,
      contentTextStyle: const TextStyle(color: AppColors.tx, fontSize: 13),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.accent : AppColors.panel),
        foregroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? const Color(0xFF08130B) : AppColors.tx2),
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.line2)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AppColors.panel2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.tx3, fontSize: 13),
    ),
  );
}
