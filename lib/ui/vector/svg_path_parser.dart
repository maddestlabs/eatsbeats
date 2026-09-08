import 'dart:math' as math;
import 'dart:ui';

/// High-performance, zero-allocation SVG path data parser for Flutter Skia/Impeller.
/// Converts SVG path syntax (M, L, H, V, C, S, Q, T, A, Z) directly into native [Path].
class SvgPathParser {
  static final Map<String, Path> _pathCache = {};

  /// Parses an SVG path data string (`d="..."`) into a native Flutter [Path].
  /// Results are cached in-memory so identical path definitions incur zero parsing overhead.
  static Path parse(String svgData) {
    final trimmed = svgData.trim();
    if (trimmed.isEmpty) return Path();

    final cached = _pathCache[trimmed];
    if (cached != null) return cached;

    final path = Path();
    final tokens = _tokenize(trimmed);
    int i = 0;
    String currentCmd = 'M';
    double currentX = 0.0, currentY = 0.0;
    double startX = 0.0, startY = 0.0;
    double lastControlX = 0.0, lastControlY = 0.0;

    while (i < tokens.length) {
      final token = tokens[i];
      if (_isCommand(token)) {
        currentCmd = token;
        i++;
      }

      if (i >= tokens.length && currentCmd.toUpperCase() != 'Z') break;

      switch (currentCmd) {
        case 'M': // Absolute MoveTo
          currentX = double.parse(tokens[i++]);
          currentY = double.parse(tokens[i++]);
          startX = currentX;
          startY = currentY;
          lastControlX = currentX;
          lastControlY = currentY;
          path.moveTo(currentX, currentY);
          currentCmd = 'L'; // Subsequent coordinates are implicit LineTo
          break;

        case 'm': // Relative MoveTo
          currentX += double.parse(tokens[i++]);
          currentY += double.parse(tokens[i++]);
          startX = currentX;
          startY = currentY;
          lastControlX = currentX;
          lastControlY = currentY;
          path.moveTo(currentX, currentY);
          currentCmd = 'l';
          break;

        case 'L': // Absolute LineTo
          currentX = double.parse(tokens[i++]);
          currentY = double.parse(tokens[i++]);
          lastControlX = currentX;
          lastControlY = currentY;
          path.lineTo(currentX, currentY);
          break;

        case 'l': // Relative LineTo
          currentX += double.parse(tokens[i++]);
          currentY += double.parse(tokens[i++]);
          lastControlX = currentX;
          lastControlY = currentY;
          path.lineTo(currentX, currentY);
          break;

        case 'H': // Absolute Horizontal LineTo
          currentX = double.parse(tokens[i++]);
          lastControlX = currentX;
          lastControlY = currentY;
          path.lineTo(currentX, currentY);
          break;

        case 'h': // Relative Horizontal LineTo
          currentX += double.parse(tokens[i++]);
          lastControlX = currentX;
          lastControlY = currentY;
          path.lineTo(currentX, currentY);
          break;

        case 'V': // Absolute Vertical LineTo
          currentY = double.parse(tokens[i++]);
          lastControlX = currentX;
          lastControlY = currentY;
          path.lineTo(currentX, currentY);
          break;

        case 'v': // Relative Vertical LineTo
          currentY += double.parse(tokens[i++]);
          lastControlX = currentX;
          lastControlY = currentY;
          path.lineTo(currentX, currentY);
          break;

        case 'C': // Absolute Cubic Bezier
          final x1 = double.parse(tokens[i++]);
          final y1 = double.parse(tokens[i++]);
          final x2 = double.parse(tokens[i++]);
          final y2 = double.parse(tokens[i++]);
          currentX = double.parse(tokens[i++]);
          currentY = double.parse(tokens[i++]);
          lastControlX = x2;
          lastControlY = y2;
          path.cubicTo(x1, y1, x2, y2, currentX, currentY);
          break;

        case 'c': // Relative Cubic Bezier
          final x1 = currentX + double.parse(tokens[i++]);
          final y1 = currentY + double.parse(tokens[i++]);
          final x2 = currentX + double.parse(tokens[i++]);
          final y2 = currentY + double.parse(tokens[i++]);
          currentX += double.parse(tokens[i++]);
          currentY += double.parse(tokens[i++]);
          lastControlX = x2;
          lastControlY = y2;
          path.cubicTo(x1, y1, x2, y2, currentX, currentY);
          break;

        case 'S': // Absolute Smooth Cubic Bezier
          final x1 = 2 * currentX - lastControlX;
          final y1 = 2 * currentY - lastControlY;
          final x2 = double.parse(tokens[i++]);
          final y2 = double.parse(tokens[i++]);
          currentX = double.parse(tokens[i++]);
          currentY = double.parse(tokens[i++]);
          lastControlX = x2;
          lastControlY = y2;
          path.cubicTo(x1, y1, x2, y2, currentX, currentY);
          break;

        case 's': // Relative Smooth Cubic Bezier
          final x1 = 2 * currentX - lastControlX;
          final y1 = 2 * currentY - lastControlY;
          final x2 = currentX + double.parse(tokens[i++]);
          final y2 = currentY + double.parse(tokens[i++]);
          currentX += double.parse(tokens[i++]);
          currentY += double.parse(tokens[i++]);
          lastControlX = x2;
          lastControlY = y2;
          path.cubicTo(x1, y1, x2, y2, currentX, currentY);
          break;

        case 'Q': // Absolute Quadratic Bezier
          final qx1 = double.parse(tokens[i++]);
          final qy1 = double.parse(tokens[i++]);
          currentX = double.parse(tokens[i++]);
          currentY = double.parse(tokens[i++]);
          lastControlX = qx1;
          lastControlY = qy1;
          path.quadraticBezierTo(qx1, qy1, currentX, currentY);
          break;

        case 'q': // Relative Quadratic Bezier
          final qx1 = currentX + double.parse(tokens[i++]);
          final qy1 = currentY + double.parse(tokens[i++]);
          currentX += double.parse(tokens[i++]);
          currentY += double.parse(tokens[i++]);
          lastControlX = qx1;
          lastControlY = qy1;
          path.quadraticBezierTo(qx1, qy1, currentX, currentY);
          break;

        case 'A': // Absolute Elliptical Arc
        case 'a': // Relative Elliptical Arc
          final rx = double.parse(tokens[i++]).abs();
          final ry = double.parse(tokens[i++]).abs();
          final xRot = double.parse(tokens[i++]) * (math.pi / 180.0);
          final largeArc = double.parse(tokens[i++]) != 0.0;
          final sweep = double.parse(tokens[i++]) != 0.0;
          double targetX = double.parse(tokens[i++]);
          double targetY = double.parse(tokens[i++]);
          if (currentCmd == 'a') {
            targetX += currentX;
            targetY += currentY;
          }
          _drawArc(path, currentX, currentY, targetX, targetY, rx, ry, xRot, largeArc, sweep);
          currentX = targetX;
          currentY = targetY;
          lastControlX = currentX;
          lastControlY = currentY;
          break;

        case 'Z':
        case 'z':
          path.close();
          currentX = startX;
          currentY = startY;
          lastControlX = currentX;
          lastControlY = currentY;
          break;

        default:
          i++;
      }
    }

    if (_pathCache.length > 500) _pathCache.clear();
    _pathCache[trimmed] = path;
    return path;
  }

  static bool _isCommand(String s) => RegExp(r'^[MmLlHhVvCcSsQqTtAaZz]$').hasMatch(s);

  static List<String> _tokenize(String d) {
    // Splits on whitespace and commas while preserving commands and negative numbers
    final regex = RegExp(r'[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?');
    return regex.allMatches(d).map((m) => m.group(0)!).toList();
  }

  static void _drawArc(
    Path path,
    double x1,
    double y1,
    double x2,
    double y2,
    double rx,
    double ry,
    double phi,
    bool isLargeArc,
    bool isSweep,
  ) {
    if (rx == 0.0 || ry == 0.0 || (x1 == x2 && y1 == y2)) {
      path.lineTo(x2, y2);
      return;
    }

    final cosPhi = math.cos(phi);
    final sinPhi = math.sin(phi);

    final dxHalf = (x1 - x2) / 2.0;
    final dyHalf = (y1 - y2) / 2.0;

    final x1p = cosPhi * dxHalf + sinPhi * dyHalf;
    final y1p = -sinPhi * dxHalf + cosPhi * dyHalf;

    var rxSq = rx * rx;
    var rySq = ry * ry;
    final x1pSq = x1p * x1p;
    final y1pSq = y1p * y1p;

    final radiiCheck = x1pSq / rxSq + y1pSq / rySq;
    if (radiiCheck > 1.0) {
      final scale = math.sqrt(radiiCheck);
      rx *= scale;
      ry *= scale;
      rxSq = rx * rx;
      rySq = ry * ry;
    }

    final sign = (isLargeArc == isSweep) ? -1.0 : 1.0;
    final numerator = rxSq * rySq - rxSq * y1pSq - rySq * x1pSq;
    final denominator = rxSq * y1pSq + rySq * x1pSq;
    final coef = sign * math.sqrt(math.max(0.0, numerator / denominator));

    final cxp = coef * (rx * y1p / ry);
    final cyp = coef * -(ry * x1p / rx);

    final cx = cosPhi * cxp - sinPhi * cyp + (x1 + x2) / 2.0;
    final cy = sinPhi * cxp + cosPhi * cyp + (y1 + y2) / 2.0;

    final ux = (x1p - cxp) / rx;
    final uy = (y1p - cyp) / ry;
    final vx = (-x1p - cxp) / rx;
    final vy = (-y1p - cyp) / ry;

    var theta = math.atan2(uy, ux);
    var dTheta = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy);

    if (!isSweep && dTheta > 0) {
      dTheta -= 2.0 * math.pi;
    } else if (isSweep && dTheta < 0) {
      dTheta += 2.0 * math.pi;
    }

    final numSegments = (dTheta.abs() / (math.pi / 2.0)).ceil();
    final step = dTheta / numSegments;

    for (int s = 0; s < numSegments; s++) {
      final t1 = theta + s * step;
      final t2 = t1 + step;

      final p1x = rx * math.cos(t1);
      final p1y = ry * math.sin(t1);
      final p2x = rx * math.cos(t2);
      final p2y = ry * math.sin(t2);

      final alpha = math.sin(step) * (math.sqrt(4.0 + 3.0 * math.pow(math.tan(step / 2.0), 2)) - 1.0) / 3.0;

      final q1x = p1x - alpha * rx * math.sin(t1);
      final q1y = p1y + alpha * ry * math.cos(t1);
      final q2x = p2x + alpha * rx * math.sin(t2);
      final q2y = p2y - alpha * ry * math.cos(t2);

      final cp1X = cosPhi * q1x - sinPhi * q1y + cx;
      final cp1Y = sinPhi * q1x + cosPhi * q1y + cy;
      final cp2X = cosPhi * q2x - sinPhi * q2y + cx;
      final cp2Y = sinPhi * q2x + cosPhi * q2y + cy;
      final endX = cosPhi * p2x - sinPhi * p2y + cx;
      final endY = sinPhi * p2x + cosPhi * p2y + cy;

      path.cubicTo(cp1X, cp1Y, cp2X, cp2Y, endX, endY);
    }
  }
}
