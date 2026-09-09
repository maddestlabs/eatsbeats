import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/eats_theme.dart';

/// Roland TB-303 authentic Step Sequencer Keycap.
/// Features dual-tone beveled keycaps (white/cream natural notes or dark charcoal sharps),
/// a molded top chamfer, embedded illuminated LED dot indicator, and tactile press animation.
class EatStepKeyButton extends StatefulWidget {
  final String? label;
  final String? subLabel;
  final bool isAccidental; // Black key (true) vs white/cream key (false)
  final bool isActive;
  final Color? activeLedColor;
  final VoidCallback onTap;
  final double width;
  final double height;
  final bool showLed;

  const EatStepKeyButton({
    super.key,
    this.label,
    this.subLabel,
    this.isAccidental = false,
    this.isActive = false,
    this.activeLedColor,
    required this.onTap,
    this.width = 36.0,
    this.height = 56.0,
    this.showLed = true,
  });

  @override
  State<EatStepKeyButton> createState() => _EatStepKeyButtonState();
}

class _EatStepKeyButtonState extends State<EatStepKeyButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final ledColor = widget.activeLedColor ?? const Color(0xFFFF2233); // Authentic 303 red LED

    // Cap base colors
    final capColor = widget.isAccidental
        ? (_isPressed ? const Color(0xFF16171B) : const Color(0xFF24262C))
        : (_isPressed ? const Color(0xFFD6D4CD) : const Color(0xFFEBE8DF));

    final textColor = widget.isAccidental ? const Color(0xFFC0C4CC) : const Color(0xFF2B2D33);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: widget.width,
        height: widget.height,
        transform: Matrix4.translationValues(0, _isPressed ? 1.8 : 0.0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3.5),
          color: capColor,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.isAccidental
                ? [
                    const Color(0xFF343842),
                    const Color(0xFF22242A),
                    const Color(0xFF141518),
                  ]
                : [
                    const Color(0xFFFFFFFF),
                    const Color(0xFFECE9E1),
                    const Color(0xFFD0CDC4),
                  ],
            stops: const [0.0, 0.45, 1.0],
          ),
          border: Border.all(
            color: widget.isAccidental ? const Color(0xFF121316) : const Color(0xFF9A968D),
            width: 1.0,
          ),
          boxShadow: _isPressed
              ? [
                  const BoxShadow(
                    color: Color(0x66000000),
                    offset: Offset(0, 1),
                    blurRadius: 1.5,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.40),
                    offset: const Offset(0, 2.5),
                    blurRadius: 3.5,
                  ),
                  const BoxShadow(
                    color: Color(0x33FFFFFF),
                    offset: Offset(0, -0.8),
                    blurRadius: 0.5,
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top Section: Illuminated LED indicator dot
            Padding(
              padding: const EdgeInsets.only(top: 5.0),
              child: widget.showLed
                  ? Container(
                      width: 5.5,
                      height: 5.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isActive ? ledColor : const Color(0xFF3A181C),
                        border: Border.all(
                          color: const Color(0xFF18181A),
                          width: 0.8,
                        ),
                        boxShadow: widget.isActive
                            ? [
                                BoxShadow(
                                  color: ledColor,
                                  blurRadius: 6,
                                  spreadRadius: 1.5,
                                ),
                                BoxShadow(
                                  color: ledColor.withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 3.0,
                                ),
                              ]
                            : null,
                      ),
                    )
                  : const SizedBox(height: 5.5),
            ),

            // Middle & Bottom Section: Text Labels
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.subLabel != null)
                    Text(
                      widget.subLabel!,
                      style: TextStyle(
                        fontSize: 7.0,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        color: textColor.withOpacity(0.70),
                      ),
                    ),
                  if (widget.label != null)
                    Text(
                      widget.label!,
                      style: TextStyle(
                        fontSize: 9.0,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                        color: textColor,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Roland TB-303 Round Tactile Stud Pushbutton (Bar / Function Buttons).
/// Features a circular metal collar bezel, recessed concentric gutter, and a domed actuator cap.
class EatTactileStudButton extends StatefulWidget {
  final String? label;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback onTap;
  final double size;

  const EatTactileStudButton({
    super.key,
    this.label,
    this.isActive = false,
    this.activeColor,
    required this.onTap,
    this.size = 28.0,
  });

  @override
  State<EatTactileStudButton> createState() => _EatTactileStudButtonState();
}

class _EatTactileStudButtonState extends State<EatTactileStudButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.activeColor ?? const Color(0xFFFF2233);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            width: widget.size,
            height: widget.size,
            transform: Matrix4.translationValues(0, _isPressed ? 1.5 : 0.0, 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Metal Collar Bezel
              gradient: const RadialGradient(
                center: Alignment(-0.25, -0.30),
                radius: 0.95,
                colors: [
                  Color(0xFFE2E4E8),
                  Color(0xFF9EA3AD),
                  Color(0xFF5A5D66),
                ],
                stops: [0.0, 0.60, 1.0],
              ),
              boxShadow: _isPressed
                  ? [
                      const BoxShadow(
                        color: Color(0x66000000),
                        offset: Offset(0, 1),
                        blurRadius: 1.5,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.45),
                        offset: const Offset(0, 2.5),
                        blurRadius: 3.5,
                      ),
                    ],
            ),
            child: Center(
              // Inner Domed Tactile Actuator Cap
              child: Container(
                width: widget.size * 0.72,
                height: widget.size * 0.72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.30, -0.35),
                    radius: 0.85,
                    colors: widget.isActive
                        ? [
                            Color.lerp(active, Colors.white, 0.5)!,
                            active,
                            Color.lerp(active, Colors.black, 0.4)!,
                          ]
                        : [
                            const Color(0xFF42454E),
                            const Color(0xFF282A30),
                            const Color(0xFF141518),
                          ],
                    stops: const [0.0, 0.50, 1.0],
                  ),
                  border: Border.all(
                    color: const Color(0xFF121316),
                    width: 0.8,
                  ),
                  boxShadow: widget.isActive
                      ? [
                          BoxShadow(
                            color: active.withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
          if (widget.label != null) ...[
            const SizedBox(height: 3),
            Text(
              widget.label!,
              style: const TextStyle(
                fontSize: 8.0,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                color: Color(0xFF282A30),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
