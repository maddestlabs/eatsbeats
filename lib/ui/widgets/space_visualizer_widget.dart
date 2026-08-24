import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../audio/procedural_ir_generator.dart';
import '../../theme/eats_theme.dart';

/// Interactive 2.5D perspective room & amp cabinet visualizer widget.
class SpaceVisualizerWidget extends StatefulWidget {
  final AcousticSpaceParams params;
  final ValueChanged<AcousticSpaceParams>? onParamsChanged;
  final double height;

  const SpaceVisualizerWidget({
    super.key,
    required this.params,
    this.onParamsChanged,
    this.height = 180,
  });

  @override
  State<SpaceVisualizerWidget> createState() => _SpaceVisualizerWidgetState();
}

class _SpaceVisualizerWidgetState extends State<SpaceVisualizerWidget> {
  int _draggedTarget = 0; // 0 = none, 1 = source, 2 = listener

  @override
  Widget build(BuildContext context) {
    final mat = AcousticMaterial.get(widget.params.material);

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF0F121C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.params.isCabinetMode
              ? EatsTheme.accentOrange.withOpacity(0.6)
              : EatsTheme.primaryCyan.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // 3D Canvas
            GestureDetector(
              onPanStart: (details) => _handlePanStart(details.localPosition),
              onPanUpdate: (details) => _handlePanUpdate(details.localPosition),
              onPanEnd: (_) => setState(() => _draggedTarget = 0),
              child: CustomPaint(
                size: Size.infinite,
                painter: _SpaceCanvasPainter(
                  params: widget.params,
                  material: mat,
                ),
              ),
            ),

            // Top Status Badges
            Positioned(
              top: 8,
              left: 10,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.params.isCabinetMode
                          ? EatsTheme.accentOrange.withOpacity(0.2)
                          : EatsTheme.primaryCyan.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: widget.params.isCabinetMode
                            ? EatsTheme.accentOrange
                            : EatsTheme.primaryCyan,
                      ),
                    ),
                    child: Text(
                      widget.params.isCabinetMode ? 'AMP CABINET' : 'ROOM ACOUSTICS',
                      style: EatsTheme.getPrimaryFontStyle(
                        color: widget.params.isCabinetMode
                            ? EatsTheme.accentOrange
                            : EatsTheme.primaryCyan,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.params.width.toStringAsFixed(2)}m × ${widget.params.length.toStringAsFixed(2)}m × ${widget.params.height.toStringAsFixed(2)}m',
                    style: EatsTheme.getDisplayFontStyle(
                      color: EatsTheme.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Material / Info Badge
            Positioned(
              bottom: 8,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: EatsTheme.accentOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.params.isCabinetMode ? 'Source' : 'Source',
                    style: EatsTheme.getPrimaryFontStyle(
                      color: EatsTheme.textPrimary,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: EatsTheme.primaryCyan,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.params.isCabinetMode ? 'Mic' : 'Listener',
                    style: EatsTheme.getPrimaryFontStyle(
                      color: EatsTheme.textPrimary,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mat.displayName,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: EatsTheme.getPrimaryFontStyle(
                        color: EatsTheme.secondaryMagenta,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
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

  void _handlePanStart(Offset localPos) {
    if (widget.onParamsChanged == null) return;
    // Simple hit check for dragging Source vs Listener
    final painter = _SpaceCanvasPainter(
      params: widget.params,
      material: AcousticMaterial.get(widget.params.material),
    );
    final size = context.size ?? const Size(300, 180);
    final srcPos = painter.projectPoint(
      widget.params.sourceX,
      widget.params.sourceY,
      widget.params.sourceZ,
      size,
    );
    final lisPos = painter.projectPoint(
      widget.params.listenerX,
      widget.params.listenerY,
      widget.params.listenerZ,
      size,
    );

    if ((localPos - srcPos).distance < 20) {
      setState(() => _draggedTarget = 1);
    } else if ((localPos - lisPos).distance < 20) {
      setState(() => _draggedTarget = 2);
    }
  }

  void _handlePanUpdate(Offset localPos) {
    if (_draggedTarget == 0 || widget.onParamsChanged == null) return;
    final size = context.size ?? const Size(300, 180);

    // Approximate inverse isometric projection
    final normX = ((localPos.dx - size.width * 0.15) / (size.width * 0.7)).clamp(0.05, 0.95);
    final normY = ((localPos.dy - size.height * 0.2) / (size.height * 0.6)).clamp(0.05, 0.95);

    if (_draggedTarget == 1) {
      widget.onParamsChanged!(widget.params.copyWith(sourceX: normX, sourceY: normY));
    } else if (_draggedTarget == 2) {
      widget.onParamsChanged!(widget.params.copyWith(listenerX: normX, listenerY: normY));
    }
  }
}

class _SpaceCanvasPainter extends CustomPainter {
  final AcousticSpaceParams params;
  final AcousticMaterial material;

  _SpaceCanvasPainter({required this.params, required this.material});

  Offset projectPoint(double nx, double ny, double nz, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.52;

    // Isometric 2.5D projection with depth scaling
    final aspectX = params.width / math.max(1.0, math.max(params.width, params.length));
    final aspectY = params.length / math.max(1.0, math.max(params.width, params.length));
    final aspectZ = params.height / math.max(1.0, math.max(params.width, params.length));

    final boxW = size.width * 0.45 * aspectX.clamp(0.6, 1.2);
    final boxL = size.width * 0.35 * aspectY.clamp(0.6, 1.2);
    final boxH = size.height * 0.45 * aspectZ.clamp(0.5, 1.1);

    final xIso = (nx - 0.5) * boxW - (ny - 0.5) * boxL * 0.8;
    final yIso = (nx - 0.5) * (boxW * 0.4) + (ny - 0.5) * (boxL * 0.4) - (nz - 0.5) * boxH;

    return Offset(cx + xIso, cy + yIso);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF0F121C);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final floorColor = params.isCabinetMode
        ? const Color(0xFF281E18)
        : const Color(0xFF161A26);
    final wallColor = params.isCabinetMode
        ? const Color(0xFF382A22)
        : const Color(0xFF1E2333);

    // Box 8 Corners
    final p000 = projectPoint(0, 0, 0, size);
    final p100 = projectPoint(1, 0, 0, size);
    final p110 = projectPoint(1, 1, 0, size);
    final p010 = projectPoint(0, 1, 0, size);

    final p001 = projectPoint(0, 0, 1, size);
    final p101 = projectPoint(1, 0, 1, size);
    final p111 = projectPoint(1, 1, 1, size);
    final p011 = projectPoint(0, 1, 1, size);

    // 1. Draw Back Walls & Floor
    final backWallLeft = Path()..moveTo(p000.dx, p000.dy)..lineTo(p010.dx, p010.dy)..lineTo(p011.dx, p011.dy)..lineTo(p001.dx, p001.dy)..close();
    final backWallRight = Path()..moveTo(p000.dx, p000.dy)..lineTo(p100.dx, p100.dy)..lineTo(p101.dx, p101.dy)..lineTo(p001.dx, p001.dy)..close();
    final floorPath = Path()..moveTo(p000.dx, p000.dy)..lineTo(p100.dx, p100.dy)..lineTo(p110.dx, p110.dy)..lineTo(p010.dx, p010.dy)..close();

    canvas.drawPath(backWallLeft, Paint()..color = wallColor.withOpacity(0.7));
    canvas.drawPath(backWallRight, Paint()..color = wallColor.withOpacity(0.9));
    canvas.drawPath(floorPath, Paint()..color = floorColor);

    // Floor Grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1.0;
    const gridSteps = 4;
    for (int i = 1; i < gridSteps; i++) {
      final t = i / gridSteps;
      final g1a = projectPoint(t, 0, 0, size);
      final g1b = projectPoint(t, 1, 0, size);
      canvas.drawLine(g1a, g1b, gridPaint);

      final g2a = projectPoint(0, t, 0, size);
      final g2b = projectPoint(1, t, 0, size);
      canvas.drawLine(g2a, g2b, gridPaint);
    }

    // 2. Wireframe Outlines
    final wirePaint = Paint()
      ..color = (params.isCabinetMode ? EatsTheme.accentOrange : EatsTheme.primaryCyan).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawLine(p000, p100, wirePaint);
    canvas.drawLine(p100, p110, wirePaint);
    canvas.drawLine(p110, p010, wirePaint);
    canvas.drawLine(p010, p000, wirePaint);

    canvas.drawLine(p001, p101, wirePaint);
    canvas.drawLine(p101, p111, wirePaint);
    canvas.drawLine(p111, p011, wirePaint);
    canvas.drawLine(p011, p001, wirePaint);

    canvas.drawLine(p000, p001, wirePaint);
    canvas.drawLine(p100, p101, wirePaint);
    canvas.drawLine(p110, p111, wirePaint);
    canvas.drawLine(p010, p011, wirePaint);

    // 3. Projected Positions for Source & Listener
    final srcPos = projectPoint(params.sourceX, params.sourceY, params.sourceZ, size);
    final srcFloor = projectPoint(params.sourceX, params.sourceY, 0, size);

    final lisPos = projectPoint(params.listenerX, params.listenerY, params.listenerZ, size);
    final lisFloor = projectPoint(params.listenerX, params.listenerY, 0, size);

    // Vertical stalk from floor
    final stalkPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(srcFloor, srcPos, stalkPaint);
    canvas.drawLine(lisFloor, lisPos, stalkPaint);

    // Reflection Rays (Visual ISM)
    final rayPaint = Paint()
      ..color = EatsTheme.secondaryMagenta.withOpacity(0.4)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final wallBounce1 = projectPoint(0, (params.sourceY + params.listenerY) / 2, params.sourceZ, size);
    canvas.drawLine(srcPos, wallBounce1, rayPaint);
    canvas.drawLine(wallBounce1, lisPos, rayPaint);

    final wallBounce2 = projectPoint((params.sourceX + params.listenerX) / 2, 0, params.sourceZ, size);
    canvas.drawLine(srcPos, wallBounce2, rayPaint);
    canvas.drawLine(wallBounce2, lisPos, rayPaint);

    // Direct sound path
    final directPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(srcPos, lisPos, directPaint);

    // 4. Source Marker (Orange Speaker / Sound Source)
    final srcPaint = Paint()
      ..color = EatsTheme.accentOrange
      ..style = PaintingStyle.fill;
    canvas.drawCircle(srcPos, 6, srcPaint);
    canvas.drawCircle(
      srcPos,
      10,
      Paint()
        ..color = EatsTheme.accentOrange.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // 5. Listener Marker (Cyan Mic / Ears)
    final lisPaint = Paint()
      ..color = EatsTheme.primaryCyan
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lisPos, 6, lisPaint);
    canvas.drawCircle(
      lisPos,
      10,
      Paint()
        ..color = EatsTheme.primaryCyan.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Mic angle pointer if in cabinet mode
    if (params.isCabinetMode) {
      final rad = params.micAngleDeg * (math.pi / 180.0);
      final pointerEnd = lisPos + Offset(math.cos(rad) * 14, -math.sin(rad) * 14);
      canvas.drawLine(
        lisPos,
        pointerEnd,
        Paint()
          ..color = EatsTheme.primaryCyan
          ..strokeWidth = 2.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpaceCanvasPainter oldDelegate) {
    return oldDelegate.params != params || oldDelegate.material != material;
  }
}
