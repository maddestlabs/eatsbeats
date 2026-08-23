import 'dart:math' as math;
import 'package:flutter/material.dart';

class ModularPatchCable {
  final Offset from;
  final Offset to;
  final Color color;
  final double tension; // 0.0 to 1.0 (lower = more gravity droop)

  const ModularPatchCable({
    required this.from,
    required this.to,
    this.color = const Color(0xFFFF9800),
    this.tension = 0.5,
  });
}

/// CustomPainter rendering realistic hanging patch cables between Eurorack module jacks.
class PatchCablePainter extends CustomPainter {
  final List<ModularPatchCable> cables;
  final double opacity;

  PatchCablePainter({
    required this.cables,
    this.opacity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.01) return;

    for (final cable in cables) {
      _paintCable(canvas, cable);
    }
  }

  void _paintCable(Canvas canvas, ModularPatchCable cable) {
    final p1 = cable.from;
    final p2 = cable.to;
    final double dist = (p2 - p1).distance;
    if (dist < 2) return;

    // Calculate gravity sag droop
    final double midX = (p1.dx + p2.dx) / 2.0;
    final double midY = (p1.dy + p2.dy) / 2.0;
    final double sag = (1.0 - cable.tension.clamp(0.1, 0.9)) * math.max(35.0, dist * 0.45);
    final controlPoint = Offset(midX, midY + sag);

    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..quadraticBezierTo(controlPoint.dx, controlPoint.dy, p2.dx, p2.dy);

    // 1. Cable Drop Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.4 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final shadowPath = Path()
      ..moveTo(p1.dx, p1.dy + 4)
      ..quadraticBezierTo(controlPoint.dx, controlPoint.dy + 8, p2.dx, p2.dy + 4);
    canvas.drawPath(shadowPath, shadowPaint);

    // 2. Main Cable Core
    final cablePaint = Paint()
      ..color = cable.color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, cablePaint);

    // 3. Cable Highlight / Sheen
    final sheenPaint = Paint()
      ..color = Colors.white.withOpacity(0.35 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, sheenPaint);

    // 4. Jack Connector Plugs on both ends
    _paintJackPlug(canvas, p1, cable.color);
    _paintJackPlug(canvas, p2, cable.color);
  }

  void _paintJackPlug(Canvas canvas, Offset pos, Color color) {
    final plugPaint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    final ringPaint = Paint()
      ..color = Colors.black.withOpacity(0.8 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(pos, 5.0, plugPaint);
    canvas.drawCircle(pos, 5.0, ringPaint);
    canvas.drawCircle(pos, 2.0, Paint()..color = Colors.black.withOpacity(opacity));
  }

  @override
  bool shouldRepaint(covariant PatchCablePainter oldDelegate) {
    return oldDelegate.cables != cables || oldDelegate.opacity != opacity;
  }
}
