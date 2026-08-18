import 'dart:math' as math;
import 'package:flutter/material.dart';
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
    final activeColor = widget.accentColor ?? EatsTheme.primaryCyan;
    final normalized = ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
    final displayVal = widget.formatValue != null
        ? widget.formatValue!(widget.value)
        : widget.value.toStringAsFixed(2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null && widget.showLabelText) ...[
          Text(
            widget.label!.toUpperCase(),
            style: EatsTheme.getDisplayFontStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: EatsTheme.textSecondary,
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
            color: Colors.black45,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: activeColor.withOpacity(0.3), width: 0.8),
          ),
          child: Text(
            displayVal,
            style: EatsTheme.getDisplayFontStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: activeColor,
            ),
          ),
        ),
      ],
    );
  }

  void _showManualEditDialog(BuildContext context) {
    final displayVal = widget.formatValue != null ? widget.formatValue!(widget.value) : widget.value.toStringAsFixed(2);
    final accent = widget.accentColor ?? EatsTheme.primaryCyan;

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
  final bool isGrungyTheme;

  _KnobPainter({
    required this.normalizedValue,
    required this.accentColor,
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



    // ----------------------------------------------------
    // 1. Outer Arc Value Track (Arc Meter around Perimeter)
    // ----------------------------------------------------
    final arcRadius = outerRadius - 3.0;
    final arcRect = Rect.fromCircle(center: center, radius: arcRadius);

    // Inactive Background Track Arc
    final inactiveArcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = isGrungyTheme ? const Color(0xFF38322B) : const Color(0xFF222733);
    canvas.drawArc(arcRect, startAngle, totalAngleRange, false, inactiveArcPaint);

    // Active Glowing Value Arc
    if (normalizedValue > 0.001) {
      final sweepAngle = (normalizedValue * totalAngleRange).clamp(0.001, totalAngleRange);

      // Arc Glow Pass
      final arcGlowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..color = accentColor.withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, arcGlowPaint);

      // Arc Foreground Line
      final activeArcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = accentColor;
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, activeArcPaint);
    }

    // ----------------------------------------------------
    // 2. Physical Knob Body & Bezel (3D Skeuomorphic Rotary Dial)
    // ----------------------------------------------------
    final knobRadius = outerRadius * 0.76;

    // Bezel Drop Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.65)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawCircle(center + const Offset(0, 2), knobRadius + 1, shadowPaint);

    // Outer Dark Bezel Well Rim
    final bezelPaint = Paint()
      ..color = isGrungyTheme ? const Color(0xFF1B1815) : const Color(0xFF14171E);
    canvas.drawCircle(center, knobRadius + 1, bezelPaint);

    // Outer Bezel Rim Line
    final bezelRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = isGrungyTheme ? const Color(0xFF3A342D) : const Color(0xFF282D3A);
    canvas.drawCircle(center, knobRadius + 1, bezelRimPaint);

    // Knob Body Cap Main Gradient
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

    // Inner Concentric Cap Face
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

    // Inner Face Bevel Rim Line
    final innerRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withOpacity(isGrungyTheme ? 0.12 : 0.20);
    canvas.drawCircle(center, innerRadius, innerRimPaint);

    // ----------------------------------------------------
    // 3. Illuminated Capsule Pointer Notch (Center Indicator)
    // ----------------------------------------------------
    final p1 = center + Offset(math.cos(currentAngle) * (knobRadius * 0.28), math.sin(currentAngle) * (knobRadius * 0.28));
    final p2 = center + Offset(math.cos(currentAngle) * (knobRadius * 0.68), math.sin(currentAngle) * (knobRadius * 0.68));

    // Pointer Glow
    final pointerGlowPaint = Paint()
      ..color = accentColor.withOpacity(0.6)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawLine(p1, p2, pointerGlowPaint);

    // Pointer Core Line
    final pointerCorePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p1, p2, pointerCorePaint);
  }

  @override
  bool shouldRepaint(covariant _KnobPainter oldDelegate) {
    return oldDelegate.normalizedValue != normalizedValue ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isGrungyTheme != isGrungyTheme;
  }
}
