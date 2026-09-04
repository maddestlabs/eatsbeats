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
    this.showValueText = true,
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

  final bool showValueText;

  @override
  State<SkeuomorphicHardwareKnob> createState() => _SkeuomorphicHardwareKnobState();
}

class _SkeuomorphicHardwareKnobState extends State<SkeuomorphicHardwareKnob> {
  double _dragStartValue = 0.0;
  double _dragStartY = 0.0;
  double _dragStartX = 0.0;

  @override
  Widget build(BuildContext context) {
    final isMinimal = widget.knobStyle == KnobStyle.minimalWhite;
    final isLight = widget.isLightChassis || isMinimal;
    final activeColor = widget.accentColor ?? (widget.knobStyle == KnobStyle.chrome || isMinimal ? const Color(0xFF141416) : EatsTheme.primaryCyan);
    final normalized = ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
    final displayVal = widget.formatValue != null
        ? widget.formatValue!(widget.value)
        : widget.value.toStringAsFixed(2);

    final labelColor = isLight
        ? const Color(0xFF1E1E24)
        : const Color(0xFFE2DDD5);

    final labelWidget = (widget.label != null && widget.showLabelText)
        ? Padding(
            padding: EdgeInsets.only(top: isMinimal ? 6.0 : 0.0, bottom: isMinimal ? 0.0 : 4.0),
            child: Text(
              widget.label!.toUpperCase(),
              style: EatsTheme.getDisplayFontStyle(
                fontSize: isMinimal ? 10.0 : 9.5,
                fontWeight: isMinimal ? FontWeight.w900 : FontWeight.w800,
                letterSpacing: isMinimal ? 1.2 : 0.8,
                color: labelColor,
              ),
            ),
          )
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isMinimal && labelWidget != null) labelWidget,
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            widget.onChangeStart?.call();
            _dragStartValue = widget.value;
            _dragStartY = details.globalPosition.dy;
            _dragStartX = details.globalPosition.dx;
          },
          onPanUpdate: (details) {
            final dy = _dragStartY - details.globalPosition.dy;
            final dx = details.globalPosition.dx - _dragStartX;
            final dragDelta = (dy.abs() >= dx.abs()) ? dy : dx;
            final range = widget.max - widget.min;
            // 150 pixels drag = full scale range
            final delta = (dragDelta / 150.0) * range;
            double newValue = (_dragStartValue + delta).clamp(widget.min, widget.max);
            if (widget.step > 0) {
              newValue = (newValue / widget.step).roundToDouble() * widget.step;
              newValue = newValue.clamp(widget.min, widget.max);
            }
            widget.onChanged(newValue);
          },
          onPanEnd: (_) => widget.onChangeEnd?.call(),
          onPanCancel: () => widget.onChangeEnd?.call(),
          onDoubleTap: () {
            widget.onChangeStart?.call();
            widget.onChanged(widget.defaultValue);
            widget.onChangeEnd?.call();
          },
          onLongPress: () => _showManualEditDialog(context),
          onSecondaryTap: () => _showManualEditDialog(context),
          onSecondaryTapDown: (_) => _showManualEditDialog(context),
          child: Tooltip(
            message: '${widget.label != null ? '${widget.label}: ' : ''}$displayVal (Double-tap to reset, Long-press to edit)',
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _KnobPainter(
                  normalizedValue: normalized,
                  accentColor: activeColor,
                  knobStyle: widget.knobStyle,
                  isLightChassis: isLight,
                  isGrungyTheme: EatsTheme.currentPreset == EatsThemePreset.ateTrack,
                ),
              ),
            ),
          ),
        ),
        if (isMinimal && labelWidget != null) labelWidget,
        if (widget.showValueText && !isMinimal) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isLight ? Colors.black.withOpacity(0.08) : Colors.black45,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isLight
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
                color: isLight ? const Color(0xFF1B1A17) : activeColor,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showManualEditDialog(BuildContext context) {
    final displayVal = widget.formatValue != null ? widget.formatValue!(widget.value) : widget.value.toStringAsFixed(2);
    final accent = widget.accentColor ?? (widget.knobStyle == KnobStyle.chrome || widget.knobStyle == KnobStyle.minimalWhite ? const Color(0xFF141416) : EatsTheme.primaryCyan);

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

  // Pre-allocated static worker paints (zero allocation per frame during rotary drag)
  static final Paint _workerFill = Paint()..style = PaintingStyle.fill;
  static final Paint _workerStroke = Paint()..style = PaintingStyle.stroke;
  static final Paint _workerShader = Paint();
  static final Paint _shadowBlurPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
  static final Paint _arcGlowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
  static final Paint _pointerGlowPaint = Paint()
    ..strokeWidth = 4.0
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

  // Static constant paints
  static final Paint _minimalInactiveArc = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFFE2E5EC);
  static final Paint _minimalActiveArc = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF1E1E24);
  static final Paint _minimalDotActive = Paint()
    ..color = const Color(0xFF1B1B1E)
    ..style = PaintingStyle.fill;
  static final Paint _minimalDotInactive = Paint()
    ..color = const Color(0xFFCAD0DC)
    ..style = PaintingStyle.fill;
  static final Paint _minimalDotBorder = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5
    ..color = Colors.white;
  static final Paint _minimalRimPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..color = const Color(0xFFD4D7DF);
  static final Paint _minimalInsetRingPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.6
    ..color = const Color(0x99DCDFE5);
  static final Paint _minimalDotShadow = Paint()
    ..color = const Color(0x4D000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
  static final Paint _minimalDotBevel = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8
    ..color = const Color(0xE6FFFFFF);
  static final Paint _minimalTopHl = Paint()
    ..color = const Color(0xE6FFFFFF)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
  static final Paint _minimalShadow = Paint()
    ..color = const Color(0x2E000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

  static final Paint _snesNotchPaint = Paint()
    ..color = const Color(0xFF2C2C32)
    ..strokeWidth = 2.6
    ..strokeCap = StrokeCap.round;
  static final Paint _chromeNotchShadow = Paint()
    ..color = const Color(0xFF000000)
    ..strokeWidth = 2.6
    ..strokeCap = StrokeCap.round;
  static final Paint _chromeNotchHl = Paint()
    ..color = const Color(0x80FFFFFF)
    ..strokeWidth = 0.8
    ..strokeCap = StrokeCap.round;

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
    final isMinimal = knobStyle == KnobStyle.minimalWhite;

    // ----------------------------------------------------
    // 1. Perimeter Radial Calibration Ticks / Dots & Value Stroke
    // ----------------------------------------------------
    if (isMinimal) {
      // 1a. Background Track Arc & Active Value Arc
      final arcRadius = outerRadius - 2.5;
      final arcRect = Rect.fromCircle(center: center, radius: arcRadius);

      canvas.drawArc(arcRect, startAngle, totalAngleRange, false, _minimalInactiveArc);

      if (normalizedValue > 0.005) {
        final sweepAngle = (normalizedValue * totalAngleRange).clamp(0.005, totalAngleRange);
        canvas.drawArc(arcRect, startAngle, sweepAngle, false, _minimalActiveArc);
      }

      // 1b. Refined Breakpoint Dots along Radius
      const int numTicks = 13;
      for (int i = 0; i < numTicks; i++) {
        final normTickVal = i / (numTicks - 1);
        final tickAngle = startAngle + normTickVal * totalAngleRange;
        final isMajor = i == 0 || i == (numTicks - 1) || i == ((numTicks - 1) ~/ 2) || i == ((numTicks - 1) ~/ 4) || i == (3 * (numTicks - 1) ~/ 4);
        final dotRadius = isMajor ? 1.5 : 1.0;
        final tickPos = center + Offset(
          math.cos(tickAngle) * arcRadius,
          math.sin(tickAngle) * arcRadius,
        );

        final isActive = normTickVal <= (normalizedValue + 0.02);
        final paint = isActive ? _minimalDotActive : _minimalDotInactive;

        canvas.drawCircle(tickPos, dotRadius, paint);
        canvas.drawCircle(tickPos, dotRadius, _minimalDotBorder);
      }
    } else if (isChrome || isLightChassis || isSnes) {
      const int numTicks = 11;
      _workerStroke.color = (isSnes || isLightChassis || isChrome)
          ? const Color(0xBF1B1A17)
          : const Color(0xA68C96A5);
      _workerStroke.strokeWidth = 1.2;
      _workerStroke.strokeCap = StrokeCap.round;

      for (int i = 0; i < numTicks; i++) {
        final tickAngle = startAngle + (i / (numTicks - 1)) * totalAngleRange;
        final isMajor = i == 0 || i == (numTicks - 1) || i == (numTicks ~/ 2);
        final innerTickRadius = outerRadius - (isMajor ? 4.5 : 3.0);
        final outerTickRadius = outerRadius - 0.5;

        final t1 = center + Offset(math.cos(tickAngle) * innerTickRadius, math.sin(tickAngle) * innerTickRadius);
        final t2 = center + Offset(math.cos(tickAngle) * outerTickRadius, math.sin(tickAngle) * outerTickRadius);
        canvas.drawLine(t1, t2, _workerStroke);
      }
    }

    // ----------------------------------------------------
    // 2. Outer Arc Value Track (Arc Meter around Perimeter)
    // ----------------------------------------------------
    if (!isMinimal) {
      final arcRadius = outerRadius - (isChrome ? 5.0 : 3.0);
      final arcRect = Rect.fromCircle(center: center, radius: arcRadius);

      // Inactive Background Track Arc
      _workerStroke.strokeWidth = isChrome ? 2.6 : 2.5;
      _workerStroke.strokeCap = StrokeCap.round;
      _workerStroke.color = (isSnes || isLightChassis)
          ? const Color(0xFFC0BCB0)
          : (isChrome ? const Color(0xFF32363E) : (isGrungyTheme ? const Color(0xFF38322B) : const Color(0xFF222733)));
      canvas.drawArc(arcRect, startAngle, totalAngleRange, false, _workerStroke);

      // Active Value Arc
      if (normalizedValue > 0.001) {
        final sweepAngle = (normalizedValue * totalAngleRange).clamp(0.001, totalAngleRange);

        if (isSnes || (isChrome && isLightChassis)) {
          // Classic Silkscreen Solid Charcoal/Black Arc (Authentic TB-303 / Tau)
          _workerStroke.strokeWidth = 2.6;
          _workerStroke.color = const Color(0xFF141416);
          canvas.drawArc(arcRect, startAngle, sweepAngle, false, _workerStroke);
        } else if (isChrome) {
          // Dark metallic chrome chassis track (deep gunmetal indicator)
          _workerStroke.strokeWidth = 2.6;
          _workerStroke.color = accentColor == const Color(0xFF141416) ? const Color(0xFF00FF9D) : accentColor;
          canvas.drawArc(arcRect, startAngle, sweepAngle, false, _workerStroke);
        } else {
          // Standard Glowing Arc
          _arcGlowPaint.strokeWidth = 4.0;
          _arcGlowPaint.color = accentColor.withOpacity(0.5);
          canvas.drawArc(arcRect, startAngle, sweepAngle, false, _arcGlowPaint);

          _workerStroke.strokeWidth = 2.5;
          _workerStroke.color = accentColor;
          canvas.drawArc(arcRect, startAngle, sweepAngle, false, _workerStroke);
        }
      }
    }

    // ----------------------------------------------------
    // 3. Physical Knob Body & Bezel (3D Skeuomorphic Rotary Dial)
    // ----------------------------------------------------
    final knobRadius = outerRadius * (isMinimal ? 0.72 : (isChrome ? 0.74 : 0.76));

    if (isMinimal) {
      // Ambient soft drop shadow (Clean ceramic elevation)
      canvas.drawCircle(center + const Offset(0, 3.5), knobRadius, _minimalShadow);
      canvas.drawCircle(center + const Offset(0, -1.0), knobRadius, _minimalTopHl);

      // Outer Bezel Rim (Subtle clean border stroke)
      canvas.drawCircle(center, knobRadius, _minimalRimPaint);

      // Matte Ceramic White Dial Face
      final dialGradient = RadialGradient(
        center: const Alignment(-0.25, -0.3),
        radius: 0.95,
        colors: const [
          Color(0xFFFFFFFF),
          Color(0xFFFBFBFC),
          Color(0xFFF0F2F5),
          Color(0xFFE6E9EE),
        ],
        stops: const [0.0, 0.45, 0.85, 1.0],
      );
      _workerShader.shader = dialGradient.createShader(Rect.fromCircle(center: center, radius: knobRadius));
      canvas.drawCircle(center, knobRadius - 0.5, _workerShader);

      // Subtle Inset Groove ring around periphery of knob face
      canvas.drawCircle(center, knobRadius * 0.88, _minimalInsetRingPaint);

      // Recessed Charcoal Dot Indicator near perimeter with subtle highlight bevel
      final dotRadius = math.max(2.4, knobRadius * 0.11);
      final dotDistance = knobRadius * 0.68;
      final dotPos = center + Offset(math.cos(currentAngle) * dotDistance, math.sin(currentAngle) * dotDistance);

      canvas.drawCircle(dotPos + const Offset(0, 0.6), dotRadius, _minimalDotShadow);
      canvas.drawCircle(dotPos, dotRadius + 0.4, _minimalDotBevel);
      canvas.drawCircle(dotPos, dotRadius, _minimalDotActive);

      return;
    }

    // Bezel Drop Shadow
    _shadowBlurPaint.color = Color.fromRGBO(0, 0, 0, (isSnes || isLightChassis) ? 0.35 : 0.65);
    canvas.drawCircle(center + const Offset(0, 2), knobRadius + 1.5, _shadowBlurPaint);

    if (isSnes) {
      // Plain White / Ivory SNES Controller Button Dial
      final bezelGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFDDD9D0),
          Color(0xFFB8B4AA),
        ],
        stops: [0.0, 0.6, 1.0],
      );
      _workerShader.shader = bezelGradient.createShader(Rect.fromCircle(center: center, radius: knobRadius + 1.2));
      canvas.drawCircle(center, knobRadius + 1.2, _workerShader);

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
      _workerShader.shader = bodyGradient.createShader(Rect.fromCircle(center: center, radius: knobRadius));
      canvas.drawCircle(center, knobRadius, _workerShader);

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
      _workerShader.shader = innerFaceGradient.createShader(Rect.fromCircle(center: center, radius: innerRadius));
      canvas.drawCircle(center, innerRadius, _workerShader);

      // Inner Face Chamfer Rim Line
      _workerStroke.strokeWidth = 0.8;
      _workerStroke.color = const Color(0xE6FFFFFF);
      canvas.drawCircle(center, innerRadius, _workerStroke);

    } else if (isChrome) {
      // ----------------------------------------------------
      // Smooth Polished Chrome Beveled Dial (TB-303 / Silver Hardware)
      // ----------------------------------------------------
      final chromeOuterBezelGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFB8C0CA),
          Color(0xFF4A5260),
          Color(0xFF8E97A4),
          Color(0xFFD4DCE6),
        ],
        stops: [0.0, 0.28, 0.65, 0.85, 1.0],
      );
      _workerShader.shader = chromeOuterBezelGradient.createShader(Rect.fromCircle(center: center, radius: knobRadius + 1.2));
      canvas.drawCircle(center, knobRadius + 1.2, _workerShader);

      final chromeBodyGradient = SweepGradient(
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
      );
      _workerShader.shader = chromeBodyGradient.createShader(Rect.fromCircle(center: center, radius: knobRadius));
      canvas.drawCircle(center, knobRadius, _workerShader);

      final innerRadius = knobRadius * 0.82;
      final innerFaceGradient = RadialGradient(
        center: const Alignment(-0.25, -0.3),
        radius: 0.85,
        colors: const [
          Color(0xFFFFFFFF),
          Color(0xFFE5E9EE),
          Color(0xFFB8C0CA),
          Color(0xFF848E9C),
        ],
        stops: const [0.0, 0.35, 0.75, 1.0],
      );
      _workerShader.shader = innerFaceGradient.createShader(Rect.fromCircle(center: center, radius: innerRadius));
      canvas.drawCircle(center, innerRadius, _workerShader);

      _workerStroke.strokeWidth = 0.9;
      _workerStroke.color = const Color(0xE6FFFFFF);
      canvas.drawCircle(center, innerRadius, _workerStroke);

    } else {
      // Standard / Grungy Metallic Knob Body
      _workerFill.color = isGrungyTheme ? const Color(0xFF1B1815) : const Color(0xFF14171E);
      canvas.drawCircle(center, knobRadius + 1, _workerFill);

      _workerStroke.strokeWidth = 1.0;
      _workerStroke.color = isGrungyTheme ? const Color(0xFF3A342D) : const Color(0xFF282D3A);
      canvas.drawCircle(center, knobRadius + 1, _workerStroke);

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
      _workerShader.shader = bodyGradient.createShader(Rect.fromCircle(center: center, radius: knobRadius));
      canvas.drawCircle(center, knobRadius, _workerShader);

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
      _workerShader.shader = innerFaceGradient.createShader(Rect.fromCircle(center: center, radius: innerRadius));
      canvas.drawCircle(center, innerRadius, _workerShader);

      _workerStroke.strokeWidth = 1.0;
      _workerStroke.color = Color.fromRGBO(255, 255, 255, isGrungyTheme ? 0.12 : 0.20);
      canvas.drawCircle(center, innerRadius, _workerStroke);
    }

    // ----------------------------------------------------
    // 4. Pointer Notch / Line
    // ----------------------------------------------------
    final p1 = center + Offset(math.cos(currentAngle) * (knobRadius * 0.15), math.sin(currentAngle) * (knobRadius * 0.15));
    final p2 = center + Offset(math.cos(currentAngle) * (knobRadius * (isChrome ? 0.64 : 0.72)), math.sin(currentAngle) * (knobRadius * (isChrome ? 0.64 : 0.72)));

    if (isSnes) {
      canvas.drawLine(p1, p2, _snesNotchPaint);
    } else if (isChrome) {
      canvas.drawLine(p1, p2, _chromeNotchShadow);

      final normalAngle = currentAngle + math.pi * 0.5;
      final offsetHl = Offset(math.cos(normalAngle) * 0.7, math.sin(normalAngle) * 0.7);
      canvas.drawLine(p1 + offsetHl, p2 + offsetHl, _chromeNotchHl);
    } else {
      _pointerGlowPaint.color = accentColor.withOpacity(0.7);
      canvas.drawLine(p1, p2, _pointerGlowPaint);

      _workerStroke.color = accentColor;
      _workerStroke.strokeWidth = 2.5;
      _workerStroke.strokeCap = StrokeCap.round;
      canvas.drawLine(p1, p2, _workerStroke);
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
