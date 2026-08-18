import 'package:flutter/material.dart';

enum EatsThemePreset {
  ateTrack,      // Ate Track (Default Vintage Gear)
  midnightBites, // Midnight Bites (Obsidian Dark)
  lightSnack,    // Light Snack (Studio Light)
  breakfast,     // Breakfast (Solarized Light)
  dinner,        // Dinner (Solarized Dark)
}

/// Central Theme Engine for Eatsbits.
/// Manages color tokens and typography styles for the application.
class EatsTheme {
  static EatsThemePreset currentPreset = EatsThemePreset.ateTrack;

  static bool get isLight =>
      currentPreset == EatsThemePreset.lightSnack ||
      currentPreset == EatsThemePreset.breakfast;

  // --- Dual-Context Font Settings ---
  static String primaryFontName = 'Sans Serif';
  static String displayFontName = 'Monospace';

  static const String _primaryFontFamily = 'sans-serif';
  static const String _displayFontFamily = 'monospace';

  /// Get TextStyle dynamically for Context 1 (Primary UI) with safety fallback
  static TextStyle getPrimaryFontStyle({double? fontSize, FontWeight? fontWeight, Color? color, TextDecoration? decoration}) {
    final baseStyle = TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color, decoration: decoration);
    return baseStyle.copyWith(fontFamily: _primaryFontFamily);
  }

  /// Get TextStyle dynamically for Context 2 (Display, Meters & Monospace Code) with safety fallback
  static TextStyle getDisplayFontStyle({double? fontSize, FontWeight? fontWeight, Color? color, TextDecoration? decoration}) {
    final baseStyle = TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color, decoration: decoration);
    return baseStyle.copyWith(fontFamily: _displayFontFamily);
  }

  // --- Color Palette Tokens ---
  static Color get backgroundDark {
    switch (currentPreset) {
      case EatsThemePreset.midnightBites:
        return const Color(0xFF000000);
      case EatsThemePreset.lightSnack:
        return const Color(0xFFF4F6F9); // Crisp clean light background
      case EatsThemePreset.breakfast:
        return const Color(0xFFFDF6E3); // Solarized base3 light background
      case EatsThemePreset.dinner:
        return const Color(0xFF002B36); // Solarized base03 dark background
      case EatsThemePreset.ateTrack:
      default:
        return const Color(0xFF141210); // Weathered vintage rack dark background
    }
  }

  static Color get panelBackground {
    switch (currentPreset) {
      case EatsThemePreset.midnightBites:
        return const Color(0xFF101010);
      case EatsThemePreset.lightSnack:
        return const Color(0xFFFFFFFF); // Pure white panel
      case EatsThemePreset.breakfast:
        return const Color(0xFFEEE8D5); // Solarized base2 panel
      case EatsThemePreset.dinner:
        return const Color(0xFF073642); // Solarized base02 panel
      case EatsThemePreset.ateTrack:
      default:
        return const Color(0xFF24211D); // Aged metal chassis surface
    }
  }

  static Color get panelHeader {
    switch (currentPreset) {
      case EatsThemePreset.midnightBites:
        return const Color(0xFF181818);
      case EatsThemePreset.lightSnack:
        return const Color(0xFFE2E8F0); // Light grey header
      case EatsThemePreset.breakfast:
        return const Color(0xFFE0D8C3); // Solarized light header
      case EatsThemePreset.dinner:
        return const Color(0xFF0A4858); // Solarized dark header
      case EatsThemePreset.ateTrack:
      default:
        return const Color(0xFF332F2A); // Dark brushed metallic header
    }
  }

  static Color get controlBackground {
    switch (currentPreset) {
      case EatsThemePreset.midnightBites:
        return const Color(0xFF222222);
      case EatsThemePreset.lightSnack:
        return const Color(0xFFCBD5E1); // Soft control fill
      case EatsThemePreset.breakfast:
        return const Color(0xFFE4DCC8); // Solarized light control well
      case EatsThemePreset.dinner:
        return const Color(0xFF001F27); // Solarized dark control well
      case EatsThemePreset.ateTrack:
      default:
        return const Color(0xFF181614); // Recessed control well background
    }
  }

  static Color get primaryCyan {
    switch (currentPreset) {
      case EatsThemePreset.lightSnack:
        return const Color(0xFF007799); // Deep Teal for high contrast
      case EatsThemePreset.breakfast:
        return const Color(0xFF2AA198); // Solarized Cyan
      case EatsThemePreset.dinner:
        return const Color(0xFF2AA198); // Solarized Cyan
      case EatsThemePreset.ateTrack:
        return const Color(0xFFFF8C00); // Warm Amber / Vintage Nixie Glow
      case EatsThemePreset.midnightBites:
      default:
        return const Color(0xFF21F4E8); // EatsBits Signature Cyan
    }
  }

  static Color get highlightColor {
    switch (currentPreset) {
      case EatsThemePreset.lightSnack:
        return const Color(0xFF0284C7);
      case EatsThemePreset.breakfast:
        return const Color(0xFF268BD2); // Solarized Blue
      case EatsThemePreset.dinner:
        return const Color(0xFF268BD2); // Solarized Blue
      case EatsThemePreset.ateTrack:
        return const Color(0xFFFF8C00);
      case EatsThemePreset.midnightBites:
      default:
        return const Color(0xFF21F4E8);
    }
  }

  static const Color secondaryMagenta = Color(0xFFFF007A);
  static const Color accentGold = Color(0xFFFFB700);
  static const Color accentGreen = Color(0xFF00FF66);
  static const Color accentOrange = Color(0xFFFF6B00);
  static const Color accentPurple = Color(0xFF9D4EDD);

  static const Color muteColor = Color(0xFFFF3B30);
  static const Color soloColor = Color(0xFFFFCC00);

  static Color get textPrimary {
    switch (currentPreset) {
      case EatsThemePreset.lightSnack:
        return const Color(0xFF0F172A);
      case EatsThemePreset.breakfast:
        return const Color(0xFF073642); // Solarized base02 (high contrast dark)
      case EatsThemePreset.dinner:
        return const Color(0xFFEEE8D5); // Solarized base2 (high contrast light)
      case EatsThemePreset.ateTrack:
      case EatsThemePreset.midnightBites:
      default:
        return const Color(0xFFF0F4F8);
    }
  }

  static Color get textLight => textPrimary;

  static Color get textSecondary {
    switch (currentPreset) {
      case EatsThemePreset.lightSnack:
        return const Color(0xFF334155);
      case EatsThemePreset.breakfast:
        return const Color(0xFF586E75); // Solarized base01
      case EatsThemePreset.dinner:
        return const Color(0xFF93A1A1); // Solarized base1
      case EatsThemePreset.ateTrack:
      case EatsThemePreset.midnightBites:
      default:
        return const Color(0xFF8E9BAE);
    }
  }

  static Color get textMuted {
    switch (currentPreset) {
      case EatsThemePreset.lightSnack:
        return const Color(0xFF64748B);
      case EatsThemePreset.breakfast:
        return const Color(0xFF93A1A1); // Solarized base1
      case EatsThemePreset.dinner:
        return const Color(0xFF586E75); // Solarized base01
      case EatsThemePreset.ateTrack:
      case EatsThemePreset.midnightBites:
      default:
        return const Color(0xFF535D6E);
    }
  }



  static ThemeData get themeData {
    final isLight = currentPreset == EatsThemePreset.lightSnack;
    final baseTheme = isLight ? ThemeData.light() : ThemeData.dark();

    return baseTheme.copyWith(
      scaffoldBackgroundColor: backgroundDark,
      primaryColor: primaryCyan,
      cardColor: panelBackground,
      colorScheme: (isLight ? const ColorScheme.light() : const ColorScheme.dark()).copyWith(
        primary: primaryCyan,
        secondary: secondaryMagenta,
        surface: panelBackground,
      ),
      textTheme: baseTheme.textTheme.apply(
        fontFamily: _primaryFontFamily,
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ).copyWith(
        bodyLarge: getPrimaryFontStyle(color: textPrimary, fontSize: 14),
        bodyMedium: getPrimaryFontStyle(color: textPrimary, fontSize: 13),
        bodySmall: getPrimaryFontStyle(color: textSecondary, fontSize: 11),
        titleLarge: getPrimaryFontStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        titleMedium: getPrimaryFontStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
        titleSmall: getPrimaryFontStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
        labelLarge: getPrimaryFontStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
        labelMedium: getPrimaryFontStyle(color: textSecondary, fontSize: 10),
        labelSmall: getPrimaryFontStyle(color: textMuted, fontSize: 9),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryCyan,
        inactiveTrackColor: controlBackground,
        thumbColor: primaryCyan,
        overlayColor: primaryCyan.withOpacity(0.2),
        trackHeight: 3.0,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
      ),
    );
  }
}
