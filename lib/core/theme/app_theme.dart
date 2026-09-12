import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;

  static List<BoxShadow> softShadow({double opacity = .08}) => [
        BoxShadow(
          color: const Color(0xFF172033).withValues(alpha: opacity),
          blurRadius: 26,
          offset: const Offset(0, 12),
        ),
      ];

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return _build(base, Brightness.light);
  }

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return _build(base, Brightness.dark);
  }

  static ThemeData _build(ThemeData base, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? const Color(0xFF0B1220) : AppColors.background;
    final surface = dark ? const Color(0xFF111A2B) : AppColors.surface;
    final surfaceSoft = dark ? const Color(0xFF172235) : AppColors.surfaceSoft;
    final border = dark ? const Color(0xFF26344A) : AppColors.border;
    final primaryText = dark ? const Color(0xFFF1F5F9) : AppColors.textPrimary;
    final secondaryText = dark ? const Color(0xFFB8C4D6) : AppColors.textSecondary;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: primaryText,
      error: AppColors.error,
      onError: Colors.white,
      outline: border,
    );

    final text = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: primaryText,
      displayColor: primaryText,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: text,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xE60B1220) : Colors.transparent,
        foregroundColor: primaryText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: primaryText, fontSize: 18, fontWeight: FontWeight.w800),
        iconTheme: IconThemeData(color: primaryText, size: 22),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        elevation: 0,
        shadowColor: dark ? Colors.black54 : const Color(0x22172033),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(radiusLg)),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(radiusMd)), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(radiusMd)), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(radiusMd)), borderSide: const BorderSide(color: AppColors.primary, width: 1.6)),
        errorBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(radiusMd)), borderSide: const BorderSide(color: AppColors.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(radiusMd)), borderSide: const BorderSide(color: AppColors.error, width: 1.6)),
        hintStyle: TextStyle(color: dark ? const Color(0xFF718096) : AppColors.textMuted, fontSize: 14),
        prefixIconColor: secondaryText,
        suffixIconColor: secondaryText,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(44, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radiusMd))),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radiusMd))),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryText,
          minimumSize: const Size(44, 48),
          side: BorderSide(color: border, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radiusMd))),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceSoft,
        selectedColor: dark ? const Color(0xFF174E4A) : AppColors.primaryLight,
        labelStyle: TextStyle(color: primaryText, fontSize: 12.5, fontWeight: FontWeight.w700),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radiusSm))),
        side: BorderSide(color: border),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF1B2739) : null,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radiusMd))),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.all(Radius.circular(radiusSm))),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
