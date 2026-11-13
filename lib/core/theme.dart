import 'package:flutter/material.dart';

class AppColors {
  static const seed = Color(0xFF4F46E5); // indigo
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFEA580C);
  static const info = Color(0xFF0284C7);
  static const purple = Color(0xFF9333EA);
  static const pink = Color(0xFFDB2777);
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(seedColor: AppColors.seed, brightness: brightness);
    final isLight = brightness == Brightness.light;
    final background = isLight ? const Color(0xFFF5F6FA) : scheme.surface;
    final cardColor = isLight ? Colors.white : scheme.surfaceContainer;
    final radius12 = BorderRadius.circular(12);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cardColor,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : scheme.surfaceContainerHighest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        extendedTextStyle:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        indicatorColor: scheme.primaryContainer,
        elevation: 3,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: const ChipThemeData(shape: StadiumBorder()),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
