import 'dart:ui';
import 'lua_engine.dart';
import 'lua_gui_model.dart';
import 'lua_gui_parser.dart';

/// Serializes [LuaGuiPanelDef] and its component tree back into clean, readable Lua code.
class LuaGuiSerializer {
  /// Serializes a [LuaGuiPanelDef] into a `function <TableName>.gui()` code block.
  /// If [existingScriptCode] is provided, replaces or injects into the existing code.
  static String serialize({
    required LuaGuiPanelDef panel,
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

    // Otherwise, inject before `return <TableName>` or at the end
    final returnMatch = RegExp(r'return\s+([A-Za-z0-9_]+)', caseSensitive: false).firstMatch(existingScriptCode);
    if (returnMatch != null) {
      final before = existingScriptCode.substring(0, returnMatch.start).trimRight();
      final after = existingScriptCode.substring(returnMatch.start);
      return '$before\n\n$guiBlock\n\n$after';
    }

    return '${existingScriptCode.trimRight()}\n\n$guiBlock\n';
  }

  /// Synthesizes a default [LuaGuiPanelDef] from a list of parameter definitions.
  static LuaGuiPanelDef generateDefaultPanel({
    required String title,
    String? subtitle,
    List<LuaParamDef> params = const [],
    PanelBackgroundStyle backgroundStyle = PanelBackgroundStyle.dark,
    Color? accentColor,
    KnobStyle defaultKnobStyle = KnobStyle.standard,
  }) {
    final List<LuaGuiNode> rows = [];
    final List<LuaGuiNode> currentKnobs = [];

    for (final p in params) {
      if (p.options.isNotEmpty) {
        currentKnobs.add(LuaGuiNode(
          type: LuaGuiNodeType.listBox,
          param: p.name,
          label: p.name.toUpperCase(),
          options: p.options,
          width: 140,
          height: 75,
        ));
      } else {
        currentKnobs.add(LuaGuiNode(
          type: LuaGuiNodeType.knob,
          param: p.name,
          label: p.name.toUpperCase(),
          size: 52,
          knobStyle: defaultKnobStyle,
        ));
      }

      if (currentKnobs.length >= 4) {
        rows.add(LuaGuiNode(
          type: LuaGuiNodeType.row,
          children: List.from(currentKnobs),
        ));
        currentKnobs.clear();
      }
    }

    if (currentKnobs.isNotEmpty) {
      rows.add(LuaGuiNode(
        type: LuaGuiNodeType.row,
        children: List.from(currentKnobs),
      ));
    }

    if (rows.isEmpty) {
      rows.add(const LuaGuiNode(
        type: LuaGuiNodeType.row,
        children: [
          LuaGuiNode(type: LuaGuiNodeType.knob, param: 'Volume', label: 'VOLUME', size: 52),
          LuaGuiNode(type: LuaGuiNodeType.knob, param: 'Cutoff', label: 'CUTOFF', size: 52),
          LuaGuiNode(type: LuaGuiNodeType.knob, param: 'Resonance', label: 'RESO', size: 52),
        ],
      ));
    }

    return LuaGuiPanelDef(
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
    if (LuaGuiParser.parseFromCode(scriptCode) != null) {
      return scriptCode;
    }
    final compilation = LuaEngine.compile(scriptCode);
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

  static void _serializeNode(StringBuffer buffer, LuaGuiNode node, {required String indent}) {
    switch (node.type) {
      case LuaGuiNodeType.row:
        final rowAlignStr = (node.align != 'space_around' && node.align.isNotEmpty) ? ', align = "${node.align}"' : '';
        final rowCrossStr = (node.crossAlign != 'center' && node.crossAlign.isNotEmpty) ? ', crossAlign = "${node.crossAlign}"' : '';
        buffer.writeln('$indent{');
        buffer.writeln('$indent  type = "row"$rowAlignStr$rowCrossStr,');
        buffer.writeln('$indent  children = {');
        for (final child in node.children) {
          _serializeNode(buffer, child, indent: '$indent    ');
        }
        buffer.writeln('$indent  }');
        buffer.writeln('$indent},');
        break;

      case LuaGuiNodeType.column:
      case LuaGuiNodeType.group:
        final typeStr = node.type == LuaGuiNodeType.column ? 'column' : 'group';
        final colAlignStr = (node.align != 'space_around' && node.align != 'top' && node.align != 'start' && node.align.isNotEmpty) ? ', align = "${node.align}"' : '';
        final colCrossStr = (node.crossAlign != 'center' && node.crossAlign.isNotEmpty) ? ', crossAlign = "${node.crossAlign}"' : '';
        buffer.writeln('$indent{');
        buffer.writeln('$indent  type = "$typeStr"$colAlignStr$colCrossStr,');
        buffer.writeln('$indent  children = {');
        for (final child in node.children) {
          _serializeNode(buffer, child, indent: '$indent    ');
        }
        buffer.writeln('$indent  }');
        buffer.writeln('$indent},');
        break;

      case LuaGuiNodeType.knob:
        final param = node.param ?? 'Param';
        final label = node.label ?? param;
        final unitStr = node.unit != null && node.unit!.isNotEmpty ? ', unit = "${_escape(node.unit!)}"' : '';
        final sizeStr = node.size != null ? ', size = ${node.size!.toInt()}' : '';
        final styleStr = node.knobStyle != KnobStyle.standard ? ', knobStyle = "${_knobStyleToString(node.knobStyle)}"' : '';
        final showLabelStr = !node.showLabel ? ', showLabel = false' : '';
        final showValueStr = !node.showValue ? ', showValue = false' : '';
        buffer.writeln('$indent{ type = "knob", param = "$param", label = "${_escape(label)}"$unitStr$sizeStr$styleStr$showLabelStr$showValueStr },');
        break;

      case LuaGuiNodeType.slider:
      case LuaGuiNodeType.fader:
        final param = node.param ?? 'Param';
        final label = node.label ?? param;
        final isH = node.orientation == 'horizontal';
        final typeStr = isH ? 'hslider' : 'vslider';
        final widthStr = node.width != null ? ', width = ${node.width!.toInt()}' : (isH ? ', width = 460' : '');
        final heightStr = !isH && node.height != null ? ', height = ${node.height!.toInt()}' : '';
        final styleStr = node.sliderStyle == SliderStyle.console ? ', style = "console"' : ', style = "capsule"';
        final showLabelStr = !node.showLabel ? ', showLabel = false' : '';
        buffer.writeln('$indent{ type = "$typeStr", param = "$param", label = "${_escape(label)}"$widthStr$heightStr$styleStr$showLabelStr },');
        break;

      case LuaGuiNodeType.switchToggle:
        final param = node.param ?? 'Switch';
        final label = node.label ?? param;
        final leftStr = node.leftText != null ? ', leftText = "${_escape(node.leftText!)}"' : '';
        final rightStr = node.rightText != null ? ', rightText = "${_escape(node.rightText!)}"' : '';
        final orientStr = node.orientation == 'vertical' ? ', orientation = "vertical"' : '';
        final showLabelStr = !node.showLabel ? ', showLabel = false' : '';
        buffer.writeln('$indent{ type = "switch", param = "$param", label = "${_escape(label)}"$leftStr$rightStr$orientStr$showLabelStr },');
        break;

      case LuaGuiNodeType.button:
        final action = node.action ?? (node.param ?? 'action');
        final label = node.label ?? 'TRIGGER';
        final widthStr = node.width != null ? ', width = ${node.width!.toInt()}' : ', width = 100';
        final heightStr = node.height != null ? ', height = ${node.height!.toInt()}' : ', height = 36';
        buffer.writeln('$indent{ type = "button", action = "$action", label = "${_escape(label)}"$widthStr$heightStr },');
        break;

      case LuaGuiNodeType.listBox:
        final param = node.param ?? 'Choice';
        final label = node.label ?? param;
        final widthStr = node.width != null ? ', width = ${node.width!.toInt()}' : ', width = 140';
        final heightStr = node.height != null ? ', height = ${node.height!.toInt()}' : ', height = 80';
        final showLabelStr = !node.showLabel ? ', showLabel = false' : '';
        buffer.writeln('$indent{ type = "listbox", param = "$param", label = "${_escape(label)}"$widthStr$heightStr$showLabelStr },');
        break;

      case LuaGuiNodeType.nixie:
        final param = node.param ?? 'Nixie';
        final label = node.label ?? param;
        final unitStr = node.unit != null && node.unit!.isNotEmpty ? ', unit = "${_escape(node.unit!)}"' : '';
        final widthStr = node.width != null ? ', width = ${node.width!.toInt()}' : '';
        final showLabelStr = !node.showLabel ? ', showLabel = false' : '';
        buffer.writeln('$indent{ type = "nixie", param = "$param", label = "${_escape(label)}"$unitStr$widthStr$showLabelStr },');
        break;

      case LuaGuiNodeType.lcd:
        final param = node.param ?? 'LCD';
        final label = node.label ?? param;
        buffer.writeln('$indent{ type = "lcd", param = "$param", label = "${_escape(label)}" },');
        break;

      case LuaGuiNodeType.spaceVisualizer:
        final heightStr = node.height != null ? ', height = ${node.height!.toInt()}' : ', height = 140';
        buffer.writeln('$indent{ type = "space_visualizer"$heightStr },');
        break;

      case LuaGuiNodeType.waveshaperCanvas:
        final heightStr = node.height != null ? ', height = ${node.height!.toInt()}' : ', height = 150';
        buffer.writeln('$indent{ type = "waveshaper_canvas"$heightStr },');
        break;

      case LuaGuiNodeType.oscilloscope:
        final widthStr = node.width != null ? ', width = ${node.width!.toInt()}' : ', width = 320';
        final heightStr = node.height != null ? ', height = ${node.height!.toInt()}' : ', height = 140';
        buffer.writeln('$indent{ type = "oscilloscope"$widthStr$heightStr },');
        break;

      case LuaGuiNodeType.spectrum:
        final widthStr = node.width != null ? ', width = ${node.width!.toInt()}' : ', width = 320';
        final heightStr = node.height != null ? ', height = ${node.height!.toInt()}' : ', height = 140';
        buffer.writeln('$indent{ type = "spectrum"$widthStr$heightStr },');
        break;

      case LuaGuiNodeType.canvas:
        final mode = node.canvasMode;
        final widthStr = node.width != null ? ', width = ${node.width!.toInt()}' : ', width = 340';
        final heightStr = node.height != null ? ', height = ${node.height!.toInt()}' : ', height = 180';
        final dpadStr = node.showDpad ? ', showDpad = true' : '';
        final actionStr = node.showActionButtons ? ', showActionButtons = true' : '';
        buffer.writeln('$indent{ type = "canvas", mode = "$mode"$widthStr$heightStr$dpadStr$actionStr },');
        break;

      case LuaGuiNodeType.divider:
        buffer.writeln('$indent{ type = "divider" },');
        break;

      case LuaGuiNodeType.label:
        final text = node.text ?? (node.label ?? '');
        buffer.writeln('$indent{ type = "label", text = "${_escape(text)}" },');
        break;

      case LuaGuiNodeType.spacer:
        buffer.writeln('$indent{ type = "spacer" },');
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
      case KnobStyle.standard:
      default:
        return 'standard';
    }
  }
}
