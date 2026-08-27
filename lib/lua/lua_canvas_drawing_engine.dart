import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Base class for recorded vector drawing operations on the programmable canvas.
abstract class LuaCanvasOp {
  const LuaCanvasOp();
}

class LuaCanvasClearOp extends LuaCanvasOp {
  final Color color;
  const LuaCanvasClearOp(this.color);
}

class LuaCanvasLineOp extends LuaCanvasOp {
  final Offset p1;
  final Offset p2;
  final Color color;
  final double strokeWidth;
  const LuaCanvasLineOp(this.p1, this.p2, this.color, this.strokeWidth);
}

class LuaCanvasRectOp extends LuaCanvasOp {
  final Rect rect;
  final Color color;
  final bool filled;
  final double strokeWidth;
  final double cornerRadius;
  const LuaCanvasRectOp(this.rect, this.color, this.filled, this.strokeWidth, this.cornerRadius);
}

class LuaCanvasCircleOp extends LuaCanvasOp {
  final Offset center;
  final double radius;
  final Color color;
  final bool filled;
  final double strokeWidth;
  const LuaCanvasCircleOp(this.center, this.radius, this.color, this.filled, this.strokeWidth);
}

class LuaCanvasTextOp extends LuaCanvasOp {
  final String text;
  final Offset position;
  final double fontSize;
  final Color color;
  final TextAlign align;
  final bool isBold;
  const LuaCanvasTextOp(this.text, this.position, this.fontSize, this.color, this.align, {this.isBold = false});
}

class LuaCanvasPathOp extends LuaCanvasOp {
  final List<Offset> points;
  final Color color;
  final bool closed;
  final Color? fillColor;
  final double strokeWidth;
  const LuaCanvasPathOp(this.points, this.color, this.closed, this.fillColor, this.strokeWidth);
}

class LuaCanvasWaveformOp extends LuaCanvasOp {
  final double gain;
  final double timebase;
  final Color color;
  final double strokeWidth;
  const LuaCanvasWaveformOp(this.gain, this.timebase, this.color, this.strokeWidth);
}

class LuaCanvasSpectrumOp extends LuaCanvasOp {
  final int bands;
  final double gain;
  final double decay;
  final Color color;
  const LuaCanvasSpectrumOp(this.bands, this.gain, this.decay, this.color);
}

class LuaCanvasGridOp extends LuaCanvasOp {
  final int cols;
  final int rows;
  final Color color;
  final double strokeWidth;
  const LuaCanvasGridOp(this.cols, this.rows, this.color, this.strokeWidth);
}

/// Canvas recorder passed to Lua draw routines.
class LuaCanvasDrawingContext {
  final double width;
  final double height;
  final Color defaultAccent;
  final List<LuaCanvasOp> ops = [];

  LuaCanvasDrawingContext({
    required this.width,
    required this.height,
    required this.defaultAccent,
  });

  Color parseColor(dynamic colorVal, [Color? fallback]) {
    if (colorVal == null) return fallback ?? defaultAccent;
    if (colorVal is Color) return colorVal;
    if (colorVal is String) {
      final s = colorVal.trim().replaceAll('#', '');
      if (s.length == 6) {
        final val = int.tryParse(s, radix: 16);
        if (val != null) return Color(0xFF000000 | val);
      } else if (s.length == 8) {
        final val = int.tryParse(s, radix: 16);
        if (val != null) return Color(val);
      }
    }
    return fallback ?? defaultAccent;
  }

  void clear([dynamic color]) {
    ops.add(LuaCanvasClearOp(parseColor(color, const Color(0xFF0D1117))));
  }

  void line(num x1, num y1, num x2, num y2, [dynamic color, num? strokeWidth]) {
    ops.add(LuaCanvasLineOp(
      Offset(x1.toDouble(), y1.toDouble()),
      Offset(x2.toDouble(), y2.toDouble()),
      parseColor(color),
      (strokeWidth?.toDouble() ?? 1.5).clamp(0.5, 16.0),
    ));
  }

  void rect(num x, num y, num w, num h, [dynamic color, bool? filled, num? strokeWidth, num? cornerRadius]) {
    ops.add(LuaCanvasRectOp(
      Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()),
      parseColor(color),
      filled ?? false,
      (strokeWidth?.toDouble() ?? 1.5).clamp(0.5, 16.0),
      (cornerRadius?.toDouble() ?? 0.0).clamp(0.0, 64.0),
    ));
  }

  void circle(num cx, num cy, num radius, [dynamic color, bool? filled, num? strokeWidth]) {
    ops.add(LuaCanvasCircleOp(
      Offset(cx.toDouble(), cy.toDouble()),
      radius.toDouble().clamp(0.5, 1000.0),
      parseColor(color),
      filled ?? false,
      (strokeWidth?.toDouble() ?? 1.5).clamp(0.5, 16.0),
    ));
  }

  void text(String str, num x, num y, [num? fontSize, dynamic color, String? align, bool? isBold]) {
    TextAlign textAlignment = TextAlign.left;
    if (align == 'center' || align == 'centre') textAlignment = TextAlign.center;
    if (align == 'right') textAlignment = TextAlign.right;

    ops.add(LuaCanvasTextOp(
      str,
      Offset(x.toDouble(), y.toDouble()),
      (fontSize?.toDouble() ?? 11.0).clamp(6.0, 72.0),
      parseColor(color, Colors.white),
      textAlignment,
      isBold: isBold ?? false,
    ));
  }

  void path(List<dynamic> points, [dynamic color, bool? closed, dynamic fillColor, num? strokeWidth]) {
    final offsetList = <Offset>[];
    for (final pt in points) {
      if (pt is List && pt.length >= 2) {
        final px = (pt[0] as num).toDouble();
        final py = (pt[1] as num).toDouble();
        offsetList.add(Offset(px, py));
      } else if (pt is Map && pt.containsKey('x') && pt.containsKey('y')) {
        final px = (pt['x'] as num).toDouble();
        final py = (pt['y'] as num).toDouble();
        offsetList.add(Offset(px, py));
      }
    }
    if (offsetList.isNotEmpty) {
      ops.add(LuaCanvasPathOp(
        offsetList,
        parseColor(color),
        closed ?? false,
        fillColor != null ? parseColor(fillColor) : null,
        (strokeWidth?.toDouble() ?? 1.5).clamp(0.5, 16.0),
      ));
    }
  }

  void waveform([num? gain, num? timebase, dynamic color, num? strokeWidth]) {
    ops.add(LuaCanvasWaveformOp(
      gain?.toDouble() ?? 1.0,
      timebase?.toDouble() ?? 1.0,
      parseColor(color),
      (strokeWidth?.toDouble() ?? 1.5).clamp(0.5, 8.0),
    ));
  }

  void spectrum([int? bands, num? gain, num? decay, dynamic color]) {
    ops.add(LuaCanvasSpectrumOp(
      bands ?? 16,
      gain?.toDouble() ?? 1.0,
      decay?.toDouble() ?? 0.6,
      parseColor(color),
    ));
  }

  void grid([int? cols, int? rows, dynamic color, num? strokeWidth]) {
    ops.add(LuaCanvasGridOp(
      cols ?? 8,
      rows ?? 6,
      parseColor(color, Colors.white.withOpacity(0.08)),
      (strokeWidth?.toDouble() ?? 1.0).clamp(0.5, 4.0),
    ));
  }
}

/// Evaluates programmable Lua 2D drawing routines with high performance.
class LuaCanvasDrawingEngine {
  /// Evaluates the script's `draw` / `on_draw` routine into a list of [LuaCanvasOp].
  static List<LuaCanvasOp> evaluate({
    required String scriptCode,
    required double width,
    required double height,
    required Map<String, double> params,
    required double time,
    required Color accentColor,
    Offset? touchPos,
    bool isTouchDown = false,
  }) {
    final ctx = LuaCanvasDrawingContext(
      width: width,
      height: height,
      defaultAccent: accentColor,
    );

    // 1. Check if the script contains a custom draw definition
    final hasCustomDraw = scriptCode.contains(RegExp(r'\.(?:draw|on_draw|paint)\s*\('));

    if (hasCustomDraw) {
      _executeScriptDraw(scriptCode, ctx, width, height, params, time, touchPos, isTouchDown);
    }

    // 2. If no ops were produced (or script has no draw definition), generate a sleek default vector canvas
    if (ctx.ops.isEmpty) {
      _generateDefaultVectorDisplay(ctx, width, height, params, time, accentColor, touchPos, isTouchDown);
    }

    return ctx.ops;
  }

  static void _executeScriptDraw(
    String scriptCode,
    LuaCanvasDrawingContext ctx,
    double width,
    double height,
    Map<String, double> params,
    double time,
    Offset? touchPos,
    bool isTouchDown,
  ) {
    try {
      // Find the draw block
      final drawMatch = RegExp(r'function\s+[\w\.]+(?:draw|on_draw|paint)\s*\([^)]*\)([\s\S]*?)end').firstMatch(scriptCode);
      if (drawMatch == null) return;
      final body = drawMatch.group(1) ?? '';

      // Parse and execute draw instructions directly
      final lines = body.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('--')) continue;

        // canvas:clear(color)
        final clearMatch = RegExp(r'canvas:clear\s*\(\s*["\x27]?([^"\x27\)]*)["\x27]?\s*\)').firstMatch(trimmed);
        if (clearMatch != null) {
          ctx.clear(clearMatch.group(1));
          continue;
        }

        // canvas:grid(cols, rows, color)
        final gridMatch = RegExp(r'canvas:grid\s*\(\s*(\d+)?\s*(?:,\s*(\d+))?\s*(?:,\s*["\x27]?([^"\x27\)]*)["\x27]?)?\s*\)').firstMatch(trimmed);
        if (gridMatch != null) {
          final c = int.tryParse(gridMatch.group(1) ?? '') ?? 8;
          final r = int.tryParse(gridMatch.group(2) ?? '') ?? 6;
          final col = gridMatch.group(3);
          ctx.grid(c, r, col);
          continue;
        }

        // canvas:line(x1, y1, x2, y2, color, strokeWidth)
        final lineMatch = RegExp(r'canvas:line\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)(?:,\s*["\x27]?([^"\x27,]+)["\x27]?)?(?:,\s*([^,\)]+))?\s*\)').firstMatch(trimmed);
        if (lineMatch != null) {
          final x1 = _evalMath(lineMatch.group(1)!, width, height, params, time);
          final y1 = _evalMath(lineMatch.group(2)!, width, height, params, time);
          final x2 = _evalMath(lineMatch.group(3)!, width, height, params, time);
          final y2 = _evalMath(lineMatch.group(4)!, width, height, params, time);
          final color = lineMatch.group(5)?.trim();
          final sw = lineMatch.group(6) != null ? _evalMath(lineMatch.group(6)!, width, height, params, time) : 1.5;
          ctx.line(x1, y1, x2, y2, color, sw);
          continue;
        }

        // canvas:rect(x, y, w, h, color, filled, strokeWidth, radius)
        final rectMatch = RegExp(r'canvas:rect\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)(?:,\s*["\x27]?([^"\x27,]+)["\x27]?)?(?:,\s*([^,\)]+))?(?:,\s*([^,\)]+))?(?:,\s*([^,\)]+))?\s*\)').firstMatch(trimmed);
        if (rectMatch != null) {
          final x = _evalMath(rectMatch.group(1)!, width, height, params, time);
          final y = _evalMath(rectMatch.group(2)!, width, height, params, time);
          final w = _evalMath(rectMatch.group(3)!, width, height, params, time);
          final h = _evalMath(rectMatch.group(4)!, width, height, params, time);
          final color = rectMatch.group(5)?.trim();
          final filled = rectMatch.group(6)?.trim() == 'true';
          final sw = rectMatch.group(7) != null ? _evalMath(rectMatch.group(7)!, width, height, params, time) : 1.5;
          final cr = rectMatch.group(8) != null ? _evalMath(rectMatch.group(8)!, width, height, params, time) : 0.0;
          ctx.rect(x, y, w, h, color, filled, sw, cr);
          continue;
        }

        // canvas:circle(cx, cy, radius, color, filled, strokeWidth)
        final circleMatch = RegExp(r'canvas:circle\s*\(\s*([^,]+),\s*([^,]+),\s*([^,\)]+)(?:,\s*["\x27]?([^"\x27,]+)["\x27]?)?(?:,\s*([^,\)]+))?(?:,\s*([^,\)]+))?\s*\)').firstMatch(trimmed);
        if (circleMatch != null) {
          final cx = _evalMath(circleMatch.group(1)!, width, height, params, time);
          final cy = _evalMath(circleMatch.group(2)!, width, height, params, time);
          final r = _evalMath(circleMatch.group(3)!, width, height, params, time);
          final color = circleMatch.group(4)?.trim();
          final filled = circleMatch.group(5)?.trim() == 'true';
          final sw = circleMatch.group(6) != null ? _evalMath(circleMatch.group(6)!, width, height, params, time) : 1.5;
          ctx.circle(cx, cy, r, color, filled, sw);
          continue;
        }

        // canvas:text(str, x, y, size, color, align)
        final textMatch = RegExp(r'canvas:text\s*\(\s*["\x27]?([^"\x27,]+)["\x27]?,\s*([^,]+),\s*([^,\)]+)(?:,\s*([^,\)]+))?(?:,\s*["\x27]?([^"\x27,]+)["\x27]?)?(?:,\s*["\x27]?([^"\x27\)]+)["\x27]?)?\s*\)').firstMatch(trimmed);
        if (textMatch != null) {
          final str = textMatch.group(1)!.trim();
          final x = _evalMath(textMatch.group(2)!, width, height, params, time);
          final y = _evalMath(textMatch.group(3)!, width, height, params, time);
          final sz = textMatch.group(4) != null ? _evalMath(textMatch.group(4)!, width, height, params, time) : 11.0;
          final color = textMatch.group(5)?.trim();
          final align = textMatch.group(6)?.trim();
          ctx.text(str, x, y, sz, color, align);
          continue;
        }

        // canvas:waveform(gain, timebase, color, strokeWidth)
        final waveMatch = RegExp(r'canvas:waveform\s*\(\s*([^,\)]+)?(?:,\s*([^,\)]+))?(?:,\s*["\x27]?([^"\x27,]+)["\x27]?)?(?:,\s*([^,\)]+))?\s*\)').firstMatch(trimmed);
        if (waveMatch != null) {
          final g = waveMatch.group(1) != null ? _evalMath(waveMatch.group(1)!, width, height, params, time) : 1.0;
          final tb = waveMatch.group(2) != null ? _evalMath(waveMatch.group(2)!, width, height, params, time) : 1.0;
          final col = waveMatch.group(3)?.trim();
          final sw = waveMatch.group(4) != null ? _evalMath(waveMatch.group(4)!, width, height, params, time) : 1.5;
          ctx.waveform(g, tb, col, sw);
          continue;
        }

        // canvas:spectrum(bands, gain, decay, color)
        final specMatch = RegExp(r'canvas:spectrum\s*\(\s*(\d+)?(?:,\s*([^,\)]+))?(?:,\s*([^,\)]+))?(?:,\s*["\x27]?([^"\x27\)]+)["\x27]?)?\s*\)').firstMatch(trimmed);
        if (specMatch != null) {
          final b = int.tryParse(specMatch.group(1) ?? '') ?? 16;
          final g = specMatch.group(2) != null ? _evalMath(specMatch.group(2)!, width, height, params, time) : 1.0;
          final d = specMatch.group(3) != null ? _evalMath(specMatch.group(3)!, width, height, params, time) : 0.6;
          final col = specMatch.group(4)?.trim();
          ctx.spectrum(b, g, d, col);
          continue;
        }
      }
    } catch (_) {
      // Fall back smoothly if user is typing incomplete code
    }
  }

  static double _evalMath(String expr, double w, double h, Map<String, double> params, double time) {
    var e = expr.trim();
    if (e == 'w' || e == 'width') return w;
    if (e == 'h' || e == 'height') return h;
    if (e == 'time' || e == 't') return time;

    // Check for parameter substitution: params["Name"] or params['Name']
    final paramMatch = RegExp(r'params\[["\x27]([^"\x27]+)["\x27]\]').allMatches(e);
    for (final m in paramMatch) {
      final pName = m.group(1)!;
      final val = params[pName] ?? 0.5;
      e = e.replaceAll(m.group(0)!, val.toString());
    }

    // Direct numeric parse
    final direct = double.tryParse(e);
    if (direct != null) return direct;

    // Handle basic arithmetic expressions: e.g. "w * 0.5", "h - 20", "w / 2 + 10"
    if (e.contains('*')) {
      final parts = e.split('*');
      return _evalMath(parts[0], w, h, params, time) * _evalMath(parts[1], w, h, params, time);
    }
    if (e.contains('/')) {
      final parts = e.split('/');
      final denom = _evalMath(parts[1], w, h, params, time);
      return denom != 0 ? _evalMath(parts[0], w, h, params, time) / denom : 0.0;
    }
    if (e.contains('+')) {
      final parts = e.split('+');
      return _evalMath(parts[0], w, h, params, time) + _evalMath(parts[1], w, h, params, time);
    }
    if (e.contains('-') && !e.startsWith('-')) {
      final parts = e.split('-');
      return _evalMath(parts[0], w, h, params, time) - _evalMath(parts[1], w, h, params, time);
    }

    return 0.0;
  }

  static void _generateDefaultVectorDisplay(
    LuaCanvasDrawingContext ctx,
    double width,
    double height,
    Map<String, double> params,
    double time,
    Color accent,
    Offset? touchPos,
    bool isTouchDown,
  ) {
    // 1. Background
    ctx.clear(const Color(0xFF090D14));

    // 2. Neon Coordinate Grid
    ctx.grid(8, 6, accent.withOpacity(0.12), 1.0);

    // 3. Border Box
    ctx.rect(0, 0, width, height, accent.withOpacity(0.4), false, 1.5, 6.0);

    // 4. Oscilloscope Audio Waveform Trace
    ctx.waveform(1.0, 1.0, accent, 1.8);

    // 5. HUD Readouts
    final cutoff = params['Cutoff'] ?? params['Frequency'] ?? 1000.0;
    final res = params['Resonance'] ?? params['Res'] ?? 1.0;
    ctx.text('VECTOR CRT • 2D CANVAS', 12, 16, 9.5, accent, 'left', true);
    ctx.text('CUTOFF: ${cutoff.toStringAsFixed(0)} Hz   RES: ${res.toStringAsFixed(2)}', 12, height - 12, 8.5, Colors.white60, 'left');

    // 6. Interactive Touch Reticle
    if (touchPos != null && isTouchDown) {
      ctx.circle(touchPos.dx, touchPos.dy, 8, accent, false, 2.0);
      ctx.line(touchPos.dx - 14, touchPos.dy, touchPos.dx + 14, touchPos.dy, accent.withOpacity(0.7), 1.0);
      ctx.line(touchPos.dx, touchPos.dy - 14, touchPos.dx, touchPos.dy + 14, accent.withOpacity(0.7), 1.0);
      ctx.text('X: ${(touchPos.dx / width).toStringAsFixed(2)}  Y: ${(1.0 - touchPos.dy / height).toStringAsFixed(2)}', touchPos.dx + 12, touchPos.dy - 8, 8.0, accent);
    }
  }
}
