import 'eats_lua_parser.dart';
import 'lua_gui_model.dart';

class LuaGuiParser {
  /// Extracts and parses the `LuaGuiPanelDef` from a Lua script string, if present.
  static LuaGuiPanelDef? parseFromCode(String luaCode) {
    if (!luaCode.contains('gui') && !luaCode.contains('GUI') && !luaCode.contains('panel') && !luaCode.contains('layout')) {
      return null;
    }

    try {
      // 1. Locate the GUI table block in the code
      final tableStr = _extractGuiTableString(luaCode);
      if (tableStr == null || tableStr.trim().isEmpty) {
        return null;
      }

      final parsed = EatsLuaParser.parseLuaTableToMap(tableStr);
      if (parsed.isEmpty) return null;

      // Handle both { panel = { title = "...", layout = {...} } } and { title = "...", layout = {...} }
      Map<String, dynamic> panelMap = parsed;
      if (parsed['panel'] is Map) {
        panelMap = Map<String, dynamic>.from(parsed['panel']);
      }

      final title = (panelMap['title'] as String?) ?? 'CUSTOM INSTRUMENT';
      final subtitle = panelMap['subtitle'] as String?;
      final style = (panelMap['style'] as String?) ?? 'rack';
      final accentColor = LuaGuiNode.parseColor(panelMap['accent'] ?? panelMap['accentColor'] ?? panelMap['color']);

      final rawLayout = panelMap['layout'] ?? panelMap['children'] ?? panelMap['items'];
      final List<LuaGuiNode> nodes = [];

      if (rawLayout is List) {
        for (final item in rawLayout) {
          final node = _parseNode(item);
          if (node != null) nodes.add(node);
        }
      } else if (rawLayout is Map) {
        final node = _parseNode(rawLayout);
        if (node != null) nodes.add(node);
      }

      if (nodes.isEmpty) return null;

      return LuaGuiPanelDef(
        title: title,
        subtitle: subtitle,
        style: style,
        accentColor: accentColor,
        children: nodes,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _extractGuiTableString(String luaCode) {
    // Look for `function ...gui()... return { ... } end`
    final guiFuncMatch = RegExp(r'function\s+[\w\.:]*gui\s*\([^)]*\)[\s\S]*?return\s*(\{[\s\S]*?\})\s*end', caseSensitive: false).firstMatch(luaCode);
    if (guiFuncMatch != null) {
      return _extractBalancedTable(luaCode, guiFuncMatch.start);
    }

    // Look for `GUI\s*=\s*\{` or `local\s+GUI\s*=\s*\{` or `\w+\.gui\s*=\s*\{`
    final guiAssignMatch = RegExp(r'(?:local\s+)?(?:[\w\.]+\.)?gui\s*=\s*\{', caseSensitive: false).firstMatch(luaCode);
    if (guiAssignMatch != null) {
      return _extractBalancedTable(luaCode, guiAssignMatch.start);
    }

    // Look for `@gui:\s*\{`
    final commentGuiMatch = RegExp(r'--\s*@gui:\s*\{', caseSensitive: false).firstMatch(luaCode);
    if (commentGuiMatch != null) {
      return _extractBalancedTable(luaCode, commentGuiMatch.start);
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

  static LuaGuiNode? _parseNode(dynamic raw) {
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
    final orientation = (m['orientation'] as String?) ?? 'vertical';
    final align = (m['align'] as String?) ?? 'space_around';
    final leftText = m['left'] as String? ?? m['leftText'] as String?;
    final rightText = m['right'] as String? ?? m['rightText'] as String?;
    final text = m['text'] as String?;

    final width = (m['width'] is num) ? (m['width'] as num).toDouble() : null;
    final height = (m['height'] is num) ? (m['height'] as num).toDouble() : null;

    List<String> options = [];
    if (m['options'] is List) {
      options = (m['options'] as List).map((e) => e.toString()).toList();
    }

    List<LuaGuiNode> children = [];
    final rawChildren = m['children'] ?? m['items'] ?? m['__list'];
    if (rawChildren is List) {
      for (final childRaw in rawChildren) {
        final childNode = _parseNode(childRaw);
        if (childNode != null) children.add(childNode);
      }
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
      options: options,
      orientation: orientation,
      align: align,
      leftText: leftText,
      rightText: rightText,
      text: text,
      children: children,
    );
  }
}
