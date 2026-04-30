import 'package:flutter/material.dart';

/// Global theme for FactoryOS.  Industrial palette: deep slate background,
/// safety-orange accents, clean Roboto type scale.
class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF0D47A1);
  static const Color secondary = Color(0xFFFF6F00);
  static const Color surface = Color(0xFFF5F7FA);
  static const Color surfaceDark = Color(0xFF101418);

  static const Color statusPending = Color(0xFF9E9E9E);
  static const Color statusAssigned = Color(0xFF1976D2);
  static const Color statusInProgress = Color(0xFFFFA000);
  static const Color statusReadyForQa = Color(0xFF7B1FA2);
  static const Color statusApproved = Color(0xFF2E7D32);
  static const Color statusRejected = Color(0xFFC62828);
  static const Color statusCompleted = Color(0xFF455A64);
  static const Color statusCancelled = Color(0xFF616161);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        secondary: secondary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: surface,
    );
    return _decorate(base);
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        secondary: secondary,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: surfaceDark,
    );
    return _decorate(base);
  }

  static ThemeData _decorate(ThemeData base) {
    return base.copyWith(
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: base.colorScheme.surface,
        foregroundColor: base.colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: base.colorScheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        useIndicator: true,
        indicatorColor: base.colorScheme.primaryContainer,
        labelType: NavigationRailLabelType.all,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textTheme: base.textTheme.copyWith(
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.35),
      ),
    );
  }
}
