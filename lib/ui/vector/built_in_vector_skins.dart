import 'package:flutter/material.dart';
import '../../lua/lua_gui_model.dart';
import 'svg_path_parser.dart';
import 'vector_skin_model.dart';

/// Registry of built-in hardware skins and EatScript template exporter.
class BuiltInVectorSkins {
  /// 1. Chrome Fluted (Acid 303 style)
  static final CustomControlSkin chromeFluted = CustomControlSkin(
    id: 'chrome_fluted',
    name: 'Chrome Fluted (303)',
    defaultSize: 56,
    chassisLayers: [
      // Outer drop shadow rim
      const VectorShapeDef(
        type: VectorShapeType.circle,
        radius: 26,
        fillColor: Color(0xFF141416),
        strokeColor: Color(0xFF383840),
        strokeWidth: 1.5,
      ),
      // Knurled perimeter ticks
      const VectorShapeDef(
        type: VectorShapeType.radialTicks,
        tickCount: 25,
        radius: 25,
        tickLength: 3.5,
        strokeColor: Color(0xFF70707A),
        strokeWidth: 1.2,
      ),
      // Inner chrome bevel
      const VectorShapeDef(
        type: VectorShapeType.circle,
        radius: 19,
        fillColor: Color(0xFF28282E),
        strokeColor: Color(0xFF50505C),
        strokeWidth: 1.0,
      ),
    ],
    // Sharp tapered cyan needle
    indicatorLayer: VectorShapeDef(
      type: VectorShapeType.svgPath,
      fillColor: const Color(0xFF00E5FF),
      svgData: "M -1.5 0 L 0 -19 L 1.5 0 Z",
      precompiledPath: SvgPathParser.parse("M -1.5 0 L 0 -19 L 1.5 0 Z"),
      glow: true,
    ),
  );

  /// 2. Minimalist Ceramic Matte White
  static final CustomControlSkin minimalMatte = CustomControlSkin(
    id: 'minimal_white',
    name: 'Minimalist Matte Ceramic',
    defaultSize: 48,
    chassisLayers: [
      const VectorShapeDef(
        type: VectorShapeType.circle,
        radius: 22,
        fillColor: Color(0xFFF2F4F8),
        strokeColor: Color(0xFFD4D8E2),
        strokeWidth: 1.0,
      ),
      const VectorShapeDef(
        type: VectorShapeType.radialTicks,
        tickCount: 11,
        radius: 21,
        tickLength: 4.0,
        strokeColor: Color(0xFF888E9E),
        strokeWidth: 1.4,
      ),
      const VectorShapeDef(
        type: VectorShapeType.circle,
        radius: 16,
        fillColor: Color(0xFFFFFFFF),
        strokeColor: Color(0xFFE4E8F0),
        strokeWidth: 0.8,
      ),
    ],
    indicatorLayer: VectorShapeDef(
      type: VectorShapeType.svgPath,
      fillColor: const Color(0xFF1E1E24),
      svgData: "M -1.2 -4 L 0 -16 L 1.2 -4 Z",
      precompiledPath: SvgPathParser.parse("M -1.2 -4 L 0 -16 L 1.2 -4 Z"),
    ),
  );

  /// 3. Vintage Bakelite Dial
  static final CustomControlSkin vintageBakelite = CustomControlSkin(
    id: 'vintage_bakelite',
    name: 'Vintage Bakelite',
    defaultSize: 56,
    chassisLayers: [
      const VectorShapeDef(
        type: VectorShapeType.circle,
        radius: 27,
        fillColor: Color(0xFF1B1512),
        strokeColor: Color(0xFF382A24),
        strokeWidth: 2.0,
      ),
      const VectorShapeDef(
        type: VectorShapeType.radialTicks,
        tickCount: 11,
        radius: 25,
        tickLength: 5.0,
        strokeColor: Color(0xFFD4A853),
        strokeWidth: 1.5,
      ),
      const VectorShapeDef(
        type: VectorShapeType.circle,
        radius: 18,
        fillColor: Color(0xFF281E19),
        strokeColor: Color(0xFF8C6D37),
        strokeWidth: 1.0,
      ),
    ],
    indicatorLayer: VectorShapeDef(
      type: VectorShapeType.svgPath,
      fillColor: const Color(0xFFF2D179),
      svgData: "M -1.5 0 L 0 -18 L 1.5 0 Z",
      precompiledPath: SvgPathParser.parse("M -1.5 0 L 0 -18 L 1.5 0 Z"),
    ),
  );

  /// 4. SNES Console Cream
  static final CustomControlSkin snesConsole = CustomControlSkin(
    id: 'snes_cream',
    name: 'SNES Console Cream',
    defaultSize: 52,
    chassisLayers: [
      const VectorShapeDef(
        type: VectorShapeType.circle,
        radius: 24,
        fillColor: Color(0xFFD3D0C8),
        strokeColor: Color(0xFFABA79E),
        strokeWidth: 1.5,
      ),
      const VectorShapeDef(
        type: VectorShapeType.radialTicks,
        tickCount: 9,
        radius: 23,
        tickLength: 4.5,
        strokeColor: Color(0xFF4F43AE),
        strokeWidth: 1.6,
      ),
      const VectorShapeDef(
        type: VectorShapeType.circle,
        radius: 17,
        fillColor: Color(0xFFE5E2DC),
        strokeColor: Color(0xFF8B84D7),
        strokeWidth: 1.0,
      ),
    ],
    indicatorLayer: VectorShapeDef(
      type: VectorShapeType.svgPath,
      fillColor: const Color(0xFF4F43AE),
      svgData: "M -2 -2 L 0 -17 L 2 -2 Z",
      precompiledPath: SvgPathParser.parse("M -2 -2 L 0 -17 L 2 -2 Z"),
    ),
  );

  /// 5. Cyber Neon Synth
  static final CustomControlSkin cyberNeon = CustomControlSkin(
    id: 'cyber_neon',
    name: 'Cyber Neon Synth',
    defaultSize: 56,
    chassisLayers: [
      const VectorShapeDef(
        type: VectorShapeType.circle,
        radius: 26,
        fillColor: Color(0xFF090B10),
        strokeColor: Color(0xFF1E2638),
        strokeWidth: 1.5,
      ),
      const VectorShapeDef(
        type: VectorShapeType.radialTicks,
        tickCount: 21,
        radius: 24,
        tickLength: 4.0,
        strokeColor: Color(0xFFFF007F),
        strokeWidth: 1.2,
        glow: true,
      ),
      const VectorShapeDef(
        type: VectorShapeType.circle,
        radius: 17,
        fillColor: Color(0xFF121622),
        strokeColor: Color(0xFF00E5FF),
        strokeWidth: 1.0,
      ),
    ],
    indicatorLayer: VectorShapeDef(
      type: VectorShapeType.svgPath,
      fillColor: const Color(0xFF00FFCC),
      svgData: "M -1.5 0 L 0 -19 L 1.5 0 Z",
      precompiledPath: SvgPathParser.parse("M -1.5 0 L 0 -19 L 1.5 0 Z"),
      glow: true,
    ),
  );

  /// Mapping from standard [KnobStyle] enum to corresponding [CustomControlSkin]
  static CustomControlSkin getSkinForKnobStyle(KnobStyle style) {
    switch (style) {
      case KnobStyle.chrome:
        return chromeFluted;
      case KnobStyle.minimalWhite:
        return minimalMatte;
      case KnobStyle.vintage:
        return vintageBakelite;
      case KnobStyle.snes:
        return snesConsole;
      case KnobStyle.customVector:
      case KnobStyle.standard:
      default:
        return chromeFluted;
    }
  }

  /// Exports any [CustomControlSkin] to clean, readable Pythonic EatScript DSL for user forking.
  static String exportToEatScript(CustomControlSkin skin, [String? customName]) {
    final name = customName ?? '${skin.id}_fork';
    final fnName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final buf = StringBuffer();
    buf.writeln('# Custom Vector Knob: $name (Eatscript)');
    buf.writeln('def $fnName():');
    buf.writeln('    return {');
    buf.writeln('        "size": ${skin.defaultSize.toInt()},');
    buf.writeln('        "chassis": [');
    for (final l in skin.chassisLayers) {
      if (l.type == VectorShapeType.circle) {
        buf.write('            {"type": "circle", "radius": ${l.radius?.toStringAsFixed(1) ?? "22.0"}');
        if (l.fillColor != null) buf.write(', "fill": "${_hex(l.fillColor!)}"');
        if (l.strokeColor != null) buf.write(', "stroke": "${_hex(l.strokeColor!)}", "strokeWidth": ${l.strokeWidth}');
        buf.writeln('},');
      } else if (l.type == VectorShapeType.radialTicks) {
        buf.write('            {"type": "ticks", "count": ${l.tickCount}, "radius": ${l.radius?.toStringAsFixed(1) ?? "22.0"}, "length": ${l.tickLength}');
        if (l.strokeColor != null) buf.write(', "color": "${_hex(l.strokeColor!)}"');
        if (l.glow) buf.write(', "glow": True');
        buf.writeln('},');
      } else if (l.type == VectorShapeType.svgPath) {
        buf.write('            {"type": "svg_path", "data": "${l.svgData ?? ""}"');
        if (l.fillColor != null) buf.write(', "fill": "${_hex(l.fillColor!)}"');
        if (l.strokeColor != null) buf.write(', "stroke": "${_hex(l.strokeColor!)}"');
        buf.writeln('},');
      }
    }
    buf.writeln('        ],');
    buf.writeln('        "indicator": {');
    buf.writeln('            "type": "svg_path",');
    buf.writeln('            "data": "${skin.indicatorLayer.svgData ?? "M -1.5 0 L 0 -19 L 1.5 0 Z"}",');
    if (skin.indicatorLayer.fillColor != null) {
      buf.writeln('            "fill": "${_hex(skin.indicatorLayer.fillColor!)}",');
    }
    if (skin.indicatorLayer.glow) {
      buf.writeln('            "glow": True,');
    }
    buf.writeln('        }');
    buf.writeln('    }');
    return buf.toString();
  }

  static String _hex(Color c) => '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}
