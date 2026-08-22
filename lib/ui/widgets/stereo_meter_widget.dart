import 'package:flutter/material.dart';
import '../../theme/eats_theme.dart';

/// A realistic inset glass-encased stereo audio meter readout featuring Left and Right
/// stereo LED bars with a printed central decibel scale (-inf to -60 dB) and glossy glass reflections.
class StereoMeterWidget extends StatelessWidget {
  final double leftLevel;  // Normalized 0.0 to 1.0+
  final double rightLevel; // Normalized 0.0 to 1.0+
  final Color? accentColor;
  final double width;
  final double height;

  const StereoMeterWidget({
    super.key,
    required this.leftLevel,
    required this.rightLevel,
    this.accentColor,
    this.width = 38.0,
    this.height = 160.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF090A0D),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2E3445), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0xE6000000), offset: Offset(0, 2), blurRadius: 4, spreadRadius: 0),
          BoxShadow(color: Color(0x66000000), offset: Offset(0, 0), blurRadius: 2, spreadRadius: 1),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          children: [
            // Inner Inset Bevel & Shadow
            Positioned.fill(
              child: CustomPaint(
                painter: _GlassMeterPainter(
                  leftLevel: leftLevel.clamp(0.0, 1.2),
                  rightLevel: rightLevel.clamp(0.0, 1.2),
                  accentColor: accentColor ?? EatsTheme.accentGreen,
                ),
              ),
            ),

            // Diagonal Glass Glare Reflection Overlay
            const Positioned.fill(
              child: CustomPaint(
                painter: _MeterGlassReflectionPainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassMeterPainter extends CustomPainter {
  final double leftLevel;
  final double rightLevel;
  final Color accentColor;

  _GlassMeterPainter({
    required this.leftLevel,
    required this.rightLevel,
    required this.accentColor,
  });

  static const List<String> dbLabels = [
    '-inf',
    '-6',
    '-12',
    '-18',
    '-24',
    '-30',
    '-36',
    '-42',
    '-48',
    '-54',
    '-60',
  ];

  static final List<TextPainter> _cachedDbPainters = dbLabels.map((label) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontFamily: 'monospace',
          color: Color(0xFF7A849B),
          fontSize: 7.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tp.layout();
    return tp;
  }).toList();

  @override
  void paint(Canvas canvas, Size size) {
    const totalSegments = 22;
    const segmentGap = 1.0;
    final totalHeight = size.height;

    // Outer dark background & inner recessed shadow
    final bgPaint = Paint()..color = const Color(0xFF0C0D12);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, totalHeight), bgPaint);

    // Inner shadow border
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, totalHeight), shadowPaint);

    // Meter Layout:
    // Left LED column width: 4.5px, Left pos: 3.5px
    // Right LED column width: 4.5px, Right pos: size.width - 8px
    // Central dB Scale text in between
    const ledWidth = 4.5;
    const leftX = 3.5;
    final rightX = size.width - 3.5 - ledWidth;

    // Draw Left LED Column
    _drawLedBar(
      canvas: canvas,
      xPos: leftX,
      width: ledWidth,
      height: totalHeight,
      level: leftLevel,
      totalSegments: totalSegments,
      segmentGap: segmentGap,
    );

    // Draw Right LED Column
    _drawLedBar(
      canvas: canvas,
      xPos: rightX,
      width: ledWidth,
      height: totalHeight,
      level: rightLevel,
      totalSegments: totalSegments,
      segmentGap: segmentGap,
    );

    // Draw Centered dB Scale Labels using pre-cached painters
    for (int i = 0; i < _cachedDbPainters.length; i++) {
      final fraction = i / (_cachedDbPainters.length - 1);
      final yPos = fraction * (totalHeight - 12.0) + 6.0;
      final tp = _cachedDbPainters[i];

      final textX = (size.width - tp.width) / 2.0;
      final textY = yPos - (tp.height / 2.0);
      tp.paint(canvas, Offset(textX, textY));
    }
  }

  void _drawLedBar({
    required Canvas canvas,
    required double xPos,
    required double width,
    required double height,
    required double level,
    required int totalSegments,
    required double segmentGap,
  }) {
    final segmentHeight = (height - (totalSegments - 1) * segmentGap) / totalSegments;

    for (int i = 0; i < totalSegments; i++) {
      final segIndexFromBottom = i;
      final threshold = (segIndexFromBottom + 1) / totalSegments;
      final isLit = level >= (threshold - (1.0 / totalSegments) * 0.5);

      final yIndexFromTop = totalSegments - 1 - i;
      final yTop = yIndexFromTop * (segmentHeight + segmentGap);
      final segRect = Rect.fromLTWH(xPos, yTop, width, segmentHeight);

      Color litColor;
      Color unlitColor;

      if (threshold > 0.88) {
        litColor = const Color(0xFFFF1744); // Red Peak
        unlitColor = const Color(0xFF2B080E);
      } else if (threshold > 0.70) {
        litColor = const Color(0xFFFFC107); // Amber Caution
        unlitColor = const Color(0xFF281C08);
      } else {
        litColor = const Color(0xFF00E676); // Neon Green
        unlitColor = const Color(0xFF082212);
      }

      if (isLit) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(segRect, const Radius.circular(0.8)),
          Paint()..color = litColor,
        );

        if (level > 0.85 && threshold > 0.80) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(segRect, const Radius.circular(0.8)),
            Paint()
              ..color = litColor.withOpacity(0.6)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
          );
        }
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(segRect, const Radius.circular(0.8)),
          Paint()..color = unlitColor,
        );
      }
    }

    // Top Peak Clip LED Indicator
    if (level >= 0.95) {
      final clipRect = Rect.fromLTWH(xPos, 0, width, 3.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(clipRect, const Radius.circular(0.8)),
        Paint()..color = const Color(0xFFFF0055),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlassMeterPainter oldDelegate) {
    return oldDelegate.leftLevel != leftLevel || oldDelegate.rightLevel != rightLevel;
  }
}

class _MeterGlassReflectionPainter extends CustomPainter {
  const _MeterGlassReflectionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final glarePath = Path();
    glarePath.moveTo(0, 0);
    glarePath.lineTo(size.width, 0);
    glarePath.lineTo(size.width, size.height * 0.5);
    glarePath.close();

    final glarePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.14),
          Colors.white.withOpacity(0.0),
        ],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.5));

    canvas.drawPath(glarePath, glarePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
