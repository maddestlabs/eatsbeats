import 'dart:math' as math;
import 'dart:ui';
import '../ui/vector/vector_skin_model.dart';
import '../ui/hardware/eat_hardware_knob_model.dart';
import '../ui/hardware/eat_hardware_scale.dart';
import '../eatscript/eat_script_engine.dart';
import 'eats_lua_parser.dart';
import 'lua_gui_model.dart';

typedef EatScriptGuiParser = LuaGuiParser;

class LuaGuiParser {
  /// Extracts and parses the `LuaGuiPanelDef` from a Lua or EatScript string, if present.
  static LuaGuiPanelDef? parseFromCode(String luaCode) {
    if (!luaCode.contains('gui') && !luaCode.contains('GUI') && !luaCode.contains('panel') && !luaCode.contains('layout')) {
      return null;
    }

    if (EatScriptEngine.isEatScript(luaCode)) {
      final comp = EatScriptEngine.compile(luaCode);
      if (comp.guiLayout != null) {
        return comp.guiLayout;
      }
    }

    try {
      // 1. Locate the GUI table block in the code
      final tableStr = _extractGuiTableString(luaCode);
      if (tableStr == null || tableStr.trim().isEmpty) {
        return null;
      }

      final parsed = EatsLuaParser.parseLuaTableToMap(tableStr);
      if (parsed.isEmpty) return null;

      return parseFromMap(parsed);
    } catch (_) {
      return null;
    }
  }

  /// Parses a [LuaGuiPanelDef] directly from a decoded Map (e.g. from Eatscript or Lua parser).
  static LuaGuiPanelDef? parseFromMap(Map<String, dynamic> parsed) {
    if (parsed.isEmpty) return null;

    try {
      // Handle both { panel = { title = "...", layout = {...} } } and { title = "...", layout = {...} }
      Map<String, dynamic> panelMap = parsed;
      if (parsed['panel'] is Map) {
        panelMap = Map<String, dynamic>.from(parsed['panel']);
      }

      final title = (panelMap['title'] as String?) ?? 'CUSTOM INSTRUMENT';
      final subtitle = panelMap['subtitle'] as String?;
      final style = (panelMap['style'] as String?) ?? 'rack';
      final bgRaw = panelMap['background'] ?? panelMap['bg'] ?? panelMap['chassis'] ?? panelMap['theme'] ?? panelMap['style'] ?? panelMap['texture'];
      final backgroundStyle = LuaGuiNode.parseBackgroundStyle(bgRaw is String ? bgRaw : null);
      final backgroundColor = LuaGuiNode.parseColor(bgRaw);
      final accentRaw = panelMap['accent'] ?? panelMap['accentColor'] ?? panelMap['color'];
      final accentColor = (accentRaw is String && accentRaw.toLowerCase() == 'track')
          ? null
          : LuaGuiNode.parseColor(accentRaw);
      final knobStyleRaw = panelMap['knobStyle'] ?? panelMap['knobs'] ?? panelMap['knob_style'];
      final defaultKnobStyle = LuaGuiNode.parseKnobStyle(knobStyleRaw is String ? knobStyleRaw : (backgroundStyle == PanelBackgroundStyle.silver ? 'chrome' : null));
      final textureRotation = (panelMap['textureRotation'] as num?)?.toDouble() ??
          (panelMap['rotation'] as num?)?.toDouble() ??
          0.0;
      final textureScale = (panelMap['textureScale'] as num?)?.toDouble() ??
          (panelMap['scale'] as num?)?.toDouble() ??
          1.0;
      final sideCheeks = (panelMap['rackSides'] as String?) ??
          (panelMap['rack_sides'] as String?) ??
          (panelMap['sideCheeks'] as String?) ??
          (panelMap['side_cheeks'] as String?) ??
          (panelMap['sides'] as String?) ??
          (panelMap['cheeks'] as String?) ??
          (panelMap['sidePanels'] as String?);

      final cornerRadius = (panelMap['cornerRadius'] as num?)?.toDouble() ??
          (panelMap['corner_radius'] as num?)?.toDouble() ??
          (panelMap['radius'] as num?)?.toDouble();

      final backgroundSvg = (panelMap['backgroundSvg'] as String?) ??
          (panelMap['bgSvg'] as String?) ??
          (panelMap['svgBackground'] as String?) ??
          (panelMap['vectorBackground'] as String?);
      final backgroundSvgOpacity = (panelMap['backgroundSvgOpacity'] as num?)?.toDouble() ??
          (panelMap['bgSvgOpacity'] as num?)?.toDouble() ??
          0.20;
      final backgroundSvgStrokeWidth = (panelMap['backgroundSvgStrokeWidth'] as num?)?.toDouble() ??
          (panelMap['bgSvgStrokeWidth'] as num?)?.toDouble() ??
          (panelMap['svgStrokeWidth'] as num?)?.toDouble() ??
          (panelMap['strokeWidth'] as num?)?.toDouble();

      final backgroundSvgTileRaw = panelMap['backgroundSvgTile'] ??
          panelMap['bgSvgTile'] ??
          panelMap['svgTile'] ??
          panelMap['tile'] ??
          panelMap['repeat'];
      final backgroundSvgTile = LuaGuiNode.parseSvgTileMode(backgroundSvgTileRaw);

      LuaGuiGradientDef? backgroundGradient;
      final gradRaw = panelMap['backgroundGradient'] ?? panelMap['gradient'];
      if (gradRaw is Map) {
        final gradMap = Map<String, dynamic>.from(gradRaw);
        final typeStr = (gradMap['type'] as String?)?.toLowerCase() ?? 'radial';
        final type = typeStr == 'linear' ? PanelGradientType.linear : PanelGradientType.radial;
        final rawColors = gradMap['colors'];
        final List<Color> colors = [];
        if (rawColors is List) {
          for (final c in rawColors) {
            final parsedCol = LuaGuiNode.parseColor(c);
            if (parsedCol != null) colors.add(parsedCol);
          }
        }
        if (colors.length >= 2) {
          final stops = (gradMap['stops'] is List)
              ? (gradMap['stops'] as List).map((s) => (s as num).toDouble()).toList()
              : null;
          final radius = (gradMap['radius'] as num?)?.toDouble() ?? 1.0;
          backgroundGradient = LuaGuiGradientDef(
            type: type,
            colors: colors,
            stops: stops,
            radius: radius,
          );
        }
      }

      List<SvgLayerDef>? backgroundSvgLayers;
      final layersRaw = panelMap['backgroundSvgLayers'] ?? panelMap['svgLayers'] ?? panelMap['layers'];
      if (layersRaw is List) {
        final List<SvgLayerDef> layers = [];
        for (final item in layersRaw) {
          if (item is Map) {
            final path = (item['path'] as String?) ?? (item['d'] as String?) ?? '';
            if (path.trim().isNotEmpty) {
              final color = LuaGuiNode.parseColor(item['color'] ?? item['tint'] ?? item['strokeColor'] ?? item['fillColor']);
              final strokeWidth = (item['strokeWidth'] as num?)?.toDouble() ?? (item['stroke'] as num?)?.toDouble();
              final styleStr = (item['style'] as String?)?.toLowerCase() ?? (item['mode'] as String?)?.toLowerCase() ?? 'stroke';
              final style = styleStr == 'fill' ? SvgLayerStyle.fill : SvgLayerStyle.stroke;
              final opacity = (item['opacity'] as num?)?.toDouble() ?? 1.0;
              final layerTileRaw = item['tile'] ?? item['repeat'] ?? item['tileMode'];
              final layerTile = layerTileRaw != null ? LuaGuiNode.parseSvgTileMode(layerTileRaw) : backgroundSvgTile;
              layers.add(SvgLayerDef(
                path: path,
                color: color,
                strokeWidth: strokeWidth,
                style: style,
                opacity: opacity,
                tileMode: layerTile,
              ));
            }
          }
        }
        if (layers.isNotEmpty) backgroundSvgLayers = layers;
      }

      final rawLayout = panelMap['layout'] ?? panelMap['children'] ?? panelMap['items'];
      final List<LuaGuiNode> nodes = [];

      if (rawLayout is List) {
        for (final item in rawLayout) {
          final node = _parseNode(item, defaultKnobStyle);
          if (node != null) nodes.add(node);
        }
      } else if (rawLayout is Map) {
        final node = _parseNode(rawLayout, defaultKnobStyle);
        if (node != null) nodes.add(node);
      }

      return LuaGuiPanelDef(
        title: title,
        subtitle: subtitle,
        style: style,
        backgroundStyle: backgroundStyle,
        backgroundColor: backgroundColor,
        accentColor: accentColor,
        defaultKnobStyle: defaultKnobStyle,
        textureRotation: textureRotation,
        textureScale: textureScale,
        sideCheeks: sideCheeks,
        cornerRadius: cornerRadius,
        backgroundSvg: backgroundSvg,
        backgroundSvgOpacity: backgroundSvgOpacity,
        backgroundSvgStrokeWidth: backgroundSvgStrokeWidth,
        backgroundSvgTile: backgroundSvgTile,
        backgroundGradient: backgroundGradient,
        backgroundSvgLayers: backgroundSvgLayers,
        children: nodes,
      );


    } catch (_) {
      return null;
    }
  }

  static String? _extractGuiTableString(String code) {
    // 1. Look for `function ...gui` or `def ...gui` followed by `return`
    final funcMatch = RegExp(
      r'(?:function\s+[\w\.:]*gui|def\s+[\w\.:]*gui)\s*\([^)]*\)[^:]*?:?[\s\S]*?return\s*\{',
      caseSensitive: false,
    ).firstMatch(code);
    if (funcMatch != null) {
      final matchedStr = funcMatch.group(0)!;
      final returnIdx = funcMatch.start + matchedStr.toLowerCase().lastIndexOf('return');
      final braceIdx = code.indexOf('{', returnIdx);
      if (braceIdx != -1) {
        return _extractBalancedTable(code, braceIdx);
      }
    }

    // 2. Look for `GUI\s*=\s*\{` or `local\s+GUI\s*=\s*\{` or `\w+\.gui\s*=\s*\{` or `gui\s*=\s*\{`
    final guiAssignMatch = RegExp(r'(?:local\s+)?(?:[\w\.]+\.)?gui\s*=\s*\{', caseSensitive: false).firstMatch(code);
    if (guiAssignMatch != null) {
      final braceIdx = code.indexOf('{', guiAssignMatch.start);
      if (braceIdx != -1) {
        return _extractBalancedTable(code, braceIdx);
      }
    }

    // 3. Look for `@gui:\s*\{`
    final commentGuiMatch = RegExp(r'(?:--|#)\s*@gui:\s*\{', caseSensitive: false).firstMatch(code);
    if (commentGuiMatch != null) {
      final braceIdx = code.indexOf('{', commentGuiMatch.start);
      if (braceIdx != -1) {
        return _extractBalancedTable(code, braceIdx);
      }
    }

    return null;
  }

  static String? _extractBalancedTable(String code, int searchFrom) {
    final startBrace = code.indexOf('{', searchFrom);
    if (startBrace == -1) return null;

    int depth = 0;
    int pos = startBrace;
    bool inQuote = false;
    String quoteChar = '';

    while (pos < code.length) {
      final c = code[pos];

      if (inQuote) {
        if (c == quoteChar && (pos == 0 || code[pos - 1] != '\\')) {
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
          if (depth == 0) {
            return code.substring(startBrace, pos + 1);
          }
        }
      }
      pos++;
    }

    return null;
  }

  static LuaGuiNode? _parseNode(dynamic raw, [KnobStyle defaultKnobStyle = KnobStyle.standard]) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);

    final rawType = (m['type'] as String?) ?? (m['widget'] as String?);
    final type = LuaGuiNode.parseType(rawType);
    if (type == LuaGuiNodeType.unknown) return null;

    final param = m['param'] as String? ?? m['name'] as String?;
    final label = m['label'] as String? ?? m['title'] as String? ?? param;
    final unit = m['unit'] as String?;
    final size = (m['size'] as num?)?.toDouble();
    final accentColor = LuaGuiNode.parseColor(m['accent'] ?? m['accentColor'] ?? m['color']);
    final cleanType = (rawType ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final isExplicitHSlider = cleanType == 'hslider' || cleanType == 'horizontalslider' || cleanType == 'hslider';
    final isExplicitVSlider = cleanType == 'vslider' || cleanType == 'verticalslider' || cleanType == 'fader';
    final defaultOrientation = isExplicitHSlider ? 'horizontal' : (isExplicitVSlider ? 'vertical' : (type == LuaGuiNodeType.slider ? 'horizontal' : 'vertical'));
    final orientation = (m['orientation'] as String?) ?? defaultOrientation;
    final align = (m['align'] as String?) ?? 'space_around';
    final crossAlign = (m['crossAlign'] as String?) ?? (m['crossAxisAlignment'] as String?) ?? 'center';
    final leftText = m['left'] as String? ?? m['leftText'] as String?;
    final rightText = m['right'] as String? ?? m['rightText'] as String?;
    final text = m['text'] as String?;
    final action = m['action'] as String? ?? m['onClick'] as String? ?? m['callback'] as String?;
    final knobStyle = m['knobStyle'] != null || m['style'] != null
        ? LuaGuiNode.parseKnobStyle((m['knobStyle'] ?? m['style']) as String?)
        : defaultKnobStyle;
    final sliderStyle = LuaGuiNode.parseSliderStyle((m['sliderStyle'] ?? m['style']) as String?);

    final width = (m['width'] is num) ? (m['width'] as num).toDouble() : null;
    final height = (m['height'] is num) ? (m['height'] as num).toDouble() : null;

    final canvasMode = (m['mode'] as String?) ?? (m['canvasMode'] as String?) ?? 'pixel';
    final cols = (m['cols'] as num?)?.toInt() ?? (m['columns'] as num?)?.toInt() ?? (m['gridCols'] as num?)?.toInt() ?? 32;
    final rows = (m['rows'] as num?)?.toInt() ?? (m['gridRows'] as num?)?.toInt() ?? 24;
    final scale = (m['scale'] is num) ? (m['scale'] as num).toDouble() : 1.0;
    final showDpad = (m['showDpad'] == true) || (m['dpad'] == true) || (m['touchControls'] == true);
    final showActionButtons = (m['showActionButtons'] == true) || (m['gamepad'] == true) || (m['buttons'] == true);
    final showLabel = m['showLabel'] == false || m['hideLabel'] == true ? false : true;
    final showValue = m['showValue'] == false || m['hideValue'] == true ? false : true;

    List<Color> palette = [];
    final rawPalette = m['palette'] ?? m['colors'];
    if (rawPalette is List) {
      for (final p in rawPalette) {
        final c = LuaGuiNode.parseColor(p);
        if (c != null) palette.add(c);
      }
    }

    List<String> options = [];
    if (m['options'] is List) {
      options = (m['options'] as List).map((e) => e.toString()).toList();
    }

    List<LuaGuiNode> children = [];
    final rawChildren = m['children'] ?? m['items'] ?? m['__list'];
    if (rawChildren is List) {
      for (final childRaw in rawChildren) {
        final childNode = _parseNode(childRaw, defaultKnobStyle);
        if (childNode != null) children.add(childNode);
      }
    }

    final bgRaw = m['background'] ?? m['bg'] ?? m['texture'] ?? m['theme'];
    final nodeBgStyle = bgRaw is String ? LuaGuiNode.parseBackgroundStyle(bgRaw) : null;
    final nodeBgColor = LuaGuiNode.parseColor(bgRaw) ?? LuaGuiNode.parseColor(m['backgroundColor'] ?? m['color']);
    final nodeTexRot = (m['textureRotation'] as num?)?.toDouble() ?? (m['rotation'] as num?)?.toDouble();
    final nodeTexScale = (m['textureScale'] as num?)?.toDouble() ?? (m['bgScale'] as num?)?.toDouble();
    final nodeCornerRadius = (m['cornerRadius'] as num?)?.toDouble() ?? (m['radius'] as num?)?.toDouble();
    final opacity = (m['opacity'] as num?)?.toDouble() ??
        (m['bgOpacity'] as num?)?.toDouble() ??
        (m['backgroundOpacity'] as num?)?.toDouble();
    final borderWidth = (m['borderWidth'] as num?)?.toDouble() ??
        (m['border'] as num?)?.toDouble();
    final borderColor = LuaGuiNode.parseColor(m['borderColor'] ?? m['border_color']);

    CustomControlSkin? customSkin;
    final rawSkin = m['skin'] ?? m['customSkin'] ?? m['vectorSkin'];
    if (rawSkin is Map) {
      customSkin = CustomControlSkin.fromMap(param ?? 'custom', Map<String, dynamic>.from(rawSkin));
    } else if (m.containsKey('chassis') || m.containsKey('indicator')) {
      customSkin = CustomControlSkin.fromMap(param ?? 'custom', m);
    }

    // Parse EatScript 6-Zone Hardware Knob styling
    EatHardwareKnobStyle? hardwareKnobStyle;
    final hwRaw = m['hardware'] ?? m['hardwareStyle'] ?? m['knobModel'] ?? m['hardwareKnob'];
    final styleStr = ((m['knobStyle'] ?? m['style'] ?? '') as String).toLowerCase();
    final hwStr = (hwRaw?.toString() ?? styleStr).toLowerCase();

    final isHardware = knobStyle == KnobStyle.hardwareKnob ||
        hwRaw != null ||
        styleStr.contains('hardware') ||
        styleStr.contains('fluted') ||
        styleStr.contains('bakelite') ||
        styleStr.contains('knurled') ||
        styleStr.contains('stepped') ||
        styleStr.contains('twotone') ||
        styleStr.contains('chrome') ||
        styleStr.contains('snes') ||
        styleStr.contains('minimal') ||
        hwStr.contains('hardware') ||
        hwStr.contains('fluted') ||
        hwStr.contains('bakelite') ||
        hwStr.contains('knurled') ||
        hwStr.contains('stepped') ||
        hwStr.contains('twotone') ||
        hwStr.contains('chrome') ||
        hwStr.contains('snes') ||
        hwStr.contains('minimal');

    final capColor = LuaGuiNode.parseColor(m['capColor'] ?? m['cap_color'] ?? m['cap']);
    final bodyColor = LuaGuiNode.parseColor(m['bodyColor'] ?? m['body_color'] ?? m['body']);
    final indicatorColor = LuaGuiNode.parseColor(m['indicatorColor'] ?? m['indicator_color'] ?? m['pointerColor'] ?? m['pointer_color'] ?? m['indicator']);
    final dialColor = LuaGuiNode.parseColor(m['dialColor'] ?? m['dial_color'] ?? m['scaleColor'] ?? m['scale_color']);

    final capSize = (m['capSize'] as num?)?.toDouble() ?? (m['cap_size'] as num?)?.toDouble();
    final bodySize = (m['bodySize'] as num?)?.toDouble() ?? (m['body_size'] as num?)?.toDouble() ?? (m['skirtSize'] as num?)?.toDouble();
    final indicatorLength = (m['indicatorLength'] as num?)?.toDouble() ?? (m['indicator_length'] as num?)?.toDouble();
    final indicatorWidth = (m['indicatorWidth'] as num?)?.toDouble() ?? (m['indicator_width'] as num?)?.toDouble();

    if (isHardware) {
      if (hwStr.contains('selector') || hwStr == 'tb303_selector') {
        hardwareKnobStyle = EatHardwareKnobStyle.tb303Selector(accentColor: accentColor);
      } else if (hwStr.contains('acid') || hwStr.contains('halo') || hwStr == 'tb303_acid_halo') {
        hardwareKnobStyle = EatHardwareKnobStyle.tb303AcidHalo(accentColor: accentColor);
      } else if (hwStr.contains('potentiometer') || hwStr.contains('sawtooth') || hwStr == 'tb303_potentiometer') {
        hardwareKnobStyle = EatHardwareKnobStyle.tb303Potentiometer(accentColor: accentColor);
      } else if (hwStr.contains('standard') || hwStr == 'standard_hardware') {
        hardwareKnobStyle = EatHardwareKnobStyle.standardHardware(accentColor: accentColor);
      } else if (hwStr.contains('chrome') || hwStr.contains('303')) {
        hardwareKnobStyle = EatHardwareKnobStyle.chromeFluted(accentColor: accentColor);
      } else if (hwStr.contains('snes')) {
        hardwareKnobStyle = EatHardwareKnobStyle.snesConsole(accentColor: accentColor);
      } else if (hwStr.contains('minimal') || hwStr.contains('ceramic')) {
        hardwareKnobStyle = EatHardwareKnobStyle.minimalWhite(accentColor: accentColor);
      } else if (hwStr.contains('fluted') || hwStr.contains('cream') || hwStr.contains('pitch')) {
        hardwareKnobStyle = EatHardwareKnobStyle.creamFluted(accentColor: accentColor);
      } else if (hwStr.contains('knurled') || hwStr.contains('metal') || hwStr.contains('sustain') || hwStr.contains('head')) {
        hardwareKnobStyle = EatHardwareKnobStyle.anodizedKnurled(isSustain: hwStr.contains('sustain'), accentColor: accentColor);
      } else if (hwStr.contains('stepped') || hwStr.contains('twotone') || hwStr.contains('punch') || hwStr.contains('rattle')) {
        hardwareKnobStyle = EatHardwareKnobStyle.twoToneStepped(accentColor: accentColor);
      } else if (hwStr.contains('encoder') || hwStr.contains('illuminated') || hwStr.contains('neon')) {
        hardwareKnobStyle = EatHardwareKnobStyle.illuminatedEncoder(activeColor: accentColor ?? const Color(0xFF00E5FF));
      } else {
        hardwareKnobStyle = EatHardwareKnobStyle.vintageBakelite(accentColor: accentColor);
      }

      if (capColor != null) hardwareKnobStyle = hardwareKnobStyle.copyWith(capColor: capColor);
      if (bodyColor != null) hardwareKnobStyle = hardwareKnobStyle.copyWith(bodyColor: bodyColor);
      if (indicatorColor != null) hardwareKnobStyle = hardwareKnobStyle.copyWith(indicatorColor: indicatorColor);
      if (dialColor != null) {
        hardwareKnobStyle = hardwareKnobStyle.copyWith(
          scale: hardwareKnobStyle.scale.copyWith(
            tickColor: dialColor,
            labelColor: dialColor,
          ),
        );
      }
      if (capSize != null) hardwareKnobStyle = hardwareKnobStyle.copyWith(capRadiusRatio: capSize);
      if (bodySize != null) hardwareKnobStyle = hardwareKnobStyle.copyWith(skirtRadiusRatio: bodySize);
      if (indicatorLength != null) hardwareKnobStyle = hardwareKnobStyle.copyWith(indicatorLength: indicatorLength);
      if (indicatorWidth != null) hardwareKnobStyle = hardwareKnobStyle.copyWith(indicatorWidth: indicatorWidth);
    }

    EatScaleGraduation? hardwareScale;
    final rawScale = m['scale'] ?? m['dialScale'] ?? m['graduations'];
    if (rawScale is List) {
      final labels = rawScale.map((e) => e.toString()).toList();
      hardwareScale = EatScaleGraduation(
        labels: labels,
        tickDivisions: math.max(1, labels.length - 1),
      );
    } else if (rawScale is String) {
      if (rawScale == '0_to_10' || rawScale == '0..10') {
        hardwareScale = EatScaleGraduation.zeroToTen();
      } else if (rawScale == 'low_mid_high' || rawScale == 'pitch') {
        hardwareScale = EatScaleGraduation.lowMidHigh();
      } else if (rawScale == '1_to_6' || rawScale == '1..6' || rawScale == 'sustain') {
        hardwareScale = EatScaleGraduation.sustainOneToSix();
      } else if (rawScale == 'db' || rawScale == 'decibel' || rawScale == 'fader') {
        hardwareScale = const EatScaleGraduation(
          tickDivisions: 12,
          labels: ['+6', '0', '-6', '-12', '-24', '-inf'],
        );
      }
    }

    if (hardwareKnobStyle != null && hardwareScale != null) {
      hardwareKnobStyle = hardwareKnobStyle.copyWith(scale: hardwareScale);
    }

    KnobStyle resolvedKnobStyle = knobStyle;
    if (customSkin != null) {
      resolvedKnobStyle = KnobStyle.customVector;
    } else if (hardwareKnobStyle != null) {
      resolvedKnobStyle = KnobStyle.hardwareKnob;
    }

    return LuaGuiNode(
      type: type,
      param: param,
      label: label,
      unit: unit,
      size: size,
      width: width,
      height: height,
      accentColor: accentColor,
      backgroundStyle: nodeBgStyle,
      backgroundColor: nodeBgColor,
      textureRotation: nodeTexRot,
      textureScale: nodeTexScale,
      cornerRadius: nodeCornerRadius,
      options: options,
      orientation: orientation,
      align: align,
      crossAlign: crossAlign,
      leftText: leftText,
      rightText: rightText,
      text: text,
      action: action,
      knobStyle: resolvedKnobStyle,
      sliderStyle: sliderStyle,
      canvasMode: canvasMode,
      cols: cols,
      rows: rows,
      scale: scale,
      showDpad: showDpad,
      showActionButtons: showActionButtons,
      showLabel: showLabel,
      showValue: showValue,
      palette: palette,
      customSkin: customSkin,
      hardwareKnobStyle: hardwareKnobStyle,
      hardwareScale: hardwareScale ?? hardwareKnobStyle?.scale,
      opacity: opacity,
      borderWidth: borderWidth,
      borderColor: borderColor,
      capColor: capColor,
      bodyColor: bodyColor,
      indicatorColor: indicatorColor,
      dialColor: dialColor,
      capSize: capSize,
      bodySize: bodySize,
      indicatorLength: indicatorLength,
      indicatorWidth: indicatorWidth,
      children: children,
    );
  }
}
