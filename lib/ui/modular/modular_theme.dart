import 'package:flutter/material.dart';

/// Design tokens, sizing, and color palette for the Eatsbits Modular Rack system.
class ModularTheme {
  // --- SIZING TOKENS ---
  /// Sizing unit in HP (Horizontal Pitch, 1HP ≈ 16.0 logical pixels).
  static const double standardHpUnit = 16.0;
  static const double hpWidth = 16.0;

  /// Standard 3U Modular Rack Module Height.
  static const double moduleHeight = 185.0;

  /// Height of the top and bottom aluminum mounting rails.
  static const double railBarHeight = 16.0;

  // --- COLOR PALETTE ---
  /// Dark textured case interior.
  static const Color caseBackground = Color(0xFF141619);

  /// Anodized aluminum rack rails with screw guide slots.
  static const Color railMetalColor = Color(0xFF23272E);
  static const Color railSlotColor = Color(0xFF111317);
  static const Color railScrewColor = Color(0xFF6E7687);

  /// Brushed aluminum module faceplates.
  static const Color faceplateDarkBg = Color(0xFF1E222B);
  static const Color faceplateLightBg = Color(0xFF282D37);
  static const Color faceplateBorder = Color(0xFF383F4D);

  /// 3.5mm Jack metal bezel.
  static const Color jackBezelMetal = Color(0xFF7E8494);
  static const Color jackHoleColor = Color(0xFF0A0C0E);

  /// Faceplate hex screw metal color.
  static const Color screwColor = Color(0xFF6E7687);

  // --- SIGNAL & CABLE COLORS ---
  /// Audio rate signals (Warm Amber/Red).
  static const Color cableAudio = Color(0xFFFF5722);

  /// Control Voltage / Pitch CV signals (Volt-per-Octave Blue/Cyan).
  static const Color cablePitchCv = Color(0xFF00E5FF);

  /// Gate / Trigger clock pulses (High-vis Yellow).
  static const Color cableGate = Color(0xFFFFD600);

  /// Low Frequency Modulation CV (Neon Green/Lime).
  static const Color cableModulation = Color(0xFF00E676);

  /// Digital Sync / Echo / Feedback (Electric Violet).
  static const Color cableDigital = Color(0xFFE040FB);

  /// Available cable palette for user customization.
  static const List<Color> cablePalette = [
    cableAudio,
    cablePitchCv,
    cableGate,
    cableModulation,
    cableDigital,
    Color(0xFFFF4081),
    Color(0xFF7C4DFF),
    Color(0xFF00B0FF),
  ];
}

// Backward compatibility alias
typedef EurorackTheme = ModularTheme;
