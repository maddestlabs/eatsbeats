import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/eats_theme.dart';

enum SwitchStyle {
  modernPill,
  vintageBat,
}

/// A versatile, realistic skeuomorphic hardware toggle switch control.
/// Supports two distinct visual aesthetics:
/// 1. [SwitchStyle.modernPill]: Sleek neomorphic / skeuomorphic recessed pill slider
///    with illuminated active color track, tactile 3D circular thumb, optional icons,
///    and both horizontal & vertical orientations.
/// 2. [SwitchStyle.vintageBat]: Vintage chrome bat-handle lever switch with hex collar
///    and status jewel LED (used exclusively for Eats-303).
class SkeuomorphicHardwareSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final SwitchStyle style;
  final Axis orientation;
  final Color? activeColor;
  final Color? ledColor;
  final String? label;
  final double? width;
  final double? height;
  final bool showLed;
  final bool showHighlightColor;
  final bool showText;
  final IconData? iconOn;
  final IconData? iconOff;
  final String? tooltip;

  const SkeuomorphicHardwareSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.style = SwitchStyle.modernPill,
    this.orientation = Axis.horizontal,
    this.activeColor,
    this.ledColor,
    this.label,
    this.width,
    this.height,
    this.showLed = true,
    this.showHighlightColor = true,
    this.showText = false,
    this.iconOn,
    this.iconOff,
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

    // Default dimensions depending on style and orientation
    final defaultW = widget.style == SwitchStyle.vintageBat
        ? 46.0
        : (widget.orientation == Axis.vertical ? 18.0 : 38.0);
    final defaultH = widget.style == SwitchStyle.vintageBat
        ? 26.0
        : (widget.orientation == Axis.vertical ? 30.0 : 20.0);

    final effectiveW = widget.width ?? defaultW;
    final effectiveH = widget.height ?? defaultH;

    final content = AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(effectiveW, effectiveH),
          painter: widget.style == SwitchStyle.vintageBat
              ? _VintageBatSwitchPainter(
                  animationValue: _animation.value,
                  isEnabled: isEnabled,
                  activeColor: activeCol,
                  ledColor: ledCol,
                  showLed: widget.showLed,
                  isGrungy: isGrungy,
                  isLight: EatsTheme.isLight,
                )
              : _ModernPillSwitchPainter(
                  animationValue: _animation.value,
                  isEnabled: isEnabled,
                  orientation: widget.orientation,
                  activeColor: activeCol,
                  showHighlightColor: widget.showHighlightColor,
                  showText: widget.showText,
                  iconOn: widget.iconOn,
                  iconOff: widget.iconOff,
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
        if (!isEnabled || widget.orientation == Axis.vertical) return;
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 50 && !widget.value) {
            widget.onChanged!(true);
          } else if (details.primaryVelocity! < -50 && widget.value) {
            widget.onChanged!(false);
          }
        }
      },
      onVerticalDragEnd: (details) {
        if (!isEnabled || widget.orientation == Axis.horizontal) return;
        if (details.primaryVelocity != null) {
          // In vertical mode, dragging up (negative velocity) turns ON
          if (details.primaryVelocity! < -50 && !widget.value) {
            widget.onChanged!(true);
          } else if (details.primaryVelocity! > 50 && widget.value) {
            widget.onChanged!(false);
          }
        }
      },
      child: MouseRegion(
        cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: SizedBox(
          width: effectiveW,
          height: effectiveH,
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

/// Modern Neomorphic/Skeuomorphic Circle Pill Switch Painter.
/// Features a recessed inset well with colored glow track or icon mode,
/// and a tactile 3D circular thumb.
class _ModernPillSwitchPainter extends CustomPainter {
  final double animationValue; // 0.0 (OFF) -> 1.0 (ON)
  final bool isEnabled;
  final Axis orientation;
  final Color activeColor;
  final bool showHighlightColor;
  final bool showText;
  final IconData? iconOn;
  final IconData? iconOff;
  final bool isGrungy;
  final bool isLight;

  _ModernPillSwitchPainter({
    required this.animationValue,
    required this.isEnabled,
    required this.orientation,
    required this.activeColor,
    required this.showHighlightColor,
    required this.showText,
    this.iconOn,
    this.iconOff,
    required this.isGrungy,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);
    final isVert = orientation == Axis.vertical;
    final trackRadius = isVert ? (w / 2) : (h / 2);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(trackRadius));

    // 1. Inset Well Outer Drop Shadow
    final dropShadowPaint = Paint()
      ..color = Colors.black.withOpacity(isLight ? 0.15 : 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawRRect(rrect.shift(const Offset(0, 1.0)), dropShadowPaint);

    // 2. Inset Track Background
    if (showHighlightColor && animationValue > 0.01) {
      // Interpolate between dark well and vibrant active color
      final offTrackColor = isLight
          ? const Color(0xFFCAD4E0)
          : (isGrungy ? const Color(0xFF1E1B18) : const Color(0xFF14171F));
      final trackColor = Color.lerp(offTrackColor, activeColor, animationValue)!;

      final trackGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          trackColor.withOpacity(0.85),
          trackColor,
          Color.lerp(trackColor, Colors.black, 0.25)!,
        ],
        stops: const [0.0, 0.45, 1.0],
      );
      final trackPaint = Paint()..shader = trackGradient.createShader(rect);
      canvas.drawRRect(rrect, trackPaint);

      // Subtle glowing bloom when active
      if (animationValue > 0.3) {
        final bloomPaint = Paint()
          ..color = activeColor.withOpacity(animationValue * 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
        canvas.drawRRect(rrect, bloomPaint);
      }
    } else {
      // Dark Inset Track
      final darkWellGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isGrungy
            ? [const Color(0xFF12100E), const Color(0xFF1C1916), const Color(0xFF26221E)]
            : (isLight
                ? [const Color(0xFFB0B9C6), const Color(0xFFCAD4E0), const Color(0xFFE2E8F0)]
                : [const Color(0xFF0D0F14), const Color(0xFF141720), const Color(0xFF1C212D)]),
        stops: const [0.0, 0.5, 1.0],
      );
      final wellPaint = Paint()..shader = darkWellGradient.createShader(rect);
      canvas.drawRRect(rrect, wellPaint);
    }

    // 3. Inset Rim Borders & Bottom Reflection
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = isGrungy
          ? const Color(0xFF38322B)
          : (isLight ? const Color(0xFF94A3B8) : const Color(0xFF2B3245));
    canvas.drawRRect(rrect, rimPaint);

    final bottomHighlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = Colors.white.withOpacity(isLight ? 0.4 : 0.12);
    canvas.drawRRect(rrect.deflate(0.5), bottomHighlight);

    // 4. Optional Icons / Text in Track
    if (!isVert && showText && w >= 36) {
      final textStyle = TextStyle(
        fontSize: (h * 0.38).clamp(7.0, 10.0),
        fontWeight: FontWeight.bold,
        color: animationValue > 0.5
            ? (showHighlightColor ? Colors.black87 : activeColor)
            : EatsTheme.textMuted.withOpacity(0.6),
        fontFamily: 'monospace',
      );
      final textSpan = TextSpan(text: animationValue > 0.5 ? 'ON' : 'OFF', style: textStyle);
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      final textOffset = animationValue > 0.5
          ? Offset(6.0, (h - tp.height) / 2)
          : Offset(w - tp.width - 6.0, (h - tp.height) / 2);
      tp.paint(canvas, textOffset);
    } else if (iconOn != null || iconOff != null) {
      final activeIcon = animationValue > 0.5 ? (iconOn ?? iconOff) : (iconOff ?? iconOn);
      if (activeIcon != null) {
        final iconPainter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(activeIcon.codePoint),
            style: TextStyle(
              inherit: false,
              color: animationValue > 0.5 ? activeColor : EatsTheme.textMuted,
              fontSize: (isVert ? w * 0.55 : h * 0.55).clamp(8.0, 14.0),
              fontFamily: activeIcon.fontFamily,
              package: activeIcon.fontPackage,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final iconPos = isVert
            ? Offset((w - iconPainter.width) / 2, animationValue > 0.5 ? h - iconPainter.height - 4 : 4)
            : Offset(animationValue > 0.5 ? 4 : w - iconPainter.width - 4, (h - iconPainter.height) / 2);
        iconPainter.paint(canvas, iconPos);
      }
    }

    // 5. 3D Tactile Circular Thumb
    final padding = 2.0;
    final thumbDiameter = isVert ? (w - padding * 2) : (h - padding * 2);
    final thumbRadius = thumbDiameter / 2;

    final Offset thumbCenter;
    if (isVert) {
      // In vertical: 0.0 is Bottom (OFF), 1.0 is Top (ON)
      final minY = padding + thumbRadius;
      final maxY = h - padding - thumbRadius;
      final currentY = maxY - animationValue * (maxY - minY);
      thumbCenter = Offset(w / 2, currentY);
    } else {
      // In horizontal: 0.0 is Left (OFF), 1.0 is Right (ON)
      final minX = padding + thumbRadius;
      final maxX = w - padding - thumbRadius;
      final currentX = minX + animationValue * (maxX - minX);
      thumbCenter = Offset(currentX, h / 2);
    }

    // Thumb Drop Shadow onto the track
    final thumbShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.drawCircle(thumbCenter + const Offset(0, 1.2), thumbRadius, thumbShadowPaint);

    // Thumb 3D Spherical Radial Gradient
    final thumbGradient = RadialGradient(
      center: const Alignment(-0.35, -0.4),
      radius: 0.9,
      colors: isGrungy
          ? [
              const Color(0xFFF5E6CC),
              const Color(0xFFC7B594),
              const Color(0xFF7A6B53),
              const Color(0xFF382F22),
            ]
          : (isLight
              ? [
                  Colors.white,
                  const Color(0xFFF1F5F9),
                  const Color(0xFFCBD5E1),
                  const Color(0xFF94A3B8),
                ]
              : [
                  const Color(0xFFFFFFFF),
                  const Color(0xFFDDE4ED),
                  const Color(0xFF7E8D9F),
                  const Color(0xFF2C3442),
                ]),
      stops: const [0.0, 0.35, 0.75, 1.0],
    );

    final thumbPaint = Paint()
      ..shader = thumbGradient.createShader(
        Rect.fromCircle(center: thumbCenter, radius: thumbRadius),
      );
    canvas.drawCircle(thumbCenter, thumbRadius, thumbPaint);

    // Thumb Outer Rim Bevel
    final thumbBevelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withOpacity(0.8);
    canvas.drawCircle(thumbCenter, thumbRadius, thumbBevelPaint);

    // Micro Grip Tactile Indents on Thumb
    if (thumbRadius >= 6.0) {
      final dotPaint = Paint()..color = Colors.black.withOpacity(0.25);
      final dotHighlight = Paint()..color = Colors.white.withOpacity(0.4);
      final dotRadius = 0.8;

      canvas.drawCircle(thumbCenter + const Offset(0, -1.5), dotRadius, dotPaint);
      canvas.drawCircle(thumbCenter + const Offset(0, -0.9), dotRadius * 0.6, dotHighlight);

      canvas.drawCircle(thumbCenter + const Offset(0, 1.5), dotRadius, dotPaint);
      canvas.drawCircle(thumbCenter + const Offset(0, 2.1), dotRadius * 0.6, dotHighlight);
    }
  }

  @override
  bool shouldRepaint(covariant _ModernPillSwitchPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isEnabled != isEnabled ||
        oldDelegate.orientation != orientation ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.showHighlightColor != showHighlightColor ||
        oldDelegate.showText != showText ||
        oldDelegate.iconOn != iconOn ||
        oldDelegate.iconOff != iconOff ||
        oldDelegate.isGrungy != isGrungy ||
        oldDelegate.isLight != isLight;
  }
}

/// Vintage Chrome Bat-Handle Switch Painter (Eats-303).
class _VintageBatSwitchPainter extends CustomPainter {
  final double animationValue; // 0.0 (OFF) -> 1.0 (ON)
  final bool isEnabled;
  final Color activeColor;
  final Color ledColor;
  final bool showLed;
  final bool isGrungy;
  final bool isLight;

  _VintageBatSwitchPainter({
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

    // 1. Recessed Bezel Outer Well
    final dropShadowPaint = Paint()
      ..color = Colors.black.withOpacity(isLight ? 0.12 : 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.drawRRect(rrect.shift(const Offset(0, 1.2)), dropShadowPaint);

    final wellGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isGrungy
          ? [const Color(0xFF141210), const Color(0xFF1E1B18), const Color(0xFF282420)]
          : (isLight
              ? [const Color(0xFFB0B9C6), const Color(0xFFCBD5E1), const Color(0xFFE2E8F0)]
              : [const Color(0xFF0F1116), const Color(0xFF161922), const Color(0xFF1F2430)]),
      stops: const [0.0, 0.5, 1.0],
    );
    final wellPaint = Paint()..shader = wellGradient.createShader(rect);
    canvas.drawRRect(rrect, wellPaint);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = isGrungy
          ? const Color(0xFF38322B)
          : (isLight ? const Color(0xFF94A3B8) : const Color(0xFF2B3245));
    canvas.drawRRect(rrect, rimPaint);

    // 2. Status Jewel LED Indicator
    final ledRadius = h * 0.16;
    final ledCenter = Offset(w - h * 0.44, h * 0.5);

    if (showLed) {
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
        final glowPaint = Paint()
          ..color = ledColor.withOpacity(glowOpacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
        canvas.drawCircle(ledCenter, ledRadius * 1.8, glowPaint);

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
      } else {
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

    // 3. Central Mounting Collar / Threaded Hex Nut Bushing
    final fulcrumX = showLed ? (h * 0.56) : (w * 0.5);
    final fulcrumY = h * 0.5;
    final fulcrum = Offset(fulcrumX, fulcrumY);
    final collarRadius = h * 0.31;

    final collarShadow = Paint()
      ..color = Colors.black.withOpacity(0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawCircle(fulcrum + const Offset(0, 1.5), collarRadius, collarShadow);

    final collarGradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 0.9,
      colors: isGrungy
          ? [const Color(0xFF6B5F4F), const Color(0xFF4A4135), const Color(0xFF29241D)]
          : [const Color(0xFF5A667A), const Color(0xFF384050), const Color(0xFF1D222C)],
    );
    final collarPaint = Paint()
      ..shader = collarGradient.createShader(
        Rect.fromCircle(center: fulcrum, radius: collarRadius),
      );
    canvas.drawCircle(fulcrum, collarRadius, collarPaint);

    final collarRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withOpacity(isGrungy ? 0.25 : 0.35);
    canvas.drawCircle(fulcrum, collarRadius, collarRimPaint);

    final boreRadius = collarRadius * 0.65;
    final borePaint = Paint()
      ..color = isGrungy ? const Color(0xFF12100E) : const Color(0xFF0B0C10);
    canvas.drawCircle(fulcrum, boreRadius, borePaint);

    // 4. 3D Chrome Bat-Handle Lever & Dynamic Cast Shadow
    const maxAngle = 0.46; // ~26.4 degrees
    final currentAngle = -maxAngle + (animationValue.clamp(-0.2, 1.2) * 2 * maxAngle);
    final handleLength = h * 0.52;

    final tip = fulcrum + Offset(math.sin(currentAngle) * handleLength, -math.cos(currentAngle) * (handleLength * 0.35));

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

    final baseWidth = collarRadius * 0.70;
    final tipRadius = h * 0.16;

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

    final cylinderGradient = LinearGradient(
      begin: Alignment(-ny, nx),
      end: Alignment(ny, -nx),
      colors: isGrungy
          ? [
              const Color(0xFF2C261F),
              const Color(0xFF6B5F4F),
              const Color(0xFFD4C29D),
              const Color(0xFF8A7A64),
              const Color(0xFF383127),
            ]
          : [
              const Color(0xFF1E2430),
              const Color(0xFF4B5568),
              const Color(0xFFF1F5F9),
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

    final glarePaint = Paint()..color = Colors.white.withOpacity(0.9);
    canvas.drawCircle(tip + const Offset(-1.2, -1.2), tipRadius * 0.32, glarePaint);
  }

  @override
  bool shouldRepaint(covariant _VintageBatSwitchPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isEnabled != isEnabled ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.ledColor != ledColor ||
        oldDelegate.showLed != showLed ||
        oldDelegate.isGrungy != isGrungy ||
        oldDelegate.isLight != isLight;
  }
}
