import 'dart:math' as math;
import '../lua/eats_lua_parser.dart';
import 'eat_param_model.dart';

/// Transpiles legacy Lua preset and script definitions into pure, Pythonic Eatscript.
class EatTranspiler {
  /// Transpiles a Lua preset script into idiomatic Eatscript.
  static String transpileLuaPreset(String luaCode) {
    final lines = luaCode.split('\n');
    final buffer = StringBuffer();

    // 1. Extract and convert header metadata
    String? id;
    String? name;
    String? category;
    String? description;
    final List<String> tags = [];

    for (final line in lines) {
      final trimmed = line.trim();
      final clean = trimmed.startsWith('--')
          ? trimmed.substring(2).trim()
          : (trimmed.startsWith('#') ? trimmed.substring(1).trim() : trimmed);

      if (clean.startsWith('@id:')) {
        id = clean.substring(4).trim();
      } else if (clean.startsWith('@name:')) {
        name = clean.substring(6).trim();
      } else if (clean.startsWith('@category:')) {
        category = clean.substring(10).trim();
      } else if (clean.startsWith('@description:')) {
        description = clean.substring(13).trim();
      } else if (clean.startsWith('@tags:') || clean.startsWith('@tag:')) {
        final prefixLen = clean.startsWith('@tags:') ? 6 : 5;
        final rawTags = clean.substring(prefixLen).split(',');
        for (final t in rawTags) {
          final ct = t.trim().toLowerCase();
          if (ct.isNotEmpty && !tags.contains(ct)) tags.add(ct);
        }
      }
    }

    if (id != null) buffer.writeln('# @id: $id');
    if (name != null) buffer.writeln('# @name: $name');
    if (category != null) buffer.writeln('# @category: $category');
    if (description != null) buffer.writeln('# @description: $description');
    if (tags.isNotEmpty) buffer.writeln('# @tags: ${tags.join(', ')}');
    buffer.writeln();

    // 2. Discover parameters from Param.add / Param.choice
    final params = extractLuaParams(luaCode);

    buffer.writeln('# --- Parameter Definitions ---');
    buffer.writeln('def init():');
    buffer.writeln('    return {');
    for (final p in params) {
      if (p.options.isNotEmpty) {
        final optsStr = p.options.map((o) => '"$o"').join(', ');
        buffer.writeln('        "${p.name}": eat.param("${p.name}", ${p.min}, ${p.max}, ${p.defaultValue}, options=[$optsStr]),');
      } else {
        buffer.writeln('        "${p.name}": eat.param("${p.name}", ${p.min}, ${p.max}, ${p.defaultValue}, step=${p.step}),');
      }
    }
    buffer.writeln('    }');
    buffer.writeln();

    // 3. Extract and convert GUI layout if present
    final guiTableStr = _extractGuiTableString(luaCode);
    if (guiTableStr != null) {
      final parsedMap = EatsLuaParser.parseLuaTableToMap(guiTableStr);
      if (parsedMap.isNotEmpty) {
        buffer.writeln('# --- Hardware GUI Layout ---');
        buffer.writeln('def gui():');
        buffer.writeln('    return {');
        _formatMap(parsedMap, buffer, indentLevel: 2);
        buffer.writeln('    }');
        buffer.writeln();
      }
    }

    // 4. Extract transform_notes / split / run / process algorithmic hooks if present
    if (luaCode.contains('transform_notes')) {
      buffer.writeln('# --- MIDI Transformation Hook ---');
      buffer.writeln('def transform_notes(notes, params, time_context):');
      if (luaCode.contains('arpeggiat') || luaCode.contains('Midi.arpeggiate')) {
        buffer.writeln('    return eat.arpeggiate(notes, rate=params.get("Rate", 1.0), octaves=params.get("Octaves", 2))');
      } else if (luaCode.contains('chord_follow') || luaCode.contains('Midi.chord_follow')) {
        buffer.writeln('    return eat.chord_follow(notes, mode=params.get("Mode", 0))');
      } else if (luaCode.contains('scale_snap') || luaCode.contains('Midi.scale_snap')) {
        buffer.writeln('    return eat.scale_snap(notes, key=params.get("Key", 0))');
      } else if (luaCode.contains('humanize') || luaCode.contains('Humanize')) {
        buffer.writeln('    return eat.humanize(notes, timing=params.get("Timing", 0.04), velocity=params.get("Velocity", 0.15))');
      } else {
        buffer.writeln('    return notes');
      }
      buffer.writeln();
    } else if (luaCode.contains('function split(')) {
      buffer.writeln('# --- Note Splitter Hook ---');
      buffer.writeln('def split(notes, params):');
      buffer.writeln('    return [');
      buffer.writeln('        {"name": "Voice 1", "notes": notes},');
      buffer.writeln('    ]');
      buffer.writeln();
    } else if (luaCode.contains('function run(')) {
      buffer.writeln('# --- Project Action Hook ---');
      buffer.writeln('def run(project, params):');
      buffer.writeln('    return params');
      buffer.writeln();
    } else if (luaCode.contains('.process(') || luaCode.contains('function process(')) {
      if (category == 'audioFx' || luaCode.contains('input_l') || luaCode.contains('input_r')) {
        buffer.writeln('# --- Audio FX DSP Process Hook ---');
        buffer.writeln('def process(input_l, input_r, params):');
        buffer.writeln('    return [input_l, input_r]');
        buffer.writeln();
      } else {
        buffer.writeln('# --- Synthesizer Voice DSP Process Hook ---');
        buffer.writeln('def process(time, freq, note, params):');
        buffer.writeln('    return 0.0');
        buffer.writeln();
      }
    }

    // 5. Preserve table name if present (for audio engine voice/DSP identifier matching)
    final tableNameMatch = RegExp(r'local\s+([A-Za-z0-9_]+)\s*=\s*\{\}').firstMatch(luaCode);
    final tableName = tableNameMatch?.group(1);
    if (tableName != null) {
      buffer.writeln('$tableName = True');
    }

    return buffer.toString();
  }

  static String? _extractGuiTableString(String code) {
    // 1. function ...gui()... return { ... }
    final funcMatch = RegExp(r'function\s+[\w\.:]*gui\s*\([^)]*\)[\s\S]*?return\s*\{', caseSensitive: false).firstMatch(code);
    if (funcMatch != null) {
      final braceIdx = code.indexOf('{', funcMatch.start);
      if (braceIdx != -1) return _extractBalancedTable(code, braceIdx);
    }

    // 2. GUI = { or .gui = { or local GUI = {
    final assignMatch = RegExp(r'(?:local\s+)?(?:[\w\.]+\.)?gui\s*=\s*\{', caseSensitive: false).firstMatch(code);
    if (assignMatch != null) {
      final braceIdx = code.indexOf('{', assignMatch.start);
      if (braceIdx != -1) return _extractBalancedTable(code, braceIdx);
    }

    // 3. -- @gui: {
    final commentMatch = RegExp(r'--\s*@gui:\s*\{', caseSensitive: false).firstMatch(code);
    if (commentMatch != null) {
      final braceIdx = code.indexOf('{', commentMatch.start);
      if (braceIdx != -1) return _extractBalancedTable(code, braceIdx);
    }

    // 4. Fallback: search for `.gui()`
    final callMatch = RegExp(r'[\w\.:]+gui\s*\(\)', caseSensitive: false).firstMatch(code);
    if (callMatch != null) {
      final braceIdx = code.indexOf('{', callMatch.start);
      if (braceIdx != -1) return _extractBalancedTable(code, braceIdx);
    }

    return null;
  }

  static String? _extractBalancedTable(String code, int startBrace) {
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

  static void _formatMap(Map<String, dynamic> map, StringBuffer buffer, {required int indentLevel}) {
    final indent = '    ' * indentLevel;
    for (final entry in map.entries) {
      final key = entry.key;
      final val = entry.value;

      if (val is Map) {
        buffer.writeln('$indent"$key": {');
        _formatMap(Map<String, dynamic>.from(val), buffer, indentLevel: indentLevel + 1);
        buffer.writeln('$indent},');
      } else if (val is List) {
        buffer.writeln('$indent"$key": [');
        _formatList(val, buffer, indentLevel: indentLevel + 1);
        buffer.writeln('$indent],');
      } else if (val is String) {
        buffer.writeln('$indent"$key": "$val",');
      } else if (val is bool) {
        buffer.writeln('$indent"$key": ${val ? "True" : "False"},');
      } else if (val == null) {
        buffer.writeln('$indent"$key": None,');
      } else {
        buffer.writeln('$indent"$key": $val,');
      }
    }
  }

  static void _formatList(List list, StringBuffer buffer, {required int indentLevel}) {
    final indent = '    ' * indentLevel;
    for (final item in list) {
      if (item is Map) {
        buffer.writeln('$indent{');
        _formatMap(Map<String, dynamic>.from(item), buffer, indentLevel: indentLevel + 1);
        buffer.writeln('$indent},');
      } else if (item is List) {
        buffer.writeln('$indent[');
        _formatList(item, buffer, indentLevel: indentLevel + 1);
        buffer.writeln('$indent],');
      } else if (item is String) {
        buffer.writeln('$indent"$item",');
      } else if (item is bool) {
        buffer.writeln('$indent${item ? "True" : "False"},');
      } else if (item == null) {
        buffer.writeln('${indent}None,');
      } else {
        buffer.writeln('$indent$item,');
      }
    }
  }

  static final RegExp _paramRegExp = RegExp(
    "Param\\.add\\(\\s*[\"']([^\"']+)[\"']\\s*,\\s*([\\d\\.-]+)\\s*,\\s*([\\d\\.-]+)\\s*,\\s*([\\d\\.-]+)(?:\\s*,\\s*([\\d\\.-]+))?\\s*\\)",
  );

  static final RegExp _choiceParamRegExp = RegExp(
    "Param\\.choice\\(\\s*[\"']([^\"']+)[\"']\\s*,\\s*\\{([^\\}]+)\\}\\s*(?:,\\s*([\\d\\.-]+))?\\s*\\)",
  );

  static final RegExp _v1ParamRegExp = RegExp(
    "getParam\\(\\s*[\"']([^\"']+)[\"']\\s*\\)",
  );

  static final RegExp _clipParamRegExp = RegExp(
    "registerParam\\(\\s*[\"']([^\"']+)[\"']\\s*,\\s*([\\d\\.-]+)\\s*,\\s*([\\d\\.-]+)\\s*,\\s*([\\d\\.-]+)\\s*\\)",
  );

  /// Extracts declared parameters from legacy Lua source code without requiring a Lua runtime.
  static List<LuaParamDef> extractLuaParams(String code) {
    final positionedParams = <MapEntry<int, LuaParamDef>>[];

    // 1. Parse Param.add("Name", min, max, default, [step])
    for (final m in _paramRegExp.allMatches(code)) {
      final name = m.group(1)!;
      final minVal = double.tryParse(m.group(2)!) ?? 0.0;
      final maxVal = double.tryParse(m.group(3)!) ?? 1.0;
      final defVal = double.tryParse(m.group(4)!) ?? minVal;
      final stepVal = (m.groupCount >= 5 && m.group(5) != null) ? (double.tryParse(m.group(5)!) ?? 0.0) : 0.0;

      positionedParams.add(MapEntry(
        m.start,
        LuaParamDef(
          name: name,
          min: minVal,
          max: maxVal,
          defaultValue: defVal,
          step: stepVal,
        ),
      ));
    }

    // 2. Parse Param.choice("Name", {"Opt1", "Opt2", ...}, [defaultIdx])
    for (final m in _choiceParamRegExp.allMatches(code)) {
      final name = m.group(1)!;
      final rawOpts = m.group(2)!;
      final defIdx = (m.groupCount >= 3 && m.group(3) != null) ? (double.tryParse(m.group(3)!) ?? 0.0) : 0.0;

      final optsList = rawOpts
          .split(',')
          .map((s) => s.trim().replaceAll(RegExp("^[\"']|[\"']\$"), ''))
          .where((s) => s.isNotEmpty)
          .toList();

      final maxVal = math.max(0, optsList.length - 1).toDouble();

      if (!positionedParams.any((e) => e.value.name == name)) {
        positionedParams.add(MapEntry(
          m.start,
          LuaParamDef(
            name: name,
            min: 0.0,
            max: maxVal,
            defaultValue: defIdx.clamp(0.0, maxVal),
            step: 1.0,
            options: optsList,
          ),
        ));
      }
    }

    // 3. Check for clip:registerParam
    for (final m in _clipParamRegExp.allMatches(code)) {
      final name = m.group(1)!;
      final minVal = double.tryParse(m.group(2)!) ?? 0.0;
      final maxVal = double.tryParse(m.group(3)!) ?? 1.0;
      final defVal = double.tryParse(m.group(4)!) ?? minVal;

      if (!positionedParams.any((e) => e.value.name == name)) {
        positionedParams.add(MapEntry(
          m.start,
          LuaParamDef(
            name: name,
            min: minVal,
            max: maxVal,
            defaultValue: defVal,
          ),
        ));
      }
    }

    // 4. Check for getParam handles
    for (final m in _v1ParamRegExp.allMatches(code)) {
      final name = m.group(1)!;
      if (!positionedParams.any((e) => e.value.name == name)) {
        positionedParams.add(MapEntry(
          m.start,
          LuaParamDef(
            name: name,
            min: 0.0,
            max: 1.0,
            defaultValue: 0.5,
          ),
        ));
      }
    }

    positionedParams.sort((a, b) => a.key.compareTo(b.key));
    return positionedParams.map((e) => e.value).toList();
  }
}
