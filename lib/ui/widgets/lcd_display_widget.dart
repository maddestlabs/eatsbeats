import 'package:flutter/material.dart';
import '../../theme/eats_theme.dart';

/// A realistic backlit LCD matrix display screen showing track index, pan, and volume level status.
class LcdDisplayWidget extends StatelessWidget {
  final String title;        // Track number/name (e.g. "1" or "KICK")
  final String leftText;     // Left status (e.g. "center" or "L32")
  final String rightText;    // Right status (e.g. "0dB" or "85%")
  final double width;
  final double height;

  const LcdDisplayWidget({
    super.key,
    required this.title,
    this.leftText = 'center',
    this.rightText = '0dB',
    this.width = 110.0,
    this.height = 38.0,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = EatsTheme.lcdBackground;
    final borderColor = EatsTheme.lcdBorder;
    final textColor = EatsTheme.lcdTextColor;
    final dotColor = EatsTheme.lcdDotColor;
    final glowColor = EatsTheme.lcdGlowColor;

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0xB3000000), offset: Offset(0, 1), blurRadius: 3),
        ],
      ),
      child: Stack(
        children: [
          // Subtle Dot Matrix Pattern Paint
          Positioned.fill(
            child: CustomPaint(
              painter: _LcdGridPainter(dotColor: dotColor),
            ),
          ),

          // LCD Display Text Content
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Centered Track Index / Title
              Center(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.0,
                    shadows: [
                      Shadow(color: glowColor, offset: const Offset(0, 0), blurRadius: 2.0),
                    ],
                  ),
                ),
              ),

              // Bottom Row: Left status (Pan) | Right status (Vol/Level)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      leftText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: textColor.withOpacity(0.85),
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  Text(
                    rightText,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: textColor.withOpacity(0.85),
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Glossy Glass Glare Overlay
          const Positioned.fill(
            child: CustomPaint(
              painter: _LcdGlassReflectionPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LcdGridPainter extends CustomPainter {
  final Color dotColor;

  const _LcdGridPainter({required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = dotColor;
    const spacing = 3.0;

    for (double y = 1; y < size.height; y += spacing) {
      for (double x = 1; x < size.width; x += spacing) {
        canvas.drawRect(Rect.fromLTWH(x, y, 1.2, 1.2), dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LcdGridPainter oldDelegate) => oldDelegate.dotColor != dotColor;
}

class _LcdGlassReflectionPainter extends CustomPainter {
  const _LcdGlassReflectionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final glarePath = Path();
    glarePath.moveTo(0, 0);
    glarePath.lineTo(size.width, 0);
    glarePath.lineTo(size.width, size.height * 0.4);
    glarePath.close();

    final glarePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.12),
          Colors.white.withOpacity(0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.4));

    canvas.drawPath(glarePath, glarePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
