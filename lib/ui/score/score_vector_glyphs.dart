// =============================================================================
// Score Vector Glyphs
//
// Musical glyph vector rendering using exact mathematical Bézier cubic splines
// adapted from Steinberg's Bravura reference font (SMuFL specification).
//
// Bravura is Copyright (c) 2014-2021 Steinberg Media Technologies GmbH
// Licensed under the SIL Open Font License, Version 1.1:
// http://scripts.sil.org/OFL
// =============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Clean, native-vector rendering paths for standard musical notation.
/// All glyphs are scaled proportionally to staff space [sp] (distance between adjacent staff lines).
class ScoreVectorGlyphs {
  /// Standard staff space in logical pixels if not specified
  static const double defaultStaffSpace = 12.0;

  // ---------------------------------------------------------------------------
  // Noteheads
  // ---------------------------------------------------------------------------

  /// Draws a standard filled (quarter/8th/16th) notehead centered at [center].
  /// Rotated approx -15 degrees for classical engraving aesthetic.
  static void drawBlackNotehead(Canvas canvas, Offset center, double sp, Paint paint) {
    final double rx = sp * 0.62;
    final double ry = sp * 0.44;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-15 * math.pi / 180.0);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), paint);
    canvas.restore();
  }

  /// Draws an open (half-note) notehead centered at [center].
  static void drawHalfNotehead(Canvas canvas, Offset center, double sp, Paint strokePaint, Paint? fillPaint) {
    final double rx = sp * 0.64;
    final double ry = sp * 0.45;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-18 * math.pi / 180.0);

    if (fillPaint != null) {
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), fillPaint);
    }

    final savedStyle = strokePaint.style;
    final savedWidth = strokePaint.strokeWidth;
    strokePaint.style = PaintingStyle.stroke;
    strokePaint.strokeWidth = sp * 0.18;

    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), strokePaint);

    strokePaint.style = savedStyle;
    strokePaint.strokeWidth = savedWidth;
    canvas.restore();
  }

  /// Draws a whole-note notehead centered at [center].
  static void drawWholeNotehead(Canvas canvas, Offset center, double sp, Paint strokePaint, Paint? fillPaint) {
    final double rx = sp * 0.78;
    final double ry = sp * 0.48;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    if (fillPaint != null) {
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), fillPaint);
    }

    final savedStyle = strokePaint.style;
    final savedWidth = strokePaint.strokeWidth;
    strokePaint.style = PaintingStyle.stroke;
    strokePaint.strokeWidth = sp * 0.22;

    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), strokePaint);

    strokePaint.style = savedStyle;
    strokePaint.strokeWidth = savedWidth;
    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // Stems & Flags
  // ---------------------------------------------------------------------------

  /// Draws a vertical stem for a note.
  static Offset drawStem({
    required Canvas canvas,
    required Offset noteCenter,
    required double sp,
    required bool isUp,
    required Paint paint,
    double lengthMultiplier = 3.5,
  }) {
    final double stemThickness = sp * 0.12;
    final double noteheadRx = sp * 0.60;
    final double stemLength = sp * lengthMultiplier;

    final double stemX = isUp
        ? (noteCenter.dx + noteheadRx - stemThickness * 0.5)
        : (noteCenter.dx - noteheadRx + stemThickness * 0.5);
    final double startY = noteCenter.dy;
    final double endY = isUp ? (noteCenter.dy - stemLength) : (noteCenter.dy + stemLength);

    final stemPaint = Paint()
      ..color = paint.color
      ..strokeWidth = stemThickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(Offset(stemX, startY), Offset(stemX, endY), stemPaint);
    return Offset(stemX, endY);
  }

  /// Draws an eighth-note or sixteenth-note flag at stem tip.
  static void drawFlag({
    required Canvas canvas,
    required Offset stemTip,
    required double sp,
    required bool isUp,
    required int flagCount,
    required Paint paint,
  }) {
    final fillPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < flagCount; i++) {
      final double yOffset = i * (sp * 0.7) * (isUp ? 1 : -1);
      final Offset anchor = Offset(stemTip.dx, stemTip.dy + yOffset);

      final path = Path();
      if (isUp) {
        path.moveTo(anchor.dx, anchor.dy);
        path.cubicTo(
          anchor.dx + sp * 0.6, anchor.dy + sp * 0.2,
          anchor.dx + sp * 0.9, anchor.dy + sp * 1.0,
          anchor.dx + sp * 0.4, anchor.dy + sp * 2.1,
        );
        path.cubicTo(
          anchor.dx + sp * 0.7, anchor.dy + sp * 1.3,
          anchor.dx + sp * 0.4, anchor.dy + sp * 0.6,
          anchor.dx, anchor.dy + sp * 0.5,
        );
        path.close();
      } else {
        path.moveTo(anchor.dx, anchor.dy);
        path.cubicTo(
          anchor.dx + sp * 0.6, anchor.dy - sp * 0.2,
          anchor.dx + sp * 0.9, anchor.dy - sp * 1.0,
          anchor.dx + sp * 0.4, anchor.dy - sp * 2.1,
        );
        path.cubicTo(
          anchor.dx + sp * 0.7, anchor.dy - sp * 1.3,
          anchor.dx + sp * 0.4, anchor.dy - sp * 0.6,
          anchor.dx, anchor.dy - sp * 0.5,
        );
        path.close();
      }
      canvas.drawPath(path, fillPaint);
    }
  }

  // ---------------------------------------------------------------------------
  // Clefs (Bravura Exact SMuFL Bézier Outlines)
  // ---------------------------------------------------------------------------

  /// Draws an authentic, engraved Treble Clef (G-clef) anchored to line 2 at [gLineY].
  /// Uses exact Bravura cubic Bézier splines (SIL OFL 1.1).
  static void drawTrebleClef(Canvas canvas, double x, double gLineY, double sp, Paint paint) {
    final path = createTrebleClefPath(x, gLineY, sp);
    final fillPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  /// Draws an authentic, engraved Bass Clef (F-clef) anchored to line 4 at [fLineY].
  /// Uses exact Bravura cubic Bézier splines (SIL OFL 1.1).
  static void drawBassClef(Canvas canvas, double x, double fLineY, double sp, Paint paint) {
    final path = createBassClefPath(x, fLineY, sp);
    final fillPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  /// Draws an authentic Grand Staff accolade curly bracket (brace) on the left of the score.
  /// Spans from [topY] (top line of treble staff) to [bottomY] (bottom line of bass staff).
  /// Uses exact Bravura cubic Bézier splines (SIL OFL 1.1).
  static void drawGrandStaffBracket(Canvas canvas, double x, double topY, double bottomY, double sp, Paint paint) {
    final path = createGrandStaffBracePath(x, topY, bottomY, sp);
    final fillPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Vertical line connecting top to bottom adjacent to the brace
    final barPaint = Paint()
      ..color = paint.color
      ..strokeWidth = sp * 0.12
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x + sp * 1.35, topY), Offset(x + sp * 1.35, bottomY), barPaint);
  }

  // ---------------------------------------------------------------------------
  // Accidentals (Bravura Exact SMuFL Bézier Outlines)
  // ---------------------------------------------------------------------------

  /// Draws a sharp symbol (#) centered at [center].
  static void drawSharp(Canvas canvas, Offset center, double sp, Paint paint) {
    final path = createSharpPath(center.dx - 0.50 * sp, center.dy, sp);
    final fillPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  /// Draws a flat symbol (b) centered at [center].
  static void drawFlat(Canvas canvas, Offset center, double sp, Paint paint) {
    final path = createFlatPath(center.dx - 0.45 * sp, center.dy, sp);
    final fillPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  /// Draws a natural symbol centered at [center].
  static void drawNatural(Canvas canvas, Offset center, double sp, Paint paint) {
    final path = createNaturalPath(center.dx - 0.34 * sp, center.dy, sp);
    final fillPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  // ---------------------------------------------------------------------------
  // Rests
  // ---------------------------------------------------------------------------

  /// Draws a whole rest (hanging bar below line 4) or half rest (sitting bar on line 3).
  static void drawBlockRest(Canvas canvas, Offset center, double sp, bool isWhole, Paint paint) {
    final double width = sp * 1.2;
    final double height = sp * 0.5;
    final rect = isWhole
        ? Rect.fromLTWH(center.dx - width / 2, center.dy, width, height)
        : Rect.fromLTWH(center.dx - width / 2, center.dy - height, width, height);

    canvas.drawRect(rect, Paint()..color = paint.color);
  }

  /// Draws a quarter rest centered at [center].
  static void drawQuarterRest(Canvas canvas, Offset center, double sp, Paint paint) {
    final path = createQuarterRestPath(center.dx - 0.54 * sp, center.dy, sp);
    final fillPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  /// Draws an eighth rest centered at [center].
  static void drawEighthRest(Canvas canvas, Offset center, double sp, Paint paint) {
    final path = createEighthRestPath(center.dx - 0.49 * sp, center.dy, sp);
    final fillPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  // ---------------------------------------------------------------------------
  // Ledger Lines
  // ---------------------------------------------------------------------------

  /// Draws a ledger line centered at [center].
  static void drawLedgerLine(Canvas canvas, Offset center, double sp, Paint paint) {
    final double width = sp * 1.9;
    final double thickness = sp * 0.10;

    final linePaint = Paint()
      ..color = paint.color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx - width / 2, center.dy),
      Offset(center.dx + width / 2, center.dy),
      linePaint,
    );
  }

  // ---------------------------------------------------------------------------
  // Bravura SMuFL Path Generators
  // ---------------------------------------------------------------------------
  /// Standard G-clef (Treble)
  /// Anchor: [x] horizontal start, [y] G4 line (Line 2)
  /// Extracted from Steinberg Bravura under SIL Open Font License 1.1.
  static Path createTrebleClefPath(double x, double y, double sp) {
    final p = Path()..fillType = PathFillType.evenOdd;
    p.moveTo(x + 1.50400 * sp, y - 1.66000 * sp);
    p.cubicTo(x + 1.49600 * sp, y - 1.70800 * sp, x + 1.50400 * sp, y - 1.71200 * sp, x + 1.52800 * sp, y - 1.73600 * sp);
    p.cubicTo(x + 1.59200 * sp, y - 1.79600 * sp, x + 1.67600 * sp, y - 1.88000 * sp, x + 1.75200 * sp, y - 1.96400 * sp);
    p.cubicTo(x + 2.08800 * sp, y - 2.33200 * sp, x + 2.28800 * sp, y - 2.80800 * sp, x + 2.28800 * sp, y - 3.26000 * sp);
    p.cubicTo(x + 2.28800 * sp, y - 3.60800 * sp, x + 2.19200 * sp, y - 3.95200 * sp, x + 2.02800 * sp, y - 4.19200 * sp);
    p.cubicTo(x + 1.96800 * sp, y - 4.28000 * sp, x + 1.86400 * sp, y - 4.39200 * sp, x + 1.82000 * sp, y - 4.39200 * sp);
    p.cubicTo(x + 1.76400 * sp, y - 4.39200 * sp, x + 1.64000 * sp, y - 4.28800 * sp, x + 1.56000 * sp, y - 4.20000 * sp);
    p.cubicTo(x + 1.26400 * sp, y - 3.87200 * sp, x + 1.16800 * sp, y - 3.37200 * sp, x + 1.16800 * sp, y - 2.95600 * sp);
    p.cubicTo(x + 1.16800 * sp, y - 2.72400 * sp, x + 1.19600 * sp, y - 2.46400 * sp, x + 1.22400 * sp, y - 2.30000 * sp);
    p.cubicTo(x + 1.23200 * sp, y - 2.25200 * sp, x + 1.23600 * sp, y - 2.24400 * sp, x + 1.18800 * sp, y - 2.20400 * sp);
    p.cubicTo(x + 0.93200 * sp, y - 1.99200 * sp, x + 0.65600 * sp, y - 1.74800 * sp, x + 0.44800 * sp, y - 1.49200 * sp);
    p.cubicTo(x + 0.17200 * sp, y - 1.14800 * sp, x + 0.00000 * sp, y - 0.77600 * sp, x + 0.00000 * sp, y - 0.34800 * sp);
    p.cubicTo(x + 0.00000 * sp, y - -0.34800 * sp, x + 0.47600 * sp, y - -1.00800 * sp, x + 1.45600 * sp, y - -1.00800 * sp);
    p.cubicTo(x + 1.54800 * sp, y - -1.00800 * sp, x + 1.65200 * sp, y - -1.00000 * sp, x + 1.73200 * sp, y - -0.98400 * sp);
    p.cubicTo(x + 1.77600 * sp, y - -0.97600 * sp, x + 1.78400 * sp, y - -0.97200 * sp, x + 1.79200 * sp, y - -1.02000 * sp);
    p.cubicTo(x + 1.84000 * sp, y - -1.28800 * sp, x + 1.90000 * sp, y - -1.63600 * sp, x + 1.90000 * sp, y - -1.82400 * sp);
    p.cubicTo(x + 1.90000 * sp, y - -2.41600 * sp, x + 1.50000 * sp, y - -2.48800 * sp, x + 1.26400 * sp, y - -2.48800 * sp);
    p.cubicTo(x + 1.04800 * sp, y - -2.48800 * sp, x + 0.94400 * sp, y - -2.42400 * sp, x + 0.94400 * sp, y - -2.37200 * sp);
    p.cubicTo(x + 0.94400 * sp, y - -2.34400 * sp, x + 0.98000 * sp, y - -2.33200 * sp, x + 1.07200 * sp, y - -2.30400 * sp);
    p.cubicTo(x + 1.19600 * sp, y - -2.26800 * sp, x + 1.34000 * sp, y - -2.16000 * sp, x + 1.34000 * sp, y - -1.92800 * sp);
    p.cubicTo(x + 1.34000 * sp, y - -1.70800 * sp, x + 1.20000 * sp, y - -1.52000 * sp, x + 0.95600 * sp, y - -1.52000 * sp);
    p.cubicTo(x + 0.68800 * sp, y - -1.52000 * sp, x + 0.52800 * sp, y - -1.73200 * sp, x + 0.52800 * sp, y - -1.98000 * sp);
    p.cubicTo(x + 0.52800 * sp, y - -2.24000 * sp, x + 0.68400 * sp, y - -2.63200 * sp, x + 1.28800 * sp, y - -2.63200 * sp);
    p.cubicTo(x + 1.55600 * sp, y - -2.63200 * sp, x + 2.07600 * sp, y - -2.51200 * sp, x + 2.07600 * sp, y - -1.83200 * sp);
    p.cubicTo(x + 2.07600 * sp, y - -1.60400 * sp, x + 2.00400 * sp, y - -1.22400 * sp, x + 1.96000 * sp, y - -0.97600 * sp);
    p.cubicTo(x + 1.95200 * sp, y - -0.92800 * sp, x + 1.95600 * sp, y - -0.93200 * sp, x + 2.01200 * sp, y - -0.90800 * sp);
    p.cubicTo(x + 2.41600 * sp, y - -0.74800 * sp, x + 2.68400 * sp, y - -0.40800 * sp, x + 2.68400 * sp, y - 0.04400 * sp);
    p.cubicTo(x + 2.68400 * sp, y - 0.55600 * sp, x + 2.30800 * sp, y - 1.00800 * sp, x + 1.72000 * sp, y - 1.00800 * sp);
    p.cubicTo(x + 1.61600 * sp, y - 1.00800 * sp, x + 1.61600 * sp, y - 1.00800 * sp, x + 1.60400 * sp, y - 1.08000 * sp);
    p.close();
    p.moveTo(x + 1.88000 * sp, y - 3.77200 * sp);
    p.cubicTo(x + 2.01200 * sp, y - 3.77200 * sp, x + 2.12000 * sp, y - 3.66400 * sp, x + 2.12000 * sp, y - 3.44400 * sp);
    p.cubicTo(x + 2.12000 * sp, y - 3.16800 * sp, x + 1.98800 * sp, y - 2.91200 * sp, x + 1.67600 * sp, y - 2.60000 * sp);
    p.cubicTo(x + 1.61200 * sp, y - 2.53600 * sp, x + 1.51600 * sp, y - 2.44400 * sp, x + 1.42400 * sp, y - 2.36400 * sp);
    p.cubicTo(x + 1.39600 * sp, y - 2.34000 * sp, x + 1.38000 * sp, y - 2.34400 * sp, x + 1.37200 * sp, y - 2.39600 * sp);
    p.cubicTo(x + 1.35600 * sp, y - 2.50000 * sp, x + 1.34800 * sp, y - 2.63600 * sp, x + 1.34800 * sp, y - 2.76400 * sp);
    p.cubicTo(x + 1.34800 * sp, y - 3.38800 * sp, x + 1.63600 * sp, y - 3.77200 * sp, x + 1.88000 * sp, y - 3.77200 * sp);
    p.close();
    p.moveTo(x + 1.44400 * sp, y - 1.04800 * sp);
    p.cubicTo(x + 1.45600 * sp, y - 0.97200 * sp, x + 1.45600 * sp, y - 0.97600 * sp, x + 1.38400 * sp, y - 0.95200 * sp);
    p.cubicTo(x + 1.03200 * sp, y - 0.83200 * sp, x + 0.80400 * sp, y - 0.51600 * sp, x + 0.80400 * sp, y - 0.17600 * sp);
    p.cubicTo(x + 0.80400 * sp, y - -0.18400 * sp, x + 0.99200 * sp, y - -0.44000 * sp, x + 1.26400 * sp, y - -0.53200 * sp);
    p.cubicTo(x + 1.29600 * sp, y - -0.54400 * sp, x + 1.34400 * sp, y - -0.55600 * sp, x + 1.37200 * sp, y - -0.55600 * sp);
    p.cubicTo(x + 1.40400 * sp, y - -0.55600 * sp, x + 1.42000 * sp, y - -0.53600 * sp, x + 1.42000 * sp, y - -0.51200 * sp);
    p.cubicTo(x + 1.42000 * sp, y - -0.48400 * sp, x + 1.38800 * sp, y - -0.47200 * sp, x + 1.36000 * sp, y - -0.46000 * sp);
    p.cubicTo(x + 1.19200 * sp, y - -0.38800 * sp, x + 1.07200 * sp, y - -0.21600 * sp, x + 1.07200 * sp, y - -0.03200 * sp);
    p.cubicTo(x + 1.07200 * sp, y - 0.19600 * sp, x + 1.22800 * sp, y - 0.36800 * sp, x + 1.47200 * sp, y - 0.43600 * sp);
    p.cubicTo(x + 1.53600 * sp, y - 0.45200 * sp, x + 1.54400 * sp, y - 0.44800 * sp, x + 1.55200 * sp, y - 0.40400 * sp);
    p.lineTo(x + 1.75200 * sp, y - -0.78800 * sp);
    p.cubicTo(x + 1.76000 * sp, y - -0.83200 * sp, x + 1.75600 * sp, y - -0.83200 * sp, x + 1.69600 * sp, y - -0.84400 * sp);
    p.cubicTo(x + 1.63200 * sp, y - -0.85600 * sp, x + 1.55200 * sp, y - -0.86400 * sp, x + 1.47200 * sp, y - -0.86400 * sp);
    p.cubicTo(x + 0.77200 * sp, y - -0.86400 * sp, x + 0.32000 * sp, y - -0.47600 * sp, x + 0.32000 * sp, y - 0.08000 * sp);
    p.cubicTo(x + 0.32000 * sp, y - 0.31600 * sp, x + 0.36000 * sp, y - 0.63200 * sp, x + 0.69200 * sp, y - 1.00800 * sp);
    p.cubicTo(x + 0.93200 * sp, y - 1.27600 * sp, x + 1.11600 * sp, y - 1.42400 * sp, x + 1.30400 * sp, y - 1.57600 * sp);
    p.cubicTo(x + 1.34400 * sp, y - 1.60800 * sp, x + 1.35200 * sp, y - 1.60400 * sp, x + 1.36000 * sp, y - 1.56000 * sp);
    p.close();
    p.moveTo(x + 1.72000 * sp, y - 0.41200 * sp);
    p.cubicTo(x + 1.71200 * sp, y - 0.46000 * sp, x + 1.71600 * sp, y - 0.47200 * sp, x + 1.76400 * sp, y - 0.46800 * sp);
    p.cubicTo(x + 2.08800 * sp, y - 0.44000 * sp, x + 2.35600 * sp, y - 0.16800 * sp, x + 2.35600 * sp, y - -0.18400 * sp);
    p.cubicTo(x + 2.35600 * sp, y - -0.43600 * sp, x + 2.20400 * sp, y - -0.64000 * sp, x + 1.98000 * sp, y - -0.75200 * sp);
    p.cubicTo(x + 1.93200 * sp, y - -0.77600 * sp, x + 1.92400 * sp, y - -0.77600 * sp, x + 1.91600 * sp, y - -0.72800 * sp);
    p.close();
    return p;
  }

  /// Standard F-clef (Bass)
  /// Anchor: [x] horizontal start, [y] F3 line (Line 4)
  /// Extracted from Steinberg Bravura under SIL Open Font License 1.1.
  static Path createBassClefPath(double x, double y, double sp) {
    final p = Path()..fillType = PathFillType.evenOdd;
    p.moveTo(x + 1.00800 * sp, y - 1.04800 * sp);
    p.cubicTo(x + 0.31200 * sp, y - 1.04800 * sp, x + 0.00000 * sp, y - 0.54000 * sp, x + 0.00000 * sp, y - 0.15600 * sp);
    p.cubicTo(x + 0.00000 * sp, y - -0.16400 * sp, x + 0.16800 * sp, y - -0.44000 * sp, x + 0.49200 * sp, y - -0.44000 * sp);
    p.cubicTo(x + 0.74400 * sp, y - -0.44000 * sp, x + 0.91600 * sp, y - -0.26400 * sp, x + 0.91600 * sp, y - -0.01600 * sp);
    p.cubicTo(x + 0.91600 * sp, y - 0.24000 * sp, x + 0.72800 * sp, y - 0.40000 * sp, x + 0.53200 * sp, y - 0.40000 * sp);
    p.cubicTo(x + 0.42400 * sp, y - 0.40000 * sp, x + 0.38400 * sp, y - 0.37200 * sp, x + 0.33200 * sp, y - 0.37200 * sp);
    p.cubicTo(x + 0.28000 * sp, y - 0.37200 * sp, x + 0.26800 * sp, y - 0.40400 * sp, x + 0.26800 * sp, y - 0.44400 * sp);
    p.cubicTo(x + 0.26800 * sp, y - 0.60400 * sp, x + 0.50800 * sp, y - 0.89600 * sp, x + 0.91600 * sp, y - 0.89600 * sp);
    p.cubicTo(x + 1.34000 * sp, y - 0.89600 * sp, x + 1.52400 * sp, y - 0.48000 * sp, x + 1.52400 * sp, y - -0.14800 * sp);
    p.cubicTo(x + 1.52400 * sp, y - -0.56000 * sp, x + 1.43600 * sp, y - -1.04000 * sp, x + 1.18800 * sp, y - -1.42400 * sp);
    p.cubicTo(x + 0.94800 * sp, y - -1.79600 * sp, x + 0.53600 * sp, y - -2.13600 * sp, x + 0.04000 * sp, y - -2.42000 * sp);
    p.cubicTo(x + 0.00400 * sp, y - -2.44000 * sp, x + -0.02000 * sp, y - -2.46000 * sp, x + -0.02000 * sp, y - -2.49200 * sp);
    p.cubicTo(x + -0.02000 * sp, y - -2.51600 * sp, x + -0.00400 * sp, y - -2.54000 * sp, x + 0.03200 * sp, y - -2.54000 * sp);
    p.cubicTo(x + 0.05200 * sp, y - -2.54000 * sp, x + 0.07600 * sp, y - -2.53200 * sp, x + 0.10000 * sp, y - -2.52000 * sp);
    p.cubicTo(x + 0.63200 * sp, y - -2.26000 * sp, x + 1.14400 * sp, y - -1.95600 * sp, x + 1.56800 * sp, y - -1.50000 * sp);
    p.cubicTo(x + 1.91600 * sp, y - -1.12400 * sp, x + 2.12400 * sp, y - -0.63600 * sp, x + 2.12400 * sp, y - -0.11200 * sp);
    p.cubicTo(x + 2.12400 * sp, y - 0.58400 * sp, x + 1.70000 * sp, y - 1.04800 * sp, x + 1.00800 * sp, y - 1.04800 * sp);
    p.close();
    p.moveTo(x + 2.51600 * sp, y - 0.72000 * sp);
    p.cubicTo(x + 2.39200 * sp, y - 0.72000 * sp, x + 2.29600 * sp, y - 0.62400 * sp, x + 2.29600 * sp, y - 0.50000 * sp);
    p.cubicTo(x + 2.29600 * sp, y - 0.37600 * sp, x + 2.39200 * sp, y - 0.28000 * sp, x + 2.51600 * sp, y - 0.28000 * sp);
    p.cubicTo(x + 2.64000 * sp, y - 0.28000 * sp, x + 2.73600 * sp, y - 0.37600 * sp, x + 2.73600 * sp, y - 0.50000 * sp);
    p.cubicTo(x + 2.73600 * sp, y - 0.62400 * sp, x + 2.64000 * sp, y - 0.72000 * sp, x + 2.51600 * sp, y - 0.72000 * sp);
    p.close();
    p.moveTo(x + 2.52000 * sp, y - -0.28400 * sp);
    p.cubicTo(x + 2.39600 * sp, y - -0.28400 * sp, x + 2.30400 * sp, y - -0.37600 * sp, x + 2.30400 * sp, y - -0.50000 * sp);
    p.cubicTo(x + 2.30400 * sp, y - -0.62400 * sp, x + 2.39600 * sp, y - -0.71600 * sp, x + 2.52000 * sp, y - -0.71600 * sp);
    p.cubicTo(x + 2.64400 * sp, y - -0.71600 * sp, x + 2.73600 * sp, y - -0.62400 * sp, x + 2.73600 * sp, y - -0.50000 * sp);
    p.cubicTo(x + 2.73600 * sp, y - -0.37600 * sp, x + 2.64400 * sp, y - -0.28400 * sp, x + 2.52000 * sp, y - -0.28400 * sp);
    p.close();
    return p;
  }

  /// Standard Flat Accidental
  /// Anchor: [x] center/left, [y] notehead center
  /// Extracted from Steinberg Bravura under SIL Open Font License 1.1.
  static Path createFlatPath(double x, double y, double sp) {
    final p = Path()..fillType = PathFillType.evenOdd;
    p.moveTo(x + 0.04800 * sp, y - -0.68000 * sp);
    p.cubicTo(x + 0.06000 * sp, y - -0.69600 * sp, x + 0.07200 * sp, y - -0.70000 * sp, x + 0.08400 * sp, y - -0.70000 * sp);
    p.cubicTo(x + 0.09600 * sp, y - -0.70000 * sp, x + 0.10800 * sp, y - -0.69200 * sp, x + 0.10800 * sp, y - -0.69200 * sp);
    p.cubicTo(x + 0.22800 * sp, y - -0.62400 * sp, x + 0.32400 * sp, y - -0.51600 * sp, x + 0.42400 * sp, y - -0.44800 * sp);
    p.cubicTo(x + 0.78000 * sp, y - -0.20000 * sp, x + 0.90400 * sp, y - 0.04400 * sp, x + 0.90400 * sp, y - 0.22800 * sp);
    p.cubicTo(x + 0.90400 * sp, y - 0.45600 * sp, x + 0.72800 * sp, y - 0.60000 * sp, x + 0.54400 * sp, y - 0.61200 * sp);
    p.cubicTo(x + 0.51600 * sp, y - 0.61200 * sp, x + 0.48800 * sp, y - 0.60800 * sp, x + 0.46000 * sp, y - 0.60000 * sp);
    p.cubicTo(x + 0.41600 * sp, y - 0.58800 * sp, x + 0.36800 * sp, y - 0.57200 * sp, x + 0.32400 * sp, y - 0.54400 * sp);
    p.cubicTo(x + 0.30000 * sp, y - 0.52400 * sp, x + 0.25600 * sp, y - 0.48800 * sp, x + 0.23600 * sp, y - 0.48800 * sp);
    p.cubicTo(x + 0.22800 * sp, y - 0.48800 * sp, x + 0.22400 * sp, y - 0.48800 * sp, x + 0.21600 * sp, y - 0.49200 * sp);
    p.cubicTo(x + 0.18800 * sp, y - 0.50400 * sp, x + 0.17200 * sp, y - 0.53200 * sp, x + 0.17200 * sp, y - 0.56000 * sp);
    p.cubicTo(x + 0.17600 * sp, y - 0.64800 * sp, x + 0.20000 * sp, y - 1.60800 * sp, x + 0.20000 * sp, y - 1.68800 * sp);
    p.cubicTo(x + 0.20000 * sp, y - 1.73200 * sp, x + 0.16400 * sp, y - 1.75600 * sp, x + 0.12400 * sp, y - 1.75600 * sp);
    p.cubicTo(x + 0.06800 * sp, y - 1.75600 * sp, x + 0.00400 * sp, y - 1.71600 * sp, x + 0.00000 * sp, y - 1.64400 * sp);
    p.cubicTo(x + 0.00000 * sp, y - 1.64400 * sp, x + 0.01600 * sp, y - -0.64000 * sp, x + 0.04800 * sp, y - -0.68000 * sp);
    p.close();
    p.moveTo(x + 0.18800 * sp, y - -0.32400 * sp);
    p.cubicTo(x + 0.18800 * sp, y - -0.32400 * sp, x + 0.17600 * sp, y - -0.08400 * sp, x + 0.17600 * sp, y - 0.07600 * sp);
    p.cubicTo(x + 0.17600 * sp, y - 0.14000 * sp, x + 0.18000 * sp, y - 0.18800 * sp, x + 0.18400 * sp, y - 0.20400 * sp);
    p.cubicTo(x + 0.20000 * sp, y - 0.25200 * sp, x + 0.30400 * sp, y - 0.34000 * sp, x + 0.36000 * sp, y - 0.37200 * sp);
    p.cubicTo(x + 0.39600 * sp, y - 0.39200 * sp, x + 0.43200 * sp, y - 0.40000 * sp, x + 0.46400 * sp, y - 0.40000 * sp);
    p.cubicTo(x + 0.50400 * sp, y - 0.40000 * sp, x + 0.54000 * sp, y - 0.38400 * sp, x + 0.56400 * sp, y - 0.35600 * sp);
    p.cubicTo(x + 0.60400 * sp, y - 0.31200 * sp, x + 0.62800 * sp, y - 0.24400 * sp, x + 0.62800 * sp, y - 0.16800 * sp);
    p.cubicTo(x + 0.62800 * sp, y - 0.09600 * sp, x + 0.60800 * sp, y - 0.01200 * sp, x + 0.56000 * sp, y - -0.07200 * sp);
    p.cubicTo(x + 0.50800 * sp, y - -0.16800 * sp, x + 0.39200 * sp, y - -0.29600 * sp, x + 0.27200 * sp, y - -0.37200 * sp);
    p.cubicTo(x + 0.25600 * sp, y - -0.38000 * sp, x + 0.24400 * sp, y - -0.38400 * sp, x + 0.23200 * sp, y - -0.38400 * sp);
    p.cubicTo(x + 0.19600 * sp, y - -0.38400 * sp, x + 0.18800 * sp, y - -0.34400 * sp, x + 0.18800 * sp, y - -0.32400 * sp);
    p.close();
    return p;
  }

  /// Standard Natural Accidental
  /// Anchor: [x] center/left, [y] notehead center
  /// Extracted from Steinberg Bravura under SIL Open Font License 1.1.
  static Path createNaturalPath(double x, double y, double sp) {
    final p = Path()..fillType = PathFillType.evenOdd;
    p.moveTo(x + 0.56400 * sp, y - 0.72400 * sp);
    p.cubicTo(x + 0.55600 * sp, y - 0.72400 * sp, x + 0.55200 * sp, y - 0.72000 * sp, x + 0.54800 * sp, y - 0.72000 * sp);
    p.cubicTo(x + 0.54800 * sp, y - 0.72000 * sp, x + 0.29200 * sp, y - 0.62800 * sp, x + 0.18800 * sp, y - 0.62800 * sp);
    p.cubicTo(x + 0.16400 * sp, y - 0.62800 * sp, x + 0.14800 * sp, y - 0.63200 * sp, x + 0.14800 * sp, y - 0.64800 * sp);
    p.lineTo(x + 0.14800 * sp, y - 1.31600 * sp);
    p.cubicTo(x + 0.14800 * sp, y - 1.34400 * sp, x + 0.12400 * sp, y - 1.36400 * sp, x + 0.10000 * sp, y - 1.36400 * sp);
    p.lineTo(x + 0.04800 * sp, y - 1.36400 * sp);
    p.cubicTo(x + 0.02000 * sp, y - 1.36400 * sp, x + 0.00000 * sp, y - 1.34400 * sp, x + 0.00000 * sp, y - 1.31600 * sp);
    p.lineTo(x + 0.00000 * sp, y - -0.74400 * sp);
    p.cubicTo(x + 0.00000 * sp, y - -0.76800 * sp, x + 0.01200 * sp, y - -0.78000 * sp, x + 0.03200 * sp, y - -0.78000 * sp);
    p.cubicTo(x + 0.03600 * sp, y - -0.78000 * sp, x + 0.04400 * sp, y - -0.77600 * sp, x + 0.04800 * sp, y - -0.77600 * sp);
    p.cubicTo(x + 0.04800 * sp, y - -0.77600 * sp, x + 0.05600 * sp, y - -0.77600 * sp, x + 0.06000 * sp, y - -0.77200 * sp);
    p.cubicTo(x + 0.11600 * sp, y - -0.74800 * sp, x + 0.34000 * sp, y - -0.65200 * sp, x + 0.45600 * sp, y - -0.65200 * sp);
    p.cubicTo(x + 0.49600 * sp, y - -0.65200 * sp, x + 0.52400 * sp, y - -0.66400 * sp, x + 0.52400 * sp, y - -0.69600 * sp);
    p.lineTo(x + 0.52400 * sp, y - -1.29200 * sp);
    p.cubicTo(x + 0.52400 * sp, y - -1.32000 * sp, x + 0.54400 * sp, y - -1.34000 * sp, x + 0.57200 * sp, y - -1.34000 * sp);
    p.lineTo(x + 0.62400 * sp, y - -1.34000 * sp);
    p.cubicTo(x + 0.64800 * sp, y - -1.34000 * sp, x + 0.67200 * sp, y - -1.32000 * sp, x + 0.67200 * sp, y - -1.29200 * sp);
    p.lineTo(x + 0.67200 * sp, y - 0.71600 * sp);
    p.cubicTo(x + 0.67200 * sp, y - 0.73600 * sp, x + 0.65600 * sp, y - 0.74800 * sp, x + 0.64000 * sp, y - 0.74800 * sp);
    p.cubicTo(x + 0.63600 * sp, y - 0.74800 * sp, x + 0.62800 * sp, y - 0.74800 * sp, x + 0.62400 * sp, y - 0.74400 * sp);
    p.close();
    p.moveTo(x + 0.14800 * sp, y - 0.15600 * sp);
    p.cubicTo(x + 0.14800 * sp, y - 0.21200 * sp, x + 0.39200 * sp, y - 0.31600 * sp, x + 0.48800 * sp, y - 0.31600 * sp);
    p.cubicTo(x + 0.51200 * sp, y - 0.31600 * sp, x + 0.52400 * sp, y - 0.31200 * sp, x + 0.52400 * sp, y - 0.29600 * sp);
    p.lineTo(x + 0.52400 * sp, y - -0.11600 * sp);
    p.cubicTo(x + 0.52400 * sp, y - -0.18800 * sp, x + 0.29600 * sp, y - -0.28000 * sp, x + 0.19600 * sp, y - -0.28000 * sp);
    p.cubicTo(x + 0.16800 * sp, y - -0.28000 * sp, x + 0.14800 * sp, y - -0.27200 * sp, x + 0.14800 * sp, y - -0.25600 * sp);
    p.close();
    return p;
  }

  /// Standard Sharp Accidental
  /// Anchor: [x] center/left, [y] notehead center
  /// Extracted from Steinberg Bravura under SIL Open Font License 1.1.
  static Path createSharpPath(double x, double y, double sp) {
    final p = Path()..fillType = PathFillType.evenOdd;
    p.moveTo(x + 0.94800 * sp, y - 0.47200 * sp);
    p.cubicTo(x + 0.97600 * sp, y - 0.48400 * sp, x + 0.99600 * sp, y - 0.51600 * sp, x + 0.99600 * sp, y - 0.54000 * sp);
    p.lineTo(x + 0.99600 * sp, y - 0.82400 * sp);
    p.cubicTo(x + 0.99600 * sp, y - 0.84400 * sp, x + 0.98400 * sp, y - 0.85600 * sp, x + 0.96800 * sp, y - 0.85600 * sp);
    p.cubicTo(x + 0.96000 * sp, y - 0.85600 * sp, x + 0.95600 * sp, y - 0.85600 * sp, x + 0.94800 * sp, y - 0.85200 * sp);
    p.cubicTo(x + 0.94800 * sp, y - 0.85200 * sp, x + 0.86800 * sp, y - 0.82000 * sp, x + 0.84800 * sp, y - 0.81600 * sp);
    p.cubicTo(x + 0.82000 * sp, y - 0.81600 * sp, x + 0.79200 * sp, y - 0.83600 * sp, x + 0.79200 * sp, y - 0.86800 * sp);
    p.lineTo(x + 0.79200 * sp, y - 1.35600 * sp);
    p.cubicTo(x + 0.79200 * sp, y - 1.38000 * sp, x + 0.76800 * sp, y - 1.40000 * sp, x + 0.73600 * sp, y - 1.40000 * sp);
    p.cubicTo(x + 0.69600 * sp, y - 1.40000 * sp, x + 0.67200 * sp, y - 1.38000 * sp, x + 0.67200 * sp, y - 1.35600 * sp);
    p.lineTo(x + 0.67200 * sp, y - 0.83600 * sp);
    p.cubicTo(x + 0.66800 * sp, y - 0.79600 * sp, x + 0.65600 * sp, y - 0.74400 * sp, x + 0.62000 * sp, y - 0.72000 * sp);
    p.cubicTo(x + 0.57200 * sp, y - 0.69200 * sp, x + 0.43600 * sp, y - 0.63600 * sp, x + 0.36800 * sp, y - 0.62000 * sp);
    p.cubicTo(x + 0.33200 * sp, y - 0.62000 * sp, x + 0.32000 * sp, y - 0.66800 * sp, x + 0.32000 * sp, y - 0.70000 * sp);
    p.lineTo(x + 0.32000 * sp, y - 1.18000 * sp);
    p.cubicTo(x + 0.32000 * sp, y - 1.20400 * sp, x + 0.29200 * sp, y - 1.22400 * sp, x + 0.26400 * sp, y - 1.22400 * sp);
    p.cubicTo(x + 0.22400 * sp, y - 1.22400 * sp, x + 0.20000 * sp, y - 1.20400 * sp, x + 0.20000 * sp, y - 1.18000 * sp);
    p.lineTo(x + 0.20000 * sp, y - 0.64000 * sp);
    p.cubicTo(x + 0.20000 * sp, y - 0.58400 * sp, x + 0.17600 * sp, y - 0.54400 * sp, x + 0.15200 * sp, y - 0.53200 * sp);
    p.cubicTo(x + 0.12800 * sp, y - 0.52000 * sp, x + 0.04800 * sp, y - 0.48800 * sp, x + 0.04800 * sp, y - 0.48800 * sp);
    p.cubicTo(x + 0.02000 * sp, y - 0.48000 * sp, x + 0.00000 * sp, y - 0.44800 * sp, x + 0.00000 * sp, y - 0.42400 * sp);
    p.lineTo(x + 0.00000 * sp, y - 0.14000 * sp);
    p.cubicTo(x + 0.00000 * sp, y - 0.11600 * sp, x + 0.01200 * sp, y - 0.10400 * sp, x + 0.03200 * sp, y - 0.10400 * sp);
    p.cubicTo(x + 0.03600 * sp, y - 0.10400 * sp, x + 0.04400 * sp, y - 0.10800 * sp, x + 0.04800 * sp, y - 0.10800 * sp);
    p.cubicTo(x + 0.04800 * sp, y - 0.10800 * sp, x + 0.10800 * sp, y - 0.13200 * sp, x + 0.13600 * sp, y - 0.14800 * sp);
    p.cubicTo(x + 0.14000 * sp, y - 0.14800 * sp, x + 0.14400 * sp, y - 0.15200 * sp, x + 0.14800 * sp, y - 0.15200 * sp);
    p.cubicTo(x + 0.17600 * sp, y - 0.15200 * sp, x + 0.20000 * sp, y - 0.11200 * sp, x + 0.20000 * sp, y - 0.08000 * sp);
    p.lineTo(x + 0.20000 * sp, y - -0.31600 * sp);
    p.cubicTo(x + 0.20000 * sp, y - -0.36000 * sp, x + 0.18000 * sp, y - -0.39600 * sp, x + 0.15600 * sp, y - -0.40800 * sp);
    p.cubicTo(x + 0.13200 * sp, y - -0.41600 * sp, x + 0.04800 * sp, y - -0.45200 * sp, x + 0.04800 * sp, y - -0.45200 * sp);
    p.cubicTo(x + 0.02000 * sp, y - -0.46000 * sp, x + 0.00000 * sp, y - -0.49200 * sp, x + 0.00000 * sp, y - -0.51600 * sp);
    p.lineTo(x + 0.00000 * sp, y - -0.80000 * sp);
    p.cubicTo(x + 0.00000 * sp, y - -0.82400 * sp, x + 0.01200 * sp, y - -0.83600 * sp, x + 0.03200 * sp, y - -0.83600 * sp);
    p.cubicTo(x + 0.03600 * sp, y - -0.83600 * sp, x + 0.04400 * sp, y - -0.83200 * sp, x + 0.04800 * sp, y - -0.83200 * sp);
    p.cubicTo(x + 0.04800 * sp, y - -0.83200 * sp, x + 0.10400 * sp, y - -0.80800 * sp, x + 0.14000 * sp, y - -0.79600 * sp);
    p.cubicTo(x + 0.14400 * sp, y - -0.79200 * sp, x + 0.14800 * sp, y - -0.79200 * sp, x + 0.15200 * sp, y - -0.79200 * sp);
    p.cubicTo(x + 0.18000 * sp, y - -0.79200 * sp, x + 0.20000 * sp, y - -0.83600 * sp, x + 0.20000 * sp, y - -0.85600 * sp);
    p.lineTo(x + 0.20000 * sp, y - -1.34800 * sp);
    p.cubicTo(x + 0.20000 * sp, y - -1.37200 * sp, x + 0.22400 * sp, y - -1.39200 * sp, x + 0.25200 * sp, y - -1.39200 * sp);
    p.cubicTo(x + 0.29200 * sp, y - -1.39200 * sp, x + 0.32000 * sp, y - -1.37200 * sp, x + 0.32000 * sp, y - -1.34800 * sp);
    p.lineTo(x + 0.32000 * sp, y - -0.79200 * sp);
    p.cubicTo(x + 0.32000 * sp, y - -0.74000 * sp, x + 0.34000 * sp, y - -0.71200 * sp, x + 0.36000 * sp, y - -0.70400 * sp);
    p.lineTo(x + 0.60400 * sp, y - -0.60400 * sp);
    p.cubicTo(x + 0.60800 * sp, y - -0.60400 * sp, x + 0.61600 * sp, y - -0.60000 * sp, x + 0.62000 * sp, y - -0.60000 * sp);
    p.cubicTo(x + 0.65200 * sp, y - -0.60000 * sp, x + 0.67200 * sp, y - -0.64800 * sp, x + 0.67200 * sp, y - -0.67200 * sp);
    p.lineTo(x + 0.67200 * sp, y - -1.17200 * sp);
    p.cubicTo(x + 0.67200 * sp, y - -1.19600 * sp, x + 0.69600 * sp, y - -1.21600 * sp, x + 0.72400 * sp, y - -1.21600 * sp);
    p.cubicTo(x + 0.76800 * sp, y - -1.21600 * sp, x + 0.79200 * sp, y - -1.19600 * sp, x + 0.79200 * sp, y - -1.17200 * sp);
    p.lineTo(x + 0.79200 * sp, y - -0.60400 * sp);
    p.cubicTo(x + 0.79200 * sp, y - -0.57200 * sp, x + 0.80800 * sp, y - -0.52400 * sp, x + 0.83600 * sp, y - -0.51200 * sp);
    p.cubicTo(x + 0.86400 * sp, y - -0.50000 * sp, x + 0.94800 * sp, y - -0.46800 * sp, x + 0.94800 * sp, y - -0.46800 * sp);
    p.cubicTo(x + 0.97600 * sp, y - -0.45600 * sp, x + 0.99600 * sp, y - -0.42400 * sp, x + 0.99600 * sp, y - -0.40000 * sp);
    p.lineTo(x + 0.99600 * sp, y - -0.11600 * sp);
    p.cubicTo(x + 0.99600 * sp, y - -0.09600 * sp, x + 0.98400 * sp, y - -0.08400 * sp, x + 0.96800 * sp, y - -0.08400 * sp);
    p.cubicTo(x + 0.96000 * sp, y - -0.08400 * sp, x + 0.95600 * sp, y - -0.08400 * sp, x + 0.94800 * sp, y - -0.08800 * sp);
    p.lineTo(x + 0.84400 * sp, y - -0.12800 * sp);
    p.cubicTo(x + 0.82000 * sp, y - -0.12800 * sp, x + 0.79200 * sp, y - -0.10400 * sp, x + 0.79200 * sp, y - -0.05600 * sp);
    p.lineTo(x + 0.79200 * sp, y - 0.31600 * sp);
    p.cubicTo(x + 0.79200 * sp, y - 0.34400 * sp, x + 0.81200 * sp, y - 0.42000 * sp, x + 0.84400 * sp, y - 0.43200 * sp);
    p.close();
    p.moveTo(x + 0.67200 * sp, y - -0.18000 * sp);
    p.cubicTo(x + 0.64800 * sp, y - -0.26000 * sp, x + 0.46000 * sp, y - -0.34000 * sp, x + 0.36800 * sp, y - -0.34000 * sp);
    p.cubicTo(x + 0.34400 * sp, y - -0.34000 * sp, x + 0.32400 * sp, y - -0.33200 * sp, x + 0.32000 * sp, y - -0.32000 * sp);
    p.cubicTo(x + 0.31200 * sp, y - -0.30400 * sp, x + 0.30800 * sp, y - -0.21600 * sp, x + 0.30800 * sp, y - -0.12000 * sp);
    p.cubicTo(x + 0.30800 * sp, y - 0.00400 * sp, x + 0.31200 * sp, y - 0.14400 * sp, x + 0.32000 * sp, y - 0.17600 * sp);
    p.cubicTo(x + 0.32800 * sp, y - 0.24400 * sp, x + 0.51200 * sp, y - 0.32800 * sp, x + 0.61200 * sp, y - 0.32800 * sp);
    p.cubicTo(x + 0.64000 * sp, y - 0.32800 * sp, x + 0.66400 * sp, y - 0.32000 * sp, x + 0.67200 * sp, y - 0.30400 * sp);
    p.cubicTo(x + 0.68000 * sp, y - 0.28400 * sp, x + 0.68800 * sp, y - 0.18400 * sp, x + 0.68800 * sp, y - 0.07600 * sp);
    p.cubicTo(x + 0.68800 * sp, y - -0.03200 * sp, x + 0.68000 * sp, y - -0.14400 * sp, x + 0.67200 * sp, y - -0.18000 * sp);
    p.close();
    return p;
  }

  /// Standard Quarter Rest
  /// Anchor: [x] center, [y] line 3
  /// Extracted from Steinberg Bravura under SIL Open Font License 1.1.
  static Path createQuarterRestPath(double x, double y, double sp) {
    final p = Path()..fillType = PathFillType.evenOdd;
    p.moveTo(x + 0.31200 * sp, y - -0.15200 * sp);
    p.cubicTo(x + 0.37600 * sp, y - -0.23200 * sp, x + 0.43200 * sp, y - -0.30800 * sp, x + 0.48400 * sp, y - -0.39200 * sp);
    p.cubicTo(x + 0.49200 * sp, y - -0.40800 * sp, x + 0.50800 * sp, y - -0.44000 * sp, x + 0.50800 * sp, y - -0.44800 * sp);
    p.cubicTo(x + 0.50800 * sp, y - -0.45200 * sp, x + 0.50800 * sp, y - -0.46000 * sp, x + 0.50400 * sp, y - -0.46400 * sp);
    p.cubicTo(x + 0.49600 * sp, y - -0.48000 * sp, x + 0.48000 * sp, y - -0.48400 * sp, x + 0.46000 * sp, y - -0.48400 * sp);
    p.cubicTo(x + 0.44400 * sp, y - -0.48400 * sp, x + 0.41200 * sp, y - -0.47600 * sp, x + 0.39600 * sp, y - -0.47200 * sp);
    p.cubicTo(x + 0.37600 * sp, y - -0.47200 * sp, x + 0.35200 * sp, y - -0.46000 * sp, x + 0.33200 * sp, y - -0.46000 * sp);
    p.cubicTo(x + 0.16000 * sp, y - -0.46000 * sp, x + 0.00400 * sp, y - -0.63200 * sp, x + 0.00400 * sp, y - -0.84400 * sp);
    p.cubicTo(x + 0.00400 * sp, y - -1.04400 * sp, x + 0.17600 * sp, y - -1.24000 * sp, x + 0.46800 * sp, y - -1.46400 * sp);
    p.cubicTo(x + 0.50000 * sp, y - -1.48800 * sp, x + 0.54000 * sp, y - -1.50000 * sp, x + 0.57200 * sp, y - -1.50000 * sp);
    p.cubicTo(x + 0.60000 * sp, y - -1.50000 * sp, x + 0.62800 * sp, y - -1.49200 * sp, x + 0.63200 * sp, y - -1.47600 * sp);
    p.cubicTo(x + 0.63600 * sp, y - -1.46400 * sp, x + 0.64000 * sp, y - -1.45600 * sp, x + 0.64000 * sp, y - -1.44800 * sp);
    p.cubicTo(x + 0.64000 * sp, y - -1.41200 * sp, x + 0.60800 * sp, y - -1.38000 * sp, x + 0.57600 * sp, y - -1.35200 * sp);
    p.cubicTo(x + 0.52400 * sp, y - -1.35200 * sp, x + 0.48000 * sp, y - -1.24400 * sp, x + 0.47200 * sp, y - -1.20800 * sp);
    p.cubicTo(x + 0.46000 * sp, y - -1.17600 * sp, x + 0.45600 * sp, y - -1.14000 * sp, x + 0.45600 * sp, y - -1.10400 * sp);
    p.cubicTo(x + 0.45600 * sp, y - -0.98000 * sp, x + 0.51600 * sp, y - -0.84000 * sp, x + 0.64400 * sp, y - -0.81600 * sp);
    p.cubicTo(x + 0.66400 * sp, y - -0.81200 * sp, x + 0.68400 * sp, y - -0.81200 * sp, x + 0.70800 * sp, y - -0.81200 * sp);
    p.cubicTo(x + 0.82400 * sp, y - -0.81200 * sp, x + 0.95600 * sp, y - -0.85600 * sp, x + 1.02000 * sp, y - -0.88000 * sp);
    p.cubicTo(x + 1.02400 * sp, y - -0.88000 * sp, x + 1.02800 * sp, y - -0.88400 * sp, x + 1.03200 * sp, y - -0.88400 * sp);
    p.cubicTo(x + 1.04400 * sp, y - -0.88800 * sp, x + 1.05200 * sp, y - -0.88800 * sp, x + 1.06000 * sp, y - -0.88800 * sp);
    p.cubicTo(x + 1.07200 * sp, y - -0.88800 * sp, x + 1.08000 * sp, y - -0.88400 * sp, x + 1.08000 * sp, y - -0.87200 * sp);
    p.cubicTo(x + 1.08000 * sp, y - -0.82400 * sp, x + 0.97600 * sp, y - -0.69200 * sp, x + 0.93200 * sp, y - -0.64400 * sp);
    p.cubicTo(x + 0.78000 * sp, y - -0.46000 * sp, x + 0.65600 * sp, y - -0.31200 * sp, x + 0.65600 * sp, y - -0.08800 * sp);
    p.cubicTo(x + 0.65600 * sp, y - -0.07200 * sp, x + 0.66000 * sp, y - -0.05200 * sp, x + 0.66000 * sp, y - -0.03600 * sp);
    p.cubicTo(x + 0.67600 * sp, y - 0.19600 * sp, x + 0.82000 * sp, y - 0.38800 * sp, x + 0.92400 * sp, y - 0.55200 * sp);
    p.cubicTo(x + 0.93600 * sp, y - 0.57200 * sp, x + 0.94000 * sp, y - 0.59200 * sp, x + 0.94000 * sp, y - 0.61200 * sp);
    p.cubicTo(x + 0.94000 * sp, y - 0.65200 * sp, x + 0.92400 * sp, y - 0.68800 * sp, x + 0.92400 * sp, y - 0.68800 * sp);
    p.cubicTo(x + 0.92400 * sp, y - 0.68800 * sp, x + 0.33200 * sp, y - 1.39200 * sp, x + 0.26400 * sp, y - 1.46000 * sp);
    p.cubicTo(x + 0.24400 * sp, y - 1.48000 * sp, x + 0.21600 * sp, y - 1.49200 * sp, x + 0.19200 * sp, y - 1.49200 * sp);
    p.cubicTo(x + 0.15200 * sp, y - 1.49200 * sp, x + 0.11200 * sp, y - 1.46400 * sp, x + 0.11200 * sp, y - 1.40800 * sp);
    p.cubicTo(x + 0.11200 * sp, y - 1.38800 * sp, x + 0.11600 * sp, y - 1.36800 * sp, x + 0.12800 * sp, y - 1.34400 * sp);
    p.cubicTo(x + 0.14400 * sp, y - 1.30000 * sp, x + 0.37200 * sp, y - 1.09600 * sp, x + 0.37200 * sp, y - 0.80800 * sp);
    p.cubicTo(x + 0.37200 * sp, y - 0.66000 * sp, x + 0.31200 * sp, y - 0.48800 * sp, x + 0.13200 * sp, y - 0.30000 * sp);
    p.cubicTo(x + 0.09200 * sp, y - 0.26000 * sp, x + 0.07600 * sp, y - 0.21600 * sp, x + 0.07600 * sp, y - 0.18400 * sp);
    p.cubicTo(x + 0.07600 * sp, y - 0.12800 * sp, x + 0.11600 * sp, y - 0.08800 * sp, x + 0.11600 * sp, y - 0.08800 * sp);
    p.close();
    return p;
  }

  /// Standard Eighth Rest
  /// Anchor: [x] center, [y] line 3
  /// Extracted from Steinberg Bravura under SIL Open Font License 1.1.
  static Path createEighthRestPath(double x, double y, double sp) {
    final p = Path()..fillType = PathFillType.evenOdd;
    p.moveTo(x + 0.53600 * sp, y - 0.42800 * sp);
    p.cubicTo(x + 0.53600 * sp, y - 0.57600 * sp, x + 0.41600 * sp, y - 0.69600 * sp, x + 0.26800 * sp, y - 0.69600 * sp);
    p.cubicTo(x + 0.12000 * sp, y - 0.69600 * sp, x + 0.00000 * sp, y - 0.57600 * sp, x + 0.00000 * sp, y - 0.42800 * sp);
    p.cubicTo(x + 0.00000 * sp, y - 0.34400 * sp, x + 0.04800 * sp, y - 0.27200 * sp, x + 0.10800 * sp, y - 0.22400 * sp);
    p.cubicTo(x + 0.14400 * sp, y - 0.20000 * sp, x + 0.18000 * sp, y - 0.18000 * sp, x + 0.22000 * sp, y - 0.17200 * sp);
    p.cubicTo(x + 0.25200 * sp, y - 0.16400 * sp, x + 0.28800 * sp, y - 0.15600 * sp, x + 0.32400 * sp, y - 0.15600 * sp);
    p.cubicTo(x + 0.38000 * sp, y - 0.15600 * sp, x + 0.43600 * sp, y - 0.16800 * sp, x + 0.48000 * sp, y - 0.18400 * sp);
    p.cubicTo(x + 0.53600 * sp, y - 0.20000 * sp, x + 0.57200 * sp, y - 0.21600 * sp, x + 0.62400 * sp, y - 0.24400 * sp);
    p.cubicTo(x + 0.63200 * sp, y - 0.24800 * sp, x + 0.64000 * sp, y - 0.24800 * sp, x + 0.64400 * sp, y - 0.24800 * sp);
    p.cubicTo(x + 0.66000 * sp, y - 0.24800 * sp, x + 0.66400 * sp, y - 0.23200 * sp, x + 0.66400 * sp, y - 0.21200 * sp);
    p.cubicTo(x + 0.66400 * sp, y - 0.20000 * sp, x + 0.66400 * sp, y - 0.18400 * sp, x + 0.66000 * sp, y - 0.16800 * sp);
    p.cubicTo(x + 0.64800 * sp, y - 0.10800 * sp, x + 0.36000 * sp, y - -0.68800 * sp, x + 0.28800 * sp, y - -0.95200 * sp);
    p.cubicTo(x + 0.28800 * sp, y - -1.00000 * sp, x + 0.38000 * sp, y - -1.00400 * sp, x + 0.40400 * sp, y - -1.00400 * sp);
    p.cubicTo(x + 0.44800 * sp, y - -1.00400 * sp, x + 0.50400 * sp, y - -0.99600 * sp, x + 0.54400 * sp, y - -0.96400 * sp);
    p.cubicTo(x + 0.55600 * sp, y - -0.95600 * sp, x + 0.94800 * sp, y - 0.44800 * sp, x + 0.94800 * sp, y - 0.44800 * sp);
    p.cubicTo(x + 0.96400 * sp, y - 0.52000 * sp, x + 0.98400 * sp, y - 0.58400 * sp, x + 0.98800 * sp, y - 0.60400 * sp);
    p.cubicTo(x + 0.98800 * sp, y - 0.64400 * sp, x + 0.94800 * sp, y - 0.66400 * sp, x + 0.94000 * sp, y - 0.66800 * sp);
    p.cubicTo(x + 0.93200 * sp, y - 0.66800 * sp, x + 0.92000 * sp, y - 0.66800 * sp, x + 0.89600 * sp, y - 0.65200 * sp);
    p.cubicTo(x + 0.86800 * sp, y - 0.62800 * sp, x + 0.66800 * sp, y - 0.38800 * sp, x + 0.53600 * sp, y - 0.38800 * sp);
    p.close();
    return p;
  }

  /// Authentic SMuFL Grand Staff Accolade Curly Brace (Bravura uniE000).
  /// Extracted from Steinberg Bravura under SIL Open Font License 1.1.
  static Path createGrandStaffBracePath(double x, double topY, double bottomY, double sp) {
    final double totalH = bottomY - topY;
    final double yScale = totalH / 1000.0;
    final double xScale = (sp * 1.35) / 71.0;
    final p = Path()..fillType = PathFillType.evenOdd;
    p.moveTo(x + 0 * xScale, bottomY - 500 * yScale);
    p.cubicTo(x + 24 * xScale, bottomY - 463 * yScale, x + 37 * xScale, bottomY - 435 * yScale, x + 37 * xScale, bottomY - 397 * yScale);
    p.cubicTo(x + 37 * xScale, bottomY - 330 * yScale, x + 2 * xScale, bottomY - 251 * yScale, x + 2 * xScale, bottomY - 175 * yScale);
    p.cubicTo(x + 2 * xScale, bottomY - 121 * yScale, x + 20 * xScale, bottomY - 48 * yScale, x + 61 * xScale, bottomY - 1 * yScale);
    p.cubicTo(x + 64 * xScale, bottomY - -3 * yScale, x + 71 * xScale, bottomY - 1 * yScale, x + 69 * xScale, bottomY - 6 * yScale);
    p.cubicTo(x + 45 * xScale, bottomY - 45 * yScale, x + 37 * xScale, bottomY - 91 * yScale, x + 37 * xScale, bottomY - 131 * yScale);
    p.cubicTo(x + 37 * xScale, bottomY - 212 * yScale, x + 69 * xScale, bottomY - 285 * yScale, x + 69 * xScale, bottomY - 354 * yScale);
    p.cubicTo(x + 69 * xScale, bottomY - 404 * yScale, x + 56 * xScale, bottomY - 452 * yScale, x + 16 * xScale, bottomY - 500 * yScale);
    p.cubicTo(x + 55 * xScale, bottomY - 547 * yScale, x + 69 * xScale, bottomY - 595 * yScale, x + 69 * xScale, bottomY - 645 * yScale);
    p.cubicTo(x + 69 * xScale, bottomY - 714 * yScale, x + 37 * xScale, bottomY - 788 * yScale, x + 37 * xScale, bottomY - 868 * yScale);
    p.cubicTo(x + 37 * xScale, bottomY - 909 * yScale, x + 44 * xScale, bottomY - 954 * yScale, x + 68 * xScale, bottomY - 993 * yScale);
    p.cubicTo(x + 71 * xScale, bottomY - 999 * yScale, x + 63 * xScale, bottomY - 1003 * yScale, x + 60 * xScale, bottomY - 999 * yScale);
    p.cubicTo(x + 19 * xScale, bottomY - 951 * yScale, x + 2 * xScale, bottomY - 879 * yScale, x + 2 * xScale, bottomY - 824 * yScale);
    p.cubicTo(x + 2 * xScale, bottomY - 748 * yScale, x + 37 * xScale, bottomY - 669 * yScale, x + 37 * xScale, bottomY - 602 * yScale);
    p.cubicTo(x + 37 * xScale, bottomY - 564 * yScale, x + 24 * xScale, bottomY - 537 * yScale, x + 0 * xScale, bottomY - 500 * yScale);
    p.close();
    return p;
  }

}
