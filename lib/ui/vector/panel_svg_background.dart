import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../lua/lua_gui_model.dart';
import 'svg_path_parser.dart';

/// Renders single or multi-layered SVG path watermarks cleanly scaled and centered behind controls,
/// with optional horizontal, vertical, or 2D tiling.
class PanelSvgBackgroundPainter extends CustomPainter {
  final String? svgData;
  final List<SvgLayerDef>? layers;
  final bool isLightChassis;
  final double opacity;
  final Color accentColor;
  final double? strokeWidth;
  final SvgTileMode tileMode;

  PanelSvgBackgroundPainter({
    this.svgData,
    this.layers,
    required this.isLightChassis,
    required this.opacity,
    required this.accentColor,
    this.strokeWidth,
    this.tileMode = SvgTileMode.none,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    if (layers != null && layers!.isNotEmpty) {
      _paintLayers(canvas, size);
      return;
    }

    if (svgData == null || svgData!.trim().isEmpty) return;
    _paintSingleSvg(canvas, size, svgData!);
  }

  void _paintLayers(Canvas canvas, Size size) {
    final parsedPaths = <Path>[];
    Rect unionBounds = Rect.zero;

    for (final layer in layers!) {
      final p = SvgPathParser.parse(layer.path);
      parsedPaths.add(p);
      final b = p.getBounds();
      if (!b.isEmpty && b.width > 0 && b.height > 0) {
        unionBounds = unionBounds.isEmpty ? b : unionBounds.expandToInclude(b);
      }
    }

    if (unionBounds.isEmpty || unionBounds.width <= 0 || unionBounds.height <= 0) return;

    void drawAllLayers(Canvas c, double scale) {
      for (int i = 0; i < layers!.length; i++) {
        final layer = layers![i];
        final path = parsedPaths[i];
        final baseColor = layer.color ?? (isLightChassis ? const Color(0xFF1B1D22) : Colors.white);
        final effectiveOp = (layer.opacity * opacity).clamp(0.0, 1.0);
        final paintColor = baseColor.withOpacity(effectiveOp);

        if (layer.style == SvgLayerStyle.fill) {
          final fillPaint = Paint()
            ..style = PaintingStyle.fill
            ..color = paintColor;
          c.drawPath(path, fillPaint);
        } else {
          final baseStroke = layer.strokeWidth ?? strokeWidth ?? 1.0;
          final effectiveStroke = math.max(0.35, baseStroke / scale);
          final strokePaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = effectiveStroke
            ..color = paintColor;
          c.drawPath(path, strokePaint);
        }
      }
    }

    if (tileMode == SvgTileMode.none) {
      // Scale to fit nicely across 90% of panel width & 90% of panel height
      final targetWidth = size.width * 0.90;
      final targetHeight = size.height * 0.90;
      final scale = math.min(targetWidth / unionBounds.width, targetHeight / unionBounds.height);

      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(scale, scale);
      canvas.translate(-unionBounds.center.dx, -unionBounds.center.dy);
      drawAllLayers(canvas, scale);
      canvas.restore();
    } else if (tileMode == SvgTileMode.x) {
      final targetHeight = size.height * 0.90;
      final scale = targetHeight / unionBounds.height;
      final tileWidth = unionBounds.width * scale;
      if (tileWidth <= 0) return;

      final numTiles = (size.width / tileWidth).ceil() + 2;
      final totalSpan = numTiles * tileWidth;
      final startX = (size.width - totalSpan) / 2.0;
      final offsetY = (size.height - targetHeight) / 2.0;

      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
      for (int t = 0; t < numTiles; t++) {
        canvas.save();
        canvas.translate(startX + t * tileWidth, offsetY);
        canvas.scale(scale, scale);
        canvas.translate(-unionBounds.left, -unionBounds.top);
        drawAllLayers(canvas, scale);
        canvas.restore();
      }
      canvas.restore();
    } else if (tileMode == SvgTileMode.y) {
      final targetWidth = size.width * 0.90;
      final scale = targetWidth / unionBounds.width;
      final tileHeight = unionBounds.height * scale;
      if (tileHeight <= 0) return;

      final numTiles = (size.height / tileHeight).ceil() + 2;
      final totalSpan = numTiles * tileHeight;
      final startY = (size.height - totalSpan) / 2.0;
      final offsetX = (size.width - targetWidth) / 2.0;

      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
      for (int t = 0; t < numTiles; t++) {
        canvas.save();
        canvas.translate(offsetX, startY + t * tileHeight);
        canvas.scale(scale, scale);
        canvas.translate(-unionBounds.left, -unionBounds.top);
        drawAllLayers(canvas, scale);
        canvas.restore();
      }
      canvas.restore();
    } else if (tileMode == SvgTileMode.xy) {
      final targetHeight = size.height * 0.50;
      final scale = targetHeight / unionBounds.height;
      final tileWidth = unionBounds.width * scale;
      final tileHeight = unionBounds.height * scale;
      if (tileWidth <= 0 || tileHeight <= 0) return;

      final numTilesX = (size.width / tileWidth).ceil() + 2;
      final numTilesY = (size.height / tileHeight).ceil() + 2;
      final startX = (size.width - numTilesX * tileWidth) / 2.0;
      final startY = (size.height - numTilesY * tileHeight) / 2.0;

      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
      for (int tx = 0; tx < numTilesX; tx++) {
        for (int ty = 0; ty < numTilesY; ty++) {
          canvas.save();
          canvas.translate(startX + tx * tileWidth, startY + ty * tileHeight);
          canvas.scale(scale, scale);
          canvas.translate(-unionBounds.left, -unionBounds.top);
          drawAllLayers(canvas, scale);
          canvas.restore();
        }
      }
      canvas.restore();
    }
  }

  void _paintSingleSvg(Canvas canvas, Size size, String data) {
    final path = SvgPathParser.parse(data);
    final bounds = path.getBounds();
    if (bounds.isEmpty || bounds.width <= 0 || bounds.height <= 0) return;

    final effectiveOpacity = opacity.clamp(0.10, 1.0);
    final baseColor = isLightChassis ? const Color(0xFF1B1D22) : Colors.white;
    final hasClosedShapes = data.contains('Z') || data.contains('z');

    void drawSingle(Canvas c, double scale) {
      if (hasClosedShapes) {
        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = baseColor.withOpacity(effectiveOpacity * 0.65);
        c.drawPath(path, fillPaint);
      }
      final baseStroke = strokeWidth ?? (hasClosedShapes ? 0.70 : 0.90);
      final effectiveStroke = math.max(0.35, baseStroke / scale);
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = effectiveStroke
        ..color = baseColor.withOpacity((effectiveOpacity * (hasClosedShapes ? 1.15 : 1.35)).clamp(0.0, 1.0));
      c.drawPath(path, strokePaint);
    }

    if (tileMode == SvgTileMode.none) {
      final targetWidth = size.width * 0.80;
      final targetHeight = size.height * 0.85;
      final scale = math.min(targetWidth / bounds.width, targetHeight / bounds.height);

      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(scale, scale);
      canvas.translate(-bounds.center.dx, -bounds.center.dy);
      drawSingle(canvas, scale);
      canvas.restore();
    } else if (tileMode == SvgTileMode.x) {
      final targetHeight = size.height * 0.85;
      final scale = targetHeight / bounds.height;
      final tileWidth = bounds.width * scale;
      if (tileWidth <= 0) return;

      final numTiles = (size.width / tileWidth).ceil() + 2;
      final totalSpan = numTiles * tileWidth;
      final startX = (size.width - totalSpan) / 2.0;
      final offsetY = (size.height - targetHeight) / 2.0;

      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
      for (int t = 0; t < numTiles; t++) {
        canvas.save();
        canvas.translate(startX + t * tileWidth, offsetY);
        canvas.scale(scale, scale);
        canvas.translate(-bounds.left, -bounds.top);
        drawSingle(canvas, scale);
        canvas.restore();
      }
      canvas.restore();
    } else if (tileMode == SvgTileMode.y) {
      final targetWidth = size.width * 0.80;
      final scale = targetWidth / bounds.width;
      final tileHeight = bounds.height * scale;
      if (tileHeight <= 0) return;

      final numTiles = (size.height / tileHeight).ceil() + 2;
      final totalSpan = numTiles * tileHeight;
      final startY = (size.height - totalSpan) / 2.0;
      final offsetX = (size.width - targetWidth) / 2.0;

      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
      for (int t = 0; t < numTiles; t++) {
        canvas.save();
        canvas.translate(offsetX, startY + t * tileHeight);
        canvas.scale(scale, scale);
        canvas.translate(-bounds.left, -bounds.top);
        drawSingle(canvas, scale);
        canvas.restore();
      }
      canvas.restore();
    } else if (tileMode == SvgTileMode.xy) {
      final targetHeight = size.height * 0.50;
      final scale = targetHeight / bounds.height;
      final tileWidth = bounds.width * scale;
      final tileHeight = bounds.height * scale;
      if (tileWidth <= 0 || tileHeight <= 0) return;

      final numTilesX = (size.width / tileWidth).ceil() + 2;
      final numTilesY = (size.height / tileHeight).ceil() + 2;
      final startX = (size.width - numTilesX * tileWidth) / 2.0;
      final startY = (size.height - numTilesY * tileHeight) / 2.0;

      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
      for (int tx = 0; tx < numTilesX; tx++) {
        for (int ty = 0; ty < numTilesY; ty++) {
          canvas.save();
          canvas.translate(startX + tx * tileWidth, startY + ty * tileHeight);
          canvas.scale(scale, scale);
          canvas.translate(-bounds.left, -bounds.top);
          drawSingle(canvas, scale);
          canvas.restore();
        }
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant PanelSvgBackgroundPainter old) {
    return old.svgData != svgData ||
        old.layers != layers ||
        old.isLightChassis != isLightChassis ||
        old.opacity != opacity ||
        old.accentColor != accentColor ||
        old.strokeWidth != strokeWidth ||
        old.tileMode != tileMode;
  }
}


