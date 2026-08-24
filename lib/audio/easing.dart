import 'dart:math' as math;

/// Types of easing curves supported for parameter automation.
enum EasingType {
  /// Holds previous value until the exact next point (vital for discrete chip registers/modes).
  step,

  /// Linear interpolation between start and end values.
  linear,

  /// Exponential curve, perceptually natural for frequency (Hz) and gain (dB).
  exponential,

  /// Gentle sine ease-in.
  sineIn,

  /// Gentle sine ease-out.
  sineOut,

  /// S-curve ease-in-out using sine.
  sineInOut,

  /// Cubic ease-in.
  cubicIn,

  /// Cubic ease-out.
  cubicOut,

  /// Smooth cubic ease-in-out with tension.
  cubicInOut,

  /// Smoothstep polynomial 3t^2 - 2t^3.
  smoothstep,

  /// Arbitrary 2D Cubic Bezier curve using normalized control points.
  cubicBezier;

  String get displayName {
    switch (this) {
      case EasingType.step:
        return 'Step (Hold)';
      case EasingType.linear:
        return 'Linear';
      case EasingType.exponential:
        return 'Exponential';
      case EasingType.sineIn:
        return 'Sine In';
      case EasingType.sineOut:
        return 'Sine Out';
      case EasingType.sineInOut:
        return 'Sine In/Out';
      case EasingType.cubicIn:
        return 'Cubic In';
      case EasingType.cubicOut:
        return 'Cubic Out';
      case EasingType.cubicInOut:
        return 'Cubic In/Out';
      case EasingType.smoothstep:
        return 'Smoothstep';
      case EasingType.cubicBezier:
        return 'Custom Bezier';
    }
  }
}

/// Comprehensive easing & curve evaluation library for Eatsbeats.
class Easing {
  /// Evaluates normalized interpolation progress [t] (0.0 to 1.0) using [type].
  /// Returns interpolated value between [v0] and [v1].
  static double interpolate(
    double t,
    double v0,
    double v1,
    EasingType type, {
    double tension = 0.0,
    double cx1 = 0.25,
    double cy1 = 0.1,
    double cx2 = 0.25,
    double cy2 = 1.0,
  }) {
    if (t <= 0.0) return v0;
    if (t >= 1.0) return v1;

    final progress = evaluateProgress(
      t,
      type,
      tension: tension,
      cx1: cx1,
      cy1: cy1,
      cx2: cx2,
      cy2: cy2,
    );

    if (type == EasingType.exponential) {
      // Handle zero or negative bounds safely for exponential scaling
      if (v0 > 0 && v1 > 0) {
        return v0 * math.pow(v1 / v0, progress);
      }
    }

    return v0 + (v1 - v0) * progress;
  }

  /// Calculates normalized curve progress (0.0 to 1.0) for a given normalized time [t] (0.0 to 1.0).
  static double evaluateProgress(
    double t,
    EasingType type, {
    double tension = 0.0,
    double cx1 = 0.25,
    double cy1 = 0.1,
    double cx2 = 0.25,
    double cy2 = 1.0,
  }) {
    final clampedT = t.clamp(0.0, 1.0);

    switch (type) {
      case EasingType.step:
        return clampedT >= 1.0 ? 1.0 : 0.0;

      case EasingType.linear:
        if (tension == 0.0) return clampedT;
        // Tension bends linear towards exponential/logarithmic
        if (tension > 0) {
          return math.pow(clampedT, 1.0 + tension * 3.0).toDouble();
        } else {
          return 1.0 - math.pow(1.0 - clampedT, 1.0 - tension * 3.0).toDouble();
        }

      case EasingType.exponential:
        return (math.exp(clampedT * 3.0) - 1.0) / (math.exp(3.0) - 1.0);

      case EasingType.sineIn:
        return 1.0 - math.cos((clampedT * math.pi) / 2.0);

      case EasingType.sineOut:
        return math.sin((clampedT * math.pi) / 2.0);

      case EasingType.sineInOut:
        return -(math.cos(math.pi * clampedT) - 1.0) / 2.0;

      case EasingType.cubicIn:
        return clampedT * clampedT * clampedT;

      case EasingType.cubicOut:
        final f = clampedT - 1.0;
        return f * f * f + 1.0;

      case EasingType.cubicInOut:
        if (clampedT < 0.5) {
          return 4.0 * clampedT * clampedT * clampedT;
        } else {
          final f = (2.0 * clampedT) - 2.0;
          return 0.5 * f * f * f + 1.0;
        }

      case EasingType.smoothstep:
        return clampedT * clampedT * (3.0 - 2.0 * clampedT);

      case EasingType.cubicBezier:
        return solveCubicBezier(clampedT, cx1, cy1, cx2, cy2);
    }
  }

  /// Solves a 1D output for a standard Cubic Bezier curve defined by (cx1, cy1) and (cx2, cy2).
  static double solveCubicBezier(
    double targetX,
    double cx1,
    double cy1,
    double cx2,
    double cy2,
  ) {
    if (targetX <= 0.0) return 0.0;
    if (targetX >= 1.0) return 1.0;

    // Newton-Raphson iteration to find t for given targetX
    double t = targetX;
    for (int i = 0; i < 8; i++) {
      final currentX = _sampleCurveX(t, cx1, cx2) - targetX;
      if (currentX.abs() < 1e-5) break;
      final dX = _sampleDerivativeX(t, cx1, cx2);
      if (dX.abs() < 1e-6) break;
      t -= currentX / dX;
      t = t.clamp(0.0, 1.0);
    }

    return _sampleCurveY(t, cy1, cy2).clamp(0.0, 1.0);
  }

  static double _sampleCurveX(double t, double cx1, double cx2) {
    // Bezier polynomial with start = (0,0), end = (1,1)
    // B(t) = 3(1-t)^2*t*P1 + 3(1-t)*t^2*P2 + t^3
    return 3.0 * (1.0 - t) * (1.0 - t) * t * cx1 +
        3.0 * (1.0 - t) * t * t * cx2 +
        t * t * t;
  }

  static double _sampleDerivativeX(double t, double cx1, double cx2) {
    return 3.0 * (1.0 - t) * (1.0 - t) * cx1 +
        6.0 * (1.0 - t) * t * (cx2 - cx1) +
        3.0 * t * t * (1.0 - cx2);
  }

  static double _sampleCurveY(double t, double cy1, double cy2) {
    return 3.0 * (1.0 - t) * (1.0 - t) * t * cy1 +
        3.0 * (1.0 - t) * t * t * cy2 +
        t * t * t;
  }
}
