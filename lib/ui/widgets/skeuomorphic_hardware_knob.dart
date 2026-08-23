import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../lua/lua_gui_model.dart';
import '../../theme/eats_theme.dart';
import 'compact_value_dialog.dart';

/// A realistic skeuomorphic metallic hardware knob control.
/// Supports vertical drag interaction, tap-hold/double-tap dialogs,
/// metallic sweep gradients, knurled perimeter ticks, and warm LED glowing indicators.
class SkeuomorphicHardwareKnob extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double defaultValue;
  final String? label;
  final bool showLabelText;
  final ValueChanged<double> onChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback? onChangeEnd;
  final double size;
  final Color? accentColor;
  final KnobStyle knobStyle;
  final bool isLightChassis;
  final String Function(double)? formatValue;
  final double step;

  const SkeuomorphicHardwareKnob({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    required this.defaultValue,
    this.label,
    this.showLabelText = true,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.size = 56.0,
    this.accentColor,
    this.knobStyle = KnobStyle.standard,
    this.isLightChassis = false,
    this.formatValue,
    this.step = 0.0,
  });

  @override
  State<SkeuomorphicHardwareKnob> createState() => _SkeuomorphicHardwareKnobState();
}

class _SkeuomorphicHardwareKnobState extends State<SkeuomorphicHardwareKnob> {
  double _dragStartValue = 0.0;
  double _dragStartY = 0.0;

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.accentColor ?? (widget.knobStyle == KnobStyle.chrome ? const Color(0xFF00FF9D) : EatsTheme.primaryCyan);
    final normalized = ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
    final displayVal = widget.formatValue != null
        ? widget.formatValue!(widget.value)
        : widget.value.toStringAsFixed(2);

    final labelColor = widget.isLightChassis
        ? const Color(0xFF1B1A17)
        : EatsTheme.textSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null && widget.showLabelText) ...[
          Text(
            widget.label!.toUpperCase(),
            style: EatsTheme.getDisplayFontStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 4),
        ],
        GestureDetector(
          onVerticalDragStart: (details) {
            widget.onChangeStart?.call();
            _dragStartValue = widget.value;
            _dragStartY = details.globalPosition.dy;
          },
          onVerticalDragUpdate: (details) {
            final dy = _dragStartY - details.globalPosition.dy;
            final range = widget.max - widget.min;
            // 200 pixels drag = full scale range
            final delta = (dy / 200.0) * range;
            double newValue = (_dragStartValue + delta).clamp(widget.min, widget.max);
            if (widget.step > 0) {
              newValue = (newValue / widget.step).roundToDouble() * widget.step;
            }
            widget.onChanged(newValue);
          },
          onVerticalDragEnd: (_) => widget.onChangeEnd?.call(),
          onVerticalDragCancel: () => widget.onChangeEnd?.call(),
          onDoubleTap: () {
            widget.onChangeStart?.call();
            widget.onChanged(widget.defaultValue);
            widget.onChangeEnd?.call();
          },
          onLongPress: () => _showManualEditDialog(context),
          onSecondaryTap: () => _showManualEditDialog(context),
          onSecondaryTapDown: (_) => _showManualEditDialog(context),
          child: Tooltip(
            message: '${widget.label ?? "Knob"}: $displayVal (Double-tap reset, Hold/Right-click to edit)',
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _KnobPainter(
                  normalizedValue: normalized,
                  accentColor: activeColor,
                  knobStyle: widget.knobStyle,
                  isLightChassis: widget.isLightChassis,
                  isGrungyTheme: EatsTheme.currentPreset == EatsThemePreset.ateTrack,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: widget.isLightChassis ? Colors.black.withOpacity(0.08) : Colors.black45,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: widget.isLightChassis
                  ? Colors.black.withOpacity(0.2)
                  : activeColor.withOpacity(0.3),
              width: 0.8,
            ),
          ),
          child: Text(
            displayVal,
            style: EatsTheme.getDisplayFontStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: widget.isLightChassis ? const Color(0xFF1B1A17) : activeColor,
            ),
          ),
        ),
      ],
    );
  }

  void _showManualEditDialog(BuildContext context) {
    final displayVal = widget.formatValue != null ? widget.formatValue!(widget.value) : widget.value.toStringAsFixed(2);
    final accent = widget.accentColor ?? (widget.knobStyle == KnobStyle.chrome ? const Color(0xFF00FF9D) : EatsTheme.primaryCyan);

    showCompactValueEditDialog(
      context: context,
      title: widget.label != null ? 'Set ${widget.label}' : 'Set Knob Value',
      initialValue: displayVal,
      minMaxHint: 'Range: ${widget.min} - ${widget.max}',
      accentColor: accent,
      onResetDefault: () => widget.onChanged(widget.defaultValue),
      onSubmit: (text) {
        final double? parsed = double.tryParse(text);
        if (parsed != null) {
          widget.onChanged(parsed.clamp(widget.min, widget.max));
        }
      },
    );
  }
}

class _KnobPainter extends CustomPainter {
  final double normalizedValue;
  final Color accentColor;
  final KnobStyle knobStyle;
  final bool isLightChassis;
  final bool isGrungyTheme;

  _KnobPainter({
    required this.normalizedValue,
    required this.accentColor,
    this.knobStyle = KnobStyle.standard,
    this.isLightChassis = false,
    required this.isGrungyTheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2;

    // Angle range: 7 o'clock (135 deg / 0.75*pi) to 5 o'clock (405 deg / 2.25*pi)
    const startAngle = 0.75 * math.pi;
    const totalAngleRange = 1.5 * math.pi;
    final currentAngle = startAngle + (normalizedValue.clamp(0.0, 1.0) * totalAngleRange);

    final isChrome = knobStyle == KnobStyle.chrome;
    final isSnes = knobStyle == KnobStyle.snes;

    // ----------------------------------------------------
    // 1. Perimeter Radial Calibration Ticks (TB-303 Dial Markings / Console Ticks)
    // ----------------------------------------------------
    if (isChrome || isLightChassis || isSnes) {
      const int numTicks = 11;
      final tickPaint = Paint()
        ..color = (isSnes || isLightChassis)
            ? const Color(0xFF2C2C32).withOpacity(0.7)
            : const Color(0xFF8C96A5).withOpacity(0.65)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < numTicks; i++) {
        final tickAngle = startAngle + (i / (numTicks - 1)) * totalAngleRange;
        final isMajor = i == 0 || i == (numTicks - 1) || i == (numTicks ~/ 2);
        final innerTickRadius = outerRadius - (isMajor ? 4.5 : 3.0);
        final outerTickRadius = outerRadius - 0.5;

        final t1 = center + Offset(math.cos(tickAngle) * innerTickRadius, math.sin(tickAngle) * innerTickRadius);
        final t2 = center + Offset(math.cos(tickAngle) * outerTickRadius, math.sin(tickAngle) * outerTickRadius);
        canvas.drawLine(t1, t2, tickPaint);
      }
    }

    // ----------------------------------------------------
    // 2. Outer Arc Value Track (Arc Meter around Perimeter)
    // ----------------------------------------------------
    final arcRadius = outerRadius - (isChrome ? 5.0 : 3.0);
    final arcRect = Rect.fromCircle(center: center, radius: arcRadius);

    // Inactive Background Track Arc
    final inactiveArcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isChrome ? 2.8 : 2.5
      ..strokeCap = StrokeCap.round
      ..color = (isSnes || isLightChassis)
          ? const Color(0xFFC0BCB0)
          : (isGrungyTheme ? const Color(0xFF38322B) : const Color(0xFF222733));
    canvas.drawArc(arcRect, startAngle, totalAngleRange, false, inactiveArcPaint);

    // Active Value Arc
    if (normalizedValue > 0.001) {
      final sweepAngle = (normalizedValue * totalAngleRange).clamp(0.001, totalAngleRange);

      if (isSnes) {
        // SNES Dark Gray / Accent Level Indicator Arc
        final activeArcPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF36353D);
        canvas.drawArc(arcRect, startAngle, sweepAngle, false, activeArcPaint);
      } else {
        // Arc Glow Pass
        final arcGlowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isChrome ? 4.5 : 4.0
          ..strokeCap = StrokeCap.round
          ..color = accentColor.withOpacity(isChrome ? 0.65 : 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
        canvas.drawArc(arcRect, startAngle, sweepAngle, false, arcGlowPaint);

        // Arc Foreground Line
        final activeArcPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isChrome ? 2.8 : 2.5
          ..strokeCap = StrokeCap.round
          ..color = accentColor;
        canvas.drawArc(arcRect, startAngle, sweepAngle, false, activeArcPaint);
      }
    }

    // ----------------------------------------------------
    // 3. Physical Knob Body & Bezel (3D Skeuomorphic Rotary Dial)
    // ----------------------------------------------------
    final knobRadius = outerRadius * (isChrome ? 0.70 : 0.76);

    // Bezel Drop Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity((isSnes || isLightChassis) ? 0.35 : 0.65)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawCircle(center + const Offset(0, 2), knobRadius + 1.5, shadowPaint);

    if (isSnes) {
      // Plain White / Ivory SNES Controller Button Dial
      final bezelPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFDDD9D0),
            Color(0xFFB8B4AA),
          ],
          stops: [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: knobRadius + 1.2));
      canvas.drawCircle(center, knobRadius + 1.2, bezelPaint);

      // Matte Plastic White Body
      final bodyGradient = RadialGradient(
        center: const Alignment(-0.25, -0.3),
        radius: 0.9,
        colors: const [
          Color(0xFFFFFFFF),
          Color(0xFFF4F2EB),
          Color(0xFFE8E5DD),
          Color(0xFFD6D2C8),
        ],
        stops: const [0.0, 0.45, 0.8, 1.0],
      );
      final knobBodyPaint = Paint()
        ..shader = bodyGradient.createShader(Rect.fromCircle(center: center, radius: knobRadius));
      canvas.drawCircle(center, knobRadius, knobBodyPaint);

      // Inner Convex Face
      final innerRadius = knobRadius * 0.80;
      final innerFaceGradient = RadialGradient(
        center: const Alignment(-0.2, -0.25),
        radius: 0.95,
        colors: const [
          Color(0xFFFFFFFF),
          Color(0xFFF2F0E8),
          Color(0xFFE2DED5),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
      final innerCapPaint = Paint()
        ..shader = innerFaceGradient.createShader(Rect.fromCircle(center: center, radius: innerRadius));
      canvas.drawCircle(center, innerRadius, innerCapPaint);

      // Inner Face Chamfer Rim Line
      final innerRimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white.withOpacity(0.9);
      canvas.drawCircle(center, innerRadius, innerRimPaint);

    } else if (isChrome) {
      // Chrome Mirror Outer Beveled Well Rim
      final chromeOuterBezelPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFF8A929E),
            Color(0xFF303640),
            Color(0xFF6B7280),
          ],
          stops: [0.0, 0.35, 0.75, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: knobRadius + 1.5));
      canvas.drawCircle(center, knobRadius + 1.5, chromeOuterBezelPaint);

      // Chrome Body Cap with Conical Mirror Gleam Gradient
      final chromeBodyPaint = Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: 0.0,
          endAngle: math.pi * 2.0,
          colors: const [
            Color(0xFFE8ECEF),
            Color(0xFF909AA8),
            Color(0xFFFFFFFF),
            Color(0xFF4A5260),
            Color(0xFFBAC3CE),
            Color(0xFFE8ECEF),
            Color(0xFF6A7382),
            Color(0xFFFFFFFF),
            Color(0xFF7E8796),
            Color(0xFFE8ECEF),
          ],
          stops: const [0.0, 0.12, 0.25, 0.38, 0.50, 0.63, 0.75, 0.85, 0.93, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: knobRadius));
      canvas.drawCircle(center, knobRadius, chromeBodyPaint);

      // Inner Concentric Cap Face (Machined Silver Face)
      final innerRadius = knobRadius * 0.82;
      final innerFaceGradient = RadialGradient(
        center: const Alignment(-0.25, -0.3),
        radius: 0.85,
        colors: const [
          Color(0xFFFFFFFF),
          Color(0xFFD6DBE0),
          Color(0xFF9BA4B0),
          Color(0xFF747D8A),
        ],
        stops: const [0.0, 0.35, 0.75, 1.0],
      );

      final innerCapPaint = Paint()
        ..shader = innerFaceGradient.createShader(Rect.fromCircle(center: center, radius: innerRadius));
      canvas.drawCircle(center, innerRadius, innerCapPaint);

      // Inner Face Chamfer Rim Line
      final innerRimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white.withOpacity(0.85);
      canvas.drawCircle(center, innerRadius, innerRimPaint);

    } else {
      // Standard / Grungy Metallic Knob Body
      final bezelPaint = Paint()
        ..color = isGrungyTheme ? const Color(0xFF1B1815) : const Color(0xFF14171E);
      canvas.drawCircle(center, knobRadius + 1, bezelPaint);

      final bezelRimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = isGrungyTheme ? const Color(0xFF3A342D) : const Color(0xFF282D3A);
      canvas.drawCircle(center, knobRadius + 1, bezelRimPaint);

      final bodyGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isGrungyTheme
            ? [
                const Color(0xFF4A433B),
                const Color(0xFF2C2722),
                const Color(0xFF1F1C18),
              ]
            : [
                const Color(0xFF3A4250),
                const Color(0xFF222834),
                const Color(0xFF161A22),
              ],
        stops: const [0.0, 0.5, 1.0],
      );

      final knobBodyPaint = Paint()
        ..shader = bodyGradient.createShader(Rect.fromCircle(center: center, radius: knobRadius));
      canvas.drawCircle(center, knobRadius, knobBodyPaint);

      final innerRadius = knobRadius * 0.82;
      final innerFaceGradient = RadialGradient(
        center: const Alignment(-0.2, -0.3),
        radius: 0.95,
        colors: isGrungyTheme
            ? [
                const Color(0xFF3D3730),
                const Color(0xFF201D19),
              ]
            : [
                const Color(0xFF2A313D),
                const Color(0xFF141820),
              ],
      );

      final innerCapPaint = Paint()
        ..shader = innerFaceGradient.createShader(Rect.fromCircle(center: center, radius: innerRadius));
      canvas.drawCircle(center, innerRadius, innerCapPaint);

      final innerRimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white.withOpacity(isGrungyTheme ? 0.12 : 0.20);
      canvas.drawCircle(center, innerRadius, innerRimPaint);
    }

    // ----------------------------------------------------
    // 4. Pointer Notch / Line
    // ----------------------------------------------------
    final p1 = center + Offset(math.cos(currentAngle) * (knobRadius * 0.22), math.sin(currentAngle) * (knobRadius * 0.22));
    final p2 = center + Offset(math.cos(currentAngle) * (knobRadius * 0.72), math.sin(currentAngle) * (knobRadius * 0.72));

    if (isSnes) {
      // Solid Dark Gray Level Indicator Notch
      final snesNotchPaint = Paint()
        ..color = const Color(0xFF2C2C32)
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p1, p2, snesNotchPaint);
    } else {
      if (isChrome) {
        // Dark pointer notch border on chrome
        final notchEdgePaint = Paint()
          ..color = const Color(0xFF1A1E24)
          ..strokeWidth = 3.8
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(p1, p2, notchEdgePaint);
      }

      // Pointer Glow
      final pointerGlowPaint = Paint()
        ..color = accentColor.withOpacity(0.7)
        ..strokeWidth = isChrome ? 3.5 : 4.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawLine(p1, p2, pointerGlowPaint);

      // Pointer Core Line
      final pointerCorePaint = Paint()
        ..color = accentColor
        ..strokeWidth = isChrome ? 2.0 : 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p1, p2, pointerCorePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _KnobPainter oldDelegate) {
    return oldDelegate.normalizedValue != normalizedValue ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.knobStyle != knobStyle ||
        oldDelegate.isLightChassis != isLightChassis ||
        oldDelegate.isGrungyTheme != isGrungyTheme;
  }
}
