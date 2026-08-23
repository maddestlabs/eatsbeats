import 'package:flutter/material.dart';
import '../../lua/lua_gui_model.dart';
import '../../theme/eats_theme.dart';

/// A versatile skeuomorphic rack panel container supporting brushed silver/TB-303,
/// grungy weathered metal, and sleek dark studio faceplates with mounting screws,
/// bevel shadows, and industrial hardware styling.
class GrungyRackPanel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? panelColor;
  final Color? accentColor;
  final PanelBackgroundStyle backgroundStyle;
  final List<Widget>? headerActions;

  const GrungyRackPanel({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.padding = const EdgeInsets.all(12.0),
    this.panelColor,
    this.accentColor,
    this.backgroundStyle = PanelBackgroundStyle.dark,
    this.headerActions,
  });

  @override
  Widget build(BuildContext context) {
    final isGrungy = backgroundStyle == PanelBackgroundStyle.grunge ||
        (backgroundStyle == PanelBackgroundStyle.dark && EatsTheme.currentPreset == EatsThemePreset.ateTrack);
    final isSilver = backgroundStyle == PanelBackgroundStyle.silver;
    final isSnes = backgroundStyle == PanelBackgroundStyle.snes;

    final baseAccent = accentColor ?? (isSnes ? const Color(0xFF7B52AB) : (isSilver ? const Color(0xFF00FF9D) : (isGrungy ? const Color(0xFFFF8C00) : EatsTheme.primaryCyan)));

    Color basePanel;
    if (panelColor != null) {
      basePanel = panelColor!;
    } else if (isSnes) {
      basePanel = const Color(0xFFD8D6CD);
    } else if (isSilver) {
      basePanel = const Color(0xFFD4D0C5);
    } else if (isGrungy) {
      basePanel = const Color(0xFF26221D);
    } else {
      basePanel = EatsTheme.panelBackground;
    }

    final headerBg = isSnes
        ? const Color(0xFFE5E2D9)
        : (isSilver
            ? const Color(0xFFE2DFD6)
            : (isGrungy ? const Color(0xFF1E1A16) : EatsTheme.panelHeader));

    final titleColor = (isSnes || isSilver)
        ? const Color(0xFF1B1A17)
        : (isGrungy ? const Color(0xFFDCD2C5) : EatsTheme.textPrimary);

    final subtitleColor = (isSnes || isSilver)
        ? const Color(0xFF4A463F)
        : (isGrungy ? const Color(0xFF8C8275) : EatsTheme.textMuted);

    final panelContent = Container(
      margin: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: basePanel,
        gradient: (isSilver || isSnes)
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isSnes
                    ? const [
                        Color(0xFFE2DFD6),
                        Color(0xFFD8D5CC),
                        Color(0xFFCCC8BD),
                        Color(0xFFDBD8CF),
                      ]
                    : const [
                        Color(0xFFE0DDD4),
                        Color(0xFFD4D0C5),
                        Color(0xFFC7C3B6),
                        Color(0xFFD8D5CC),
                      ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              )
            : null,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSnes
              ? const Color(0xFF908C82)
              : (isSilver
                  ? const Color(0xFF8C887D)
                  : (isGrungy ? const Color(0xFF423B33) : EatsTheme.panelHeader)),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity((isSilver || isSnes) ? 0.35 : 0.4),
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
              color: headerBg,
              gradient: (isSilver || isSnes)
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isSnes
                          ? const [
                              Color(0xFFECEAE2),
                              Color(0xFFDDD9D0),
                            ]
                          : const [
                              Color(0xFFECEAE3),
                              Color(0xFFDAD6CC),
                            ],
                    )
                  : null,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isSnes
                      ? const Color(0xFF827D72)
                      : (isSilver
                          ? const Color(0xFF7A756A)
                          : (isGrungy ? baseAccent.withOpacity(0.4) : Colors.white10)),
                  width: (isSilver || isSnes) ? 1.5 : 1.0,
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
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: titleColor,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle!,
                          style: EatsTheme.getPrimaryFontStyle(
                            fontSize: 9,
                            fontWeight: isSilver ? FontWeight.w600 : FontWeight.normal,
                            color: subtitleColor,
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
      painter: _RackPanelBorderPainter(
        isGrungy: isGrungy,
        isSilver: isSilver,
        accentColor: baseAccent,
      ),
      child: panelContent,
    );
  }
}

class _RackPanelBorderPainter extends CustomPainter {
  final bool isGrungy;
  final bool isSilver;
  final Color accentColor;

  _RackPanelBorderPainter({
    required this.isGrungy,
    required this.isSilver,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isGrungy && !isSilver) return;

    if (isSilver) {
      // 1. Brushed Aluminum Grain Lines
      final grainPaint = Paint()
        ..color = const Color(0xFFFFFFFF).withOpacity(0.06)
        ..strokeWidth = 1.0;
      for (double y = 6; y < size.height - 6; y += 3) {
        canvas.drawLine(Offset(6, y), Offset(size.width - 6, y + 0.5), grainPaint);
      }

      // 2. Corner Stainless Steel Hex Screws
      const screwRadius = 3.5;
      const inset = 7.0;
      final screwCenters = [
        Offset(inset, inset), // Top Left
        Offset(size.width - inset, inset), // Top Right
        Offset(inset, size.height - inset), // Bottom Left
        Offset(size.width - inset, size.height - inset), // Bottom Right
      ];

      for (final center in screwCenters) {
        canvas.drawCircle(center + const Offset(0, 1), screwRadius, Paint()..color = Colors.black45);
        const screwGradient = RadialGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFF6E6A60)],
          stops: [0.3, 1.0],
        );
        canvas.drawCircle(
          center,
          screwRadius,
          Paint()..shader = screwGradient.createShader(Rect.fromCircle(center: center, radius: screwRadius)),
        );
        final slotPaint = Paint()
          ..color = const Color(0xFF2E2B25)
          ..strokeWidth = 1.0;
        canvas.drawLine(center - const Offset(2, 0), center + const Offset(2, 0), slotPaint);
        canvas.drawLine(center - const Offset(0, 2), center + const Offset(0, 2), slotPaint);
      }
      return;
    }

    // 1. Native Brushed Metal Grain Hatching (Grunge Theme)
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
      canvas.drawCircle(center + const Offset(0, 1), screwRadius, Paint()..color = Colors.black87);
      const screwGradient = RadialGradient(
        colors: [Color(0xFF8A8275), Color(0xFF26221F)],
        stops: [0.5, 1.0],
      );
      canvas.drawCircle(
        center,
        screwRadius,
        Paint()..shader = screwGradient.createShader(Rect.fromCircle(center: center, radius: screwRadius)),
      );
      final slotPaint = Paint()
        ..color = const Color(0xFF141210)
        ..strokeWidth = 1.0;
      canvas.drawLine(center - const Offset(2, 0), center + const Offset(2, 0), slotPaint);
      canvas.drawLine(center - const Offset(0, 2), center + const Offset(0, 2), slotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RackPanelBorderPainter oldDelegate) {
    return oldDelegate.isGrungy != isGrungy ||
        oldDelegate.isSilver != isSilver ||
        oldDelegate.accentColor != accentColor;
  }
}
