import 'package:flutter/material.dart';
import 'eurorack_theme.dart';

/// A standard Eurorack module panel with brushed aluminum texture, mounting hex screws,
/// title bar, and internal controls/jacks.
class ModularFaceplateWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int hpWidth; // Width in HP (Horizontal Pitch: 1HP = 16px)
  final Color accentColor;
  final Widget child;

  const ModularFaceplateWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.hpWidth = 10,
    this.accentColor = const Color(0xFFFF9800),
    required this.child,
  });

  double get pixelWidth => hpWidth * EurorackTheme.standardHpUnit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: pixelWidth,
      height: EurorackTheme.moduleHeight,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: EurorackTheme.faceplateDarkBg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: EurorackTheme.faceplateBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 4 Corner Eurorack Hex Mounting Screws
          const Positioned(top: 4, left: 4, child: _EurorackScrew()),
          const Positioned(top: 4, right: 4, child: _EurorackScrew()),
          const Positioned(bottom: 4, left: 4, child: _EurorackScrew()),
          const Positioned(bottom: 4, right: 4, child: _EurorackScrew()),

          // Main Module Faceplate Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Module Header
                Container(
                  padding: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: accentColor.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: accentColor,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle!.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 7.5,
                            color: Color(0xFF888888),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ],
                    ],
                  ),
                ),

                // Controls & Jacks Area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 2),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EurorackScrew extends StatelessWidget {
  const _EurorackScrew();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: EurorackTheme.railScrewColor,
        border: Border.all(color: Colors.black54, width: 0.5),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 1),
        ],
      ),
      child: Center(
        child: Container(
          width: 3,
          height: 1,
          color: Colors.black87,
        ),
      ),
    );
  }
}
