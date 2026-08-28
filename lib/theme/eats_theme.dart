import 'package:flutter/material.dart';

enum EatsThemePreset {
  ateTrack,      // Ate Track (Default Vintage Gear)
  midnightBites, // Midnight Bites (Obsidian Dark)
  lightSnack,    // Light Snack (Studio Light)
  breakfast,     // Breakfast (Solarized Light)
  dinner,        // Dinner (Solarized Dark)
}

/// Central Theme Engine for Eatsbeats.
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
  static TextStyle getPrimaryFontStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    TextDecoration? decoration,
    double? letterSpacing,
  }) {
    final baseStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      decoration: decoration,
      letterSpacing: letterSpacing,
    );
    return baseStyle.copyWith(fontFamily: _primaryFontFamily);
  }

  /// Get TextStyle dynamically for Context 2 (Display, Meters & Monospace Code) with safety fallback
  static TextStyle getDisplayFontStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    TextDecoration? decoration,
    double? letterSpacing,
  }) {
    final baseStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      decoration: decoration,
      letterSpacing: letterSpacing,
    );
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
        return const Color(0xFF21F4E8); // EatsBeats Signature Cyan
    }
  }

  static Color get accentCyan => primaryCyan;

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

  /// Display text color for tempo/BPM, glowing nixie displays, and LCD readouts on dark glass.
  static Color get tempoTextColor {
    switch (currentPreset) {
      case EatsThemePreset.ateTrack:
        return const Color(0xFFFFF2D6); // Warm glowing amber-cream
      case EatsThemePreset.midnightBites:
        return const Color(0xFFE0FFFF); // Electric neon cyan-white
      case EatsThemePreset.lightSnack:
        return const Color(0xFFE0F7FA); // Crisp illuminated cyan-white
      case EatsThemePreset.breakfast:
        return const Color(0xFFFFF8E7); // Luminous solarized warm gold
      case EatsThemePreset.dinner:
        return const Color(0xFFEEE8D5); // Solarized luminous light
      default:
        return const Color(0xFFF0F4F8);
    }
  }

  /// Ambient bloom glow color for Nixie tubes and illuminated digits.
  static Color get tempoGlowColor {
    switch (currentPreset) {
      case EatsThemePreset.ateTrack:
        return const Color(0xFFFF8C00); // Vintage Amber Glow
      case EatsThemePreset.midnightBites:
        return const Color(0xFF21F4E8); // Cyber Neon Cyan Glow
      case EatsThemePreset.lightSnack:
        return const Color(0xFF00B4D8); // Electric Ice Blue Glow
      case EatsThemePreset.breakfast:
        return const Color(0xFFB58900); // Solarized Gold Tube Glow
      case EatsThemePreset.dinner:
        return const Color(0xFF2AA198); // Solarized Cyan Glow
      default:
        return const Color(0xFF21F4E8);
    }
  }

  /// Mixer & hardware LCD screen background well color.
  static Color get lcdBackground {
    switch (currentPreset) {
      case EatsThemePreset.ateTrack:
        return const Color(0xFF141210);
      case EatsThemePreset.midnightBites:
        return const Color(0xFF080D11);
      case EatsThemePreset.lightSnack:
        return const Color(0xFFE2E8F0);
      case EatsThemePreset.breakfast:
        return const Color(0xFFE8E2CF);
      case EatsThemePreset.dinner:
        return const Color(0xFF00212B);
      default:
        return const Color(0xFF0F1510);
    }
  }

  /// Mixer & hardware LCD screen bevel border color.
  static Color get lcdBorder {
    switch (currentPreset) {
      case EatsThemePreset.ateTrack:
        return const Color(0xFF3B3226);
      case EatsThemePreset.midnightBites:
        return const Color(0xFF132A32);
      case EatsThemePreset.lightSnack:
        return const Color(0xFF94A3B8);
      case EatsThemePreset.breakfast:
        return const Color(0xFFB58900);
      case EatsThemePreset.dinner:
        return const Color(0xFF0A4858);
      default:
        return const Color(0xFF2A3628);
    }
  }

  /// Mixer & hardware LCD screen pixel text readout color.
  static Color get lcdTextColor {
    switch (currentPreset) {
      case EatsThemePreset.ateTrack:
        return const Color(0xFFFFB347); // Vintage amber LCD pixels
      case EatsThemePreset.midnightBites:
        return const Color(0xFF38EEDD); // Neon cyan LCD pixels
      case EatsThemePreset.lightSnack:
        return const Color(0xFF0F172A); // High-contrast crisp studio slate
      case EatsThemePreset.breakfast:
        return const Color(0xFF586E75); // Solarized base01
      case EatsThemePreset.dinner:
        return const Color(0xFF2AA198); // Solarized cyan
      default:
        return const Color(0xFF98B890);
    }
  }

  /// Mixer & hardware LCD pixel dot matrix grid pattern color.
  static Color get lcdDotColor {
    switch (currentPreset) {
      case EatsThemePreset.ateTrack:
        return const Color(0xFF221C16);
      case EatsThemePreset.midnightBites:
        return const Color(0xFF0E1A22);
      case EatsThemePreset.lightSnack:
        return const Color(0xFFCBD5E1);
      case EatsThemePreset.breakfast:
        return const Color(0xFFDDD5C0);
      case EatsThemePreset.dinner:
        return const Color(0xFF073642);
      default:
        return const Color(0xFF141F16);
    }
  }

  /// Mixer & hardware LCD pixel optical bloom glow color.
  static Color get lcdGlowColor {
    switch (currentPreset) {
      case EatsThemePreset.ateTrack:
        return const Color(0x66FF8C00);
      case EatsThemePreset.midnightBites:
        return const Color(0x6621F4E8);
      case EatsThemePreset.lightSnack:
        return const Color(0x22007799);
      case EatsThemePreset.breakfast:
        return const Color(0x33B58900);
      case EatsThemePreset.dinner:
        return const Color(0x662AA198);
      default:
        return const Color(0x99486840);
    }
  }

  /// Text color for Arranger clip headers and names.
  static Color get clipTextColor {
    switch (currentPreset) {
      case EatsThemePreset.lightSnack:
        return const Color(0xFF0F172A);
      case EatsThemePreset.breakfast:
        return const Color(0xFF073642);
      case EatsThemePreset.dinner:
        return const Color(0xFFEEE8D5);
      case EatsThemePreset.ateTrack:
        return const Color(0xFFFFF2D6);
      case EatsThemePreset.midnightBites:
      default:
        return const Color(0xFFF0F4F8);
    }
  }

  /// Text color for Chord Track clip headers and progression tags.
  static Color get chordTrackTextColor {
    switch (currentPreset) {
      case EatsThemePreset.lightSnack:
        return const Color(0xFF0F172A);
      case EatsThemePreset.breakfast:
        return const Color(0xFF073642);
      case EatsThemePreset.dinner:
        return const Color(0xFFEEE8D5);
      case EatsThemePreset.ateTrack:
        return const Color(0xFFFFE0B2);
      case EatsThemePreset.midnightBites:
      default:
        return const Color(0xFFE0FFFF);
    }
  }

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

  /// Script editor background canvas color
  static Color get codeEditorBackground {
    switch (currentPreset) {
      case EatsThemePreset.lightSnack:
        return const Color(0xFFFFFFFF); // Clean white editor
      case EatsThemePreset.breakfast:
        return const Color(0xFFFDF6E3); // Solarized light base3
      case EatsThemePreset.dinner:
        return const Color(0xFF002B36); // Solarized dark base03
      case EatsThemePreset.ateTrack:
        return const Color(0xFF141210); // Weathered grungy dark
      case EatsThemePreset.midnightBites:
      default:
        return const Color(0xFF0D0F17); // Obsidian code dark
    }
  }

  /// Script editor line number gutter background color
  static Color get codeEditorGutterBackground {
    switch (currentPreset) {
      case EatsThemePreset.lightSnack:
        return const Color(0xFFF1F5F9); // Slate-100 gutter
      case EatsThemePreset.breakfast:
        return const Color(0xFFEEE8D5); // Solarized base2 gutter
      case EatsThemePreset.dinner:
        return const Color(0xFF073642); // Solarized base02 gutter
      case EatsThemePreset.ateTrack:
        return const Color(0xFF1B1814); // Grungy rack gutter
      case EatsThemePreset.midnightBites:
      default:
        return const Color(0xFF08090E); // Deep dark gutter
    }
  }

  /// Script editor primary text color
  static Color get codeEditorTextColor {
    switch (currentPreset) {
      case EatsThemePreset.lightSnack:
        return const Color(0xFF0F172A); // High-contrast slate-900
      case EatsThemePreset.breakfast:
        return const Color(0xFF073642); // Solarized base02 high contrast
      case EatsThemePreset.dinner:
        return const Color(0xFF2AA198); // Solarized cyan
      case EatsThemePreset.ateTrack:
        return const Color(0xFFFFD580); // Warm amber text
      case EatsThemePreset.midnightBites:
      default:
        return const Color(0xFF00FFCC); // Neon cyber cyan
    }
  }

  /// Script editor line number text color
  static Color get codeEditorGutterTextColor {
    switch (currentPreset) {
      case EatsThemePreset.lightSnack:
        return const Color(0xFF94A3B8);
      case EatsThemePreset.breakfast:
        return const Color(0xFF93A1A1);
      case EatsThemePreset.dinner:
        return const Color(0xFF586E75);
      case EatsThemePreset.ateTrack:
      case EatsThemePreset.midnightBites:
      default:
        return const Color(0xFF535D6E);
    }
  }

  /// Script editor border color
  static Color get codeEditorBorder {
    switch (currentPreset) {
      case EatsThemePreset.lightSnack:
        return const Color(0xFFCBD5E1);
      case EatsThemePreset.breakfast:
        return const Color(0xFFD33682).withOpacity(0.3);
      case EatsThemePreset.dinner:
        return const Color(0xFF2AA198).withOpacity(0.4);
      case EatsThemePreset.ateTrack:
        return const Color(0xFF3B332A);
      case EatsThemePreset.midnightBites:
      default:
        return const Color(0xFF2B3245);
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
      popupMenuTheme: PopupMenuThemeData(
        color: panelHeader,
        surfaceTintColor: Colors.transparent,
        textStyle: getPrimaryFontStyle(color: textPrimary, fontSize: 11),
        labelTextStyle: WidgetStateProperty.all(getPrimaryFontStyle(color: textPrimary, fontSize: 11)),
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
