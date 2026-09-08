import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'svg_path_parser.dart';

enum VectorShapeType {
  circle,
  rect,
  arc,
  radialTicks,
  svgPath,
}

/// A declarative vector drawing primitive within a custom control skin.
class VectorShapeDef {
  final VectorShapeType type;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
  final double? radius;
  final Rect? rect;
  final double? cornerRadius;
  final int tickCount;
  final double tickLength;
  final double startAngle;
  final double sweepAngle;
  final String? svgData;
  final Path? precompiledPath;
  final bool glow;

  const VectorShapeDef({
    required this.type,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 1.0,
    this.radius,
    this.rect,
    this.cornerRadius,
    this.tickCount = 11,
    this.tickLength = 5.0,
    this.startAngle = 0.0,
    this.sweepAngle = 2 * math.pi,
    this.svgData,
    this.precompiledPath,
    this.glow = false,
  });

  /// Instantiates a [VectorShapeDef] from a script map configuration.
  factory VectorShapeDef.fromMap(Map<String, dynamic> map) {
    final rawType = (map['type'] as String? ?? 'circle').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    VectorShapeType type = VectorShapeType.circle;
    if (rawType == 'rect' || rawType == 'rectangle') {
      type = VectorShapeType.rect;
    } else if (rawType == 'arc') {
      type = VectorShapeType.arc;
    } else if (rawType == 'ticks' || rawType == 'radialticks' || rawType == 'notches') {
      type = VectorShapeType.radialTicks;
    } else if (rawType == 'svg' || rawType == 'svgpath' || rawType == 'path') {
      type = VectorShapeType.svgPath;
    }

    final fill = _parseColor(map['fill'] ?? map['fillColor']);
    final stroke = _parseColor(map['stroke'] ?? map['strokeColor'] ?? map['color']);
    final strokeWidth = (map['strokeWidth'] as num?)?.toDouble() ??
        (map['width'] as num?)?.toDouble() ??
        (map['weight'] as num?)?.toDouble() ??
        1.5;

    final radius = (map['radius'] as num?)?.toDouble() ?? (map['r'] as num?)?.toDouble();
    final cornerRadius = (map['cornerRadius'] as num?)?.toDouble() ?? (map['corner_radius'] as num?)?.toDouble();
    final tickCount = (map['count'] as num?)?.toInt() ?? (map['tickCount'] as num?)?.toInt() ?? 11;
    final tickLength = (map['length'] as num?)?.toDouble() ?? (map['tickLength'] as num?)?.toDouble() ?? 5.0;

    final svgData = map['data'] as String? ?? map['svg'] as String? ?? map['d'] as String? ?? map['path'] as String?;
    Path? precompiled;
    if (type == VectorShapeType.svgPath && svgData != null && svgData.isNotEmpty) {
      precompiled = SvgPathParser.parse(svgData);
    }

    final glow = map['glow'] == true;

    return VectorShapeDef(
      type: type,
      fillColor: fill,
      strokeColor: stroke,
      strokeWidth: strokeWidth,
      radius: radius,
      cornerRadius: cornerRadius,
      tickCount: tickCount,
      tickLength: tickLength,
      svgData: svgData,
      precompiledPath: precompiled,
      glow: glow,
    );
  }

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'type': type.name,
    };
    if (fillColor != null) m['fill'] = _hex(fillColor!);
    if (strokeColor != null) m['stroke'] = _hex(strokeColor!);
    if (strokeWidth != 1.0) m['strokeWidth'] = strokeWidth;
    if (radius != null) m['radius'] = radius;
    if (cornerRadius != null) m['cornerRadius'] = cornerRadius;
    if (type == VectorShapeType.radialTicks) {
      m['count'] = tickCount;
      m['length'] = tickLength;
    }
    if (svgData != null) m['data'] = svgData;
    if (glow) m['glow'] = true;
    return m;
  }

  static Color? _parseColor(dynamic val) {
    if (val == null) return null;
    if (val is Color) return val;
    if (val is String) {
      final s = val.trim().replaceAll('#', '');
      if (s.length == 6) {
        return Color(int.parse('FF$s', radix: 16));
      } else if (s.length == 8) {
        return Color(int.parse(s, radix: 16));
      }
    }
    return null;
  }

  static String _hex(Color c) => '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}

/// A complete custom control skin consisting of a pre-recorded chassis and dynamic indicator.
class CustomControlSkin {
  final String id;
  final String? name;
  final double defaultSize;
  final List<VectorShapeDef> chassisLayers; // Rendered into ui.Picture once
  final VectorShapeDef indicatorLayer;      // Rotated or translated at 120 FPS
  final double startAngle;                  // In radians (e.g. -135° = -2.356)
  final double sweepAngle;                  // In radians (e.g. 270° = 4.712)

  const CustomControlSkin({
    required this.id,
    this.name,
    this.defaultSize = 56.0,
    required this.chassisLayers,
    required this.indicatorLayer,
    this.startAngle = -2.35619, // -135°
    this.sweepAngle = 4.71239,  // 270°
  });

  factory CustomControlSkin.fromMap(String id, Map<String, dynamic> map) {
    final size = (map['size'] as num?)?.toDouble() ?? 56.0;
    final name = map['name'] as String? ?? id;

    // Start angle & sweep
    final startDeg = (map['startAngle'] as num?)?.toDouble() ?? -135.0;
    final sweepDeg = (map['sweepAngle'] as num?)?.toDouble() ?? 270.0;
    final startRad = startDeg * (math.pi / 180.0);
    final sweepRad = sweepDeg * (math.pi / 180.0);

    // Chassis layers
    final List<VectorShapeDef> chassis = [];
    final rawChassis = map['chassis'] ?? map['background'] ?? map['body'];
    if (rawChassis is List) {
      for (final item in rawChassis) {
        if (item is Map) {
          chassis.add(VectorShapeDef.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    // Indicator layer
    VectorShapeDef indicator = VectorShapeDef(
      type: VectorShapeType.svgPath,
      fillColor: const Color(0xFF00E5FF),
      svgData: "M -1.5 0 L 0 -18 L 1.5 0 Z",
      precompiledPath: SvgPathParser.parse("M -1.5 0 L 0 -18 L 1.5 0 Z"),
    );

    final rawIndicator = map['indicator'] ?? map['pointer'] ?? map['needle'] ?? map['thumb'];
    if (rawIndicator is Map) {
      indicator = VectorShapeDef.fromMap(Map<String, dynamic>.from(rawIndicator));
    } else if (rawIndicator is String) {
      // Direct SVG string shorthand: indicator = "M -1.5 0 L 0 -18 L 1.5 0 Z"
      indicator = VectorShapeDef(
        type: VectorShapeType.svgPath,
        svgData: rawIndicator,
        precompiledPath: SvgPathParser.parse(rawIndicator),
      );
    }

    return CustomControlSkin(
      id: id,
      name: name,
      defaultSize: size,
      chassisLayers: chassis,
      indicatorLayer: indicator,
      startAngle: startRad,
      sweepAngle: sweepRad,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'size': defaultSize,
      'chassis': chassisLayers.map((e) => e.toMap()).toList(),
      'indicator': indicatorLayer.toMap(),
    };
  }
}
