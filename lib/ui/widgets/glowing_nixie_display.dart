import 'package:flutter/material.dart';
import '../../theme/eats_theme.dart';

/// A vintage dark glass readout display with glowing amber Nixie/LED text digits,
/// optical bloom, and recessed bevel frame.
class GlowingNixieDisplay extends StatelessWidget {
  final String label;
  final String valueText;
  final String? unit;
  final Color? glowColor;
  final double fontSize;

  const GlowingNixieDisplay({
    super.key,
    required this.label,
    required this.valueText,
    this.unit,
    this.glowColor,
    this.fontSize = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;
    final amberGlow = glowColor ?? (isGrungy ? const Color(0xFFFF8C00) : EatsTheme.primaryCyan);

    final hasLabel = label.trim().isNotEmpty;
    final displayBox = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0B0A), // Deep glass well
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isGrungy ? const Color(0xFF3B342C) : Colors.white12,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.8),
            blurRadius: 3,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Optical Bloom Glow Backdrop
          Text(
            valueText + (unit != null ? ' $unit' : ''),
            style: EatsTheme.getDisplayFontStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: amberGlow,
            ).copyWith(
              shadows: [
                Shadow(
                  color: amberGlow,
                  blurRadius: 8.0,
                ),
                Shadow(
                  color: amberGlow.withOpacity(0.6),
                  blurRadius: 16.0,
                ),
              ],
            ),
          ),
          // Crisp Sharp Text Foreground
          Text(
            valueText + (unit != null ? ' $unit' : ''),
            style: EatsTheme.getDisplayFontStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: isGrungy ? const Color(0xFFFFF2D6) : Colors.white,
            ),
          ),
        ],
      ),
    );

    final content = CustomPaint(
      foregroundPainter: _LcdGlassReflectionPainter(),
      child: displayBox,
    );

    if (!hasLabel) {
      return content;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: EatsTheme.getDisplayFontStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isGrungy ? const Color(0xFF9E9284) : EatsTheme.textMuted,
          ),
        ),
        const SizedBox(height: 3),
        content,
      ],
    );
  }
}

class _LcdGlassReflectionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Curved Glass Specular Glare Streak Reflection
    final glarePath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.75, 0)
      ..lineTo(0, size.height * 0.85)
      ..close();
    canvas.drawPath(
      glarePath,
      Paint()..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white.withOpacity(0.18), Colors.transparent],
      ).createShader(Offset.zero & size),
    );

    // 2. CRT Micro-Scanlines
    final scanlinePaint = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..strokeWidth = 1.0;
    for (double y = 1; y < size.height; y += 2.5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanlinePaint);
    }

    // 3. Dark Recessed Glass Inner Bezel Border Shadow
    final bezelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.black.withOpacity(0.65);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(4)), bezelPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
