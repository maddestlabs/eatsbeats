import 'package:flutter/material.dart';
import 'modular_theme.dart';

enum JackType {
  input,
  output,
}

enum JackSignalType {
  audio,
  pitchCv,
  gate,
  modulation,
  digital,
}

/// A 3.5mm Modular Mini-Jack socket with metallic hex nut, signal LED, and label.
/// Supports interactive patch cable dragging, tap-to-connect/disconnect, and fixed slot centering.
class ModularJackWidget extends StatelessWidget {
  final String label;
  final String? jackId;
  final JackType type;
  final JackSignalType signalType;
  final bool isConnected;
  final bool isHovered;
  final double signalActivity; // 0.0 to 1.0 for LED brightness
  final VoidCallback? onTap;
  final Function(DragStartDetails details)? onDragStart;
  final Function(DragUpdateDetails details)? onDragUpdate;
  final Function(DragEndDetails details)? onDragEnd;

  const ModularJackWidget({
    super.key,
    required this.label,
    this.jackId,
    this.type = JackType.input,
    this.signalType = JackSignalType.audio,
    this.isConnected = false,
    this.isHovered = false,
    this.signalActivity = 0.0,
    this.onTap,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  Color get signalColor {
    switch (signalType) {
      case JackSignalType.audio:
        return ModularTheme.cableAudio;
      case JackSignalType.pitchCv:
        return ModularTheme.cablePitchCv;
      case JackSignalType.gate:
        return ModularTheme.cableGate;
      case JackSignalType.modulation:
        return ModularTheme.cableModulation;
      case JackSignalType.digital:
        return ModularTheme.cableDigital;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onPanStart: onDragStart,
      onPanUpdate: onDragUpdate,
      onPanEnd: onDragEnd,
      child: Container(
        width: 48,
        height: 38,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 3.5mm Metallic Socket with Hex Nut (22x22px)
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isHovered
                      ? [const Color(0xFFFFFFFF), signalColor]
                      : [const Color(0xFFB0B5BF), const Color(0xFF5A5E66)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 3,
                    offset: const Offset(0, 1.5),
                  ),
                  if (isConnected || isHovered || signalActivity > 0.1)
                    BoxShadow(
                      color: signalColor.withOpacity(isHovered ? 0.95 : (0.5 * (signalActivity > 0 ? signalActivity : 0.8))),
                      blurRadius: isHovered ? 12 : 6,
                    ),
                ],
              ),
              child: Center(
                // Inner Jack Bezel Ring
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: type == JackType.output
                        ? signalColor.withOpacity(0.25)
                        : ModularTheme.faceplateDarkBg,
                    border: Border.all(
                      color: (isConnected || isHovered) ? signalColor : ModularTheme.jackBezelMetal,
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    // Center Hole (6x6px)
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: ModularTheme.jackHoleColor,
                      ),
                      child: isConnected
                          ? Center(
                              child: Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: signalColor,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Jack Text Label
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 7.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
                color: (isConnected || isHovered) ? signalColor : const Color(0xFF888888),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
