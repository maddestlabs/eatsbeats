import 'package:flutter/material.dart';
import '../../theme/eats_theme.dart';

/// A realistic skeuomorphic mechanical push button with 3D bevels,
/// tactile pressed state animation, and glowing LED backlight.
class SkeuomorphicHardwareButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final Widget? customChild;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final double height;
  final double? width;
  final EdgeInsetsGeometry padding;
  final bool showLed;
  final BorderRadius? borderRadius;

  const SkeuomorphicHardwareButton({
    super.key,
    this.label,
    this.icon,
    this.customChild,
    this.isActive = false,
    this.activeColor,
    required this.onTap,
    this.onDoubleTap,
    this.height = 36.0,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.showLed = true,
    this.borderRadius,
  });

  @override
  State<SkeuomorphicHardwareButton> createState() => _SkeuomorphicHardwareButtonState();
}

class _SkeuomorphicHardwareButtonState extends State<SkeuomorphicHardwareButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;
    final ledColor = widget.activeColor ?? (isGrungy ? const Color(0xFFFF8C00) : EatsTheme.primaryCyan);
    final btnColor = widget.isActive
        ? Color.alphaBlend(
            ledColor.withOpacity(isGrungy ? 0.45 : 0.35),
            isGrungy ? const Color(0xFF38322B) : EatsTheme.panelHeader,
          )
        : (isGrungy
            ? (_isPressed ? const Color(0xFF1E1B18) : const Color(0xFF38322B))
            : (_isPressed ? EatsTheme.controlBackground : EatsTheme.panelHeader));

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onDoubleTap: widget.onDoubleTap,
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        height: widget.height,
        width: widget.width,
        padding: (widget.width != null && widget.padding == const EdgeInsets.symmetric(horizontal: 12, vertical: 6))
            ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
            : widget.padding,
        transform: Matrix4.translationValues(0, _isPressed ? 2.0 : 0.0, 0),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
          color: btnColor,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(isGrungy ? 0.15 : 0.10),
              Colors.transparent,
              Colors.black.withOpacity(0.15),
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
          border: Border.all(
            color: widget.isActive
                ? ledColor
                : (isGrungy ? const Color(0xFF594F45) : (EatsTheme.isLight ? Colors.black26 : Colors.white24)),
            width: widget.isActive ? 1.5 : 1.0,
          ),
          boxShadow: _isPressed
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(EatsTheme.isLight ? 0.15 : 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                  if (widget.isActive)
                    BoxShadow(
                      color: ledColor.withOpacity(0.6),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Illuminated LED Indicator Dot
              if (widget.showLed) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isActive ? ledColor : Colors.black45,
                    boxShadow: widget.isActive
                        ? [
                            BoxShadow(
                              color: ledColor,
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (widget.customChild != null)
                widget.customChild!
              else ...[
                () {
                  final activeContentColor = (widget.activeColor != null)
                      ? (widget.activeColor!.computeLuminance() > 0.35 ? const Color(0xFF0B0E14) : Colors.white)
                      : (isGrungy ? const Color(0xFFFFF8E7) : (EatsTheme.isLight ? const Color(0xFF0F172A) : Colors.white));
                  final inactiveContentColor = widget.activeColor != null
                      ? (EatsTheme.isLight && widget.activeColor == EatsTheme.primaryCyan ? const Color(0xFF006680) : widget.activeColor!.withOpacity(0.95))
                      : (isGrungy ? const Color(0xFFA89C8C) : EatsTheme.textSecondary);
                  final finalColor = widget.isActive ? activeContentColor : inactiveContentColor;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          size: (widget.label != null && widget.label!.isNotEmpty) ? 16 : 18,
                          color: finalColor,
                        ),
                        if (widget.label != null && widget.label!.isNotEmpty) const SizedBox(width: 6),
                      ],
                      if (widget.label != null && widget.label!.isNotEmpty)
                        Text(
                          widget.label!.toUpperCase(),
                          style: EatsTheme.getDisplayFontStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: finalColor,
                          ),
                        ),
                    ],
                  );
                }(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
