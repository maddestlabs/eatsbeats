import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../lua/lua_gui_model.dart' show SliderStyle;
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
  final SliderStyle style;
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
    this.style = SliderStyle.capsule,
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
        final widgetHeight = isHoriz ? (widget.style == SliderStyle.capsule ? 26.0 : 36.0) : totalLength;

        final content = SizedBox(
          width: widgetWidth,
          height: widgetHeight,
          child: CustomPaint(
            painter: _FaderPainter(
              normalizedValue: normalized,
              accentColor: activeColor,
              isGrungyTheme: isGrungy,
              orientation: widget.orientation,
              style: widget.style,
              showLevelMarkings: widget.showLevelMarkings,
            ),
          ),
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
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
  final SliderStyle style;
  final bool showLevelMarkings;

  _FaderPainter({
    required this.normalizedValue,
    required this.accentColor,
    required this.isGrungyTheme,
    required this.orientation,
    required this.style,
    required this.showLevelMarkings,
  });

  // Pre-allocated static worker paints (zero allocation per frame during fader drag)
  static final Paint _workerFill = Paint()..style = PaintingStyle.fill;
  static final Paint _workerStroke = Paint()..style = PaintingStyle.stroke;
  static final Paint _workerShader = Paint();
  static final Paint _blurShadow5 = Paint()
    ..color = const Color(0xA6000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
  static final Paint _blurShadow4 = Paint()
    ..color = const Color(0x99000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
  static final Paint _contactShadow80 = Paint()..color = const Color(0xCC000000);
  static final Paint _contactShadow75 = Paint()..color = const Color(0xBF000000);
  static final Paint _stripeGlow = Paint()
    ..strokeWidth = 4.0
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

  static final Paint _trackSlotDark = Paint()..color = const Color(0xFF070708);
  static final Paint _trackSlotBorderGrungy = Paint()
    ..color = const Color(0xFF38322B)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  static final Paint _trackSlotBorderNormal = Paint()
    ..color = const Color(0xFF202633)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;

  static final Paint _tickMajor = Paint()..color = const Color(0xFF687285)..strokeWidth = 1.0;
  static final Paint _tickMinor = Paint()..color = const Color(0xFF3A4252)..strokeWidth = 0.8;
  static final Paint _scoreDark = Paint()..color = const Color(0xFF0F1014)..strokeWidth = 1.0;
  static final Paint _scoreLight = Paint()..color = const Color(0xFF707684)..strokeWidth = 0.8;

  static final Paint _capWhiteRim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..color = const Color(0x59FFFFFF);
  static final Paint _capInsetGroove = Paint()..color = const Color(0xFF0B0C0F);
  static final Paint _stripeWhiteCore = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..strokeWidth = 2.0;

  static final TextPainter _cachedZeroLabel = TextPainter(
    text: const TextSpan(
      text: '0.00',
      style: TextStyle(fontFamily: 'monospace', color: Color(0xFF687285), fontSize: 7, fontWeight: FontWeight.bold),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final isHoriz = orientation == Axis.horizontal;
    final trackLength = isHoriz ? size.width : size.height;
    final trackCross = isHoriz ? size.height : size.width;
    final centerCross = trackCross / 2;

    // Capsule Style (Real-world tactile pill track + circular aluminum button thumb)
    if (style == SliderStyle.capsule && isHoriz) {
      _paintCapsuleSlider(canvas, size, trackLength, trackCross, centerCross);
      return;
    }

    if (style == SliderStyle.minimalPill) {
      _paintMinimalPillSlider(canvas, size, trackLength, trackCross, centerCross, isHoriz);
      return;
    }

    final capBreadth = isHoriz ? 32.0 : 18.0;
    final capThickness = isHoriz ? 18.0 : 32.0;

    // 1. Recessed Studio Track Well & Slot
    final slotBorderPaint = isGrungyTheme ? _trackSlotBorderGrungy : _trackSlotBorderNormal;

    if (isHoriz) {
      final slotRect = Rect.fromLTRB(10, centerCross - 2.5, trackLength - 10, centerCross + 2.5);
      final rrect = RRect.fromRectAndRadius(slotRect, const Radius.circular(2));
      canvas.drawRRect(rrect, _trackSlotDark);
      canvas.drawRRect(rrect, slotBorderPaint);
    } else {
      final slotRect = Rect.fromLTRB(centerCross - 2.5, 10, centerCross + 2.5, trackLength - 10);
      final rrect = RRect.fromRectAndRadius(slotRect, const Radius.circular(2));
      canvas.drawRRect(rrect, _trackSlotDark);
      canvas.drawRRect(rrect, slotBorderPaint);
    }

    // Level Scale Tick Marks (when showLevelMarkings is true)
    if (!isHoriz && showLevelMarkings) {
      const miny = 14.0;
      final maxy = trackLength - 14.0;
      final travel = maxy - miny;

      const numTicks = 16;
      for (int i = 0; i <= numTicks; i++) {
        final frac = i / numTicks;
        final yPos = maxy - (frac * travel);

        final isMajor = (i % 4 == 0);
        final tickLen = isMajor ? 5.0 : 3.0;
        final paint = isMajor ? _tickMajor : _tickMinor;

        // Left Ticks
        canvas.drawLine(Offset(centerCross - 4.0 - tickLen, yPos), Offset(centerCross - 4.0, yPos), paint);
        // Right Ticks
        canvas.drawLine(Offset(centerCross + 4.0, yPos), Offset(centerCross + 4.0 + tickLen, yPos), paint);
      }

      // Draw bottom "0.00" label using pre-cached TextPainter
      _cachedZeroLabel.paint(canvas, Offset(centerCross - (_cachedZeroLabel.width / 2), trackLength - 9));
    }

    // Outer Recessed Channel Boundary Frame
    final channelBoundary = isHoriz
        ? Rect.fromLTRB(6, centerCross - 14, trackLength - 6, centerCross + 14)
        : Rect.fromLTRB(centerCross - 14, 6, centerCross + 14, trackLength - 6);
    _workerStroke.style = PaintingStyle.stroke;
    _workerStroke.strokeWidth = 1.0;
    _workerStroke.color = isGrungyTheme ? const Color(0xFF2B2621) : const Color(0xFF161C26);
    canvas.drawRRect(
      RRect.fromRectAndRadius(channelBoundary, const Radius.circular(3)),
      _workerStroke,
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
      _blurShadow5,
    );
    // Layer 2: Tight directional contact shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect.shift(const Offset(0, 2)), const Radius.circular(2)),
      _contactShadow80,
    );

    // High-End Skeuomorphic 3D Metallic Fader Cap Gradient
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

    _workerShader.shader = capGradient.createShader(capRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, const Radius.circular(3)),
      _workerShader,
    );

    // Recessed Central Knurling Grip Area Background Shading
    const bevelDepth = 5.5;
    final gripRect = !isHoriz
        ? Rect.fromLTRB(capRect.left + 1.0, capRect.top + bevelDepth, capRect.right - 1.0, capRect.bottom - bevelDepth)
        : Rect.fromLTRB(capRect.left + bevelDepth, capRect.top + 1.0, capRect.right - bevelDepth, capRect.bottom - 1.0);

    _workerFill.color = const Color(0x1F000000);
    canvas.drawRect(gripRect, _workerFill);

    // Knurling Score Lines inside the Central Grip Section
    if (!isHoriz) {
      for (double y = gripRect.top + 2.0; y < gripRect.bottom - 1.5; y += 2.6) {
        if ((y - capCenterPos).abs() < 2.5) continue;
        canvas.drawLine(Offset(capRect.left + 2.0, y), Offset(capRect.right - 2.0, y), _scoreDark);
        canvas.drawLine(Offset(capRect.left + 2.0, y + 0.8), Offset(capRect.right - 2.0, y + 0.8), _scoreLight);
      }
    } else {
      for (double x = gripRect.left + 2.0; x < gripRect.right - 1.5; x += 2.6) {
        if ((x - capCenterPos).abs() < 2.5) continue;
        canvas.drawLine(Offset(x, capRect.top + 2.0), Offset(x, capRect.bottom - 2.0), _scoreDark);
        canvas.drawLine(Offset(x + 0.8, capRect.top + 2.0), Offset(x + 0.8, capRect.bottom - 2.0), _scoreLight);
      }
    }

    // 3D Facet Bevel Highlight & Shadow Frames
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, const Radius.circular(3)),
      _capWhiteRim,
    );

    _workerStroke.strokeWidth = 1.0;
    if (!isHoriz) {
      _workerStroke.color = const Color(0xD9FFFFFF);
      canvas.drawLine(
        Offset(capRect.left + 2.0, capRect.top + 1.0),
        Offset(capRect.right - 2.0, capRect.top + 1.0),
        _workerStroke,
      );
      _workerStroke.color = const Color(0x991B1C22);
      canvas.drawLine(
        Offset(capRect.left + 1.5, capRect.top + bevelDepth),
        Offset(capRect.right - 1.5, capRect.top + bevelDepth),
        _workerStroke,
      );
      _workerStroke.color = const Color(0x40FFFFFF);
      canvas.drawLine(
        Offset(capRect.left + 1.5, capRect.bottom - bevelDepth),
        Offset(capRect.right - 1.5, capRect.bottom - bevelDepth),
        _workerStroke,
      );
      _workerStroke.color = const Color(0xFF08090C);
      canvas.drawLine(
        Offset(capRect.left + 2.0, capRect.bottom - 1.0),
        Offset(capRect.right - 2.0, capRect.bottom - 1.0),
        _workerStroke,
      );
    } else {
      _workerStroke.color = const Color(0xD9FFFFFF);
      canvas.drawLine(
        Offset(capRect.left + 1.0, capRect.top + 2.0),
        Offset(capRect.left + 1.0, capRect.bottom - 2.0),
        _workerStroke,
      );
      _workerStroke.color = const Color(0x991B1C22);
      canvas.drawLine(
        Offset(capRect.left + bevelDepth, capRect.top + 1.5),
        Offset(capRect.left + bevelDepth, capRect.bottom - 1.5),
        _workerStroke,
      );
      _workerStroke.color = const Color(0x40FFFFFF);
      canvas.drawLine(
        Offset(capRect.right - bevelDepth, capRect.top + 1.5),
        Offset(capRect.right - bevelDepth, capRect.bottom - 1.5),
        _workerStroke,
      );
      _workerStroke.color = const Color(0xFF08090C);
      canvas.drawLine(
        Offset(capRect.right - 1.0, capRect.top + 2.0),
        Offset(capRect.right - 1.0, capRect.bottom - 2.0),
        _workerStroke,
      );
    }

    // Center Recessed Notch & Illuminated Neon Indicator Stripe
    final neonColor = accentColor == EatsTheme.primaryCyan ? const Color(0xFFFF007A) : accentColor;
    
    if (isHoriz) {
      canvas.drawRect(
        Rect.fromLTRB(capCenterPos - 1.5, capRect.top + 1.5, capCenterPos + 1.5, capRect.bottom - 1.5),
        _capInsetGroove,
      );
    } else {
      canvas.drawRect(
        Rect.fromLTRB(capRect.left + 1.5, capCenterPos - 1.5, capRect.right - 1.5, capCenterPos + 1.5),
        _capInsetGroove,
      );
    }

    _stripeGlow.color = neonColor;
    _workerStroke.color = neonColor;
    _workerStroke.strokeWidth = 2.0;

    if (isHoriz) {
      final topP = Offset(capCenterPos, capRect.top + 2);
      final botP = Offset(capCenterPos, capRect.bottom - 2);
      canvas.drawLine(topP, botP, _stripeGlow);
      canvas.drawLine(topP, botP, _workerStroke);
      canvas.drawLine(topP, botP, _stripeWhiteCore);
    } else {
      final leftP = Offset(capRect.left + 2, capCenterPos);
      final rightP = Offset(capRect.right - 2, capCenterPos);
      canvas.drawLine(leftP, rightP, _stripeGlow);
      canvas.drawLine(leftP, rightP, _workerStroke);
      canvas.drawLine(leftP, rightP, _stripeWhiteCore);
    }
  }

  void _paintCapsuleSlider(Canvas canvas, Size size, double trackLength, double trackCross, double centerCross) {
    const margin = 10.0;
    const trackHeight = 7.0;
    const halfTrackH = trackHeight / 2.0;
    final trackRadius = Radius.circular(halfTrackH);
    final slotRect = Rect.fromLTRB(margin, centerCross - halfTrackH, trackLength - margin, centerCross + halfTrackH);
    final slotRRect = RRect.fromRectAndRadius(slotRect, trackRadius);

    // 1. Recessed Base Track Groove
    _workerFill.color = const Color(0xFF12151B);
    canvas.drawRRect(slotRRect, _workerFill);

    // 2. Track Inner Shadow (dark top edge)
    _workerShader.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF07090C), Color(0x0012151B)],
      stops: [0.0, 0.70],
    ).createShader(slotRect);
    canvas.drawRRect(slotRRect, _workerShader);

    // 3. Track Outer Border / Bottom Specular Highlight
    _workerStroke.style = PaintingStyle.stroke;
    _workerStroke.strokeWidth = 1.0;
    _workerStroke.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF090A0E), Color(0xFF2B303C)],
    ).createShader(slotRect);
    canvas.drawRRect(slotRRect, _workerStroke);

    // 4. Glowing Active Track Fill
    final thumbTravel = (trackLength - 2 * margin - 16.0);
    final thumbCenterPos = margin + 8.0 + (normalizedValue.clamp(0.0, 1.0) * thumbTravel);

    if (thumbCenterPos > margin + halfTrackH) {
      final activeRect = Rect.fromLTRB(margin, centerCross - halfTrackH + 0.5, thumbCenterPos, centerCross + halfTrackH - 0.5);
      final activeRRect = RRect.fromRectAndRadius(activeRect, Radius.circular(halfTrackH - 0.5));

      final activeGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withOpacity(0.95),
          accentColor.withOpacity(0.70),
        ],
      );
      _workerShader.shader = activeGradient.createShader(activeRect);
      canvas.drawRRect(activeRRect, _workerShader);

      // Specular Top Ridge inside active fill
      _workerStroke.shader = null;
      _workerStroke.color = const Color(0x59FFFFFF);
      _workerStroke.strokeWidth = 0.8;
      canvas.drawLine(
        Offset(margin + halfTrackH, centerCross - halfTrackH + 1.0),
        Offset(thumbCenterPos - 1.0, centerCross - halfTrackH + 1.0),
        _workerStroke,
      );
    }

    // 5. Circular Brushed Metallic Disc Thumb Button
    const thumbRadius = 9.0;
    final thumbCenter = Offset(thumbCenterPos, centerCross);
    final thumbRect = Rect.fromCircle(center: thumbCenter, radius: thumbRadius);

    // Ambient Soft Drop Shadow
    canvas.drawCircle(
      thumbCenter.translate(0, 2.5),
      thumbRadius + 0.5,
      _blurShadow4,
    );

    // Tight Contact Shadow
    canvas.drawCircle(
      thumbCenter.translate(0, 1.2),
      thumbRadius,
      _contactShadow75,
    );

    // Outer Beveled Dark Rim
    _workerFill.color = const Color(0xFF4A4E58);
    canvas.drawCircle(thumbCenter, thumbRadius, _workerFill);

    // Radial Metallic Brushed Face Gradient
    final buttonGradient = RadialGradient(
      center: const Alignment(-0.25, -0.35),
      radius: 0.85,
      colors: const [
        Color(0xFFFFFFFF), // Specular light reflection on top-left
        Color(0xFFE6E9EE), // Polished aluminum body
        Color(0xFFB8BFC8), // Mid-tone metallic gradient
        Color(0xFF7A808A), // Shaded bottom-right aluminum bevel
      ],
      stops: const [0.0, 0.35, 0.75, 1.0],
    );
    _workerShader.shader = buttonGradient.createShader(thumbRect);
    canvas.drawCircle(thumbCenter, thumbRadius - 0.9, _workerShader);

    // Subtle Machined Center Concentric Ring
    _workerStroke.shader = null;
    _workerStroke.color = const Color(0x8C888E99);
    _workerStroke.strokeWidth = 0.7;
    canvas.drawCircle(thumbCenter, 3.0, _workerStroke);
  }

  void _paintMinimalPillSlider(Canvas canvas, Size size, double trackLength, double trackCross, double centerCross, bool isHoriz) {
    const margin = 12.0;
    const slotThickness = 3.5;
    const halfSlot = slotThickness / 2.0;

    // 1. Recessed Narrow Dark Slit Track
    final slotRect = isHoriz
        ? Rect.fromLTRB(margin, centerCross - halfSlot, trackLength - margin, centerCross + halfSlot)
        : Rect.fromLTRB(centerCross - halfSlot, margin, centerCross + halfSlot, trackLength - margin);

    final slotRRect = RRect.fromRectAndRadius(slotRect, const Radius.circular(1.8));

    // Dark track well
    _workerFill.color = const Color(0xFF1E2024);
    canvas.drawRRect(slotRRect, _workerFill);

    // Inset top/left shadow for physical slot depth
    _workerStroke.shader = null;
    _workerStroke.color = const Color(0xFF0F1012);
    _workerStroke.style = PaintingStyle.stroke;
    _workerStroke.strokeWidth = 0.8;
    canvas.drawRRect(slotRRect, _workerStroke);

    // 2. Compute Thumb Position
    final thumbTravel = trackLength - 2 * margin - 12.0;
    final thumbCenterPos = isHoriz
        ? margin + 6.0 + (normalizedValue.clamp(0.0, 1.0) * thumbTravel)
        : trackLength - margin - 6.0 - (normalizedValue.clamp(0.0, 1.0) * thumbTravel);

    // 3. Ceramic Matte White Capsule Thumb
    final thumbW = isHoriz ? 11.0 : 26.0;
    final thumbH = isHoriz ? 26.0 : 11.0;
    final thumbRadius = const Radius.circular(5.0);

    final thumbCenter = isHoriz ? Offset(thumbCenterPos, centerCross) : Offset(centerCross, thumbCenterPos);
    final thumbRect = Rect.fromCenter(center: thumbCenter, width: thumbW, height: thumbH);
    final thumbRRect = RRect.fromRectAndRadius(thumbRect, thumbRadius);

    // Ambient drop shadow
    _workerFill.color = const Color(0x33000000);
    canvas.drawRRect(
      RRect.fromRectAndRadius(thumbRect.translate(0, 3.0), thumbRadius),
      _blurShadow4,
    );

    // Subtle contact shadow
    _workerFill.color = const Color(0x59000000);
    canvas.drawRRect(
      RRect.fromRectAndRadius(thumbRect.translate(0, 1.0), thumbRadius),
      _workerFill,
    );

    // Thumb Body Gradient (Matte ceramic white)
    final thumbGradient = LinearGradient(
      begin: isHoriz ? Alignment.centerLeft : Alignment.topCenter,
      end: isHoriz ? Alignment.centerRight : Alignment.bottomCenter,
      colors: const [
        Color(0xFFFFFFFF),
        Color(0xFFF7F8FA),
        Color(0xFFECEEF2),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    _workerShader.shader = thumbGradient.createShader(thumbRect);
    canvas.drawRRect(thumbRRect, _workerShader);

    // Outer subtle border
    _workerStroke.shader = null;
    _workerStroke.strokeWidth = 1.0;
    _workerStroke.color = const Color(0xFFD2D5DC);
    canvas.drawRRect(thumbRRect, _workerStroke);

    // Center Dark Indicator Notch Line
    _workerStroke.color = const Color(0xFF22242A);
    _workerStroke.strokeWidth = 1.6;
    _workerStroke.strokeCap = StrokeCap.round;

    if (isHoriz) {
      canvas.drawLine(
        Offset(thumbCenter.dx, thumbCenter.dy - 6.0),
        Offset(thumbCenter.dx, thumbCenter.dy + 6.0),
        _workerStroke,
      );
    } else {
      canvas.drawLine(
        Offset(thumbCenter.dx - 6.0, thumbCenter.dy),
        Offset(thumbCenter.dx + 6.0, thumbCenter.dy),
        _workerStroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FaderPainter oldDelegate) {
    return oldDelegate.normalizedValue != normalizedValue ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isGrungyTheme != isGrungyTheme ||
        oldDelegate.orientation != orientation ||
        oldDelegate.style != style ||
        oldDelegate.showLevelMarkings != showLevelMarkings;
  }
}
