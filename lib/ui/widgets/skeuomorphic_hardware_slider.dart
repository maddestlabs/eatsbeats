import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/eats_theme.dart';
import 'compact_value_dialog.dart';

/// A realistic skeuomorphic console mixer fader slider control.
/// Renders a recessed track slot, metallic ribbed fader cap with indicator stripe,
/// drop shadows, decibel tick marks, and double-tap/long-press gestures.
class SkeuomorphicHardwareSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double defaultValue;
  final String? label;
  final ValueChanged<double> onChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback? onChangeEnd;
  final Color? activeColor;
  final Axis orientation;
  final double length;
  final String Function(double)? formatValue;
  final bool showLevelMarkings;
  final bool showTooltip;
  final int? divisions;
  final double step;

  const SkeuomorphicHardwareSlider({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.5,
    required this.defaultValue,
    this.label,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor,
    this.orientation = Axis.horizontal,
    this.length = 160.0,
    this.formatValue,
    this.showLevelMarkings = true,
    this.showTooltip = true,
    this.divisions,
    this.step = 0.0,
  });

  @override
  State<SkeuomorphicHardwareSlider> createState() => _SkeuomorphicHardwareSliderState();
}

class _SkeuomorphicHardwareSliderState extends State<SkeuomorphicHardwareSlider> {
  void _updateValueFromPos(Offset localPosition, double totalLength, bool isHoriz) {
    final pos = isHoriz ? localPosition.dx : localPosition.dy;
    const margin = 14.0;
    final capTravel = math.max(1.0, totalLength - 2 * margin);
    final normalized = isHoriz
        ? ((pos - margin) / capTravel).clamp(0.0, 1.0)
        : ((totalLength - margin - pos) / capTravel).clamp(0.0, 1.0);
    final range = widget.max - widget.min;
    double newVal = widget.min + normalized * range;

    if (widget.step > 0) {
      newVal = (newVal / widget.step).roundToDouble() * widget.step;
    } else if (widget.divisions != null && widget.divisions! > 0) {
      final stepVal = range / widget.divisions!;
      newVal = (newVal / stepVal).roundToDouble() * stepVal;
    }

    newVal = newVal.clamp(widget.min, widget.max);
    widget.onChanged(newVal);
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.activeColor ?? EatsTheme.primaryCyan;
    final normalized = ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;
    final isHoriz = widget.orientation == Axis.horizontal;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalLength = isHoriz
            ? (constraints.hasBoundedWidth && constraints.maxWidth.isFinite ? constraints.maxWidth : widget.length)
            : (constraints.hasBoundedHeight && constraints.maxHeight.isFinite ? constraints.maxHeight : widget.length);

        final widgetWidth = isHoriz ? totalLength : 40.0;
        final widgetHeight = isHoriz ? 36.0 : totalLength;

        final content = SizedBox(
          width: widgetWidth,
          height: widgetHeight,
          child: CustomPaint(
            painter: _FaderPainter(
              normalizedValue: normalized,
              accentColor: activeColor,
              isGrungyTheme: isGrungy,
              orientation: widget.orientation,
              showLevelMarkings: widget.showLevelMarkings,
            ),
          ),
        );

        return GestureDetector(
          onTapDown: (details) {
            widget.onChangeStart?.call();
            _updateValueFromPos(details.localPosition, totalLength, isHoriz);
            widget.onChangeEnd?.call();
          },
          onPanDown: (details) => widget.onChangeStart?.call(),
          onPanStart: (details) => _updateValueFromPos(details.localPosition, totalLength, isHoriz),
          onPanUpdate: (details) => _updateValueFromPos(details.localPosition, totalLength, isHoriz),
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
          child: widget.showTooltip
              ? Tooltip(
                  message: '${widget.label ?? "Fader"}: ${widget.value.toStringAsFixed(2)}',
                  child: content,
                )
              : content,
        );
      },
    );
  }

  void _showManualEditDialog(BuildContext context) {
    final displayVal = widget.formatValue != null ? widget.formatValue!(widget.value) : widget.value.toStringAsFixed(2);
    final accent = widget.activeColor ?? EatsTheme.primaryCyan;

    showCompactValueEditDialog(
      context: context,
      title: widget.label != null ? 'Edit ${widget.label}' : 'Edit Value',
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

class _FaderPainter extends CustomPainter {
  final double normalizedValue;
  final Color accentColor;
  final bool isGrungyTheme;
  final Axis orientation;
  final bool showLevelMarkings;

  _FaderPainter({
    required this.normalizedValue,
    required this.accentColor,
    required this.isGrungyTheme,
    required this.orientation,
    required this.showLevelMarkings,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isHoriz = orientation == Axis.horizontal;
    final trackLength = isHoriz ? size.width : size.height;
    final trackCross = isHoriz ? size.height : size.width;

    final centerCross = trackCross / 2;
    final capBreadth = isHoriz ? 32.0 : 18.0;
    final capThickness = isHoriz ? 18.0 : 32.0;

    // 1. Recessed Studio Track Well & Slot
    final trackSlotPaint = Paint()..color = const Color(0xFF070708);
    final slotBorderPaint = Paint()
      ..color = isGrungyTheme ? const Color(0xFF38322B) : const Color(0xFF202633)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    if (isHoriz) {
      final slotRect = Rect.fromLTRB(10, centerCross - 2.5, trackLength - 10, centerCross + 2.5);
      canvas.drawRRect(RRect.fromRectAndRadius(slotRect, const Radius.circular(2)), trackSlotPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(slotRect, const Radius.circular(2)), slotBorderPaint);
    } else {
      final slotRect = Rect.fromLTRB(centerCross - 2.5, 10, centerCross + 2.5, trackLength - 10);
      canvas.drawRRect(RRect.fromRectAndRadius(slotRect, const Radius.circular(2)), trackSlotPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(slotRect, const Radius.circular(2)), slotBorderPaint);
    }

    // Level Scale Tick Marks (when showLevelMarkings is true)
    if (!isHoriz && showLevelMarkings) {
      final tickPaintMajor = Paint()..color = const Color(0xFF687285)..strokeWidth = 1.0;
      final tickPaintMinor = Paint()..color = const Color(0xFF3A4252)..strokeWidth = 0.8;
      const miny = 14.0;
      final maxy = trackLength - 14.0;
      final travel = maxy - miny;

      const numTicks = 16;
      for (int i = 0; i <= numTicks; i++) {
        final frac = i / numTicks;
        final yPos = maxy - (frac * travel);

        final isMajor = (i % 4 == 0);
        final tickLen = isMajor ? 5.0 : 3.0;
        final paint = isMajor ? tickPaintMajor : tickPaintMinor;

        // Left Ticks
        canvas.drawLine(Offset(centerCross - 4.0 - tickLen, yPos), Offset(centerCross - 4.0, yPos), paint);
        // Right Ticks
        canvas.drawLine(Offset(centerCross + 4.0, yPos), Offset(centerCross + 4.0 + tickLen, yPos), paint);
      }

      // Draw bottom "0.00" label
      final textPainter = TextPainter(
        text: const TextSpan(
          text: '0.00',
          style: TextStyle(fontFamily: 'monospace', color: Color(0xFF687285), fontSize: 7, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(centerCross - (textPainter.width / 2), trackLength - 9));
    }

    // Outer Recessed Channel Boundary Frame
    final channelBoundary = isHoriz
        ? Rect.fromLTRB(6, centerCross - 14, trackLength - 6, centerCross + 14)
        : Rect.fromLTRB(centerCross - 14, 6, centerCross + 14, trackLength - 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(channelBoundary, const Radius.circular(3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = isGrungyTheme ? const Color(0xFF2B2621) : const Color(0xFF161C26),
    );


    // 2. Fader Cap Position Calculation
    final capTravel = trackLength - 28.0;
    final capCenterPos = isHoriz
        ? 14.0 + (normalizedValue * capTravel)
        : (trackLength - 14.0) - (normalizedValue * capTravel);

    final capRect = isHoriz
        ? Rect.fromCenter(center: Offset(capCenterPos, centerCross), width: capThickness, height: capBreadth)
        : Rect.fromCenter(center: Offset(centerCross, capCenterPos), width: capBreadth, height: capThickness);

    // Realistic Heavy 3D Dual-Layer Drop Shadow
    // Layer 1: Ambient soft blur shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect.shift(const Offset(0, 4)), const Radius.circular(3)),
      Paint()
        ..color = Colors.black.withOpacity(0.65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0),
    );
    // Layer 2: Tight directional contact shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect.shift(const Offset(0, 2)), const Radius.circular(2)),
      Paint()..color = Colors.black.withOpacity(0.8),
    );

    // High-End Skeuomorphic 3D Metallic Fader Cap Gradient
    // Features lit top/left bevel chamfer, darker recessed knurled middle, and shaded bottom/right bevel chamfer
    final capGradient = LinearGradient(
      colors: const [
        Color(0xFFF2F5FA), // Lit specular top/left bevel edge
        Color(0xFFD6DADF), // Bright metallic silver top/left chamfer
        Color(0xFF7D8390), // Top chamfer fold line transition
        Color(0xFF30333B), // Upper shadow edge into knurled recess
        Color(0xFF4A4E58), // Mid knurled body metallic sheen
        Color(0xFF26282E), // Lower shadow edge out of knurled recess
        Color(0xFF5A606C), // Bottom chamfer fold line transition
        Color(0xFF202228), // Shaded metallic bottom/right chamfer
        Color(0xFF0D0E12), // Dark bottom rim shadow
      ],
      stops: const [0.0, 0.05, 0.16, 0.19, 0.50, 0.81, 0.84, 0.95, 1.0],
      begin: isHoriz ? Alignment.centerLeft : Alignment.topCenter,
      end: isHoriz ? Alignment.centerRight : Alignment.bottomCenter,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, const Radius.circular(3)),
      Paint()..shader = capGradient.createShader(capRect),
    );

    // Recessed Central Knurling Grip Area Background Shading (bevel size reduced by ~30% to 5.5px)
    const bevelDepth = 5.5;
    final gripRect = !isHoriz
        ? Rect.fromLTRB(capRect.left + 1.0, capRect.top + bevelDepth, capRect.right - 1.0, capRect.bottom - bevelDepth)
        : Rect.fromLTRB(capRect.left + bevelDepth, capRect.top + 1.0, capRect.right - bevelDepth, capRect.bottom - 1.0);

    canvas.drawRect(
      gripRect,
      Paint()..color = Colors.black.withOpacity(0.12),
    );

    // Knurling Score Lines inside the Central Grip Section
    final scoreLineDark = Paint()..color = const Color(0xFF0F1014)..strokeWidth = 1.0;
    final scoreLineLight = Paint()..color = const Color(0xFF707684)..strokeWidth = 0.8;

    if (!isHoriz) {
      // Vertical Slider: Horizontal scoring lines across top and bottom halves of middle grip
      for (double y = gripRect.top + 2.0; y < gripRect.bottom - 1.5; y += 2.6) {
        // Skip lines near the center notch indicator line
        if ((y - capCenterPos).abs() < 2.5) continue;
        canvas.drawLine(Offset(capRect.left + 2.0, y), Offset(capRect.right - 2.0, y), scoreLineDark);
        canvas.drawLine(Offset(capRect.left + 2.0, y + 0.8), Offset(capRect.right - 2.0, y + 0.8), scoreLineLight);
      }
    } else {
      // Horizontal Slider: Vertical scoring lines across left and right halves of middle grip
      for (double x = gripRect.left + 2.0; x < gripRect.right - 1.5; x += 2.6) {
        if ((x - capCenterPos).abs() < 2.5) continue;
        canvas.drawLine(Offset(x, capRect.top + 2.0), Offset(x, capRect.bottom - 2.0), scoreLineDark);
        canvas.drawLine(Offset(x + 0.8, capRect.top + 2.0), Offset(x + 0.8, capRect.bottom - 2.0), scoreLineLight);
      }
    }

    // 3D Facet Bevel Highlight & Shadow Frames
    // 1. Outer subtle rim highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, const Radius.circular(3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white.withOpacity(0.35),
    );

    // 2. Top/Left Specular Chamfer Highlight Line
    if (!isHoriz) {
      canvas.drawLine(
        Offset(capRect.left + 2.0, capRect.top + 1.0),
        Offset(capRect.right - 2.0, capRect.top + 1.0),
        Paint()
          ..color = Colors.white.withOpacity(0.85)
          ..strokeWidth = 1.0,
      );
      // Top Bevel Chamfer Fold Line
      canvas.drawLine(
        Offset(capRect.left + 1.5, capRect.top + bevelDepth),
        Offset(capRect.right - 1.5, capRect.top + bevelDepth),
        Paint()
          ..color = const Color(0xFF1B1C22).withOpacity(0.6)
          ..strokeWidth = 1.0,
      );
      // Bottom Bevel Chamfer Fold Line
      canvas.drawLine(
        Offset(capRect.left + 1.5, capRect.bottom - bevelDepth),
        Offset(capRect.right - 1.5, capRect.bottom - bevelDepth),
        Paint()
          ..color = Colors.white.withOpacity(0.25)
          ..strokeWidth = 1.0,
      );
      // Bottom Chamfer Edge Shadow Line
      canvas.drawLine(
        Offset(capRect.left + 2.0, capRect.bottom - 1.0),
        Offset(capRect.right - 2.0, capRect.bottom - 1.0),
        Paint()
          ..color = const Color(0xFF08090C)
          ..strokeWidth = 1.0,
      );
    } else {
      canvas.drawLine(
        Offset(capRect.left + 1.0, capRect.top + 2.0),
        Offset(capRect.left + 1.0, capRect.bottom - 2.0),
        Paint()
          ..color = Colors.white.withOpacity(0.85)
          ..strokeWidth = 1.0,
      );
      // Left Bevel Chamfer Fold Line
      canvas.drawLine(
        Offset(capRect.left + bevelDepth, capRect.top + 1.5),
        Offset(capRect.left + bevelDepth, capRect.bottom - 1.5),
        Paint()
          ..color = const Color(0xFF1B1C22).withOpacity(0.6)
          ..strokeWidth = 1.0,
      );
      // Right Bevel Chamfer Fold Line
      canvas.drawLine(
        Offset(capRect.right - bevelDepth, capRect.top + 1.5),
        Offset(capRect.right - bevelDepth, capRect.bottom - 1.5),
        Paint()
          ..color = Colors.white.withOpacity(0.25)
          ..strokeWidth = 1.0,
      );
      // Right Chamfer Edge Shadow Line
      canvas.drawLine(
        Offset(capRect.right - 1.0, capRect.top + 2.0),
        Offset(capRect.right - 1.0, capRect.bottom - 2.0),
        Paint()
          ..color = const Color(0xFF08090C)
          ..strokeWidth = 1.0,
      );
    }

    // Center Recessed Notch & Illuminated Neon Indicator Stripe
    final neonColor = accentColor == EatsTheme.primaryCyan ? const Color(0xFFFF007A) : accentColor;
    
    // Draw Dark Inset Center Groove Notch
    if (isHoriz) {
      canvas.drawRect(
        Rect.fromLTRB(capCenterPos - 1.5, capRect.top + 1.5, capCenterPos + 1.5, capRect.bottom - 1.5),
        Paint()..color = const Color(0xFF0B0C0F),
      );
    } else {
      canvas.drawRect(
        Rect.fromLTRB(capRect.left + 1.5, capCenterPos - 1.5, capRect.right - 1.5, capCenterPos + 1.5),
        Paint()..color = const Color(0xFF0B0C0F),
      );
    }

    final stripeGlowPaint = Paint()
      ..color = neonColor
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    final stripePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 2.0;

    final stripeAccentPaint = Paint()
      ..color = neonColor
      ..strokeWidth = 2.0;

    if (isHoriz) {
      final topP = Offset(capCenterPos, capRect.top + 2);
      final botP = Offset(capCenterPos, capRect.bottom - 2);
      canvas.drawLine(topP, botP, stripeGlowPaint);
      canvas.drawLine(topP, botP, stripeAccentPaint);
      canvas.drawLine(topP, botP, stripePaint);
    } else {
      final leftP = Offset(capRect.left + 2, capCenterPos);
      final rightP = Offset(capRect.right - 2, capCenterPos);
      canvas.drawLine(leftP, rightP, stripeGlowPaint);
      canvas.drawLine(leftP, rightP, stripeAccentPaint);
      canvas.drawLine(leftP, rightP, stripePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FaderPainter oldDelegate) {
    return oldDelegate.normalizedValue != normalizedValue ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isGrungyTheme != isGrungyTheme ||
        oldDelegate.orientation != orientation;
  }
}
