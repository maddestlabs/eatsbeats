import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'vector_skin_model.dart';

/// Ultra-high performance 2-pass CustomPainter for scriptable hardware controls.
///
/// PASS 1 (Retained Chassis): Static bezels, ticks, knurling, and background shapes
/// are recorded into a [Picture] ONCE upon initialization or resize.
///
/// PASS 2 (Dynamic Indicator): At 60/120 FPS, paints the cached picture with a single
/// GPU command, then applies a hardware matrix rotation to the needle/pointer.
class TwoPassVectorKnobPainter extends CustomPainter {
  final double normalizedValue;
  final CustomControlSkin skin;
  final Color accentColor;

  Picture? _cachedChassisPicture;
  Size? _lastSize;

  TwoPassVectorKnobPainter({
    required this.normalizedValue,
    required this.skin,
    required this.accentColor,
  });

  // Reusable worker paints to ensure ZERO heap allocation during 60/120 FPS frame callbacks
  static final Paint _workerFill = Paint()..style = PaintingStyle.fill;
  static final Paint _workerStroke = Paint()..style = PaintingStyle.stroke;
  static final Paint _workerGlow = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);

    // 1. PASS 1: Build & cache static chassis Picture if resized or not yet recorded
    if (_cachedChassisPicture == null || _lastSize != size) {
      final recorder = PictureRecorder();
      final chassisCanvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.width, size.height));
      _recordChassis(chassisCanvas, size, center);
      _cachedChassisPicture = recorder.endRecording();
      _lastSize = size;
    }

    // Single blit of pre-recorded vector chassis (near 0 CPU cost)
    canvas.drawPicture(_cachedChassisPicture!);

    // 2. PASS 2: Dynamic Indicator (Hardware matrix transform)
    final angle = skin.startAngle + (normalizedValue.clamp(0.0, 1.0) * skin.sweepAngle);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    _drawIndicator(canvas, skin.indicatorLayer, size);

    canvas.restore();
  }

  void _recordChassis(Canvas canvas, Size size, Offset center) {
    final scale = size.width / skin.defaultSize;

    for (final layer in skin.chassisLayers) {
      final color = layer.fillColor ?? layer.strokeColor ?? accentColor;

      if (layer.glow) {
        _workerGlow.color = color.withOpacity(0.6);
        _workerGlow.strokeWidth = layer.strokeWidth * scale * 1.5;
        _renderShape(canvas, center, layer, _workerGlow, size, scale);
      }

      final isFill = layer.fillColor != null;
      final Paint paint = isFill ? _workerFill : _workerStroke;
      paint.color = color;
      paint.strokeWidth = layer.strokeWidth * scale;

      _renderShape(canvas, center, layer, paint, size, scale);
    }
  }

  void _renderShape(Canvas canvas, Offset center, VectorShapeDef layer, Paint paint, Size size, double scale) {
    switch (layer.type) {
      case VectorShapeType.circle:
        final r = (layer.radius ?? (skin.defaultSize / 2 - 4)) * scale;
        canvas.drawCircle(center, r, paint);
        break;

      case VectorShapeType.rect:
        final rectDef = layer.rect ?? Rect.fromCenter(center: Offset.zero, width: skin.defaultSize * 0.8, height: skin.defaultSize * 0.8);
        final scaledRect = Rect.fromCenter(
          center: center + rectDef.center * scale,
          width: rectDef.width * scale,
          height: rectDef.height * scale,
        );
        if (layer.cornerRadius != null && layer.cornerRadius! > 0) {
          canvas.drawRRect(RRect.fromRectAndRadius(scaledRect, Radius.circular(layer.cornerRadius! * scale)), paint);
        } else {
          canvas.drawRect(scaledRect, paint);
        }
        break;

      case VectorShapeType.radialTicks:
        _drawTicks(canvas, center, layer, size, scale, paint);
        break;

      case VectorShapeType.svgPath:
        if (layer.precompiledPath != null) {
          canvas.save();
          canvas.translate(center.dx, center.dy);
          canvas.scale(scale, scale);
          canvas.drawPath(layer.precompiledPath!, paint);
          canvas.restore();
        }
        break;

      case VectorShapeType.arc:
        final r = (layer.radius ?? (skin.defaultSize / 2 - 4)) * scale;
        final rect = Rect.fromCircle(center: center, radius: r);
        canvas.drawArc(rect, layer.startAngle, layer.sweepAngle, false, paint);
        break;
    }
  }

  void _drawTicks(Canvas canvas, Offset center, VectorShapeDef def, Size size, double scale, Paint paint) {
    final tickPaint = Paint()
      ..color = paint.color
      ..strokeWidth = math.max(0.8, def.strokeWidth * scale)
      ..strokeCap = StrokeCap.round;

    final r = (def.radius ?? (skin.defaultSize / 2 - 3)) * scale;
    final tickLen = def.tickLength * scale;

    for (int i = 0; i < def.tickCount; i++) {
      final t = i / (def.tickCount > 1 ? def.tickCount - 1 : 1);
      final tickAngle = skin.startAngle + (t * skin.sweepAngle);
      final cosA = math.cos(tickAngle);
      final sinA = math.sin(tickAngle);

      final p1 = center + Offset(cosA * (r - tickLen), sinA * (r - tickLen));
      final p2 = center + Offset(cosA * r, sinA * r);
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  void _drawIndicator(Canvas canvas, VectorShapeDef def, Size size) {
    final scale = size.width / skin.defaultSize;
    final color = def.fillColor ?? def.strokeColor ?? accentColor;

    if (def.glow) {
      _workerGlow.color = color.withOpacity(0.7);
      _workerGlow.strokeWidth = def.strokeWidth * scale * 2.0;
      if (def.precompiledPath != null) {
        canvas.save();
        canvas.scale(scale, scale);
        canvas.drawPath(def.precompiledPath!, _workerGlow);
        canvas.restore();
      }
    }

    final isFill = def.fillColor != null;
    final Paint paint = isFill ? _workerFill : _workerStroke;
    paint.color = color;
    paint.strokeWidth = def.strokeWidth * scale;

    if (def.precompiledPath != null) {
      canvas.save();
      canvas.scale(scale, scale);
      canvas.drawPath(def.precompiledPath!, paint);
      canvas.restore();
    } else {
      // Default needle line
      final needleLen = (def.radius ?? (skin.defaultSize * 0.38)) * scale;
      canvas.drawLine(Offset.zero, Offset(0, -needleLen), paint);
    }
  }

  @override
  bool shouldRepaint(covariant TwoPassVectorKnobPainter old) {
    return old.normalizedValue != normalizedValue ||
        old.accentColor != accentColor ||
        old.skin != skin;
  }
}
