import 'dart:ui';
import 'eat_param_model.dart';
import '../ui/vector/vector_skin_model.dart';
import '../ui/hardware/eat_hardware_knob_model.dart';
import '../ui/hardware/eat_hardware_scale.dart';
import 'eat_gui_model.dart';
import 'eat_gui_parser.dart';
import 'eat_script_engine.dart';

// Backwards-compatibility aliases
typedef LuaGuiSerializer = EatGuiSerializer;
typedef EatScriptGuiSerializer = EatGuiSerializer;

/// Serializes [EatScriptGuiPanelDef] and its component tree into clean Eatscript or legacy Lua code.
class EatGuiSerializer {
  /// Serializes a [EatScriptGuiPanelDef] into an EatScript `def gui():` or Lua `function <TableName>.gui()` code block.
  /// Defaults to pure Pythonic EatScript unless existing code is legacy Lua.
  static String serialize({
    required EatScriptGuiPanelDef panel,
    String? existingScriptCode,
    String instrumentName = 'Instrument',
  }) {
    final isLua = existingScriptCode != null && !EatScriptEngine.isEatScript(existingScriptCode);
    if (isLua) {
      return serializeToLua(
        panel: panel,
        existingScriptCode: existingScriptCode,
        instrumentName: instrumentName,
      );
    }
    return serializeToEatScript(
      panel: panel,
      existingScriptCode: existingScriptCode,
      instrumentName: instrumentName,
    );
  }

  /// Serializes [EatScriptGuiPanelDef] into a pure, Pythonic EatScript `def gui():` block.
  static String serializeToEatScript({
    required EatScriptGuiPanelDef panel,
    String? existingScriptCode,
    String instrumentName = 'Instrument',
  }) {
    final buffer = StringBuffer();
    buffer.writeln('# --- Hardware GUI Layout ---');
    buffer.writeln('def gui():');
    buffer.writeln('    return {');
    buffer.writeln('        "panel": {');
    buffer.writeln('            "title": "${_escape(panel.title)}",');
    if (panel.subtitle != null && panel.subtitle!.isNotEmpty) {
      buffer.writeln('            "subtitle": "${_escape(panel.subtitle!)}",');
    }
    if (panel.backgroundStyle == PanelBackgroundStyle.custom && panel.backgroundColor != null) {
      buffer.writeln('            "background": "#${panel.backgroundColor!.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}",');
    } else {
      buffer.writeln('            "background": "${_backgroundStyleToString(panel.backgroundStyle)}",');
    }
    if (panel.textureRotation != 0.0) {
      buffer.writeln('            "textureRotation": ${panel.textureRotation.toInt()},');
    }
    if (panel.textureScale != 1.0) {
      buffer.writeln('            "textureScale": ${panel.textureScale},');
    }
    if (panel.sideCheeks != null && panel.sideCheeks!.isNotEmpty && panel.sideCheeks != 'none') {
      buffer.writeln('            "rackSides": "${_escape(panel.sideCheeks!)}",');
    }
    if (panel.cornerRadius != null) {
      buffer.writeln('            "cornerRadius": ${panel.cornerRadius!.toInt()},');
    }
    if (panel.backgroundSvg != null && panel.backgroundSvg!.isNotEmpty) {
      buffer.writeln('            "backgroundSvg": "${_escape(panel.backgroundSvg!)}",');
      buffer.writeln('            "backgroundSvgOpacity": ${panel.backgroundSvgOpacity},');
      if (panel.backgroundSvgStrokeWidth != null) {
        buffer.writeln('            "backgroundSvgStrokeWidth": ${panel.backgroundSvgStrokeWidth},');
      }
    }
    if (panel.backgroundSvgTile != SvgTileMode.none) {
      buffer.writeln('            "backgroundSvgTile": "${_tileModeToString(panel.backgroundSvgTile)}",');
    }
    if (panel.backgroundGradient != null) {
      final grad = panel.backgroundGradient!;
      final typeStr = grad.type == PanelGradientType.linear ? 'linear' : 'radial';
      final colorsStr = grad.colors.map((c) => '"${_hex(c)}"').join(', ');
      buffer.writeln('            "backgroundGradient": {');
      buffer.writeln('                "type": "$typeStr",');
      buffer.writeln('                "colors": [$colorsStr],');
      if (grad.radius != 1.0) {
        buffer.writeln('                "radius": ${grad.radius},');
      }
      if (grad.stops != null) {
        buffer.writeln('                "stops": [${grad.stops!.join(', ')}],');
      }
      buffer.writeln('            },');
    }
    if (panel.backgroundSvgLayers != null && panel.backgroundSvgLayers!.isNotEmpty) {
      buffer.writeln('            "backgroundSvgLayers": [');
      for (final layer in panel.backgroundSvgLayers!) {
        buffer.writeln('                {');
        buffer.writeln('                    "path": "${_escape(layer.path)}",');
        if (layer.color != null) {
          buffer.writeln('                    "color": "${_hex(layer.color!)}",');
        }
        if (layer.strokeWidth != null) {
          buffer.writeln('                    "strokeWidth": ${layer.strokeWidth},');
        }
        buffer.writeln('                    "style": "${layer.style == SvgLayerStyle.fill ? 'fill' : 'stroke'}",');
        if (layer.opacity != 1.0) {
          buffer.writeln('                    "opacity": ${layer.opacity},');
        }
        if (layer.tileMode != SvgTileMode.none) {
          buffer.writeln('                    "tile": "${_tileModeToString(layer.tileMode)}",');
        }
        buffer.writeln('                },');
      }
      buffer.writeln('            ],');
    }

    if (panel.accentColor != null) {
      buffer.writeln('            "accent": "#${panel.accentColor!.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}",');
    } else {
      buffer.writeln('            "accent": "track",');
    }
    if (panel.defaultKnobStyle != KnobStyle.standard) {
      buffer.writeln('            "knobStyle": "${_knobStyleToString(panel.defaultKnobStyle)}",');
    }
    buffer.writeln('            "layout": [');


    for (final child in panel.children) {
      _serializeNodeEat(buffer, child, indent: '                ');
    }

    buffer.writeln('            ],');
    buffer.writeln('        },');
    buffer.writeln('    }');

    final guiBlock = buffer.toString().trimRight();

    if (existingScriptCode == null || existingScriptCode.trim().isEmpty) {
      return '# @name: $instrumentName\n# @category: instrument\n\n$guiBlock\n';
    }

    // 1. Replace existing `def gui():` block if found
    final defGuiRegex = RegExp(r'(?:#\s*---\s*Hardware GUI Layout\s*---[\s\n]*)?def\s+gui\s*\([^)]*\):', multiLine: true);
    final defMatch = defGuiRegex.firstMatch(existingScriptCode);
    if (defMatch != null) {
      final startIdx = defMatch.start;
      final returnIdx = existingScriptCode.indexOf('return', defMatch.end);
      if (returnIdx != -1) {
        final braceIdx = existingScriptCode.indexOf('{', returnIdx);
        if (braceIdx != -1) {
          final endBraceIdx = _findMatchingClosingBrace(existingScriptCode, braceIdx);
          if (endBraceIdx != -1) {
            final before = existingScriptCode.substring(0, startIdx).trimRight();
            final after = existingScriptCode.substring(endBraceIdx + 1).trimLeft();
            return '$before\n\n$guiBlock\n\n$after';
          }
        }
      }
    }

    // 2. Replace existing legacy Lua `function ...gui()...end` block if found
    final guiFuncMatch = RegExp(r'function\s+[\w\.:]*gui\s*\([^)]*\)[\s\S]*?end', caseSensitive: false).firstMatch(existingScriptCode);
    if (guiFuncMatch != null) {
      final before = existingScriptCode.substring(0, guiFuncMatch.start).trimRight();
      final after = existingScriptCode.substring(guiFuncMatch.end).trimLeft();
      return '$before\n\n$guiBlock\n\n$after';
    }

    // 3. Inject before `def process` or `# --- Synthesizer Voice DSP Process Hook ---`
    final procMatch = RegExp(r'(?:#\s*---\s*Synthesizer Voice DSP Process Hook\s*---[\s\n]*)?def\s+process\s*\(', multiLine: true).firstMatch(existingScriptCode);
    if (procMatch != null) {
      final before = existingScriptCode.substring(0, procMatch.start).trimRight();
      final after = existingScriptCode.substring(procMatch.start);
      return '$before\n\n$guiBlock\n\n$after';
    }

    // 4. Inject before `def transform_notes`
    final transMatch = RegExp(r'(?:#\s*---\s*MIDI Transformation Hook\s*---[\s\n]*)?def\s+transform_notes\s*\(', multiLine: true).firstMatch(existingScriptCode);
    if (transMatch != null) {
      final before = existingScriptCode.substring(0, transMatch.start).trimRight();
      final after = existingScriptCode.substring(transMatch.start);
      return '$before\n\n$guiBlock\n\n$after';
    }

    return '${existingScriptCode.trimRight()}\n\n$guiBlock\n';
  }

  /// Serializes a [EatScriptGuiPanelDef] into legacy Lua code (`function <TableName>.gui()`).
  static String serializeToLua({
    required EatScriptGuiPanelDef panel,
    String? existingScriptCode,
    String instrumentName = 'Instrument',
  }) {
    String tableName = instrumentName.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');
    if (tableName.isEmpty) tableName = 'Instrument';

    if (existingScriptCode != null) {
      final nameMatch = RegExp(r'local\s+([A-Za-z0-9_]+)\s*=\s*\{\}').firstMatch(existingScriptCode);
      if (nameMatch != null) {
        tableName = nameMatch.group(1) ?? tableName;
      }
    }

    final buffer = StringBuffer();
    buffer.writeln('function $tableName.gui()');
    buffer.writeln('  return {');
    buffer.writeln('    panel = {');
    buffer.writeln('      title = "${_escape(panel.title)}",');
    if (panel.subtitle != null && panel.subtitle!.isNotEmpty) {
      buffer.writeln('      subtitle = "${_escape(panel.subtitle!)}",');
    }
    if (panel.backgroundStyle == PanelBackgroundStyle.custom && panel.backgroundColor != null) {
      buffer.writeln('      background = "#${panel.backgroundColor!.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}",');
    } else {
      buffer.writeln('      background = "${_backgroundStyleToString(panel.backgroundStyle)}",');
    }
    if (panel.textureRotation != 0.0) {
      buffer.writeln('      textureRotation = ${panel.textureRotation.toInt()},');
    }
    if (panel.textureScale != 1.0) {
      buffer.writeln('      textureScale = ${panel.textureScale},');
    }
    if (panel.sideCheeks != null && panel.sideCheeks!.isNotEmpty && panel.sideCheeks != 'none') {
      buffer.writeln('      rackSides = "${_escape(panel.sideCheeks!)}",');
    }
    if (panel.cornerRadius != null) {
      buffer.writeln('      cornerRadius = ${panel.cornerRadius!.toInt()},');
    }
    if (panel.backgroundSvg != null && panel.backgroundSvg!.isNotEmpty) {
      buffer.writeln('      backgroundSvg = "${_escape(panel.backgroundSvg!)}",');
      buffer.writeln('      backgroundSvgOpacity = ${panel.backgroundSvgOpacity},');
      if (panel.backgroundSvgStrokeWidth != null) {
        buffer.writeln('      backgroundSvgStrokeWidth = ${panel.backgroundSvgStrokeWidth},');
      }
    }
    if (panel.accentColor != null) {
      buffer.writeln('      accent = "#${panel.accentColor!.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}",');
    } else {
      buffer.writeln('      accent = "track",');
    }
    if (panel.defaultKnobStyle != KnobStyle.standard) {
      buffer.writeln('      knobStyle = "${_knobStyleToString(panel.defaultKnobStyle)}",');
    }
    buffer.writeln('      layout = {');

    for (final child in panel.children) {
      _serializeNode(buffer, child, indent: '        ');
    }

    buffer.writeln('      }');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln('end');

    final guiBlock = buffer.toString();

    if (existingScriptCode == null || existingScriptCode.trim().isEmpty) {
      return '-- @name: $instrumentName\nlocal $tableName = {}\n\n$guiBlock\n\nreturn $tableName\n';
    }

    // Replace existing `function ...gui()...end` block if found
    final guiFuncMatch = RegExp(r'function\s+[\w\.:]*gui\s*\([^)]*\)[\s\S]*?end', caseSensitive: false).firstMatch(existingScriptCode);
    if (guiFuncMatch != null) {
      final before = existingScriptCode.substring(0, guiFuncMatch.start).trimRight();
      final after = existingScriptCode.substring(guiFuncMatch.end).trimLeft();
      return '$before\n\n$guiBlock\n\n$after';
    }

    // Otherwise, inject before top-level `return <TableName>` or at the end
    final returnMatch = RegExp(r'^\s*return\s+([A-Za-z0-9_]+)\s*$', multiLine: true).firstMatch(existingScriptCode);
    if (returnMatch != null) {
      final before = existingScriptCode.substring(0, returnMatch.start).trimRight();
      final after = existingScriptCode.substring(returnMatch.start);
      return '$before\n\n$guiBlock\n\n$after';
    }

    return '${existingScriptCode.trimRight()}\n\n$guiBlock\n';
  }

  static int _findMatchingClosingBrace(String text, int startBrace) {
    int depth = 0;
    bool inQuote = false;
    String quoteChar = '';
    for (int i = startBrace; i < text.length; i++) {
      final c = text[i];
      if (inQuote) {
        if (c == quoteChar && (i == 0 || text[i - 1] != '\\')) {
          inQuote = false;
        }
      } else {
        if (c == '"' || c == "'") {
          inQuote = true;
          quoteChar = c;
        } else if (c == '{') {
          depth++;
        } else if (c == '}') {
          depth--;
          if (depth == 0) return i;
        }
      }
    }
    return -1;
  }

  /// Synthesizes a default [EatScriptGuiPanelDef] from a list of parameter definitions.
  static EatScriptGuiPanelDef generateDefaultPanel({
    required String title,
    String? subtitle,
    List<LuaParamDef> params = const [],
    PanelBackgroundStyle backgroundStyle = PanelBackgroundStyle.dark,
    Color? accentColor,
    KnobStyle defaultKnobStyle = KnobStyle.standard,
  }) {
    final List<EatScriptGuiNode> rows = [];
    final List<EatScriptGuiNode> currentKnobs = [];

    for (final p in params) {
      if (p.options.isNotEmpty) {
        currentKnobs.add(EatScriptGuiNode(
          type: EatScriptGuiNodeType.listBox,
          param: p.name,
          label: p.name.toUpperCase(),
          options: p.options,
          width: 140,
          height: 75,
        ));
      } else {
        currentKnobs.add(EatScriptGuiNode(
          type: EatScriptGuiNodeType.knob,
          param: p.name,
          label: p.name.toUpperCase(),
          size: 52,
          knobStyle: defaultKnobStyle,
        ));
      }

      if (currentKnobs.length >= 4) {
        rows.add(EatScriptGuiNode(
          type: EatScriptGuiNodeType.row,
          children: List.from(currentKnobs),
        ));
        currentKnobs.clear();
      }
    }

    if (currentKnobs.isNotEmpty) {
      rows.add(EatScriptGuiNode(
        type: EatScriptGuiNodeType.row,
        children: List.from(currentKnobs),
      ));
    }

    if (rows.isEmpty) {
      rows.add(const EatScriptGuiNode(
        type: EatScriptGuiNodeType.row,
        children: [
          EatScriptGuiNode(type: EatScriptGuiNodeType.knob, param: 'Volume', label: 'VOLUME', size: 52),
          EatScriptGuiNode(type: EatScriptGuiNodeType.knob, param: 'Cutoff', label: 'CUTOFF', size: 52),
          EatScriptGuiNode(type: EatScriptGuiNodeType.knob, param: 'Resonance', label: 'RESO', size: 52),
        ],
      ));
    }

    return EatScriptGuiPanelDef(
      title: title,
      subtitle: subtitle ?? 'Custom Instrument Faceplate',
      backgroundStyle: backgroundStyle,
      accentColor: accentColor ?? const Color(0xFF00E5FF),
      defaultKnobStyle: defaultKnobStyle,
      children: rows,
    );
  }

  /// Ensures that [scriptCode] contains a `function <Name>.gui()` block.
  /// If missing, synthesizes and injects a default panel layout based on the script's parameters.
  static String ensureGuiBlock(String scriptCode, {String instrumentName = 'Instrument'}) {
    if (EatScriptGuiParser.parseFromCode(scriptCode) != null) {
      return scriptCode;
    }
    final compilation = EatScriptEngine.compile(scriptCode).toLuaCompilationResult();
    final defaultPanel = generateDefaultPanel(
      title: instrumentName.isNotEmpty ? instrumentName.toUpperCase() : 'CUSTOM SYNTH',
      params: compilation.params,
    );
    return serialize(
      panel: defaultPanel,
      existingScriptCode: scriptCode,
      instrumentName: instrumentName,
    );
  }

  static void _serializeNode(StringBuffer buffer, EatScriptGuiNode node, {required String indent}) {
    switch (node.type) {
      case EatScriptGuiNodeType.row:
        final rowAlignStr = (node.align != 'space_around' && node.align.isNotEmpty) ? ', align = "${node.align}"' : '';
        final rowCrossStr = (node.crossAlign != 'center' && node.crossAlign.isNotEmpty) ? ', crossAlign = "${node.crossAlign}"' : '';
        final rowBgStr = node.backgroundStyle != null
            ? ', background = "${_backgroundStyleToString(node.backgroundStyle!)}"'
            : (node.backgroundColor != null
                ? ', background = "#${node.backgroundColor!.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}"'
                : '');
        final rowRotStr = (node.textureRotation != null && node.textureRotation != 0.0) ? ', textureRotation = ${node.textureRotation!.toInt()}' : '';
        final rowOpacityStr = node.opacity != null ? ', opacity = ${node.opacity}' : '';
        final rowBorderWidthStr = node.borderWidth != null ? ', borderWidth = ${node.borderWidth}' : '';
        final rowBorderColorStr = node.borderColor != null
            ? ', borderColor = "#${node.borderColor!.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}"'
            : '';
        buffer.writeln('$indent{');
        buffer.writeln('$indent  type = "row"$rowAlignStr$rowCrossStr$rowBgStr$rowRotStr$rowOpacityStr$rowBorderWidthStr$rowBorderColorStr,');
        buffer.writeln('$indent  children = {');
        for (final child in node.children) {
          _serializeNode(buffer, child, indent: '$indent    ');
        }
        buffer.writeln('$indent  }');
        buffer.writeln('$indent},');
        break;

      case EatScriptGuiNodeType.column:
      case EatScriptGuiNodeType.group:
        final typeStr = node.type == EatScriptGuiNodeType.column ? 'column' : 'group';
        final colAlignStr = (node.align != 'space_around' && node.align != 'top' && node.align != 'start' && node.align.isNotEmpty) ? ', align = "${node.align}"' : '';
        final colCrossStr = (node.crossAlign != 'center' && node.crossAlign.isNotEmpty) ? ', crossAlign = "${node.crossAlign}"' : '';
        final labelStr = (node.label != null && node.label!.isNotEmpty) ? ', label = "${_escape(node.label!)}"' : '';
        final groupBgStr = node.backgroundStyle != null
            ? ', background = "${_backgroundStyleToString(node.backgroundStyle!)}"'
            : (node.backgroundColor != null
                ? ', background = "#${node.backgroundColor!.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}"'
                : '');
        final groupRotStr = (node.textureRotation != null && node.textureRotation != 0.0) ? ', textureRotation = ${node.textureRotation!.toInt()}' : '';
        final groupOpacityStr = node.opacity != null ? ', opacity = ${node.opacity}' : '';
        final groupBorderWidthStr = node.borderWidth != null ? ', borderWidth = ${node.borderWidth}' : '';
        final groupBorderColorStr = node.borderColor != null
            ? ', borderColor = "#${node.borderColor!.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}"'
            : '';
        buffer.writeln('$indent{');
        buffer.writeln('$indent  type = "$typeStr"$labelStr$colAlignStr$colCrossStr$groupBgStr$groupRotStr$groupOpacityStr$groupBorderWidthStr$groupBorderColorStr,');
        buffer.writeln('$indent  children = {');
        for (final child in node.children) {
          _serializeNode(buffer, child, indent: '$indent    ');
        }
        buffer.writeln('$indent  }');
        buffer.writeln('$indent},');
        break;

      case EatScriptGuiNodeType.knob:
        final param = node.param ?? 'Param';
        final label = node.label ?? param;
        final unitStr = node.unit != null && node.unit!.isNotEmpty ? ', unit = "${_escape(node.unit!)}"' : '';
        final sizeStr = node.size != null ? ', size = ${node.size!.toInt()}' : '';
        final showLabelStr = !node.showLabel ? ', showLabel = false' : '';
        final showValueStr = !node.showValue ? ', showValue = false' : '';

        if (node.customSkin != null) {
          final skin = node.customSkin!;
          buffer.writeln('$indent{');
          buffer.writeln('$indent  type = "knob", param = "$param", label = "${_escape(label)}"$unitStr$sizeStr, style = "custom"$showLabelStr$showValueStr,');
          buffer.writeln('$indent  chassis = {');
          for (final l in skin.chassisLayers) {
            if (l.type == VectorShapeType.circle) {
              final fill = l.fillColor != null ? ', fill = "${_hex(l.fillColor!)}"' : '';
              final stroke = l.strokeColor != null ? ', stroke = "${_hex(l.strokeColor!)}"' : '';
              buffer.writeln('$indent    { type = "circle", radius = ${l.radius ?? 22.0}$fill$stroke },');
            } else if (l.type == VectorShapeType.radialTicks) {
              final col = l.strokeColor != null ? ', color = "${_hex(l.strokeColor!)}"' : '';
              buffer.writeln('$indent    { type = "ticks", count = ${l.tickCount}, radius = ${l.radius ?? 22.0}, length = ${l.tickLength}$col },');
            } else if (l.type == VectorShapeType.svgPath) {
              buffer.writeln('$indent    { type = "svg_path", data = "${l.svgData ?? ""}" },');
            }
          }
          buffer.writeln('$indent  },');
          buffer.writeln('$indent  indicator = {');
          buffer.writeln('$indent    type = "svg_path",');
          buffer.writeln('$indent    data = "${skin.indicatorLayer.svgData ?? "M -1.5 0 L 0 -19 L 1.5 0 Z"}",');
          if (skin.indicatorLayer.fillColor != null) {
            buffer.writeln('$indent    fill = "${_hex(skin.indicatorLayer.fillColor!)}",');
          }
          buffer.writeln('$indent  }');
          buffer.writeln('$indent},');
        } else {
          String styleStr = '';
          if (node.knobStyle == KnobStyle.hardwareKnob) {
            final hwName = _getHardwarePresetName(node.hardwareKnobStyle);
            styleStr = ', knobStyle = "hardware", style = "$hwName", hardware = "$hwName"';
          } else if (node.knobStyle != KnobStyle.standard) {
            styleStr = ', knobStyle = "${_knobStyleToString(node.knobStyle)}"';
          }
          final capStr = node.capColor != null ? ', capColor = "${_colorStr(node.capColor!)}"' : '';
          final bodyStr = node.bodyColor != null ? ', bodyColor = "${_colorStr(node.bodyColor!)}"' : '';
          final indStr = node.indicatorColor != null ? ', indicatorColor = "${_colorStr(node.indicatorColor!)}"' : '';
          final dialStr = node.dialColor != null ? ', dialColor = "${_colorStr(node.dialColor!)}"' : '';
          final capSizeStr = node.capSize != null ? ', capSize = ${node.capSize}' : '';
          final bodySizeStr = node.bodySize != null ? ', bodySize = ${node.bodySize}' : '';
          final indLenStr = node.indicatorLength != null ? ', indicatorLength = ${node.indicatorLength}' : '';
          final indWidthStr = node.indicatorWidth != null ? ', indicatorWidth = ${node.indicatorWidth}' : '';
          final scaleStr = _getScaleStringLua(node);
          buffer.writeln('$indent{ type = "knob", param = "$param", label = "${_escape(label)}"$unitStr$sizeStr$styleStr$showLabelStr$showValueStr$capStr$bodyStr$indStr$dialStr$capSizeStr$bodySizeStr$indLenStr$indWidthStr$scaleStr },');
        }
        break;

      case EatScriptGuiNodeType.slider:
      case EatScriptGuiNodeType.fader:
        final param = node.param ?? 'Param';
        final label = node.label ?? param;
        final isH = node.orientation == 'horizontal';
        final typeStr = isH ? 'hslider' : 'vslider';
        final widthStr = node.width != null ? ', width = ${node.width!.toInt()}' : (isH ? ', width = 460' : '');
        final heightStr = !isH && node.height != null ? ', height = ${node.height!.toInt()}' : '';
        final styleStr = node.sliderStyle == SliderStyle.console
            ? ', style = "console"'
            : (node.sliderStyle == SliderStyle.minimalPill ? ', style = "minimal_pill"' : ', style = "capsule"');
        final showLabelStr = !node.showLabel ? ', showLabel = false' : '';
        final scaleStr = _getScaleStringLua(node);
        buffer.writeln('$indent{ type = "$typeStr", param = "$param", label = "${_escape(label)}"$widthStr$heightStr$styleStr$showLabelStr$scaleStr },');
        break;

      case EatScriptGuiNodeType.switchToggle:
        final param = node.param ?? 'Switch';
        final label = node.label ?? param;
        final leftStr = node.leftText != null ? ', leftText = "${_escape(node.leftText!)}"' : '';
        final rightStr = node.rightText != null ? ', rightText = "${_escape(node.rightText!)}"' : '';
        final orientStr = node.orientation == 'vertical' ? ', orientation = "vertical"' : '';
        final showLabelStr = !node.showLabel ? ', showLabel = false' : '';
        buffer.writeln('$indent{ type = "switch", param = "$param", label = "${_escape(label)}"$leftStr$rightStr$orientStr$showLabelStr },');
        break;

      case EatScriptGuiNodeType.segmentedPill:
        final param = node.param ?? 'Mode';
        final label = node.label ?? param;
        final optsStr = node.options.isNotEmpty ? ', options = { ${node.options.map((o) => '"${_escape(o)}"').join(', ')} }' : '';
        final showLabelStr = !node.showLabel ? ', showLabel = false' : '';
        buffer.writeln('$indent{ type = "segmented_pill", param = "$param", label = "${_escape(label)}"$optsStr$showLabelStr },');
        break;

      case EatScriptGuiNodeType.button:
        final action = node.action ?? (node.param ?? 'action');
        final label = node.label ?? 'TRIGGER';
        final widthStr = node.width != null ? ', width = ${node.width!.toInt()}' : ', width = 100';
        final heightStr = node.height != null ? ', height = ${node.height!.toInt()}' : ', height = 36';
        buffer.writeln('$indent{ type = "button", action = "$action", label = "${_escape(label)}"$widthStr$heightStr },');
        break;

      case EatScriptGuiNodeType.listBox:
        final param = node.param ?? 'Choice';
        final label = node.label ?? param;
        final widthStr = node.width != null ? ', width = ${node.width!.toInt()}' : ', width = 140';
        final heightStr = node.height != null ? ', height = ${node.height!.toInt()}' : ', height = 80';
        final showLabelStr = !node.showLabel ? ', showLabel = false' : '';
        buffer.writeln('$indent{ type = "listbox", param = "$param", label = "${_escape(label)}"$widthStr$heightStr$showLabelStr },');
        break;

      case EatScriptGuiNodeType.nixie:
        final param = node.param ?? 'Nixie';
        final label = node.label ?? param;
        final unitStr = node.unit != null && node.unit!.isNotEmpty ? ', unit = "${_escape(node.unit!)}"' : '';
        final widthStr = node.width != null ? ', width = ${node.width!.toInt()}' : '';
        final showLabelStr = !node.showLabel ? ', showLabel = false' : '';
        buffer.writeln('$indent{ type = "nixie", param = "$param", label = "${_escape(label)}"$unitStr$widthStr$showLabelStr },');
        break;

      case EatScriptGuiNodeType.lcd:
        final param = node.param ?? 'LCD';
        final label = node.label ?? param;
        buffer.writeln('$indent{ type = "lcd", param = "$param", label = "${_escape(label)}" },');
        break;

      case EatScriptGuiNodeType.spaceVisualizer:
        final heightStr = node.height != null ? ', height = ${node.height!.toInt()}' : ', height = 140';
        buffer.writeln('$indent{ type = "space_visualizer"$heightStr },');
        break;

      case EatScriptGuiNodeType.waveshaperCanvas:
        final heightStr = node.height != null ? ', height = ${node.height!.toInt()}' : ', height = 150';
        buffer.writeln('$indent{ type = "waveshaper_canvas"$heightStr },');
        break;

      case EatScriptGuiNodeType.oscilloscope:
        final widthStr = node.width != null ? ', width = ${node.width!.toInt()}' : ', width = 320';
        final heightStr = node.height != null ? ', height = ${node.height!.toInt()}' : ', height = 140';
        buffer.writeln('$indent{ type = "oscilloscope"$widthStr$heightStr },');
        break;

      case EatScriptGuiNodeType.spectrum:
        final widthStr = node.width != null ? ', width = ${node.width!.toInt()}' : ', width = 320';
        final heightStr = node.height != null ? ', height = ${node.height!.toInt()}' : ', height = 140';
        buffer.writeln('$indent{ type = "spectrum"$widthStr$heightStr },');
        break;

      case EatScriptGuiNodeType.canvas:
        final mode = node.canvasMode;
        final widthStr = node.width != null ? ', width = ${node.width!.toInt()}' : ', width = 340';
        final heightStr = node.height != null ? ', height = ${node.height!.toInt()}' : ', height = 180';
        final dpadStr = node.showDpad ? ', showDpad = true' : '';
        final actionStr = node.showActionButtons ? ', showActionButtons = true' : '';
        buffer.writeln('$indent{ type = "canvas", mode = "$mode"$widthStr$heightStr$dpadStr$actionStr },');
        break;

      case EatScriptGuiNodeType.divider:
        buffer.writeln('$indent{ type = "divider" },');
        break;

      case EatScriptGuiNodeType.label:
        final text = node.text ?? (node.label ?? '');
        buffer.writeln('$indent{ type = "label", text = "${_escape(text)}" },');
        break;

      case EatScriptGuiNodeType.spacer:
        buffer.writeln('$indent{ type = "spacer" },');
        break;

      default:
        break;
    }
  }

  static void _serializeNodeEat(StringBuffer buffer, EatScriptGuiNode node, {required String indent}) {
    switch (node.type) {
      case EatScriptGuiNodeType.row:
      case EatScriptGuiNodeType.column:
      case EatScriptGuiNodeType.group:
        final typeStr = node.type == EatScriptGuiNodeType.row
            ? 'row'
            : (node.type == EatScriptGuiNodeType.column ? 'column' : 'group');
        buffer.writeln('$indent{');
        buffer.writeln('$indent    "type": "$typeStr",');
        if (node.label != null && node.label!.isNotEmpty) {
          buffer.writeln('$indent    "label": "${_escape(node.label!)}",');
        }
        if (node.accentColor != null) {
          buffer.writeln('$indent    "accent": "${_hex(node.accentColor!)}",');
        }
        if (node.backgroundColor != null) {
          buffer.writeln('$indent    "background": "${_hex(node.backgroundColor!)}",');
        } else if (node.backgroundStyle != null) {
          buffer.writeln('$indent    "background": "${_backgroundStyleToString(node.backgroundStyle!)}",');
        }
        if (node.opacity != null) {
          buffer.writeln('$indent    "opacity": ${node.opacity},');
        }
        if (node.borderWidth != null) {
          buffer.writeln('$indent    "borderWidth": ${node.borderWidth},');
        }
        if (node.borderColor != null) {
          buffer.writeln('$indent    "borderColor": "${_hex(node.borderColor!)}",');
        }
        if (node.width != null) {
          buffer.writeln('$indent    "width": ${node.width!.toInt()},');
        }
        if (node.height != null) {
          buffer.writeln('$indent    "height": ${node.height!.toInt()},');
        }
        if (node.orientation != null) {
          buffer.writeln('$indent    "orientation": "${node.orientation}",');
        }
        if (node.align != null) {
          buffer.writeln('$indent    "align": "${node.align}",');
        }
        if (node.crossAlign != null) {
          buffer.writeln('$indent    "crossAlign": "${node.crossAlign}",');
        }
        if (node.cornerRadius != null) {
          buffer.writeln('$indent    "cornerRadius": ${node.cornerRadius!.toInt()},');
        }
        buffer.writeln('$indent    "children": [');
        for (final c in node.children) {
          _serializeNodeEat(buffer, c, indent: '$indent        ');
        }
        buffer.writeln('$indent    ],');
        buffer.writeln('$indent},');
        break;

      case EatScriptGuiNodeType.knob:
        final param = node.param ?? 'Param';
        final label = node.label ?? param;
        final unitStr = node.unit != null && node.unit!.isNotEmpty ? ', "unit": "${_escape(node.unit!)}"' : '';
        final sizeStr = node.size != null ? ', "size": ${node.size!.toInt()}' : '';
        final showLabelStr = !node.showLabel ? ', "showLabel": False' : '';
        final showValueStr = !node.showValue ? ', "showValue": False' : '';
        final accentStr = node.accentColor != null ? ', "accent": "${_hex(node.accentColor!)}"' : '';

        if (node.customSkin != null) {
          final skin = node.customSkin!;
          buffer.writeln('$indent{');
          buffer.writeln('$indent    "type": "knob", "param": "$param", "label": "${_escape(label)}"$unitStr$sizeStr, "style": "custom"$showLabelStr$showValueStr$accentStr,');
          buffer.writeln('$indent    "skin": {');
          buffer.writeln('$indent        "chassis": [');
          for (final l in skin.chassisLayers) {
            if (l.type == VectorShapeType.circle) {
              final fill = l.fillColor != null ? ', "fill": "${_hex(l.fillColor!)}"' : '';
              final stroke = l.strokeColor != null ? ', "stroke": "${_hex(l.strokeColor!)}"' : '';
              buffer.writeln('$indent            {"type": "circle", "radius": ${l.radius ?? 22.0}$fill$stroke},');
            } else if (l.type == VectorShapeType.radialTicks) {
              final col = l.strokeColor != null ? ', "color": "${_hex(l.strokeColor!)}"' : '';
              buffer.writeln('$indent            {"type": "ticks", "count": ${l.tickCount}, "radius": ${l.radius ?? 22.0}, "length": ${l.tickLength}$col},');
            } else if (l.type == VectorShapeType.svgPath) {
              buffer.writeln('$indent            {"type": "svg_path", "data": "${l.svgData ?? ""}"},');
            }
          }
          buffer.writeln('$indent        ],');
          buffer.writeln('$indent        "indicator": {');
          buffer.writeln('$indent            "type": "svg_path",');
          buffer.writeln('$indent            "data": "${skin.indicatorLayer.svgData ?? "M -1.5 0 L 0 -19 L 1.5 0 Z"}",');
          if (skin.indicatorLayer.fillColor != null) {
            buffer.writeln('$indent            "fill": "${_hex(skin.indicatorLayer.fillColor!)}",');
          }
          buffer.writeln('$indent        },');
          buffer.writeln('$indent    },');
          buffer.writeln('$indent},');
        } else {
          String styleStr = '';
          if (node.knobStyle == KnobStyle.hardwareKnob) {
            final hwName = _getHardwarePresetName(node.hardwareKnobStyle);
            styleStr = ', "knobStyle": "hardware", "style": "$hwName", "hardware": "$hwName"';
          } else if (node.knobStyle != KnobStyle.standard) {
            styleStr = ', "knobStyle": "${_knobStyleToString(node.knobStyle)}"';
          }
          final capStr = node.capColor != null ? ', "capColor": "${_colorStr(node.capColor!)}"' : '';
          final bodyStr = node.bodyColor != null ? ', "bodyColor": "${_colorStr(node.bodyColor!)}"' : '';
          final indStr = node.indicatorColor != null ? ', "indicatorColor": "${_colorStr(node.indicatorColor!)}"' : '';
          final dialStr = node.dialColor != null ? ', "dialColor": "${_colorStr(node.dialColor!)}"' : '';
          final capSizeStr = node.capSize != null ? ', "capSize": ${node.capSize}' : '';
          final bodySizeStr = node.bodySize != null ? ', "bodySize": ${node.bodySize}' : '';
          final indLenStr = node.indicatorLength != null ? ', "indicatorLength": ${node.indicatorLength}' : '';
          final indWidthStr = node.indicatorWidth != null ? ', "indicatorWidth": ${node.indicatorWidth}' : '';
          final scaleStr = _getScaleStringEat(node);
          buffer.writeln('$indent{"type": "knob", "param": "$param", "label": "${_escape(label)}"$unitStr$sizeStr$styleStr$showLabelStr$showValueStr$accentStr$capStr$bodyStr$indStr$dialStr$capSizeStr$bodySizeStr$indLenStr$indWidthStr$scaleStr},');
        }
        break;

      case EatScriptGuiNodeType.slider:
      case EatScriptGuiNodeType.fader:
        final param = node.param ?? 'Param';
        final label = node.label ?? param;
        final isH = node.orientation == 'horizontal';
        final typeStr = isH ? 'hslider' : 'vslider';
        final widthStr = node.width != null ? ', "width": ${node.width!.toInt()}' : (isH ? ', "width": 460' : '');
        final heightStr = !isH && node.height != null ? ', "height": ${node.height!.toInt()}' : '';
        final styleStr = node.sliderStyle == SliderStyle.console
            ? ', "style": "console"'
            : (node.sliderStyle == SliderStyle.minimalPill ? ', "style": "minimal_pill"' : ', "style": "capsule"');
        final showLabelStr = !node.showLabel ? ', "showLabel": False' : '';
        final accentStr = node.accentColor != null ? ', "accent": "${_hex(node.accentColor!)}"' : '';
        final scaleStr = _getScaleStringEat(node);
        buffer.writeln('$indent{"type": "$typeStr", "param": "$param", "label": "${_escape(label)}"$widthStr$heightStr$styleStr$showLabelStr$accentStr$scaleStr},');
        break;

      case EatScriptGuiNodeType.switchToggle:
        final param = node.param ?? 'Switch';
        final label = node.label ?? param;
        final leftStr = node.leftText != null ? ', "leftText": "${_escape(node.leftText!)}"' : '';
        final rightStr = node.rightText != null ? ', "rightText": "${_escape(node.rightText!)}"' : '';
        final orientStr = node.orientation == 'vertical' ? ', "orientation": "vertical"' : '';
        final showLabelStr = !node.showLabel ? ', "showLabel": False' : '';
        buffer.writeln('$indent{"type": "switch", "param": "$param", "label": "${_escape(label)}"$leftStr$rightStr$orientStr$showLabelStr},');
        break;

      case EatScriptGuiNodeType.segmentedPill:
        final param = node.param ?? 'Mode';
        final label = node.label ?? param;
        final optsStr = node.options.isNotEmpty ? ', "options": [${node.options.map((o) => '"${_escape(o)}"').join(', ')}]' : '';
        final showLabelStr = !node.showLabel ? ', "showLabel": False' : '';
        buffer.writeln('$indent{"type": "segmented_pill", "param": "$param", "label": "${_escape(label)}"$optsStr$showLabelStr},');
        break;

      case EatScriptGuiNodeType.button:
        final action = node.action ?? (node.param ?? 'action');
        final label = node.label ?? 'TRIGGER';
        final widthStr = node.width != null ? ', "width": ${node.width!.toInt()}' : ', "width": 100';
        final heightStr = node.height != null ? ', "height": ${node.height!.toInt()}' : ', "height": 36';
        buffer.writeln('$indent{"type": "button", "action": "$action", "label": "${_escape(label)}"$widthStr$heightStr},');
        break;

      case EatScriptGuiNodeType.listBox:
        final param = node.param ?? 'Choice';
        final label = node.label ?? param;
        final widthStr = node.width != null ? ', "width": ${node.width!.toInt()}' : ', "width": 140';
        final heightStr = node.height != null ? ', "height": ${node.height!.toInt()}' : ', "height": 80';
        final optsStr = node.options.isNotEmpty ? ', "options": [${node.options.map((o) => '"${_escape(o)}"').join(', ')}]' : '';
        final showLabelStr = !node.showLabel ? ', "showLabel": False' : '';
        buffer.writeln('$indent{"type": "listbox", "param": "$param", "label": "${_escape(label)}"$widthStr$heightStr$optsStr$showLabelStr},');
        break;

      case EatScriptGuiNodeType.nixie:
        final param = node.param ?? 'Nixie';
        final label = node.label ?? param;
        final unitStr = node.unit != null && node.unit!.isNotEmpty ? ', "unit": "${_escape(node.unit!)}"' : '';
        final widthStr = node.width != null ? ', "width": ${node.width!.toInt()}' : '';
        final showLabelStr = !node.showLabel ? ', "showLabel": False' : '';
        buffer.writeln('$indent{"type": "nixie", "param": "$param", "label": "${_escape(label)}"$unitStr$widthStr$showLabelStr},');
        break;

      case EatScriptGuiNodeType.lcd:
        final param = node.param ?? 'LCD';
        final label = node.label ?? param;
        buffer.writeln('$indent{"type": "lcd", "param": "$param", "label": "${_escape(label)}"},');
        break;

      case EatScriptGuiNodeType.spaceVisualizer:
        final heightStr = node.height != null ? ', "height": ${node.height!.toInt()}' : ', "height": 140';
        buffer.writeln('$indent{"type": "space_visualizer"$heightStr},');
        break;

      case EatScriptGuiNodeType.waveshaperCanvas:
        final heightStr = node.height != null ? ', "height": ${node.height!.toInt()}' : ', "height": 150';
        buffer.writeln('$indent{"type": "waveshaper_canvas"$heightStr},');
        break;

      case EatScriptGuiNodeType.oscilloscope:
        final widthStr = node.width != null ? ', "width": ${node.width!.toInt()}' : ', "width": 320';
        final heightStr = node.height != null ? ', "height": ${node.height!.toInt()}' : ', "height": 140';
        buffer.writeln('$indent{"type": "oscilloscope"$widthStr$heightStr},');
        break;

      case EatScriptGuiNodeType.spectrum:
        final widthStr = node.width != null ? ', "width": ${node.width!.toInt()}' : ', "width": 320';
        final heightStr = node.height != null ? ', "height": ${node.height!.toInt()}' : ', "height": 140';
        buffer.writeln('$indent{"type": "spectrum"$widthStr$heightStr},');
        break;

      case EatScriptGuiNodeType.canvas:
        final mode = node.canvasMode;
        final widthStr = node.width != null ? ', "width": ${node.width!.toInt()}' : ', "width": 340';
        final heightStr = node.height != null ? ', "height": ${node.height!.toInt()}' : ', "height": 180';
        final dpadStr = node.showDpad ? ', "showDpad": True' : '';
        final actionStr = node.showActionButtons ? ', "showActionButtons": True' : '';
        buffer.writeln('$indent{"type": "canvas", "mode": "$mode"$widthStr$heightStr$dpadStr$actionStr},');
        break;

      case EatScriptGuiNodeType.divider:
        buffer.writeln('$indent{"type": "divider"},');
        break;

      case EatScriptGuiNodeType.label:
        final text = node.text ?? (node.label ?? '');
        buffer.writeln('$indent{"type": "label", "text": "${_escape(text)}"},');
        break;

      case EatScriptGuiNodeType.spacer:
        buffer.writeln('$indent{"type": "spacer"},');
        break;

      default:
        break;
    }
  }

  static String _escape(String s) => s.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n');

  static String _backgroundStyleToString(PanelBackgroundStyle style) {
    switch (style) {
      case PanelBackgroundStyle.silver:
        return 'silver';
      case PanelBackgroundStyle.grunge:
        return 'grunge';
      case PanelBackgroundStyle.snes:
        return 'snes';
      case PanelBackgroundStyle.walnut:
        return 'walnut';
      case PanelBackgroundStyle.mahogany:
        return 'mahogany';
      case PanelBackgroundStyle.blondePine:
        return 'blonde_pine';
      case PanelBackgroundStyle.rosewood:
        return 'rosewood';
      case PanelBackgroundStyle.brushedSteel:
        return 'brushed_steel';
      case PanelBackgroundStyle.brushedSteelVert:
        return 'brushed_steel_vert';
      case PanelBackgroundStyle.matteMetal:
        return 'matte_metal';
      case PanelBackgroundStyle.tolex:
        return 'tolex';
      case PanelBackgroundStyle.carbon:
        return 'carbon';
      case PanelBackgroundStyle.mesh:
        return 'mesh';
      case PanelBackgroundStyle.minimalWhite:
        return 'minimal_white';
      case PanelBackgroundStyle.pcbGreen:
        return 'pcb_green';
      case PanelBackgroundStyle.custom:
        return 'custom';
      case PanelBackgroundStyle.dark:
      default:
        return 'dark';
    }
  }

  static String _knobStyleToString(KnobStyle style) {
    switch (style) {
      case KnobStyle.chrome:
        return 'chrome';
      case KnobStyle.vintage:
        return 'vintage';
      case KnobStyle.snes:
        return 'snes';
      case KnobStyle.minimalWhite:
        return 'minimal_white';
      case KnobStyle.customVector:
        return 'custom';
      case KnobStyle.hardwareKnob:
        return 'hardware';
      case KnobStyle.standard:
      default:
        return 'standard';
    }
  }

  static String _getHardwarePresetName(EatHardwareKnobStyle? style) {
    if (style == null) return 'vintage_bakelite';
    if (style.capStyle == EatCapStyle.diagonalBar) return 'tb303_selector';
    if (style.haloColor != null) return 'tb303_acid_halo';
    if (style.knurlStyle == EatKnurlStyle.fineSawtooth) return 'tb303_potentiometer';
    if (style.indicatorColor == const Color(0xFF51388E)) return 'snes_console';
    if (style.capColor == const Color(0xFFF6F6F7)) return 'minimal_white';
    if (style.capColor == const Color(0xFF1E2026)) return 'standard_hardware';
    if (style.capColor == const Color(0xFFDCDFE5)) return 'chrome_fluted';
    if (style.knurlStyle == EatKnurlStyle.fluted) return 'cream_fluted';
    if (style.knurlStyle == EatKnurlStyle.diamond) return 'anodized_knurled';
    if (style.skirtStyle == EatSkirtStyle.stepped) return 'two_tone_stepped';
    if (style.indicatorStyle == EatIndicatorStyle.illuminatedLed) return 'encoder';
    return 'vintage_bakelite';
  }

  static String _tileModeToString(SvgTileMode mode) {
    switch (mode) {
      case SvgTileMode.x:
        return 'x';
      case SvgTileMode.y:
        return 'y';
      case SvgTileMode.xy:
        return 'xy';
      case SvgTileMode.none:
      default:
        return 'none';
    }
  }

  static String _hex(Color c) => '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  static String _colorStr(Color c) {
    if (EatScriptGuiNode.isTrackColor(c)) return 'track';
    return _hex(c);
  }

  static String? _getScalePresetString(EatScaleGraduation scale) {
    if (scale.labels.contains('CLASSIC')) return 'mode_steps';
    if (scale.labels.contains('low') && scale.labels.contains('mid') && scale.labels.contains('high')) return 'low_mid_high';
    if (scale.leadLabel == 'dyn' || (scale.labels.isNotEmpty && scale.labels.first == '1' && scale.labels.last == '6')) return '1_to_6';
    if (scale.hasBlockCenterDetent) return 'tb303_dial';
    if (scale.labels.contains('+6') && scale.labels.contains('-inf')) return 'db';
    if (scale.labels.length == 11 && scale.labels.first == '0' && scale.labels.last == '10') return '0_to_10';
    if (scale.labels.contains('0') && scale.hasCenterDetent && scale.labels.contains('-5')) return 'bipolar';
    if (scale.tickDivisions == 0 && scale.labels.isEmpty) return 'none';
    if (scale.labels.isEmpty && scale.tickDivisions > 0) return 'clean_ticks';
    return null;
  }

  static String _getScaleStringEat(EatScriptGuiNode node) {
    final scale = node.hardwareScale ?? (node.knobStyle == KnobStyle.hardwareKnob ? node.hardwareKnobStyle?.scale : null);
    if (scale == null) return '';

    final preset = _getScalePresetString(scale);
    if (node.knobStyle == KnobStyle.hardwareKnob) {
      final hwName = _getHardwarePresetName(node.hardwareKnobStyle);
      if (node.hardwareScale == null) {
        if (hwName == 'tb303_selector' && preset == 'mode_steps') return '';
        if (hwName == 'tb303_potentiometer' && preset == 'tb303_dial') return '';
        if ((hwName == 'standard_hardware' || hwName == 'encoder') && preset == 'clean_ticks') return '';
        if (hwName != 'tb303_selector' && hwName != 'tb303_potentiometer' && hwName != 'standard_hardware' && hwName != 'encoder' && preset == '0_to_10') return '';
      } else {
        if (hwName == 'tb303_selector' && preset == 'mode_steps') return '';
        if (hwName == 'tb303_potentiometer' && preset == 'tb303_dial') return '';
      }
    }

    if (preset != null) {
      return ', "scale": "$preset"';
    } else if (scale.labels.isNotEmpty) {
      final labelsStr = scale.labels.map((l) => '"${_escape(l)}"').join(', ');
      return ', "scale": [$labelsStr]';
    }
    return '';
  }

  static String _getScaleStringLua(EatScriptGuiNode node) {
    final scale = node.hardwareScale ?? (node.knobStyle == KnobStyle.hardwareKnob ? node.hardwareKnobStyle?.scale : null);
    if (scale == null) return '';

    final preset = _getScalePresetString(scale);
    if (node.knobStyle == KnobStyle.hardwareKnob) {
      final hwName = _getHardwarePresetName(node.hardwareKnobStyle);
      if (node.hardwareScale == null) {
        if (hwName == 'tb303_selector' && preset == 'mode_steps') return '';
        if (hwName == 'tb303_potentiometer' && preset == 'tb303_dial') return '';
        if ((hwName == 'standard_hardware' || hwName == 'encoder') && preset == 'clean_ticks') return '';
        if (hwName != 'tb303_selector' && hwName != 'tb303_potentiometer' && hwName != 'standard_hardware' && hwName != 'encoder' && preset == '0_to_10') return '';
      } else {
        if (hwName == 'tb303_selector' && preset == 'mode_steps') return '';
        if (hwName == 'tb303_potentiometer' && preset == 'tb303_dial') return '';
      }
    }

    if (preset != null) {
      return ', scale = "$preset"';
    } else if (scale.labels.isNotEmpty) {
      final labelsStr = scale.labels.map((l) => '"${_escape(l)}"').join(', ');
      return ', scale = { $labelsStr }';
    }
    return '';
  }
}

