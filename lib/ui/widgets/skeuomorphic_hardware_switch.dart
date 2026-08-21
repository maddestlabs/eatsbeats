import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/eats_theme.dart';

/// A realistic skeuomorphic metallic hardware toggle switch control.
/// Features a recessed faceplate slot, threaded hex mounting collar,
/// 3D tapered chrome bat handle with specular lighting and dynamic cast shadow,
/// tactile spring-snap physics animation, and a glowing jewel status LED.
class SkeuomorphicHardwareSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final Color? ledColor;
  final String? label;
  final double width;
  final double height;
  final bool showLed;
  final String? tooltip;

  const SkeuomorphicHardwareSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.ledColor,
    this.label,
    this.width = 46.0,
    this.height = 26.0,
    this.showLed = true,
    this.tooltip,
  });

  @override
  State<SkeuomorphicHardwareSwitch> createState() => _SkeuomorphicHardwareSwitchState();
}

class _SkeuomorphicHardwareSwitchState extends State<SkeuomorphicHardwareSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      value: widget.value ? 1.0 : 0.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    );
  }

  @override
  void didUpdateWidget(covariant SkeuomorphicHardwareSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (widget.onChanged == null) return;
    final nextVal = !widget.value;
    widget.onChanged!(nextVal);
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onChanged != null;
    final isGrungy = EatsTheme.currentPreset == EatsThemePreset.ateTrack;
    final activeCol = widget.activeColor ??
        (isGrungy ? const Color(0xFFFF8C00) : EatsTheme.primaryCyan);
    final ledCol = widget.ledColor ?? activeCol;

    final content = AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _HardwareSwitchPainter(
            animationValue: _animation.value,
            isEnabled: isEnabled,
            activeColor: activeCol,
            ledColor: ledCol,
            showLed: widget.showLed,
            isGrungy: isGrungy,
            isLight: EatsTheme.isLight,
          ),
        );
      },
    );

    Widget interactive = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isEnabled ? _toggle : null,
      onHorizontalDragEnd: (details) {
        if (!isEnabled) return;
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 50 && !widget.value) {
            widget.onChanged!(true);
          } else if (details.primaryVelocity! < -50 && widget.value) {
            widget.onChanged!(false);
          }
        }
      },
      child: MouseRegion(
        cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Center(child: content),
        ),
      ),
    );

    if (widget.tooltip != null) {
      interactive = Tooltip(
        message: widget.tooltip!,
        child: interactive,
      );
    }

    if (widget.label != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isEnabled ? _toggle : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            interactive,
            const SizedBox(width: 8),
            Text(
              widget.label!,
              style: EatsTheme.getPrimaryFontStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isEnabled
                    ? (widget.value ? EatsTheme.textPrimary : EatsTheme.textSecondary)
                    : EatsTheme.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return interactive;
  }
}

class _HardwareSwitchPainter extends CustomPainter {
  final double animationValue; // 0.0 (OFF) -> 1.0 (ON)
  final bool isEnabled;
  final Color activeColor;
  final Color ledColor;
  final bool showLed;
  final bool isGrungy;
  final bool isLight;

  _HardwareSwitchPainter({
    required this.animationValue,
    required this.isEnabled,
    required this.activeColor,
    required this.ledColor,
    required this.showLed,
    required this.isGrungy,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(h / 2));

    // ----------------------------------------------------
    // 1. Recessed Bezel Outer Well (Chassis Inset Plate)
    // ----------------------------------------------------
    // Drop shadow beneath the recessed well
    final dropShadowPaint = Paint()
      ..color = Colors.black.withOpacity(isLight ? 0.12 : 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.drawRRect(rrect.shift(const Offset(0, 1.2)), dropShadowPaint);

    // Well background gradient (recessed depth)
    final wellGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isGrungy
          ? [
              const Color(0xFF141210),
              const Color(0xFF1E1B18),
              const Color(0xFF282420),
            ]
          : (isLight
              ? [
                  const Color(0xFFB0B9C6),
                  const Color(0xFFCBD5E1),
                  const Color(0xFFE2E8F0),
                ]
              : [
                  const Color(0xFF0F1116),
                  const Color(0xFF161922),
                  const Color(0xFF1F2430),
                ]),
      stops: const [0.0, 0.5, 1.0],
    );

    final wellPaint = Paint()..shader = wellGradient.createShader(rect);
    canvas.drawRRect(rrect, wellPaint);

    // Well inner top shadow (etched rim)
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = isGrungy
          ? const Color(0xFF38322B)
          : (isLight ? const Color(0xFF94A3B8) : const Color(0xFF2B3245));
    canvas.drawRRect(rrect, rimPaint);

    // Highlight reflection on bottom rim of well
    final bottomHighlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withOpacity(isGrungy ? 0.08 : (isLight ? 0.5 : 0.15));
    final highlightPath = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(h / 2, h / 2), radius: h / 2),
        math.pi * 0.5,
        math.pi * 0.5,
      )
      ..lineTo(w - h / 2, h)
      ..addArc(
        Rect.fromCircle(center: Offset(w - h / 2, h / 2), radius: h / 2),
        0,
        math.pi * 0.5,
      );
    canvas.drawPath(highlightPath, bottomHighlightPaint);

    // ----------------------------------------------------
    // 2. Status Jewel LED Indicator
    // ----------------------------------------------------
    final ledRadius = h * 0.16;
    final ledCenter = Offset(w - h * 0.44, h * 0.5);

    if (showLed) {
      // Inset dark LED Bezel
      final ledBezelPaint = Paint()
        ..color = isGrungy ? const Color(0xFF1B1815) : const Color(0xFF0D0F14);
      canvas.drawCircle(ledCenter, ledRadius + 1.2, ledBezelPaint);

      final ledBezelRimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = isGrungy
            ? const Color(0xFF4A4238)
            : (isLight ? const Color(0xFF64748B) : const Color(0xFF333B4D));
      canvas.drawCircle(ledCenter, ledRadius + 1.2, ledBezelRimPaint);

      if (animationValue > 0.05 && isEnabled) {
        final glowOpacity = (animationValue * 0.75).clamp(0.0, 0.75);
        // Outer Glow Bloom
        final glowPaint = Paint()
          ..color = ledColor.withOpacity(glowOpacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
        canvas.drawCircle(ledCenter, ledRadius * 1.8, glowPaint);

        // Core Glowing Lamp
        final lampGradient = RadialGradient(
          center: const Alignment(-0.25, -0.25),
          radius: 0.85,
          colors: [
            Colors.white,
            ledColor,
            Color.lerp(ledColor, Colors.black, 0.4)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
        final lampPaint = Paint()
          ..shader = lampGradient.createShader(
            Rect.fromCircle(center: ledCenter, radius: ledRadius),
          );
        canvas.drawCircle(ledCenter, ledRadius, lampPaint);

        // Specular Hotspot
        final spotPaint = Paint()..color = Colors.white.withOpacity(0.9);
        canvas.drawCircle(ledCenter + const Offset(-0.8, -0.8), ledRadius * 0.35, spotPaint);
      } else {
        // Unlit Dark Lamp Glass
        final unlitGradient = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          radius: 0.9,
          colors: isGrungy
              ? [const Color(0xFF3D3428), const Color(0xFF1E1A14)]
              : [const Color(0xFF282E3D), const Color(0xFF10131A)],
        );
        final unlitPaint = Paint()
          ..shader = unlitGradient.createShader(
            Rect.fromCircle(center: ledCenter, radius: ledRadius),
          );
        canvas.drawCircle(ledCenter, ledRadius, unlitPaint);
      }
    }

    // ----------------------------------------------------
    // 3. Central Mounting Collar / Threaded Hex Nut Bushing
    // ----------------------------------------------------
    // Switch pivot fulcrum travels slightly or sits securely at center-left
    final fulcrumX = showLed ? (h * 0.56) : (w * 0.5);
    final fulcrumY = h * 0.5;
    final fulcrum = Offset(fulcrumX, fulcrumY);
    final collarRadius = h * 0.31;

    // Collar cast shadow
    final collarShadow = Paint()
      ..color = Colors.black.withOpacity(0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawCircle(fulcrum + const Offset(0, 1.5), collarRadius, collarShadow);

    // Collar Metallic Radial/Linear Gradient
    final collarGradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 0.9,
      colors: isGrungy
          ? [
              const Color(0xFF6B5F4F),
              const Color(0xFF4A4135),
              const Color(0xFF29241D),
            ]
          : [
              const Color(0xFF5A667A),
              const Color(0xFF384050),
              const Color(0xFF1D222C),
            ],
    );
    final collarPaint = Paint()
      ..shader = collarGradient.createShader(
        Rect.fromCircle(center: fulcrum, radius: collarRadius),
      );
    canvas.drawCircle(fulcrum, collarRadius, collarPaint);

    // Collar outer bevel edge
    final collarRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withOpacity(isGrungy ? 0.25 : 0.35);
    canvas.drawCircle(fulcrum, collarRadius, collarRimPaint);

    // Inner Dark Slot Bore
    final boreRadius = collarRadius * 0.65;
    final borePaint = Paint()
      ..color = isGrungy ? const Color(0xFF12100E) : const Color(0xFF0B0C10);
    canvas.drawCircle(fulcrum, boreRadius, borePaint);

    // ----------------------------------------------------
    // 4. 3D Chrome Bat-Handle Lever & Dynamic Cast Shadow
    // ----------------------------------------------------
    // Toggle angle: OFF tilts left (-26° = -0.46 rad), ON tilts right (+26° = +0.46 rad)
    const maxAngle = 0.46; // ~26.4 degrees
    final currentAngle = -maxAngle + (animationValue.clamp(-0.2, 1.2) * 2 * maxAngle);
    final handleLength = h * 0.52;

    // Lever tip point
    final tip = fulcrum + Offset(math.sin(currentAngle) * handleLength, -math.cos(currentAngle) * (handleLength * 0.35));

    // Dynamic Cast Shadow of the Bat Handle onto the well
    final shadowTip = fulcrum + Offset(
      math.sin(currentAngle) * (handleLength * 1.15) + (currentAngle > 0 ? 2.5 : -2.5),
      (handleLength * 0.45) + 1.5,
    );
    final shadowPath = Path()
      ..moveTo(fulcrum.dx - 2.5, fulcrum.dy + 1)
      ..lineTo(shadowTip.dx - 3, shadowTip.dy)
      ..arcToPoint(
        Offset(shadowTip.dx + 3, shadowTip.dy),
        radius: const Radius.circular(3),
      )
      ..lineTo(fulcrum.dx + 2.5, fulcrum.dy + 1)
      ..close();

    final batShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.50)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawPath(shadowPath, batShadowPaint);

    // 3D Tapered Bat Cylinder Shaft
    final baseWidth = collarRadius * 0.70;
    final tipRadius = h * 0.16;

    // Normal vector perpendicular to handle direction
    final dx = tip.dx - fulcrum.dx;
    final dy = tip.dy - fulcrum.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    final nx = len > 0 ? (-dy / len) : 0.0;
    final ny = len > 0 ? (dx / len) : 1.0;

    final pBaseLeft = fulcrum + Offset(nx * baseWidth * 0.5, ny * baseWidth * 0.5);
    final pBaseRight = fulcrum - Offset(nx * baseWidth * 0.5, ny * baseWidth * 0.5);
    final pTipLeft = tip + Offset(nx * tipRadius, ny * tipRadius);
    final pTipRight = tip - Offset(nx * tipRadius, ny * tipRadius);

    final shaftPath = Path()
      ..moveTo(pBaseLeft.dx, pBaseLeft.dy)
      ..lineTo(pTipLeft.dx, pTipLeft.dy)
      ..lineTo(pTipRight.dx, pTipRight.dy)
      ..lineTo(pBaseRight.dx, pBaseRight.dy)
      ..close();

    // Metallic Specular Cylinder Gradient
    final cylinderGradient = LinearGradient(
      begin: Alignment(-ny, nx),
      end: Alignment(ny, -nx),
      colors: isGrungy
          ? [
              const Color(0xFF2C261F),
              const Color(0xFF6B5F4F),
              const Color(0xFFD4C29D), // Warm specular highlight streak
              const Color(0xFF8A7A64),
              const Color(0xFF383127),
            ]
          : [
              const Color(0xFF1E2430),
              const Color(0xFF4B5568),
              const Color(0xFFF1F5F9), // Crisp chrome highlight streak
              const Color(0xFF8C9BAE),
              const Color(0xFF242C3C),
            ],
      stops: const [0.0, 0.25, 0.50, 0.78, 1.0],
    );

    final shaftPaint = Paint()
      ..shader = cylinderGradient.createShader(
        Rect.fromPoints(pBaseLeft, pTipRight),
      );
    canvas.drawPath(shaftPath, shaftPaint);

    // Decorative Knurled Grip Rings on the Shaft
    final mid1 = Offset.lerp(fulcrum, tip, 0.45)!;
    final mid2 = Offset.lerp(fulcrum, tip, 0.65)!;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.black.withOpacity(0.35);
    canvas.drawLine(
      mid1 + Offset(nx * tipRadius * 1.1, ny * tipRadius * 1.1),
      mid1 - Offset(nx * tipRadius * 1.1, ny * tipRadius * 1.1),
      ringPaint,
    );
    canvas.drawLine(
      mid2 + Offset(nx * tipRadius * 1.05, ny * tipRadius * 1.05),
      mid2 - Offset(nx * tipRadius * 1.05, ny * tipRadius * 1.05),
      ringPaint,
    );

    // Spherical Dome Tip Cap
    final tipDomeGradient = RadialGradient(
      center: const Alignment(-0.35, -0.4),
      radius: 0.85,
      colors: isGrungy
          ? [
              const Color(0xFFFFF2D6),
              const Color(0xFFC7B28B),
              const Color(0xFF635541),
              const Color(0xFF2D261C),
            ]
          : [
              Colors.white,
              const Color(0xFFDDE4ED),
              const Color(0xFF69788D),
              const Color(0xFF1E2532),
            ],
      stops: const [0.0, 0.35, 0.75, 1.0],
    );

    final tipPaint = Paint()
      ..shader = tipDomeGradient.createShader(
        Rect.fromCircle(center: tip, radius: tipRadius),
      );
    canvas.drawCircle(tip, tipRadius, tipPaint);

    // Specular Glare Dot on Tip
    final glarePaint = Paint()..color = Colors.white.withOpacity(0.9);
    canvas.drawCircle(tip + const Offset(-1.2, -1.2), tipRadius * 0.32, glarePaint);
  }

  @override
  bool shouldRepaint(covariant _HardwareSwitchPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isEnabled != isEnabled ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.ledColor != ledColor ||
        oldDelegate.showLed != showLed ||
        oldDelegate.isGrungy != isGrungy ||
        oldDelegate.isLight != isLight;
  }
}
