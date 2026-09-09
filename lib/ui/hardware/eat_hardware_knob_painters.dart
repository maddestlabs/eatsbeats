import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/eats_theme.dart';
import 'eat_hardware_knob_model.dart';
import 'eat_hardware_scale.dart';

/// PASS 1: Static Dial Painter (Cached once in GPU memory via RepaintBoundary).
/// Draws chassis gutter, dial graduation ticks, numeric/semantic labels, and inactive arc track.
class EatStaticDialPainter extends CustomPainter {
  final EatHardwareKnobStyle style;

  EatStaticDialPainter({required this.style});

  // Zero-alloc static worker paints for static pass
  static final Paint _staticFill = Paint()..style = PaintingStyle.fill;
  static final Paint _staticStroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final scale = style.scale;
    final hasLabels = scale.labels.isNotEmpty;
    final scalePad = hasLabels ? 22.0 : (scale.tickDivisions > 0 ? 10.0 : 4.0);
    final coreDiameter = math.max(20.0, size.width - scalePad);
    // Base radius of the inner knob core (approx 36% of core diameter)
    final baseRadius = coreDiameter * 0.36;

    // 0. Ambient / Chassis Trench Halo Glow (e.g. Acid Neon Green or Track Accent)
    if (style.haloColor != null) {
      final haloRadius = baseRadius * (style.skirtRadiusRatio > 1.0 ? style.skirtRadiusRatio : 1.0) + style.bezelWidth + 1.0;
      final haloColor = style.haloColor!;

      _staticStroke.strokeCap = StrokeCap.round;

      // Soft diffuse ambient outer halo
      _staticStroke.color = haloColor.withOpacity(0.20);
      _staticStroke.strokeWidth = 9.0;
      canvas.drawCircle(center, haloRadius, _staticStroke);

      // Mid-intensity radiant aura
      _staticStroke.color = haloColor.withOpacity(0.45);
      _staticStroke.strokeWidth = 5.0;
      canvas.drawCircle(center, haloRadius, _staticStroke);

      // Intense core glow ring
      _staticStroke.color = haloColor.withOpacity(0.90);
      _staticStroke.strokeWidth = 2.0;
      canvas.drawCircle(center, haloRadius, _staticStroke);
    }

    // 1. Mounting Bezel / Collar / Gutter
    if (style.bezelStyle != EatBezelStyle.none) {
      final bezelRadius = baseRadius * style.skirtRadiusRatio + style.bezelWidth;
      _staticStroke.color = style.bezelColor ?? const Color(0x33000000);
      _staticStroke.strokeWidth = style.bezelWidth;
      canvas.drawCircle(center, bezelRadius, _staticStroke);
    }

    // 2. Inactive Arc Track (if arcMode is enabled)
    if (style.arcMode != EatArcMode.disabled) {
      final arcRadius = baseRadius * style.trackRadiusRatio;
      _staticStroke.color = style.trackInactiveColor;
      _staticStroke.strokeWidth = style.trackThickness;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: arcRadius),
        scale.startAngle,
        scale.sweepAngle,
        false,
        _staticStroke,
      );
    }

    // 3. Dial Scale Graduation Ticks & Detents
    final tickColor = scale.tickColor ?? const Color(0xFF1E1E24);
    _staticStroke.color = tickColor;

    final divisions = math.max(1, scale.tickDivisions);
    final tickRingRadius = baseRadius * style.trackRadiusRatio + 3.0;

    for (int i = 0; i <= divisions; i++) {
      final t = i / divisions;
      final angle = scale.startAngle + (t * scale.sweepAngle);
      final isCenterDetent = scale.hasCenterDetent && (t - 0.5).abs() < 0.01;
      final isMajor = i == 0 || i == divisions || isCenterDetent;
      final isDetent = scale.detents.any((d) => (t - d).abs() < 0.01);
      final isBlock = scale.hasBlockCenterDetent && isCenterDetent;

      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      if (isBlock) {
        // Authentic TB-303 bold rectangular calibration block at 12 o'clock
        _staticStroke.strokeCap = StrokeCap.square;
        _staticStroke.strokeWidth = scale.majorTickWidth;
        final p1 = Offset(center.dx + tickRingRadius * cosA, center.dy + tickRingRadius * sinA);
        final p2 = Offset(center.dx + (tickRingRadius + scale.majorTickLength) * cosA, center.dy + (tickRingRadius + scale.majorTickLength) * sinA);
        canvas.drawLine(p1, p2, _staticStroke);
        _staticStroke.strokeCap = StrokeCap.round;
      } else {
        final len = (isMajor || isDetent) ? scale.majorTickLength : scale.tickLength;
        final strokeW = (isMajor || isDetent) ? scale.majorTickWidth : scale.tickWidth;

        _staticStroke.strokeWidth = strokeW;

        final p1 = Offset(center.dx + (tickRingRadius) * cosA, center.dy + (tickRingRadius) * sinA);
        final p2 = Offset(center.dx + (tickRingRadius + len) * cosA, center.dy + (tickRingRadius + len) * sinA);

        canvas.drawLine(p1, p2, _staticStroke);
      }
    }

    // 4. Dial Scale Text Legends (e.g., '0'..'10', 'low'/'mid'/'high', '1'..'6')
    if (scale.labels.isNotEmpty) {
      final textCount = scale.labels.length;
      final textRingRadius = tickRingRadius + scale.majorTickLength + 3.0;
      final textColor = scale.labelColor ?? tickColor;

      for (int i = 0; i < textCount; i++) {
        final label = scale.labels[i];
        final t = textCount > 1 ? i / (textCount - 1) : 0.5;
        final angle = scale.startAngle + (t * scale.sweepAngle);

        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: scale.labelFontSize,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              color: textColor,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final labelCenter = Offset(
          center.dx + textRingRadius * math.cos(angle),
          center.dy + textRingRadius * math.sin(angle),
        );

        final topLeft = Offset(
          labelCenter.dx - textPainter.width / 2,
          labelCenter.dy - textPainter.height / 2,
        );

        textPainter.paint(canvas, topLeft);
      }
    }

    // 5. Lead Label (e.g. 'dyn' for sustain)
    if (scale.leadLabel != null && scale.leadLabel!.isNotEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: scale.leadLabel!,
          style: TextStyle(
            fontSize: scale.labelFontSize,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
            color: scale.labelColor ?? tickColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final leadAngle = scale.startAngle + 0.35; // Positioned near bottom left
      final leadRadius = tickRingRadius + scale.majorTickLength + 7.0;
      final leadCenter = Offset(
        center.dx + leadRadius * math.cos(leadAngle),
        center.dy + leadRadius * math.sin(leadAngle),
      );

      textPainter.paint(
        canvas,
        Offset(leadCenter.dx - textPainter.width / 2, leadCenter.dy - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant EatStaticDialPainter old) {
    return old.style != style;
  }
}

/// PASS 2: Dynamic Knob Painter (Zero-allocation, running at 60/120 FPS).
/// Paints rotating skirt, knurled flutes/grips, insert disc, indicator pointer, and active halo arc.
class EatDynamicKnobPainter extends CustomPainter {
  final double normalizedValue;
  final EatHardwareKnobStyle style;

  EatDynamicKnobPainter({
    required this.normalizedValue,
    required this.style,
  });

  // Reusable static worker paints for ZERO heap allocations inside paint()
  static final Paint _workerFill = Paint()..style = PaintingStyle.fill;
  static final Paint _workerStroke = Paint()..style = PaintingStyle.stroke;
  static final Paint _workerShader = Paint();
  static final Paint _workerArc = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _knobDropShadow = Paint()
    ..color = const Color(0x73000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
  static final Paint _knobContactShadow = Paint()
    ..color = const Color(0x8C000000);
  static final Paint _capWhiteBevel = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.9
    ..color = const Color(0x55FFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final scale = style.scale;
    final hasLabels = scale.labels.isNotEmpty;
    final scalePad = hasLabels ? 22.0 : (scale.tickDivisions > 0 ? 10.0 : 4.0);
    final coreDiameter = math.max(20.0, size.width - scalePad);
    final baseRadius = coreDiameter * 0.36;
    final clampedValue = normalizedValue.clamp(0.0, 1.0);
    final currentAngle = scale.startAngle + (clampedValue * scale.sweepAngle);

    // 1. Active Value Arc (Unipolar or Bipolar)
    if (style.arcMode == EatArcMode.unipolar) {
      _workerArc.color = style.trackActiveColor;
      _workerArc.strokeWidth = style.trackThickness;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: baseRadius * style.trackRadiusRatio),
        scale.startAngle,
        clampedValue * scale.sweepAngle,
        false,
        _workerArc,
      );
    } else if (style.arcMode == EatArcMode.bipolarCenter) {
      _workerArc.color = style.trackActiveColor;
      _workerArc.strokeWidth = style.trackThickness;
      final centerAngle = scale.startAngle + (scale.sweepAngle / 2.0);
      final sweep = (clampedValue - 0.5) * scale.sweepAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: baseRadius * style.trackRadiusRatio),
        centerAngle,
        sweep,
        false,
        _workerArc,
      );
    }

    // 2. Physical Ambient & Contact Drop Shadow under knob base
    final outerRadius = baseRadius * (style.skirtRadiusRatio > 1.0 ? style.skirtRadiusRatio : 1.0);
    canvas.drawCircle(center + const Offset(0, 2.6), outerRadius, _knobDropShadow);
    canvas.drawCircle(center + const Offset(0, 1.2), outerRadius, _knobContactShadow);

    // 3. Skirt & Outer Flange (Rotating Core Base with 3D Radial Lighting)
    if (style.skirtRadiusRatio > 1.0) {
      final skirtRadius = baseRadius * style.skirtRadiusRatio;
      final skirtLight = Color.lerp(style.bodyColor, Colors.white, 0.20)!;
      final skirtDark = Color.lerp(style.bodyColor, Colors.black, 0.42)!;
      final skirtGradient = RadialGradient(
        center: const Alignment(-0.25, -0.30),
        radius: 0.95,
        colors: [skirtLight, style.bodyColor, skirtDark],
        stops: const [0.0, 0.55, 1.0],
      );
      _workerShader.shader = skirtGradient.createShader(Rect.fromCircle(center: center, radius: skirtRadius));
      canvas.drawCircle(center, skirtRadius, _workerShader);

      // Skirt bevel border
      _workerStroke.color = Colors.black.withOpacity(0.40);
      _workerStroke.strokeWidth = 1.0;
      canvas.drawCircle(center, skirtRadius, _workerStroke);
    }

    // 4. Knurled Perimeter Grip Texture with Dual-Pass Tactile Groove Lighting
    if (style.knurlStyle != EatKnurlStyle.none && (style.ribCount > 0 || style.knurlStyle == EatKnurlStyle.fineSawtooth)) {
      final knurlColor = style.knurlColor ?? Colors.black.withOpacity(0.50);
      final outerR = baseRadius * (style.skirtRadiusRatio > 1.0 ? style.skirtRadiusRatio : 1.0);
      final innerR = outerR - style.ribDepth;

      if (style.knurlStyle == EatKnurlStyle.fineSawtooth) {
        // Authentic TB-303 48-tooth fine serrated potentiometer knurling
        final toothCount = style.ribCount > 0 ? style.ribCount : 48;
        final angleStep = (2.0 * math.pi) / toothCount;

        for (int i = 0; i < toothCount; i++) {
          final toothAngle = currentAngle + (i * angleStep);
          final cosT = math.cos(toothAngle);
          final sinT = math.sin(toothAngle);

          // Deep shadow valley groove of the sawtooth
          final p1 = Offset(center.dx + innerR * cosT, center.dy + innerR * sinT);
          final p2 = Offset(center.dx + outerR * cosT, center.dy + outerR * sinT);
          _workerStroke.color = knurlColor;
          _workerStroke.strokeWidth = 1.0;
          canvas.drawLine(p1, p2, _workerStroke);

          // Crisp lit crest facet highlight
          final crestAngle = toothAngle + (angleStep * 0.40);
          final cosC = math.cos(crestAngle);
          final sinC = math.sin(crestAngle);
          final p1C = Offset(center.dx + (innerR + 0.3) * cosC, center.dy + (innerR + 0.3) * sinC);
          final p2C = Offset(center.dx + outerR * cosC, center.dy + outerR * sinC);
          _workerStroke.color = const Color(0x77FFFFFF);
          _workerStroke.strokeWidth = 0.85;
          canvas.drawLine(p1C, p2C, _workerStroke);
        }
      } else {
        final ribCount = style.ribCount;
        for (int i = 0; i < ribCount; i++) {
          final ribAngle = currentAngle + (i * 2.0 * math.pi / ribCount);
          final cosR = math.cos(ribAngle);
          final sinR = math.sin(ribAngle);

          final p1 = Offset(center.dx + innerR * cosR, center.dy + innerR * sinR);
          final p2 = Offset(center.dx + outerR * cosR, center.dy + outerR * sinR);

          // Dark CNC milled groove
          _workerStroke.color = knurlColor;
          _workerStroke.strokeWidth = 1.4;
          canvas.drawLine(p1, p2, _workerStroke);

          // Micro-highlight line for physical 3D depth
          final p1Hl = Offset(p1.dx + 0.5, p1.dy + 0.5);
          final p2Hl = Offset(p2.dx + 0.5, p2.dy + 0.5);
          _workerStroke.color = const Color(0x33FFFFFF);
          _workerStroke.strokeWidth = 0.8;
          canvas.drawLine(p1Hl, p2Hl, _workerStroke);
        }
      }
    }

    // 5. Main Body Core Cylinder with Overhead 3D Lighting
    final bodyLight = Color.lerp(style.bodyColor, Colors.white, 0.22)!;
    final bodyDark = Color.lerp(style.bodyColor, Colors.black, 0.38)!;
    final bodyGradient = RadialGradient(
      center: const Alignment(-0.25, -0.30),
      radius: 0.92,
      colors: [bodyLight, style.bodyColor, bodyDark],
      stops: const [0.0, 0.50, 1.0],
    );
    _workerShader.shader = bodyGradient.createShader(Rect.fromCircle(center: center, radius: baseRadius));
    canvas.drawCircle(center, baseRadius, _workerShader);

    // Subtle edge rim shading
    _workerStroke.color = Colors.black.withOpacity(0.35);
    _workerStroke.strokeWidth = 0.8;
    canvas.drawCircle(center, baseRadius, _workerStroke);

    // 6. Cap & Insert Disc with High-End Lathe / Overhead Specular Lighting
    final defaultCapRatio = style.capStyle == EatCapStyle.insetRim ? 0.82 : 0.94;
    final effectiveCapRatio = (style.capRadiusRatio ?? defaultCapRatio).clamp(0.40, 1.0);
    final capRadius = baseRadius * effectiveCapRatio;

    if (style.capStyle == EatCapStyle.declinedScoop) {
      // Authentic Roland TB-303 / JC-303 Declined Wedge Scoop Cap
      // 1. Flat plateau circular disc with directional overhead lighting
      final capLight = Color.lerp(style.capColor, Colors.white, 0.25)!;
      final capDark = Color.lerp(style.capColor, Colors.black, 0.26)!;
      final plateauGradient = RadialGradient(
        center: const Alignment(-0.25, -0.30),
        radius: 0.90,
        colors: [capLight, style.capColor, capDark],
        stops: const [0.0, 0.50, 1.0],
      );
      _workerShader.shader = plateauGradient.createShader(Rect.fromCircle(center: center, radius: capRadius));
      canvas.drawCircle(center, capRadius, _workerShader);

      // 2. The Declined Wedge Scoop (oriented along currentAngle towards indicator)
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(currentAngle);

      // Clip strictly inside the circular cap boundary
      final capPath = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: capRadius));
      canvas.clipPath(capPath);

      // Transverse chord ridge step line positioned at x = -capRadius * 0.12
      final chordX = -capRadius * 0.12;

      // Fill the declined wedge facet with authentic slope gradient (matching JC-303 vector design)
      final wedgeRect = Rect.fromLTRB(chordX, -capRadius, capRadius + 2.0, capRadius);
      final wedgeLight = Color.lerp(style.capColor, Colors.white, 0.42)!;
      final wedgeMid = Color.lerp(style.capColor, Colors.white, 0.18)!;
      final wedgeDark = Color.lerp(style.capColor, Colors.black, 0.24)!;
      final wedgeGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [wedgeLight, wedgeMid, wedgeDark],
        stops: const [0.0, 0.45, 1.0],
      );
      _workerShader.shader = wedgeGradient.createShader(wedgeRect);
      canvas.drawRect(wedgeRect, _workerShader);

      // Crisp specular crest ridge line along the chord step
      _workerStroke.color = const Color(0x99FFFFFF);
      _workerStroke.strokeWidth = 1.0;
      canvas.drawLine(Offset(chordX, -capRadius), Offset(chordX, capRadius), _workerStroke);

      // Drop shadow underneath the chord crest line for 3D physical drop
      _workerStroke.color = const Color(0x55000000);
      _workerStroke.strokeWidth = 1.2;
      canvas.drawLine(Offset(chordX + 1.0, -capRadius), Offset(chordX + 1.0, capRadius), _workerStroke);

      // 3. Etched Pointer Notch Line centered right down the declined scoop
      final notchStart = chordX + (capRadius * 0.22);
      final notchEnd = capRadius * style.indicatorLength;

      // Contact shadow for etched depth
      _workerStroke.color = const Color(0x66000000);
      _workerStroke.strokeWidth = style.indicatorWidth;
      _workerStroke.strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(notchStart, 0.7), Offset(notchEnd, 0.7), _workerStroke);

      // Crisp dark pointer notch
      _workerStroke.color = style.indicatorColor;
      canvas.drawLine(Offset(notchStart, 0), Offset(notchEnd, 0), _workerStroke);

      canvas.restore();

      // Outer rim chamfer
      canvas.drawCircle(center, capRadius, _capWhiteBevel);
    } else if (style.capStyle == EatCapStyle.diagonalBar) {
      // 1. Satin bakelite disc face
      final capLight = Color.lerp(style.capColor, Colors.white, 0.14)!;
      final capDark = Color.lerp(style.capColor, Colors.black, 0.35)!;
      final capGradient = RadialGradient(
        center: const Alignment(-0.25, -0.30),
        radius: 0.90,
        colors: [capLight, style.capColor, capDark],
        stops: const [0.0, 0.50, 1.0],
      );
      _workerShader.shader = capGradient.createShader(Rect.fromCircle(center: center, radius: capRadius));
      canvas.drawCircle(center, capRadius, _workerShader);

      // Lit rim chamfer
      canvas.drawCircle(center, capRadius, _capWhiteBevel);

      // 2. Raised tactile diagonal ridge bar
      final barHalfLength = capRadius * 0.94;
      final barHalfWidth = capRadius * 0.23;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(currentAngle);

      final barRect = Rect.fromLTRB(-barHalfLength, -barHalfWidth, barHalfLength, barHalfWidth);
      final barRRect = RRect.fromRectAndRadius(barRect, const Radius.circular(2.0));

      // Bar contact drop shadow onto disc
      canvas.drawRRect(barRRect.shift(const Offset(0, 1.6)), _knobDropShadow);

      // Bar body gradient
      final barLight = Color.lerp(style.capColor, Colors.white, 0.22)!;
      final barDark = Color.lerp(style.capColor, Colors.black, 0.40)!;
      final barGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [barLight, style.capColor, barDark],
        stops: const [0.0, 0.35, 1.0],
      );
      _workerShader.shader = barGradient.createShader(barRect);
      canvas.drawRRect(barRRect, _workerShader);

      // Lit upper bevel on ridge
      _workerStroke.color = const Color(0x55FFFFFF);
      _workerStroke.strokeWidth = 0.9;
      canvas.drawLine(Offset(-barHalfLength + 2.0, -barHalfWidth), Offset(barHalfLength - 2.0, -barHalfWidth), _workerStroke);

      // Shadow lower bevel on ridge
      _workerStroke.color = Colors.black.withOpacity(0.55);
      _workerStroke.strokeWidth = 0.9;
      canvas.drawLine(Offset(-barHalfLength + 2.0, barHalfWidth), Offset(barHalfLength - 2.0, barHalfWidth), _workerStroke);

      // High-contrast pointer notch on tip
      final tipStart = barHalfLength * 0.35;
      final tipEnd = barHalfLength * 0.90;
      _workerStroke.color = const Color(0x66000000);
      _workerStroke.strokeWidth = style.indicatorWidth;
      _workerStroke.strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(tipStart, 0.7), Offset(tipEnd, 0.7), _workerStroke);

      _workerStroke.color = style.indicatorColor;
      canvas.drawLine(Offset(tipStart, 0), Offset(tipEnd, 0), _workerStroke);

      canvas.restore();

      // 3. Curved specular glass/acrylic gloss reflection streak (pinned to overhead 10:30 lighting)
      final glossRect = Rect.fromCircle(center: center + const Offset(-1.5, -2.5), radius: capRadius * 0.75);
      _workerStroke.color = const Color(0x38FFFFFF);
      _workerStroke.strokeWidth = capRadius * 0.28;
      _workerStroke.strokeCap = StrokeCap.round;
      canvas.drawArc(glossRect, -math.pi * 0.88, math.pi * 0.65, false, _workerStroke);

      // Inner crisp specular glint line
      _workerStroke.color = const Color(0x55FFFFFF);
      _workerStroke.strokeWidth = 1.0;
      canvas.drawArc(glossRect, -math.pi * 0.82, math.pi * 0.50, false, _workerStroke);
    } else if (style.capStyle == EatCapStyle.brushedMetal) {
      // Anisotropic brushed metallic lathe reflections that turn with the knob
      final brushedGradient = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi * 2.0,
        colors: [
          Color.lerp(style.capColor, Colors.white, 0.40)!,
          Color.lerp(style.capColor, Colors.black, 0.22)!,
          Color.lerp(style.capColor, Colors.white, 0.48)!,
          Color.lerp(style.capColor, Colors.black, 0.32)!,
          Color.lerp(style.capColor, Colors.white, 0.30)!,
          Color.lerp(style.capColor, Colors.black, 0.24)!,
          Color.lerp(style.capColor, Colors.white, 0.45)!,
          Color.lerp(style.capColor, Colors.white, 0.40)!,
        ],
        stops: const [0.0, 0.15, 0.30, 0.50, 0.65, 0.78, 0.90, 1.0],
        transform: GradientRotation(currentAngle),
      );
      _workerShader.shader = brushedGradient.createShader(Rect.fromCircle(center: center, radius: capRadius));
      canvas.drawCircle(center, capRadius, _workerShader);

      final capOverlay = RadialGradient(
        center: const Alignment(-0.25, -0.30),
        radius: 0.85,
        colors: const [
          Color(0x33FFFFFF),
          Color(0x00FFFFFF),
          Color(0x40000000),
        ],
        stops: const [0.0, 0.55, 1.0],
      );
      _workerShader.shader = capOverlay.createShader(Rect.fromCircle(center: center, radius: capRadius));
      canvas.drawCircle(center, capRadius, _workerShader);
    } else {
      // Overhead studio illumination with natural falloff
      final capLight = Color.lerp(style.capColor, Colors.white, 0.26)!;
      final capDark = Color.lerp(style.capColor, Colors.black, 0.30)!;
      final capGradient = RadialGradient(
        center: const Alignment(-0.25, -0.30),
        radius: 0.88,
        colors: [capLight, style.capColor, capDark],
        stops: const [0.0, 0.52, 1.0],
      );
      _workerShader.shader = capGradient.createShader(Rect.fromCircle(center: center, radius: capRadius));
      canvas.drawCircle(center, capRadius, _workerShader);
    }

    // Lit top-left specular chamfer rim
    canvas.drawCircle(center, capRadius, _capWhiteBevel);

    if (style.capStyle == EatCapStyle.insetRim) {
      _workerStroke.color = Colors.black.withOpacity(0.40);
      _workerStroke.strokeWidth = style.bevelWidth;
      canvas.drawCircle(center, capRadius - 0.5, _workerStroke);
    }

    // 7. Indicator Pointer (Analytical Trigonometry, Zero Allocations)
    // Note: diagonalBar and declinedScoop cap styles render their own integrated pointer notch
    if (style.capStyle != EatCapStyle.diagonalBar && style.capStyle != EatCapStyle.declinedScoop) {
      final cosA = math.cos(currentAngle);
      final sinA = math.sin(currentAngle);

      switch (style.indicatorStyle) {
        case EatIndicatorStyle.line:
          final startR = capRadius * 0.20;
          final endR = capRadius * style.indicatorLength;
          final pStart = Offset(center.dx + startR * cosA, center.dy + startR * sinA);
          final pEnd = Offset(center.dx + endR * cosA, center.dy + endR * sinA);

          // Subtle contact shadow line
          final pStartSh = Offset(pStart.dx + 0.6, pStart.dy + 0.8);
          final pEndSh = Offset(pEnd.dx + 0.6, pEnd.dy + 0.8);
          _workerStroke.color = const Color(0x66000000);
          _workerStroke.strokeWidth = style.indicatorWidth;
          _workerStroke.strokeCap = StrokeCap.round;
          canvas.drawLine(pStartSh, pEndSh, _workerStroke);

          // Lit indicator line
          _workerStroke.color = style.indicatorColor;
          canvas.drawLine(pStart, pEnd, _workerStroke);
          break;

        case EatIndicatorStyle.pipDot:
          // Indent punch pip dot on outer perimeter
          final pipR = capRadius * style.indicatorLength;
          final pipCenter = Offset(center.dx + pipR * cosA, center.dy + pipR * sinA);
          _workerFill.color = style.indicatorColor;
          canvas.drawCircle(pipCenter, style.indicatorWidth, _workerFill);
          break;

        case EatIndicatorStyle.illuminatedLed:
          // Active neon/LED glow pip
          final ledR = capRadius * style.indicatorLength;
          final ledCenter = Offset(center.dx + ledR * cosA, center.dy + ledR * sinA);

          // Core bright LED
          _workerFill.color = style.indicatorColor;
          canvas.drawCircle(ledCenter, style.indicatorWidth * 0.9, _workerFill);

          // Halo ring simulation (zero-alloc multi-pass stroke instead of MaskFilter blur)
          _workerStroke.color = style.indicatorColor.withOpacity(0.4);
          _workerStroke.strokeWidth = 2.0;
          canvas.drawCircle(ledCenter, style.indicatorWidth * 1.6, _workerStroke);
          break;

        case EatIndicatorStyle.triangleNeedle:
          // Protruding arrow/needle pointer
          final tipR = baseRadius * 1.08;
          final baseR = capRadius * 0.75;
          final halfAngle = 0.12;

          final pTip = Offset(center.dx + tipR * cosA, center.dy + tipR * sinA);
          final pLeft = Offset(center.dx + baseR * math.cos(currentAngle - halfAngle), center.dy + baseR * math.sin(currentAngle - halfAngle));
          final pRight = Offset(center.dx + baseR * math.cos(currentAngle + halfAngle), center.dy + baseR * math.sin(currentAngle + halfAngle));

          final path = Path()
            ..moveTo(pTip.dx, pTip.dy)
            ..lineTo(pLeft.dx, pLeft.dy)
            ..lineTo(pRight.dx, pRight.dy)
            ..close();

          _workerFill.color = style.indicatorColor;
          canvas.drawPath(path, _workerFill);
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant EatDynamicKnobPainter old) {
    return old.normalizedValue != normalizedValue || old.style != style;
  }
}
