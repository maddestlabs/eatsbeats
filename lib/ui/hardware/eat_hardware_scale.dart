import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/eats_theme.dart';

/// Universal graduation scale and legend configuration for hardware controls.
/// Supports radial rotary knobs, dials, and can project linearly onto faders.
class EatScaleGraduation {
  /// Starting angle in radians (e.g., 135° = 2.35619 radians, bottom-left origin).
  final double startAngle;

  /// Angular sweep range in radians (e.g., 270° = 4.71239 radians, or 300° = 5.23599).
  final double sweepAngle;

  /// Number of tick divisions (e.g., 10 divisions = 11 tick marks).
  final int tickDivisions;

  /// Additional minor subdivisions per major tick interval (0 for none).
  final int minorSubdivisions;

  /// Whether a prominent center detent tick is rendered.
  final bool hasCenterDetent;

  /// Whether the center detent is drawn as a prominent bold rectangular mark (as seen on the TB-303).
  final bool hasBlockCenterDetent;

  /// Explicit detent points normalized in 0.0 .. 1.0 (e.g. [0.5] for center).
  final List<double> detents;

  /// Length of standard ticks in pixels (scaled dynamically by control size).
  final double tickLength;

  /// Length of major/detent ticks.
  final double majorTickLength;

  /// Stroke width of tick marks.
  final double tickWidth;

  /// Stroke width of major ticks.
  final double majorTickWidth;

  /// Color of tick marks (if null, falls back to chassis contrast).
  final Color? tickColor;

  /// Optional text legends (numbers or words) placed around the perimeter.
  final List<String> labels;

  /// Optional prefix or lead badge label printed near the start (e.g., 'dyn').
  final String? leadLabel;

  /// Font size for graduation labels.
  final double labelFontSize;

  /// Color of graduation label text.
  final Color? labelColor;

  /// Distance multiplier outside tick ring where text labels are positioned.
  final double labelDistanceRatio;

  const EatScaleGraduation({
    this.startAngle = 2.35619, // 135° in radians
    this.sweepAngle = 4.71239, // 270° in radians
    this.tickDivisions = 10,
    this.minorSubdivisions = 0,
    this.hasCenterDetent = false,
    this.hasBlockCenterDetent = false,
    this.detents = const [],
    this.tickLength = 3.5,
    this.majorTickLength = 5.5,
    this.tickWidth = 1.0,
    this.majorTickWidth = 1.4,
    this.tickColor,
    this.labels = const [],
    this.leadLabel,
    this.labelFontSize = 8.0,
    this.labelColor,
    this.labelDistanceRatio = 1.28,
  });

  /// 0 to 10 numerical dial scale (as seen on Kick Body/Punch & Snare Head/Wires).
  factory EatScaleGraduation.zeroToTen({
    Color? tickColor,
    Color? labelColor,
    double startAngle = 2.35619,
    double sweepAngle = 4.71239,
  }) {
    return EatScaleGraduation(
      startAngle: startAngle,
      sweepAngle: sweepAngle,
      tickDivisions: 10,
      tickLength: 3.5,
      majorTickLength: 5.5,
      tickWidth: 1.0,
      majorTickWidth: 1.5,
      tickColor: tickColor,
      labels: const ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10'],
      labelFontSize: 7.5,
      labelColor: labelColor,
      labelDistanceRatio: 1.26,
    );
  }

  /// 3-point semantic frequency/tonal scale (e.g., 'low', 'mid', 'high' on Kick/Snare Pitch).
  factory EatScaleGraduation.lowMidHigh({
    Color? tickColor,
    Color? labelColor,
    double startAngle = 2.35619,
    double sweepAngle = 4.71239,
  }) {
    return EatScaleGraduation(
      startAngle: startAngle,
      sweepAngle: sweepAngle,
      tickDivisions: 2,
      hasCenterDetent: true,
      detents: const [0.5],
      tickLength: 3.5,
      majorTickLength: 5.5,
      tickWidth: 1.2,
      majorTickWidth: 1.6,
      tickColor: tickColor,
      labels: const ['low', 'mid', 'high'],
      labelFontSize: 8.0,
      labelColor: labelColor,
      labelDistanceRatio: 1.30,
    );
  }

  /// 1 to 6 numerical scale with 'dyn' lead label (as seen on Snare Sustain).
  factory EatScaleGraduation.sustainOneToSix({
    Color? tickColor,
    Color? labelColor,
    double startAngle = 2.35619,
    double sweepAngle = 4.71239,
  }) {
    return EatScaleGraduation(
      startAngle: startAngle,
      sweepAngle: sweepAngle,
      tickDivisions: 5,
      tickLength: 3.5,
      majorTickLength: 5.5,
      tickWidth: 1.0,
      majorTickWidth: 1.5,
      tickColor: tickColor,
      labels: const ['1', '2', '3', '4', '5', '6'],
      leadLabel: 'dyn',
      labelFontSize: 7.5,
      labelColor: labelColor,
      labelDistanceRatio: 1.26,
    );
  }

  /// Bipolar scale with prominent 0 center detent (-max .. 0 .. +max).
  factory EatScaleGraduation.bipolar({
    Color? tickColor,
    Color? labelColor,
    double startAngle = 2.35619,
    double sweepAngle = 4.71239,
    List<String> labels = const ['-5', '0', '+5'],
  }) {
    return EatScaleGraduation(
      startAngle: startAngle,
      sweepAngle: sweepAngle,
      tickDivisions: 10,
      hasCenterDetent: true,
      detents: const [0.5],
      tickLength: 3.0,
      majorTickLength: 5.5,
      tickWidth: 1.0,
      majorTickWidth: 1.8,
      tickColor: tickColor,
      labels: labels,
      labelFontSize: 7.5,
      labelColor: labelColor,
      labelDistanceRatio: 1.26,
    );
  }

  /// Clean minimal tick marks without text labels.
  factory EatScaleGraduation.cleanTicks({
    int divisions = 10,
    Color? tickColor,
    Color? labelColor,
    double startAngle = 2.35619,
    double sweepAngle = 4.71239,
  }) {
    return EatScaleGraduation(
      startAngle: startAngle,
      sweepAngle: sweepAngle,
      tickDivisions: divisions,
      tickLength: 3.5,
      majorTickLength: 4.5,
      tickWidth: 1.2,
      majorTickWidth: 1.5,
      tickColor: tickColor,
      labelColor: labelColor,
      labels: const [],
    );
  }

  /// Authentic Roland TB-303 potentiometer graduation dial.
  /// Features 10 divisions with thin radial lines and a bold rectangular 12 o'clock calibration block.
  factory EatScaleGraduation.tb303Dial({
    Color? tickColor,
    Color? labelColor,
    List<String> labels = const [],
    double startAngle = 2.35619,
    double sweepAngle = 4.71239,
  }) {
    return EatScaleGraduation(
      startAngle: startAngle,
      sweepAngle: sweepAngle,
      tickDivisions: 10,
      hasCenterDetent: true,
      hasBlockCenterDetent: true,
      detents: const [0.5],
      tickLength: 3.6,
      majorTickLength: 6.2,
      tickWidth: 1.1,
      majorTickWidth: 3.2,
      tickColor: tickColor ?? const Color(0xFF1E1E24),
      labels: labels,
      labelFontSize: 7.5,
      labelColor: labelColor,
      labelDistanceRatio: 1.28,
    );
  }

  /// TB-303 Rotary Mode Selector scale with discrete stepped detent points.
  factory EatScaleGraduation.tb303Selector({
    Color? tickColor,
    Color? labelColor,
    List<String> labels = const ['CLASSIC', 'STEP', 'WAVE', 'RAND', 'SETUP'],
    double startAngle = 2.35619,
    double sweepAngle = 4.71239,
  }) {
    return EatScaleGraduation(
      startAngle: startAngle,
      sweepAngle: sweepAngle,
      tickDivisions: labels.length > 1 ? labels.length - 1 : 4,
      hasCenterDetent: false,
      hasBlockCenterDetent: false,
      tickLength: 2.5,
      majorTickLength: 3.5,
      tickWidth: 1.4,
      majorTickWidth: 1.4,
      tickColor: tickColor ?? const Color(0xFF1E1E24),
      labels: labels,
      labelFontSize: 7.0,
      labelColor: labelColor,
      labelDistanceRatio: 1.35,
    );
  }

  /// Converts a normalized 0.0..1.0 value to the exact radial angle in radians.
  double valueToAngle(double normalizedValue) {
    return startAngle + (normalizedValue.clamp(0.0, 1.0) * sweepAngle);
  }

  /// Analytical polar-to-Cartesian coordinate projection (Zero-allocation).
  Offset polarToCartesian(Offset center, double radius, double angle) {
    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
  }

  EatScaleGraduation copyWith({
    double? startAngle,
    double? sweepAngle,
    int? tickDivisions,
    int? minorSubdivisions,
    bool? hasCenterDetent,
    bool? hasBlockCenterDetent,
    List<double>? detents,
    double? tickLength,
    double? majorTickLength,
    double? tickWidth,
    double? majorTickWidth,
    Color? tickColor,
    List<String>? labels,
    String? leadLabel,
    double? labelFontSize,
    Color? labelColor,
    double? labelDistanceRatio,
  }) {
    return EatScaleGraduation(
      startAngle: startAngle ?? this.startAngle,
      sweepAngle: sweepAngle ?? this.sweepAngle,
      tickDivisions: tickDivisions ?? this.tickDivisions,
      minorSubdivisions: minorSubdivisions ?? this.minorSubdivisions,
      hasCenterDetent: hasCenterDetent ?? this.hasCenterDetent,
      hasBlockCenterDetent: hasBlockCenterDetent ?? this.hasBlockCenterDetent,
      detents: detents ?? this.detents,
      tickLength: tickLength ?? this.tickLength,
      majorTickLength: majorTickLength ?? this.majorTickLength,
      tickWidth: tickWidth ?? this.tickWidth,
      majorTickWidth: majorTickWidth ?? this.majorTickWidth,
      tickColor: tickColor ?? this.tickColor,
      labels: labels ?? this.labels,
      leadLabel: leadLabel ?? this.leadLabel,
      labelFontSize: labelFontSize ?? this.labelFontSize,
      labelColor: labelColor ?? this.labelColor,
      labelDistanceRatio: labelDistanceRatio ?? this.labelDistanceRatio,
    );
  }
}
