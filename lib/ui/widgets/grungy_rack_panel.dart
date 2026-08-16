import 'package:flutter/material.dart';
import '../../theme/eats_theme.dart';

/// A grungy, weathered metallic rack panel container with corner mounting screws,
/// bevel shadows, and industrial faceplate styling.
class GrungyRackPanel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? panelColor;
  final Color? accentColor;
  final List<Widget>? headerActions;

  const GrungyRackPanel({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.padding = const EdgeInsets.all(12.0),
    this.panelColor,
    this.accentColor,
    this.headerActions,
  });

  @override
  Widget build(BuildContext context) {
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;
    final baseAccent = accentColor ?? EatsTheme.primaryCyan;
    final basePanel = panelColor ?? (isGrungy ? const Color(0xFF26221D) : EatsTheme.panelBackground);

    final panelContent = Container(
      margin: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: basePanel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isGrungy ? const Color(0xFF423B33) : EatsTheme.panelHeader,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            // Faceplate Header Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isGrungy ? const Color(0xFF1E1A16) : EatsTheme.panelHeader,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(5),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: isGrungy ? baseAccent.withOpacity(0.4) : Colors.white10,
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Stamped LED indicator dot
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: baseAccent,
                      boxShadow: [
                        BoxShadow(
                          color: baseAccent,
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.toUpperCase(),
                          style: EatsTheme.getDisplayFontStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isGrungy ? const Color(0xFFDCD2C5) : EatsTheme.textPrimary,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            subtitle!,
                            style: EatsTheme.getPrimaryFontStyle(
                              fontSize: 9,
                              color: isGrungy ? const Color(0xFF8C8275) : EatsTheme.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (headerActions != null) ...headerActions!,
                ],
              ),
            ),
            // Main Module Body Content
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      );

    return CustomPaint(
      painter: _RackPanelBorderPainter(isGrungy: isGrungy, accentColor: baseAccent),
      child: panelContent,
    );
  }
}

class _RackPanelBorderPainter extends CustomPainter {
  final bool isGrungy;
  final Color accentColor;

  _RackPanelBorderPainter({required this.isGrungy, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isGrungy) return;

    // 1. Native Brushed Metal Grain Hatching
    final grainPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withOpacity(0.035)
      ..strokeWidth = 1.0;
    for (double y = 6; y < size.height - 6; y += 4) {
      canvas.drawLine(Offset(6, y), Offset(size.width - 6, y + 0.8), grainPaint);
    }

    // 2. Chassis Corner & Perimeter Vignette
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: [Colors.transparent, Colors.black.withOpacity(0.30)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6)), vignettePaint);

    // 3. Draw Corner Mounting Bolts/Screws
    const screwRadius = 3.5;
    const inset = 7.0;

    final screwCenters = [
      Offset(inset, inset), // Top Left
      Offset(size.width - inset, inset), // Top Right
      Offset(inset, size.height - inset), // Bottom Left
      Offset(size.width - inset, size.height - inset), // Bottom Right
    ];

    for (final center in screwCenters) {
      // Screw Drop Shadow
      canvas.drawCircle(center + const Offset(0, 1), screwRadius, Paint()..color = Colors.black87);

      // Metallic Screw Head Gradient
      const screwGradient = RadialGradient(
        colors: [Color(0xFF8A8275), Color(0xFF26221F)],
        stops: [0.5, 1.0],
      );
      canvas.drawCircle(
        center,
        screwRadius,
        Paint()..shader = screwGradient.createShader(Rect.fromCircle(center: center, radius: screwRadius)),
      );

      // Cross Slot Cuts on Screws
      final slotPaint = Paint()
        ..color = const Color(0xFF141210)
        ..strokeWidth = 1.0;
      canvas.drawLine(center - const Offset(2, 0), center + const Offset(2, 0), slotPaint);
      canvas.drawLine(center - const Offset(0, 2), center + const Offset(0, 2), slotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RackPanelBorderPainter oldDelegate) {
    return oldDelegate.isGrungy != isGrungy || oldDelegate.accentColor != accentColor;
  }
}
