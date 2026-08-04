import 'package:flutter/material.dart';

import 'app_theme_style.dart';
import 'vyra_style.dart';

/// Theme factory for VYRA. Three theme styles are supported — Modern
/// (premium Material 3), NeoBrutalism (bold flat colors, hard edges) and
/// Glass (frosted translucent surfaces) — each with light and dark variants.
class AppTheme {
  AppTheme._();

  static ThemeData light(Color seed) =>
      forStyle(AppThemeStyle.modern, Brightness.light, seed);

  static ThemeData dark(Color seed) =>
      forStyle(AppThemeStyle.modern, Brightness.dark, seed);

  static ThemeData forStyle(
    AppThemeStyle style,
    Brightness brightness,
    Color seed,
  ) =>
      switch (style) {
        AppThemeStyle.modern => _buildModern(brightness, seed),
        AppThemeStyle.neobrutalism => _buildNeoBrutalism(brightness),
        AppThemeStyle.glass => _buildGlass(brightness, seed),
      };

  /* ------------------------------ MODERN ------------------------------ */

  static ThemeData _buildModern(Brightness brightness, Color seed) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [
        VyraStyle(
          radius: 20,
          border: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
          quoteGradient: true,
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
      ),
    );
  }

  /* --------------------------- NEOBRUTALISM --------------------------- */

  static const _black = Color(0xFF111111);
  static const _cream = Color(0xFFF7F1E5);
  static const _paper = Color(0xFFFFFDF7);
  static const _pink = Color(0xFFFF4D6D);
  static const _yellow = Color(0xFFFFD60A);
  static const _blue = Color(0xFF3A86FF);
  static const _red = Color(0xFFFF0000);

  static ThemeData _buildNeoBrutalism(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final borderColor = isDark ? _cream : _black;
    final border = BorderSide(color: borderColor, width: 2.5);
    final base = ColorScheme.fromSeed(seedColor: _pink, brightness: brightness);
    final scheme = base.copyWith(
      primary: _pink,
      onPrimary: Colors.white,
      secondary: _yellow,
      onSecondary: _black,
      tertiary: _blue,
      onTertiary: Colors.white,
      error: _red,
      onError: Colors.white,
      surface: isDark ? _black : _cream,
      onSurface: isDark ? _cream : _black,
      surfaceContainerLowest: isDark ? const Color(0xFF1B1B1B) : _paper,
      surfaceContainerLow: isDark ? const Color(0xFF1B1B1B) : _paper,
      surfaceContainer: isDark ? const Color(0xFF242424) : _paper,
      surfaceContainerHigh: isDark ? const Color(0xFF2A2A2A) : _paper,
      surfaceContainerHighest: isDark ? const Color(0xFF2A2A2A) : _paper,
      onSurfaceVariant:
          isDark ? const Color(0xFFD8D2C2) : const Color(0xFF3A3A3A),
      outline: borderColor,
      outlineVariant: borderColor,
      primaryContainer: _yellow,
      onPrimaryContainer: _black,
      shadow: _black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [
        VyraStyle(
          radius: 10,
          border: border,
          hardShadow: BoxShadow(color: _black, offset: const Offset(0, 4)),
          uppercaseLabels: true,
          quoteGradient: false,
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: border,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF242424) : _paper,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: border,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: border,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _pink, width: 2.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: border,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: _yellow,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? _black
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: borderColor, thickness: 1.5),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _black,
        contentTextStyle: const TextStyle(color: _cream, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /* ------------------------------- GLASS ------------------------------- */

  static ThemeData _buildGlass(Brightness brightness, Color seed) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final cardColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.55);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.85);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF14151D) : const Color(0xFFE6EAF6),
      extensions: [
        VyraStyle(
          radius: 26,
          border: BorderSide(color: borderColor),
          hardShadow: BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          quoteGradient: false,
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: borderColor),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isDark ? Colors.black.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.6),
        indicatorColor: scheme.primaryContainer,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
    );
  }
}
