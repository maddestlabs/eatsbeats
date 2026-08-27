import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../audio/audio_engine.dart';
import '../../lua/lua_canvas_drawing_engine.dart';
import '../../lua/lua_gui_model.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import '../../theme/eats_theme.dart';

/// Interactive high-performance Programmable 2D Canvas widget driven by Lua draw scripts.
class LuaProgrammableCanvasWidget extends StatefulWidget {
  final DawState dawState;
  final TrackChannel track;
  final LuaGuiNode node;
  final Color accentColor;
  final bool isLightChassis;

  const LuaProgrammableCanvasWidget({
    super.key,
    required this.dawState,
    required this.track,
    required this.node,
    required this.accentColor,
    this.isLightChassis = false,
  });

  @override
  State<LuaProgrammableCanvasWidget> createState() => _LuaProgrammableCanvasWidgetState();
}

class _LuaProgrammableCanvasWidgetState extends State<LuaProgrammableCanvasWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  double _time = 0.0;
  Offset? _touchPos;
  bool _isTouchDown = false;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onTick);
    _ticker.repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    if (!TickerMode.of(context)) return;
    setState(() {
      _time += 1.0 / 60.0;
    });
  }

  void _handlePointer(Offset localPos, bool isDown, double w, double h) {
    setState(() {
      _touchPos = localPos;
      _isTouchDown = isDown;
    });

    // If script contains Cutoff/Resonance or X/Y parameters, map touch intuitively
    if (isDown && w > 0 && h > 0) {
      final normX = (localPos.dx / w).clamp(0.0, 1.0);
      final normY = (1.0 - (localPos.dy / h)).clamp(0.0, 1.0);

      // Check if track has Cutoff / Resonance
      if (widget.track.luaParams.containsKey('Cutoff')) {
        final minCut = 20.0;
        final maxCut = 20000.0;
        final newCut = minCut * math.pow(maxCut / minCut, normX);
        widget.track.luaParams['Cutoff'] = newCut;
      }
      if (widget.track.luaParams.containsKey('Resonance')) {
        widget.track.luaParams['Resonance'] = normY * 15.0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.node.width ?? 340.0;
    final height = widget.node.height ?? 180.0;

    final trackId = widget.track.id;
    final isMasterBus = trackId == 'master_bus' || trackId == 'master' || widget.track.name.toLowerCase().contains('master');
    final targetTrackId = isMasterBus ? null : trackId;

    final ops = LuaCanvasDrawingEngine.evaluate(
      scriptCode: widget.track.luaScriptCode,
      width: width,
      height: height,
      params: widget.track.luaParams,
      time: _time,
      accentColor: widget.accentColor,
      touchPos: _touchPos,
      isTouchDown: _isTouchDown,
    );

    return GestureDetector(
      onPanStart: (d) => _handlePointer(d.localPosition, true, width, height),
      onPanUpdate: (d) => _handlePointer(d.localPosition, true, width, height),
      onPanEnd: (_) => _handlePointer(_touchPos ?? Offset.zero, false, width, height),
      onPanCancel: () => _handlePointer(_touchPos ?? Offset.zero, false, width, height),
      onTapDown: (d) => _handlePointer(d.localPosition, true, width, height),
      onTapUp: (_) => _handlePointer(_touchPos ?? Offset.zero, false, width, height),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF090D14),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: widget.accentColor.withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.accentColor.withOpacity(0.12),
              blurRadius: 8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4.5),
          child: CustomPaint(
            size: Size(width, height),
            painter: _LuaCanvasPainter(
              ops: ops,
              audioEngine: widget.dawState.audioEngine,
              targetTrackId: targetTrackId,
              accentColor: widget.accentColor,
              time: _time,
            ),
          ),
        ),
      ),
    );
  }
}

class _LuaCanvasPainter extends CustomPainter {
  final List<LuaCanvasOp> ops;
  final AudioEngine audioEngine;
  final String? targetTrackId;
  final Color accentColor;
  final double time;

  _LuaCanvasPainter({
    required this.ops,
    required this.audioEngine,
    required this.targetTrackId,
    required this.accentColor,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final op in ops) {
      if (op is LuaCanvasClearOp) {
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = op.color,
        );
      } else if (op is LuaCanvasLineOp) {
        canvas.drawLine(
          op.p1,
          op.p2,
          Paint()
            ..color = op.color
            ..strokeWidth = op.strokeWidth
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      } else if (op is LuaCanvasRectOp) {
        final paint = Paint()
          ..color = op.color
          ..style = op.filled ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = op.strokeWidth;

        if (op.cornerRadius > 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(op.rect, Radius.circular(op.cornerRadius)),
            paint,
          );
        } else {
          canvas.drawRect(op.rect, paint);
        }
      } else if (op is LuaCanvasCircleOp) {
        canvas.drawCircle(
          op.center,
          op.radius,
          Paint()
            ..color = op.color
            ..style = op.filled ? PaintingStyle.fill : PaintingStyle.stroke
            ..strokeWidth = op.strokeWidth,
        );
      } else if (op is LuaCanvasTextOp) {
        final tp = TextPainter(
          text: TextSpan(
            text: op.text,
            style: TextStyle(
              color: op.color,
              fontSize: op.fontSize,
              fontWeight: op.isBold ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: op.align,
        );
        tp.layout();
        double tx = op.position.dx;
        if (op.align == TextAlign.center) {
          tx -= tp.width / 2;
        } else if (op.align == TextAlign.right) {
          tx -= tp.width;
        }
        tp.paint(canvas, Offset(tx, op.position.dy));
      } else if (op is LuaCanvasPathOp) {
        if (op.points.length >= 2) {
          final path = Path()..moveTo(op.points.first.dx, op.points.first.dy);
          for (int i = 1; i < op.points.length; i++) {
            path.lineTo(op.points[i].dx, op.points[i].dy);
          }
          if (op.closed) path.close();

          if (op.fillColor != null) {
            canvas.drawPath(path, Paint()..color = op.fillColor!..style = PaintingStyle.fill);
          }
          canvas.drawPath(
            path,
            Paint()
              ..color = op.color
              ..strokeWidth = op.strokeWidth
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round,
          );
        }
      } else if (op is LuaCanvasGridOp) {
        final gridPaint = Paint()
          ..color = op.color
          ..strokeWidth = op.strokeWidth
          ..style = PaintingStyle.stroke;

        final dx = size.width / op.cols;
        final dy = size.height / op.rows;

        for (int c = 1; c < op.cols; c++) {
          canvas.drawLine(Offset(c * dx, 0), Offset(c * dx, size.height), gridPaint);
        }
        for (int r = 1; r < op.rows; r++) {
          canvas.drawLine(Offset(0, r * dy), Offset(size.width, r * dy), gridPaint);
        }
      } else if (op is LuaCanvasWaveformOp) {
        final samples = audioEngine.getWaveformSamples(
          trackId: targetTrackId,
          count: 96,
          gain: op.gain,
          timebase: op.timebase,
        );

        final wavePath = Path();
        final midY = size.height / 2;
        final stepX = size.width / (samples.length - 1);

        for (int i = 0; i < samples.length; i++) {
          final x = i * stepX;
          final y = (midY - (samples[i] * (size.height * 0.42))).clamp(2.0, size.height - 2.0);
          if (i == 0) {
            wavePath.moveTo(x, y);
          } else {
            wavePath.lineTo(x, y);
          }
        }

        // Glow pass
        canvas.drawPath(
          wavePath,
          Paint()
            ..color = op.color.withOpacity(0.3)
            ..strokeWidth = op.strokeWidth * 2.5
            ..style = PaintingStyle.stroke,
        );
        // Trace pass
        canvas.drawPath(
          wavePath,
          Paint()
            ..color = op.color
            ..strokeWidth = op.strokeWidth
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      } else if (op is LuaCanvasSpectrumOp) {
        final bands = audioEngine.getSpectrumBands(
          trackId: targetTrackId,
          bands: op.bands,
          gain: op.gain,
          decay: op.decay,
        );

        final totalWidth = size.width - 16;
        final barWidth = (totalWidth / bands.length) * 0.75;
        final gap = (totalWidth / bands.length) * 0.25;

        for (int b = 0; b < bands.length; b++) {
          final x = 8 + b * (barWidth + gap);
          final barH = (bands[b] * (size.height - 24)).clamp(2.0, size.height - 24);
          final y = size.height - 8 - barH;

          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, barWidth, barH),
              const Radius.circular(2),
            ),
            Paint()..color = op.color,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LuaCanvasPainter oldDelegate) => true;
}
