import 'package:flutter/material.dart';
import 'eat_hardware_scale.dart';

enum EatCapStyle {
  flat,
  brushedMetal,
  convexDome,
  insetRim,
  diagonalBar,
  declinedScoop,
}

enum EatSkirtStyle {
  straight,
  flared,
  stepped,
}

enum EatKnurlStyle {
  none,
  fluted,
  diamond,
  serrated,
  fineSawtooth,
}

enum EatIndicatorStyle {
  line,
  pipDot,
  illuminatedLed,
  triangleNeedle,
}

enum EatArcMode {
  disabled,
  unipolar,
  bipolarCenter,
}

enum EatBezelStyle {
  none,
  gutter,
  threadedNut,
  hexCollar,
}

/// Comprehensive hardware knob visual specification adhering to the
/// 6-Zone Anatomical Taxonomy and Zero-Allocation Performance Constraints.
class EatHardwareKnobStyle {
  // 1. Cap & Insert Disc
  final EatCapStyle capStyle;
  final Color capColor;
  final double bevelWidth;
  final double? capRadiusRatio; // Configurable ratio of baseRadius (0.50 .. 0.98)

  // 2. Main Body & Skirt
  final EatSkirtStyle skirtStyle;
  final Color bodyColor;
  final double skirtRadiusRatio; // e.g. 1.0 for straight, 1.25 for flared skirt
  final double bodyElevation;    // Visual depth / rim thickness

  // 3. Knurling & Grip Texture
  final EatKnurlStyle knurlStyle;
  final int ribCount;            // 0 for smooth, 16..36 for fluted notches
  final double ribDepth;
  final Color? knurlColor;

  // 4. Indicator / Position Pointer
  final EatIndicatorStyle indicatorStyle;
  final Color indicatorColor;
  final double indicatorLength;  // Ratio of cap radius (0.2 .. 0.95)
  final double indicatorWidth;

  // 5. Mounting Bezel / Collar
  final EatBezelStyle bezelStyle;
  final Color? bezelColor;
  final double bezelWidth;

  // 6. Dial Scale & Halo Track
  final EatScaleGraduation scale;
  final EatArcMode arcMode;
  final Color trackActiveColor;
  final Color trackInactiveColor;
  final double trackThickness;
  final double trackRadiusRatio;

  // 7. Ambient / Trench Backlight Halo (e.g., D16 Phoscyon 2 acid green or track color)
  final Color? haloColor;

  const EatHardwareKnobStyle({
    this.capStyle = EatCapStyle.flat,
    required this.capColor,
    this.bevelWidth = 1.0,
    this.capRadiusRatio,
    this.skirtStyle = EatSkirtStyle.straight,
    required this.bodyColor,
    this.skirtRadiusRatio = 1.0,
    this.bodyElevation = 2.0,
    this.knurlStyle = EatKnurlStyle.none,
    this.ribCount = 0,
    this.ribDepth = 1.5,
    this.knurlColor,
    this.indicatorStyle = EatIndicatorStyle.line,
    required this.indicatorColor,
    this.indicatorLength = 0.85,
    this.indicatorWidth = 2.0,
    this.bezelStyle = EatBezelStyle.gutter,
    this.bezelColor,
    this.bezelWidth = 1.5,
    this.scale = const EatScaleGraduation(),
    this.arcMode = EatArcMode.disabled,
    this.trackActiveColor = const Color(0xFF00E5FF),
    this.trackInactiveColor = const Color(0x33000000),
    this.trackThickness = 2.5,
    this.trackRadiusRatio = 1.15,
    this.haloColor,
  });

  /// Preset 1: Cream Vintage Fluted (Kick & Snare Pitch).
  /// Features an off-white fluted cap, recessed black notch pointer line,
  /// and an arc halo with "low - mid - high" semantic graduations.
  factory EatHardwareKnobStyle.creamFluted({
    Color? accentColor,
    Color? textColor,
  }) {
    final active = accentColor ?? const Color(0xFF222226);
    return EatHardwareKnobStyle(
      capStyle: EatCapStyle.insetRim,
      capColor: const Color(0xFFE8E5DC),       // Cream off-white
      bodyColor: const Color(0xFFC7C2B4),      // Muted vintage body
      skirtStyle: EatSkirtStyle.flared,
      skirtRadiusRatio: 1.14,
      knurlStyle: EatKnurlStyle.fluted,
      ribCount: 20,
      ribDepth: 1.2,
      knurlColor: const Color(0xFFA8A395),
      indicatorStyle: EatIndicatorStyle.line,
      indicatorColor: const Color(0xFF1E1E22),  // Black etched notch
      indicatorLength: 0.85,
      indicatorWidth: 2.2,
      bezelStyle: EatBezelStyle.gutter,
      scale: EatScaleGraduation.lowMidHigh(
        tickColor: const Color(0xFF222226),
        labelColor: textColor ?? const Color(0xFF1E1E22),
      ),
      arcMode: EatArcMode.unipolar,
      trackActiveColor: active,
      trackInactiveColor: const Color(0x28000000),
      trackThickness: 2.0,
      trackRadiusRatio: 1.20,
    );
  }

  /// Preset 2: Vintage Bakelite with Flared Skirt (Kick Body & Snare Wires).
  /// Deep charcoal/black console body with wide flared skirt against faceplate,
  /// crisp white radial notch line, and 0 to 10 graduation scale.
  factory EatHardwareKnobStyle.vintageBakelite({
    Color? accentColor,
    Color? textColor,
  }) {
    return EatHardwareKnobStyle(
      capStyle: EatCapStyle.flat,
      capColor: const Color(0xFF202024),       // Deep Bakelite black
      bodyColor: const Color(0xFF2C2C32),      // Charcoal core
      skirtStyle: EatSkirtStyle.flared,
      skirtRadiusRatio: 1.24,
      knurlStyle: EatKnurlStyle.none,
      indicatorStyle: EatIndicatorStyle.line,
      indicatorColor: const Color(0xFFFFFFFF),  // High-contrast white notch
      indicatorLength: 0.88,
      indicatorWidth: 2.2,
      bezelStyle: EatBezelStyle.gutter,
      scale: EatScaleGraduation.zeroToTen(
        tickColor: const Color(0xFF1E1E24),
        labelColor: textColor ?? const Color(0xFF1E1E24),
      ),
      arcMode: EatArcMode.disabled,
    );
  }

  /// Preset 3: Anodized Knurled Metal (Snare Sustain & Head).
  /// Silver knurled tactile perimeter grip ring, recessed flat face insert,
  /// and high-contrast pointer line.
  factory EatHardwareKnobStyle.anodizedKnurled({
    bool isSustain = false,
    Color? accentColor,
    Color? textColor,
  }) {
    return EatHardwareKnobStyle(
      capStyle: EatCapStyle.brushedMetal,
      capColor: const Color(0xFFDEDCD5),       // Brushed light metal insert
      bodyColor: const Color(0xFF90939A),      // Anodized silver body
      skirtStyle: EatSkirtStyle.straight,
      skirtRadiusRatio: 1.08,
      knurlStyle: EatKnurlStyle.diamond,
      ribCount: 32,
      ribDepth: 1.8,
      knurlColor: const Color(0xFF4B4F58),      // Dark metal knurl grooves
      indicatorStyle: EatIndicatorStyle.line,
      indicatorColor: const Color(0xFF1E1E22),
      indicatorLength: 0.86,
      indicatorWidth: 2.2,
      bezelStyle: EatBezelStyle.gutter,
      scale: isSustain
          ? EatScaleGraduation.sustainOneToSix(
              tickColor: const Color(0xFF1E1E24),
              labelColor: textColor ?? const Color(0xFF1E1E24),
            )
          : EatScaleGraduation.zeroToTen(
              tickColor: const Color(0xFF1E1E24),
              labelColor: textColor ?? const Color(0xFF1E1E24),
            ),
      arcMode: EatArcMode.disabled,
    );
  }

  /// Preset 4: Two-Tone Stepped Console Knob (Kick Punch & Snare Rattle).
  /// Off-white center cap seated in a stepped dark skirt flange with white notch.
  factory EatHardwareKnobStyle.twoToneStepped({
    Color? accentColor,
    Color? textColor,
  }) {
    return EatHardwareKnobStyle(
      capStyle: EatCapStyle.insetRim,
      capColor: const Color(0xFFE2DDD5),       // Cream insert
      bodyColor: const Color(0xFF28282D),      // Dark stepped skirt
      skirtStyle: EatSkirtStyle.stepped,
      skirtRadiusRatio: 1.25,
      knurlStyle: EatKnurlStyle.none,
      indicatorStyle: EatIndicatorStyle.line,
      indicatorColor: const Color(0xFFFFFFFF),  // Crisp white indicator
      indicatorLength: 0.85,
      indicatorWidth: 2.2,
      bezelStyle: EatBezelStyle.gutter,
      scale: EatScaleGraduation.zeroToTen(
        tickColor: const Color(0xFF1E1E24),
        labelColor: textColor ?? const Color(0xFF1E1E24),
      ),
      arcMode: EatArcMode.disabled,
    );
  }

  /// Preset 5: Illuminated Modern Studio Encoder (Cyan/Amber LED Pip).
  factory EatHardwareKnobStyle.illuminatedEncoder({
    Color activeColor = const Color(0xFF00E5FF),
  }) {
    return EatHardwareKnobStyle(
      capStyle: EatCapStyle.convexDome,
      capColor: const Color(0xFF18181C),
      bodyColor: const Color(0xFF24242A),
      skirtStyle: EatSkirtStyle.straight,
      skirtRadiusRatio: 1.05,
      knurlStyle: EatKnurlStyle.serrated,
      ribCount: 24,
      ribDepth: 1.4,
      indicatorStyle: EatIndicatorStyle.illuminatedLed,
      indicatorColor: activeColor,
      indicatorLength: 0.78,
      indicatorWidth: 4.0,
      scale: EatScaleGraduation.cleanTicks(
        divisions: 10,
        tickColor: activeColor.withOpacity(0.4),
      ),
      arcMode: EatArcMode.unipolar,
      trackActiveColor: activeColor,
      trackInactiveColor: const Color(0x33000000),
      trackThickness: 3.0,
    );
  }

  /// Preset 6: Standard Metallic Hardware Knob (Eatsbeats Studio Standard).
  factory EatHardwareKnobStyle.standardHardware({
    Color? accentColor,
    Color? textColor,
  }) {
    final active = accentColor ?? const Color(0xFF00E5FF);
    return EatHardwareKnobStyle(
      capStyle: EatCapStyle.flat,
      capColor: const Color(0xFF1E2026),
      bodyColor: const Color(0xFF2A2D35),
      skirtStyle: EatSkirtStyle.straight,
      skirtRadiusRatio: 1.08,
      knurlStyle: EatKnurlStyle.fluted,
      ribCount: 24,
      ribDepth: 1.5,
      knurlColor: const Color(0xFF16181D),
      indicatorStyle: EatIndicatorStyle.line,
      indicatorColor: active,
      indicatorLength: 0.85,
      indicatorWidth: 2.2,
      bezelStyle: EatBezelStyle.gutter,
      scale: EatScaleGraduation.cleanTicks(
        divisions: 10,
        tickColor: const Color(0xFF3E434F),
        labelColor: textColor ?? const Color(0xFF1E1E24),
      ),
      arcMode: EatArcMode.unipolar,
      trackActiveColor: active,
      trackInactiveColor: const Color(0x33000000),
      trackThickness: 2.5,
      trackRadiusRatio: 1.15,
    );
  }

  /// Preset 7: Chrome Fluted Rotary Knob (Vintage 303 Bassline).
  factory EatHardwareKnobStyle.chromeFluted({
    Color? accentColor,
    Color? textColor,
  }) {
    return EatHardwareKnobStyle(
      capStyle: EatCapStyle.brushedMetal,
      capColor: const Color(0xFFDCDFE5),
      bodyColor: const Color(0xFFB0B4BC),
      skirtStyle: EatSkirtStyle.flared,
      skirtRadiusRatio: 1.18,
      knurlStyle: EatKnurlStyle.fluted,
      ribCount: 20,
      ribDepth: 1.6,
      knurlColor: const Color(0xFF8C909A),
      indicatorStyle: EatIndicatorStyle.line,
      indicatorColor: const Color(0xFF141416),
      indicatorLength: 0.86,
      indicatorWidth: 2.2,
      bezelStyle: EatBezelStyle.gutter,
      bezelColor: const Color(0xFF80848D),
      scale: EatScaleGraduation.zeroToTen(
        tickColor: const Color(0xFF2B2E36),
        labelColor: textColor ?? const Color(0xFF1E1E24),
      ),
      arcMode: EatArcMode.disabled,
    );
  }

  /// Preset 8: SNES Console Cream (16-Bit Retro Faceplate).
  factory EatHardwareKnobStyle.snesConsole({
    Color? accentColor,
    Color? textColor,
  }) {
    return EatHardwareKnobStyle(
      capStyle: EatCapStyle.convexDome,
      capColor: const Color(0xFFE4E1D8),
      bodyColor: const Color(0xFFCAC6BB),
      skirtStyle: EatSkirtStyle.stepped,
      skirtRadiusRatio: 1.15,
      knurlStyle: EatKnurlStyle.none,
      indicatorStyle: EatIndicatorStyle.line,
      indicatorColor: const Color(0xFF51388E),
      indicatorLength: 0.82,
      indicatorWidth: 2.5,
      bezelStyle: EatBezelStyle.gutter,
      bezelColor: const Color(0xFFB0ACA0),
      scale: EatScaleGraduation.cleanTicks(
        divisions: 8,
        tickColor: const Color(0xFF6B6874),
        labelColor: textColor ?? const Color(0xFF51388E),
      ),
      arcMode: EatArcMode.disabled,
    );
  }

  /// Preset 9: Minimalist Matte Ceramic (Dieter Rams / OP-1 Aesthetic).
  factory EatHardwareKnobStyle.minimalWhite({
    Color? accentColor,
    Color? textColor,
  }) {
    final active = accentColor ?? const Color(0xFF1A1A1E);
    return EatHardwareKnobStyle(
      capStyle: EatCapStyle.flat,
      capColor: const Color(0xFFF6F6F7),
      bodyColor: const Color(0xFFE4E5E8),
      skirtStyle: EatSkirtStyle.straight,
      skirtRadiusRatio: 1.0,
      knurlStyle: EatKnurlStyle.none,
      indicatorStyle: EatIndicatorStyle.line,
      indicatorColor: const Color(0xFF1A1A1E),
      indicatorLength: 0.88,
      indicatorWidth: 1.6,
      bezelStyle: EatBezelStyle.none,
      scale: EatScaleGraduation.cleanTicks(
        divisions: 8,
        tickColor: const Color(0xFFBBBDC4),
        labelColor: textColor ?? const Color(0xFF1E1E24),
      ),
      arcMode: EatArcMode.unipolar,
      trackActiveColor: active,
      trackInactiveColor: const Color(0x18000000),
      trackThickness: 1.8,
      trackRadiusRatio: 1.12,
    );
  }

  /// Preset 10: Roland TB-303 Fine-Serrated Potentiometer (Cutoff & Resonance).
  /// Features 48 fine-tooth triangular flutes, authentic declined wedge scoop cap,
  /// chassis gutter trench ring, and 10-division dial with bold 12 o'clock center mark.
  factory EatHardwareKnobStyle.tb303Potentiometer({
    Color? accentColor,
    Color? textColor,
  }) {
    return EatHardwareKnobStyle(
      capStyle: EatCapStyle.declinedScoop,
      capColor: const Color(0xFFE2E4E8),
      bodyColor: const Color(0xFFB4B9C2),
      skirtStyle: EatSkirtStyle.straight,
      skirtRadiusRatio: 1.05,
      knurlStyle: EatKnurlStyle.fineSawtooth,
      ribCount: 48,
      ribDepth: 1.4,
      knurlColor: const Color(0xFF5A5E69),
      indicatorStyle: EatIndicatorStyle.line,
      indicatorColor: const Color(0xFF141416),
      indicatorLength: 0.88,
      indicatorWidth: 2.0,
      bezelStyle: EatBezelStyle.gutter,
      bezelColor: const Color(0xFF26282E),
      bezelWidth: 1.4,
      scale: EatScaleGraduation.tb303Dial(
        tickColor: const Color(0xFF22242B),
        labelColor: textColor ?? const Color(0xFF1E1E24),
      ),
      arcMode: EatArcMode.disabled,
    );
  }

  /// Preset 11: TB-303 Acid Neon Halo Glow (D16 Phoscyon Aesthetic).
  /// Combines the 48-tooth fluted aluminum knob with a luminous glowing acid green
  /// (or customizable track accent) backlight ring recessed into the chassis gutter.
  factory EatHardwareKnobStyle.tb303AcidHalo({
    Color? accentColor,
    Color? textColor,
  }) {
    final glow = accentColor ?? const Color(0xFF00FF88);
    return EatHardwareKnobStyle(
      capStyle: EatCapStyle.declinedScoop,
      capColor: const Color(0xFFE0E3E7),
      bodyColor: const Color(0xFFB0B5BF),
      skirtStyle: EatSkirtStyle.straight,
      skirtRadiusRatio: 1.06,
      knurlStyle: EatKnurlStyle.fineSawtooth,
      ribCount: 48,
      ribDepth: 1.4,
      knurlColor: const Color(0xFF585D68),
      indicatorStyle: EatIndicatorStyle.line,
      indicatorColor: const Color(0xFF121214),
      indicatorLength: 0.88,
      indicatorWidth: 2.0,
      bezelStyle: EatBezelStyle.gutter,
      bezelColor: const Color(0xFF1E2026),
      bezelWidth: 1.5,
      scale: EatScaleGraduation.tb303Dial(
        tickColor: const Color(0xFF22242B),
        labelColor: textColor ?? const Color(0xFF1E1E24),
      ),
      arcMode: EatArcMode.disabled,
      haloColor: glow,
    );
  }

  /// Preset 12: TB-303 Rotary Selector (Mode / Wave / Function).
  /// Features a dark satin bakelite cylinder with a raised diagonal tactile grip bar,
  /// an authentic curved specular gloss reflection streak, and versatile scale graduations.
  factory EatHardwareKnobStyle.tb303Selector({
    Color? accentColor,
    Color? textColor,
    EatScaleGraduation? scale,
    List<String>? labels,
  }) {
    final effectiveScale = scale ??
        (labels != null
            ? EatScaleGraduation.tb303Selector(
                labels: labels,
                tickColor: const Color(0xFF1A1A1E),
                labelColor: textColor ?? const Color(0xFF1E1E24),
              )
            : EatScaleGraduation.zeroToTen(
                tickColor: const Color(0xFF1A1A1E),
                labelColor: textColor ?? const Color(0xFF1E1E24),
              ));

    return EatHardwareKnobStyle(
      capStyle: EatCapStyle.diagonalBar,
      capColor: const Color(0xFF222429),
      bodyColor: const Color(0xFF18191D),
      skirtStyle: EatSkirtStyle.straight,
      skirtRadiusRatio: 1.04,
      knurlStyle: EatKnurlStyle.none,
      indicatorStyle: EatIndicatorStyle.line,
      indicatorColor: const Color(0xFFF2F4F8),
      indicatorLength: 0.94,
      indicatorWidth: 2.2,
      bezelStyle: EatBezelStyle.gutter,
      bezelColor: const Color(0xFF16171B),
      bezelWidth: 1.4,
      scale: effectiveScale,
      arcMode: EatArcMode.disabled,
    );
  }

  EatHardwareKnobStyle copyWith({
    EatCapStyle? capStyle,
    Color? capColor,
    double? bevelWidth,
    double? capRadiusRatio,
    EatSkirtStyle? skirtStyle,
    Color? bodyColor,
    double? skirtRadiusRatio,
    double? bodyElevation,
    EatKnurlStyle? knurlStyle,
    int? ribCount,
    double? ribDepth,
    Color? knurlColor,
    EatIndicatorStyle? indicatorStyle,
    Color? indicatorColor,
    double? indicatorLength,
    double? indicatorWidth,
    EatBezelStyle? bezelStyle,
    Color? bezelColor,
    double? bezelWidth,
    EatScaleGraduation? scale,
    EatArcMode? arcMode,
    Color? trackActiveColor,
    Color? trackInactiveColor,
    double? trackThickness,
    double? trackRadiusRatio,
    Color? haloColor,
  }) {
    return EatHardwareKnobStyle(
      capStyle: capStyle ?? this.capStyle,
      capColor: capColor ?? this.capColor,
      bevelWidth: bevelWidth ?? this.bevelWidth,
      capRadiusRatio: capRadiusRatio ?? this.capRadiusRatio,
      skirtStyle: skirtStyle ?? this.skirtStyle,
      bodyColor: bodyColor ?? this.bodyColor,
      skirtRadiusRatio: skirtRadiusRatio ?? this.skirtRadiusRatio,
      bodyElevation: bodyElevation ?? this.bodyElevation,
      knurlStyle: knurlStyle ?? this.knurlStyle,
      ribCount: ribCount ?? this.ribCount,
      ribDepth: ribDepth ?? this.ribDepth,
      knurlColor: knurlColor ?? this.knurlColor,
      indicatorStyle: indicatorStyle ?? this.indicatorStyle,
      indicatorColor: indicatorColor ?? this.indicatorColor,
      indicatorLength: indicatorLength ?? this.indicatorLength,
      indicatorWidth: indicatorWidth ?? this.indicatorWidth,
      bezelStyle: bezelStyle ?? this.bezelStyle,
      bezelColor: bezelColor ?? this.bezelColor,
      bezelWidth: bezelWidth ?? this.bezelWidth,
      scale: scale ?? this.scale,
      arcMode: arcMode ?? this.arcMode,
      trackActiveColor: trackActiveColor ?? this.trackActiveColor,
      trackInactiveColor: trackInactiveColor ?? this.trackInactiveColor,
      trackThickness: trackThickness ?? this.trackThickness,
      trackRadiusRatio: trackRadiusRatio ?? this.trackRadiusRatio,
      haloColor: haloColor ?? this.haloColor,
    );
  }
}
