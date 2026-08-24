import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/eats_theme.dart';

/// Interactive 2D transfer curve canvas for WaveShaper distortion FX.
/// Inspired by FL Studio WaveShaper and Kilohearts Shaper.
class WaveshaperCanvasWidget extends StatefulWidget {
  final int shapeType; // 0 = Soft S-Curve, 1 = Asymmetric Tube, 2 = Sine Wavefold, 3 = Angry 1, 4 = Angry 2
  final double tension; // -1.0 to 1.0
  final double preGain; // 0.1 to 4.0
  final double postGain; // 0.0 to 4.0
  final bool dcFilter;
  final ValueChanged<int>? onShapeChanged;
  final ValueChanged<double>? onTensionChanged;
  final double height;

  const WaveshaperCanvasWidget({
    super.key,
    required this.shapeType,
    required this.tension,
    this.preGain = 1.0,
    this.postGain = 1.0,
    this.dcFilter = true,
    this.onShapeChanged,
    this.onTensionChanged,
    this.height = 160.0,
  });

  @override
  State<WaveshaperCanvasWidget> createState() => _WaveshaperCanvasWidgetState();
}

class _WaveshaperCanvasWidgetState extends State<WaveshaperCanvasWidget> {
  static const List<String> shapeNames = [
    'SOFT SATURATION',
    'TUBE ASYMMETRIC',
    'SINE WAVEFOLD',
    'ANGRY 1',
    'ANGRY 2',
  ];

  void _handlePan(Offset localPos, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final normalizedX = (localPos.dx / size.width).clamp(0.0, 1.0);
    final normalizedY = (1.0 - (localPos.dy / size.height)).clamp(0.0, 1.0);

    // Calculate curve tension from vertical offset relative to diagonal
    final newTension = ((normalizedY - normalizedX) * 2.5).clamp(-1.0, 1.0);
    widget.onTensionChanged?.call(newTension);
  }

  @override
  Widget build(BuildContext context) {
    final accent = EatsTheme.primaryCyan;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.5), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // 2D Grid & Curve Canvas
            LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  onPanStart: (details) => _handlePan(details.localPosition, size),
                  onPanUpdate: (details) => _handlePan(details.localPosition, size),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _WaveshaperPainter(
                      shapeType: widget.shapeType,
                      tension: widget.tension,
                      preGain: widget.preGain,
                      dcFilter: widget.dcFilter,
                    ),
                  ),
                );
              },
            ),

            // Top Left: Preset Selection Pill
            Positioned(
              top: 8,
              left: 10,
              child: PopupMenuButton<int>(
                initialValue: widget.shapeType,
                color: EatsTheme.panelHeader,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(color: accent, width: 1.0),
                ),
                onSelected: (val) => widget.onShapeChanged?.call(val),
                itemBuilder: (ctx) {
                  return List.generate(shapeNames.length, (idx) {
                    final isSelected = widget.shapeType == idx;
                    return PopupMenuItem<int>(
                      value: idx,
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            size: 14,
                            color: isSelected ? accent : EatsTheme.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            shapeNames[idx],
                            style: EatsTheme.getDisplayFontStyle(
                              color: isSelected ? Colors.white : EatsTheme.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: accent.withOpacity(0.7), width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.show_chart, size: 12, color: accent),
                      const SizedBox(width: 5),
                      Text(
                        shapeNames[widget.shapeType.clamp(0, shapeNames.length - 1)],
                        style: EatsTheme.getDisplayFontStyle(
                          color: accent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, size: 12, color: accent),
                    ],
                  ),
                ),
              ),
            ),

            // Top Right: DC Filter & Tension Status Badges
            Positioned(
              top: 8,
              right: 10,
              child: Row(
                children: [
                  if (widget.dcFilter)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                      decoration: BoxDecoration(
                        color: EatsTheme.accentGreen.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: EatsTheme.accentGreen.withOpacity(0.7)),
                      ),
                      child: Text(
                        'DC FILTER ON',
                        style: EatsTheme.getPrimaryFontStyle(
                          color: EatsTheme.accentGreen,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFF353C52)),
                    ),
                    child: Text(
                      'TENSION ${(widget.tension >= 0 ? "+" : "")}${widget.tension.toStringAsFixed(2)}',
                      style: EatsTheme.getDisplayFontStyle(
                        color: EatsTheme.textMuted,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Hint Overlay
            Positioned(
              bottom: 6,
              left: 10,
              child: Text(
                'DRAG CURVE TO ADJUST SHAPE & TENSION',
                style: EatsTheme.getDisplayFontStyle(
                  color: EatsTheme.textMuted.withOpacity(0.6),
                  fontSize: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveshaperPainter extends CustomPainter {
  final int shapeType;
  final double tension;
  final double preGain;
  final bool dcFilter;

  _WaveshaperPainter({
    required this.shapeType,
    required this.tension,
    required this.preGain,
    required this.dcFilter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2.0;
    final cy = h / 2.0;

    // 1. Oscilloscope Grid Lines
    final gridPaint = Paint()
      ..color = const Color(0xFF1B2232).withOpacity(0.6)
      ..strokeWidth = 0.8;

    const numDivs = 8;
    for (int i = 1; i < numDivs; i++) {
      final gx = (w / numDivs) * i;
      final gy = (h / numDivs) * i;
      canvas.drawLine(Offset(gx, 0), Offset(gx, h), gridPaint);
      canvas.drawLine(Offset(0, gy), Offset(w, gy), gridPaint);
    }

    // 2. Center Zero-Crossing Axes
    final axisPaint = Paint()
      ..color = const Color(0xFF32415C).withOpacity(0.8)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(cx, 0), Offset(cx, h), axisPaint);
    canvas.drawLine(Offset(0, cy), Offset(w, cy), axisPaint);

    // 3. Linear Reference Line (Diagonal)
    final refPaint = Paint()
      ..color = const Color(0xFF222B3D)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, h), Offset(w, 0), refPaint);

    // 4. Compute and Draw WaveShaper Transfer Curve
    const numPoints = 128;
    final curvePath = Path();
    final fillPath = Path();
    fillPath.moveTo(0, cy);

    for (int i = 0; i <= numPoints; i++) {
      final xNorm = (i / numPoints) * 2.0 - 1.0; // -1.0 to 1.0
      final xPre = xNorm * preGain;
      double y = xNorm;

      switch (shapeType) {
        case 0: // Soft S-Curve / Tanh (FL Studio WaveShaper)
          final k = 1.0 + (tension + 1.0) * 3.0;
          y = _fastTanh(xPre * k) / _fastTanh(k);
        case 1: // Asymmetric Tube Drive
          if (xPre > 0) {
            y = 1.0 - math.exp(-xPre * (2.0 + tension * 1.5));
          } else {
            y = -(1.0 - math.exp(xPre * (1.2 - tension * 0.5))) * 0.85;
          }
        case 2: // Sine Wavefold Distortion
          y = math.sin(xPre * math.pi * (1.0 + (tension + 1.0) * 0.7));
        case 3: // Angry 1 (Kilohearts multi-fold)
          final folded = (xPre * (2.0 + tension * 1.5)).abs() % 2.0;
          y = (folded > 1.0 ? 2.0 - folded : folded) * 2.0 - 1.0;
          if (xPre < 0) y = -y;
        case 4: // Angry 2 (Extreme wavefold crunch)
          final fold2 = math.sin(xPre * math.pi * 2.0 * (1.2 + tension));
          y = _fastTanh(fold2 * 2.5);
        default:
          y = _fastTanh(xPre * 2.0);
      }

      y = y.clamp(-1.0, 1.0);

      final screenX = (xNorm + 1.0) * 0.5 * w;
      final screenY = (1.0 - (y + 1.0) * 0.5) * h;

      if (i == 0) {
        curvePath.moveTo(screenX, screenY);
      } else {
        curvePath.lineTo(screenX, screenY);
      }
      fillPath.lineTo(screenX, screenY);
    }

    fillPath.lineTo(w, cy);
    fillPath.close();

    // 5. Fill Under Curve with Neon Cyan Ambient Gradient
    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        EatsTheme.primaryCyan.withOpacity(0.20),
        EatsTheme.primaryCyan.withOpacity(0.02),
        EatsTheme.primaryCyan.withOpacity(0.20),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    canvas.drawPath(fillPath, Paint()..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, w, h)));

    // 6. Glowing Stroke Curve
    final glowPaint = Paint()
      ..color = EatsTheme.primaryCyan.withOpacity(0.4)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawPath(curvePath, glowPaint);

    final strokePaint = Paint()
      ..color = EatsTheme.primaryCyan
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(curvePath, strokePaint);

    // 7. Draggable Tension Control Handle Point in Center
    final handleX = cx;
    final handleY = (1.0 - ((tension * 0.5) + 0.5)) * h;
    canvas.drawCircle(
      Offset(handleX, handleY),
      5.0,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(handleX, handleY),
      7.0,
      Paint()
        ..color = EatsTheme.primaryCyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  static double _fastTanh(double x) {
    if (x > 3.0) return 1.0;
    if (x < -3.0) return -1.0;
    final x2 = x * x;
    return x * (27.0 + x2) / (27.0 + 9.0 * x2);
  }

  @override
  bool shouldRepaint(covariant _WaveshaperPainter oldDelegate) {
    return oldDelegate.shapeType != shapeType ||
        oldDelegate.tension != tension ||
        oldDelegate.preGain != preGain ||
        oldDelegate.dcFilter != dcFilter;
  }
}
